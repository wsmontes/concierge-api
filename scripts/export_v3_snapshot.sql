-- =============================================================================
-- Concierge Analyzer - V3 Database Snapshot Export
-- Purpose: Export complete V3 database state for analysis/sharing
-- Dependencies: MySQL 8.0+
-- Usage: mysql -u root -p concierge < export_v3_snapshot.sql > v3_snapshot.txt
-- =============================================================================

SELECT '============================================' AS '';
SELECT 'CONCIERGE ANALYZER V3 DATABASE SNAPSHOT' AS '';
SELECT '============================================' AS '';
SELECT NOW() AS 'Generated At';
SELECT DATABASE() AS 'Database';
SELECT '' AS '';

-- =============================================================================
-- SCHEMA INFORMATION
-- =============================================================================

SELECT '============================================' AS '';
SELECT 'TABLES' AS '';
SELECT '============================================' AS '';

SHOW TABLES LIKE '%_v3';

SELECT '' AS '';
SELECT '------- entities_v3 Structure -------' AS '';
SHOW CREATE TABLE entities_v3\G

SELECT '' AS '';
SELECT '------- curations_v3 Structure -------' AS '';
SHOW CREATE TABLE curations_v3\G

-- =============================================================================
-- INDEXES
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'INDEXES ON entities_v3' AS '';
SELECT '============================================' AS '';

SHOW INDEX FROM entities_v3;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'INDEXES ON curations_v3' AS '';
SELECT '============================================' AS '';

SHOW INDEX FROM curations_v3;

-- =============================================================================
-- VIEWS
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'VIEWS' AS '';
SELECT '============================================' AS '';

SELECT TABLE_NAME, VIEW_DEFINITION 
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE 'vw_%'
ORDER BY TABLE_NAME;

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'STORED FUNCTIONS' AS '';
SELECT '============================================' AS '';

SELECT ROUTINE_NAME, ROUTINE_DEFINITION, DTD_IDENTIFIER AS RETURNS
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
  AND ROUTINE_TYPE = 'FUNCTION'
ORDER BY ROUTINE_NAME;

-- =============================================================================
-- DATA COUNTS
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'DATA SUMMARY' AS '';
SELECT '============================================' AS '';

SELECT 
  'entities_v3' AS table_name,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT type) AS unique_types,
  MIN(created_at) AS oldest_record,
  MAX(created_at) AS newest_record
FROM entities_v3;

SELECT 
  'curations_v3' AS table_name,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT entity_id) AS unique_entities,
  COUNT(DISTINCT JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id'))) AS unique_curators,
  MIN(created_at) AS oldest_record,
  MAX(created_at) AS newest_record
FROM curations_v3;

-- =============================================================================
-- ENTITIES DATA
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'ENTITIES DATA (Full JSON)' AS '';
SELECT '============================================' AS '';

SELECT 
  id,
  type,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) AS status,
  created_at,
  updated_at,
  version,
  JSON_PRETTY(doc) AS document
FROM entities_v3
ORDER BY type, id;

-- =============================================================================
-- CURATIONS DATA
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'CURATIONS DATA (Full JSON)' AS '';
SELECT '============================================' AS '';

SELECT 
  id,
  entity_id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id')) AS curator_id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.name')) AS curator_name,
  created_at,
  updated_at,
  version,
  JSON_PRETTY(doc) AS document
FROM curations_v3
ORDER BY entity_id, id;

-- =============================================================================
-- ANALYSIS QUERIES
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'ENTITY TYPE DISTRIBUTION' AS '';
SELECT '============================================' AS '';

SELECT 
  type,
  COUNT(*) AS count,
  GROUP_CONCAT(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) SEPARATOR ', ') AS entities
FROM entities_v3
GROUP BY type
ORDER BY count DESC;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'ENTITY STATUS DISTRIBUTION' AS '';
SELECT '============================================' AS '';

SELECT 
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) AS status,
  COUNT(*) AS count,
  GROUP_CONCAT(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) SEPARATOR ', ') AS entities
FROM entities_v3
GROUP BY status
ORDER BY count DESC;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'METADATA TYPES IN USE' AS '';
SELECT '============================================' AS '';

SELECT DISTINCT
  jt.metadata_type,
  COUNT(*) AS entity_count
FROM entities_v3 e
CROSS JOIN JSON_TABLE(
  e.doc,
  '$.metadata[*]' COLUMNS (
    metadata_type VARCHAR(128) PATH '$.type'
  )
) jt
GROUP BY jt.metadata_type
ORDER BY entity_count DESC;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'CURATIONS PER ENTITY' AS '';
SELECT '============================================' AS '';

SELECT 
  e.id AS entity_id,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.name')) AS entity_name,
  e.type AS entity_type,
  COUNT(c.id) AS curation_count,
  GROUP_CONCAT(JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.name')) SEPARATOR ', ') AS curators
FROM entities_v3 e
LEFT JOIN curations_v3 c ON e.id = c.entity_id
GROUP BY e.id, entity_name, e.type
ORDER BY curation_count DESC, entity_name;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'CURATORS ACTIVITY' AS '';
SELECT '============================================' AS '';

SELECT 
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id')) AS curator_id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.name')) AS curator_name,
  COUNT(*) AS total_curations,
  COUNT(DISTINCT entity_id) AS entities_curated,
  MIN(created_at) AS first_curation,
  MAX(created_at) AS last_curation
FROM curations_v3
GROUP BY curator_id, curator_name
ORDER BY total_curations DESC;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'CATEGORY USAGE (All Categories)' AS '';
SELECT '============================================' AS '';

SELECT 
  category,
  COUNT(*) AS usage_count,
  COUNT(DISTINCT curation_id) AS curations_using_it
FROM vw_curation_concepts
GROUP BY category
ORDER BY usage_count DESC;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'TOP CONCEPTS BY CATEGORY' AS '';
SELECT '============================================' AS '';

SELECT 
  category,
  concept,
  COUNT(*) AS usage_count
FROM vw_curation_concepts
GROUP BY category, concept
ORDER BY category, usage_count DESC, concept;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'SYNC STATUS (if applicable)' AS '';
SELECT '============================================' AS '';

SELECT 
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.sync.status')) AS sync_status,
  COUNT(*) AS count,
  GROUP_CONCAT(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) SEPARATOR ', ') AS entities
FROM entities_v3
WHERE JSON_EXTRACT(doc, '$.sync') IS NOT NULL
GROUP BY sync_status;

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'ENTITIES WITH SERVER IDs' AS '';
SELECT '============================================' AS '';

SELECT 
  id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name,
  CAST(JSON_EXTRACT(doc, '$.sync.serverId') AS UNSIGNED) AS server_id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.sync.status')) AS sync_status,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.sync.lastSyncedAt')) AS last_synced
FROM entities_v3
WHERE JSON_EXTRACT(doc, '$.sync.serverId') IS NOT NULL
ORDER BY server_id;

-- =============================================================================
-- JSON STRUCTURE VALIDATION
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT 'JSON STRUCTURE VALIDATION' AS '';
SELECT '============================================' AS '';

SELECT 
  'entities_v3' AS table_name,
  'All documents valid' AS status,
  COUNT(*) AS valid_count
FROM entities_v3
WHERE JSON_VALID(doc) = 1
  AND JSON_TYPE(JSON_EXTRACT(doc, '$.name')) = 'STRING'
  AND JSON_TYPE(JSON_EXTRACT(doc, '$.metadata')) = 'ARRAY';

SELECT 
  'curations_v3' AS table_name,
  'All documents valid' AS status,
  COUNT(*) AS valid_count
FROM curations_v3
WHERE JSON_VALID(doc) = 1
  AND JSON_TYPE(JSON_EXTRACT(doc, '$.curator')) = 'OBJECT'
  AND JSON_TYPE(JSON_EXTRACT(doc, '$.categories')) = 'OBJECT';

-- =============================================================================
-- COMPLETION
-- =============================================================================

SELECT '' AS '';
SELECT '============================================' AS '';
SELECT '✅ SNAPSHOT EXPORT COMPLETE' AS '';
SELECT '============================================' AS '';
SELECT NOW() AS 'Completed At';
