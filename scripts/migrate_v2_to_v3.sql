-- =============================================================================
-- Migration Script: V2 to V3
-- Purpose: Transform existing data from V2 schema to document-oriented V3
-- Dependencies: Requires schema_v3.sql to be executed first
-- Safety: Uses temporary staging, can be rolled back before final commit
-- =============================================================================

-- Start transaction for safety
START TRANSACTION;

-- =============================================================================
-- STEP 1: Verify V3 schema exists
-- =============================================================================

SELECT 'Checking V3 schema...' AS step;

SELECT 
  CASE 
    WHEN (SELECT COUNT(*) FROM information_schema.tables 
          WHERE table_schema = DATABASE() AND table_name = 'entities_v3') = 0
    THEN 'ERROR: entities_v3 table does not exist. Run schema_v3.sql first.'
    WHEN (SELECT COUNT(*) FROM information_schema.tables 
          WHERE table_schema = DATABASE() AND table_name = 'curations_v3') = 0
    THEN 'ERROR: curations_v3 table does not exist. Run schema_v3.sql first.'
    ELSE 'OK: V3 schema exists'
  END AS validation_result;

-- =============================================================================
-- STEP 2: Check if V2 tables exist
-- =============================================================================

SELECT 'Checking for V2 data sources...' AS step;

-- Determine which V2 table exists (could be 'entities' or 'entities_v2')
SET @v2_entities_table = (
  SELECT table_name 
  FROM information_schema.tables 
  WHERE table_schema = DATABASE() 
    AND table_name IN ('entities', 'entities_v2')
  LIMIT 1
);

SET @v2_curations_table = (
  SELECT table_name 
  FROM information_schema.tables 
  WHERE table_schema = DATABASE() 
    AND table_name IN ('curations', 'curations_v2')
  LIMIT 1
);

SELECT 
  COALESCE(@v2_entities_table, 'NOT FOUND') AS entities_source_table,
  COALESCE(@v2_curations_table, 'NOT FOUND') AS curations_source_table;

-- =============================================================================
-- STEP 3: Migrate ENTITIES
-- Purpose: Transform V2 entity structure into V3 JSON documents
-- =============================================================================

SELECT 'Migrating entities to V3...' AS step;

-- Option A: If V2 has separate columns (models_v2.py structure)
-- Adjust this based on your actual V2 schema

INSERT INTO entities_v3 (id, type, doc, created_at, updated_at, version)
SELECT 
  -- Assuming V2 has columns: id, type, name, status, metadata (JSON), created_at, updated_at
  id,
  type,
  
  -- Build JSON document from V2 columns
  JSON_OBJECT(
    'name', name,
    'status', COALESCE(status, 'draft'),
    'metadata', COALESCE(metadata, JSON_ARRAY()),
    
    -- Sync information (if exists in V2)
    'sync', JSON_OBJECT(
      'serverId', external_id,
      'status', CASE 
        WHEN external_id IS NOT NULL THEN 'synced'
        ELSE 'pending'
      END,
      'lastSyncedAt', updated_at
    ),
    
    -- Audit fields (optional in V3 doc)
    'createdBy', COALESCE(created_by, 'migration'),
    'updatedBy', COALESCE(updated_by, 'migration')
  ) AS doc,
  
  COALESCE(created_at, CURRENT_TIMESTAMP(3)),
  COALESCE(updated_at, CURRENT_TIMESTAMP(3)),
  1  -- Reset version to 1 for migration
  
FROM entities  -- Change to entities_v2 if that's your source table
WHERE NOT EXISTS (
  SELECT 1 FROM entities_v3 WHERE entities_v3.id = entities.id
);

-- Report migration results
SELECT 
  'Entities migrated' AS step,
  COUNT(*) AS total_entities,
  SUM(CASE WHEN type = 'restaurant' THEN 1 ELSE 0 END) AS restaurants,
  SUM(CASE WHEN type = 'hotel' THEN 1 ELSE 0 END) AS hotels,
  SUM(CASE WHEN type = 'attraction' THEN 1 ELSE 0 END) AS attractions,
  SUM(CASE WHEN type = 'event' THEN 1 ELSE 0 END) AS events,
  SUM(CASE WHEN type = 'other' THEN 1 ELSE 0 END) AS other
FROM entities_v3;

-- =============================================================================
-- STEP 4: Migrate CURATIONS
-- Purpose: Transform V2 curation structure into V3 JSON documents
-- =============================================================================

SELECT 'Migrating curations to V3...' AS step;

-- Option A: If V2 has separate columns
INSERT INTO curations_v3 (id, entity_id, doc, created_at, updated_at, version)
SELECT 
  -- Assuming V2 has: id, entity_id, curator_id, curator_name, categories (JSON), created_at
  id,
  entity_id,
  
  -- Build JSON document from V2 columns
  JSON_OBJECT(
    'curator', JSON_OBJECT(
      'id', curator_id,
      'name', COALESCE(curator_name, curator_id),
      'email', curator_email  -- If exists
    ),
    'createdAt', COALESCE(created_at, CURRENT_TIMESTAMP(3)),
    'updatedAt', COALESCE(updated_at, created_at, CURRENT_TIMESTAMP(3)),
    'categories', COALESCE(categories, JSON_OBJECT()),
    'sources', COALESCE(sources, JSON_ARRAY('migrated from V2')),
    'notes', JSON_OBJECT(
      'public', COALESCE(public_notes, ''),
      'private', COALESCE(private_notes, '')
    )
  ) AS doc,
  
  COALESCE(created_at, CURRENT_TIMESTAMP(3)),
  COALESCE(updated_at, CURRENT_TIMESTAMP(3)),
  1  -- Reset version to 1 for migration
  
FROM curations  -- Change to curations_v2 if that's your source table
WHERE NOT EXISTS (
  SELECT 1 FROM curations_v3 WHERE curations_v3.id = curations.id
)
AND entity_id IN (SELECT id FROM entities_v3);  -- Only migrate if entity exists

-- Report migration results
SELECT 
  'Curations migrated' AS step,
  COUNT(*) AS total_curations,
  COUNT(DISTINCT entity_id) AS unique_entities_curated,
  COUNT(DISTINCT JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id'))) AS unique_curators
FROM curations_v3;

-- =============================================================================
-- STEP 5: Validate migrated data
-- =============================================================================

SELECT 'Validating migrated data...' AS step;

-- Check for entities without required fields
SELECT 
  'Entities with invalid documents' AS validation,
  COUNT(*) AS count
FROM entities_v3
WHERE JSON_EXTRACT(doc, '$.name') IS NULL
   OR JSON_EXTRACT(doc, '$.metadata') IS NULL
   OR NOT JSON_VALID(doc);

-- Check for curations without required fields
SELECT 
  'Curations with invalid documents' AS validation,
  COUNT(*) AS count
FROM curations_v3
WHERE JSON_EXTRACT(doc, '$.curator') IS NULL
   OR JSON_EXTRACT(doc, '$.categories') IS NULL
   OR NOT JSON_VALID(doc);

-- Check for orphaned curations (should be 0 due to WHERE clause)
SELECT 
  'Orphaned curations' AS validation,
  COUNT(*) AS count
FROM curations_v3 c
WHERE NOT EXISTS (SELECT 1 FROM entities_v3 e WHERE e.id = c.entity_id);

-- Sample documents to verify structure
SELECT 
  'Sample entity document' AS sample,
  id,
  type,
  JSON_PRETTY(doc) AS document
FROM entities_v3
LIMIT 1;

SELECT 
  'Sample curation document' AS sample,
  id,
  entity_id,
  JSON_PRETTY(doc) AS document
FROM curations_v3
LIMIT 1;

-- =============================================================================
-- STEP 6: Performance check - ensure indexes are used
-- =============================================================================

SELECT 'Checking index usage...' AS step;

-- Test functional index on name
EXPLAIN SELECT * FROM entities_v3 
WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) LIKE '%fogo%';

-- Test functional index on curator
EXPLAIN SELECT * FROM curations_v3 
WHERE JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id')) = 'curator_wagner';

-- =============================================================================
-- FINAL STEP: Commit or Rollback
-- =============================================================================

-- Review all output above. If everything looks correct:
-- COMMIT;

-- If there are issues:
-- ROLLBACK;

SELECT 
  'Migration complete. Review results above.' AS status,
  'Execute COMMIT to finalize or ROLLBACK to undo.' AS action;

-- =============================================================================
-- POST-MIGRATION: Optional cleanup (DO NOT RUN until verified)
-- =============================================================================

-- After verifying V3 works correctly, you can optionally:
-- 1. Rename V2 tables for backup:
--    RENAME TABLE entities TO entities_v2_backup;
--    RENAME TABLE curations TO curations_v2_backup;
--
-- 2. Create aliases for backward compatibility:
--    CREATE VIEW entities AS SELECT * FROM vw_entities;
--    CREATE VIEW curations AS SELECT * FROM vw_curations;
--
-- 3. Or drop V2 tables entirely (DANGEROUS - ensure backups exist):
--    DROP TABLE IF EXISTS entities_v2_backup;
--    DROP TABLE IF EXISTS curations_v2_backup;
