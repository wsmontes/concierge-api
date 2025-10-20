-- =============================================================================
-- V3 Example Queries
-- Purpose: Demonstrate JSON_TABLE, functional indexes, and document queries
-- Dependencies: schema_v3.sql must be executed first with sample data
-- Usage: Run these queries to understand V3's capabilities
-- =============================================================================

-- =============================================================================
-- SECTION 1: BASIC ENTITY QUERIES
-- =============================================================================

-- Query 1.1: Get complete entity document
SELECT 
  id,
  type,
  JSON_PRETTY(doc) AS document,
  version
FROM entities_v3
WHERE id = 'rest_fogo_de_chao_jardins';

-- Query 1.2: List all restaurants by name (uses functional index)
SELECT 
  id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) AS status,
  updated_at
FROM entities_v3
WHERE type = 'restaurant'
ORDER BY JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) ASC
LIMIT 50;

-- Query 1.3: Search entities by name (case-insensitive, uses functional index)
SELECT 
  id,
  type,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name
FROM entities_v3
WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) LIKE LOWER('%fogo%')
ORDER BY JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'));

-- Query 1.4: Filter by status (uses functional index)
SELECT 
  id,
  type,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) AS status
FROM entities_v3
WHERE JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) = 'active'
ORDER BY updated_at DESC;

-- Query 1.5: Find entities by sync status
SELECT 
  id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.sync.status')) AS sync_status,
  CAST(JSON_EXTRACT(doc, '$.sync.serverId') AS UNSIGNED) AS server_id
FROM entities_v3
WHERE JSON_UNQUOTE(JSON_EXTRACT(doc, '$.sync.status')) = 'synced';

-- Query 1.6: Entities with Google Places metadata
SELECT 
  e.id,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.name')) AS name,
  jt.metadata_type,
  jt.place_id
FROM entities_v3 e
CROSS JOIN JSON_TABLE(
  e.doc,
  '$.metadata[*]' COLUMNS (
    metadata_type VARCHAR(128) PATH '$.type',
    place_id VARCHAR(256) PATH '$.data.placeId',
    rating DECIMAL(3,2) PATH '$.data.rating.average'
  )
) jt
WHERE jt.metadata_type = 'google_places';

-- Query 1.7: Entities with rating above threshold
SELECT 
  e.id,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.name')) AS name,
  jt.rating,
  jt.total_ratings
FROM entities_v3 e
CROSS JOIN JSON_TABLE(
  e.doc,
  '$.metadata[*]' COLUMNS (
    metadata_type VARCHAR(128) PATH '$.type',
    rating DECIMAL(3,2) PATH '$.data.rating.average',
    total_ratings INT PATH '$.data.rating.totalRatings'
  )
) jt
WHERE jt.metadata_type = 'google_places' 
  AND jt.rating >= 4.5
ORDER BY jt.rating DESC;

-- =============================================================================
-- SECTION 2: CURATION QUERIES
-- =============================================================================

-- Query 2.1: Get complete curation document
SELECT 
  id,
  entity_id,
  JSON_PRETTY(doc) AS document,
  version
FROM curations_v3
WHERE id = 'cur_wagner_rest_fogo_de_chao_jardins';

-- Query 2.2: List all curations for an entity
SELECT 
  c.id,
  JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.name')) AS curator,
  JSON_KEYS(JSON_EXTRACT(c.doc, '$.categories')) AS categories,
  c.created_at
FROM curations_v3 c
WHERE c.entity_id = 'rest_fogo_de_chao_jardins'
ORDER BY c.created_at DESC;

-- Query 2.3: Curations by specific curator (uses functional index)
SELECT 
  c.id,
  c.entity_id,
  JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.name')) AS curator,
  JSON_KEYS(JSON_EXTRACT(c.doc, '$.categories')) AS categories
FROM curations_v3 c
WHERE JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.id')) = 'curator_wagner'
ORDER BY c.created_at DESC;

-- =============================================================================
-- SECTION 3: CATEGORY CONCEPT QUERIES (JSON_TABLE)
-- =============================================================================

-- Query 3.1: Find entities with specific mood (explode array)
SELECT DISTINCT
  c.entity_id,
  e.doc->>'$.name' AS entity_name,
  jt.mood_concept
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.mood'),
  '$[*]' COLUMNS (mood_concept VARCHAR(512) PATH '$')
) jt
WHERE jt.mood_concept = 'lively';

-- Query 3.2: Find entities with specific cuisine
SELECT DISTINCT
  c.entity_id,
  e.doc->>'$.name' AS entity_name,
  jt.cuisine
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.cuisine'),
  '$[*]' COLUMNS (cuisine VARCHAR(512) PATH '$')
) jt
WHERE jt.cuisine = 'brazilian';

-- Query 3.3: Intersection - entities with BOTH 'lively' AND 'executive' mood
SELECT 
  c.entity_id,
  e.doc->>'$.name' AS entity_name,
  GROUP_CONCAT(DISTINCT jt.mood) AS moods
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.mood'),
  '$[*]' COLUMNS (mood VARCHAR(512) PATH '$')
) jt
WHERE jt.mood IN ('lively', 'executive')
GROUP BY c.entity_id, e.doc->>'$.name'
HAVING COUNT(DISTINCT jt.mood) = 2;

-- Query 3.4: Top 10 most common mood concepts
SELECT 
  jt.mood,
  COUNT(*) AS frequency
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.mood'),
  '$[*]' COLUMNS (mood VARCHAR(512) PATH '$')
) jt
GROUP BY jt.mood
ORDER BY frequency DESC
LIMIT 10;

-- Query 3.5: Top 10 most common cuisine concepts
SELECT 
  jt.cuisine,
  COUNT(*) AS frequency
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.cuisine'),
  '$[*]' COLUMNS (cuisine VARCHAR(512) PATH '$')
) jt
GROUP BY jt.cuisine
ORDER BY frequency DESC
LIMIT 10;

-- Query 3.6: All concepts for a specific category across all curations
SELECT DISTINCT
  jt.concept
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.suitable_for'),
  '$[*]' COLUMNS (concept VARCHAR(512) PATH '$')
) jt
ORDER BY jt.concept;

-- =============================================================================
-- SECTION 4: ADVANCED MULTI-CATEGORY QUERIES
-- =============================================================================

-- Query 4.1: Entities matching multiple criteria (Brazilian + Expensive + Lively)
SELECT DISTINCT
  c.entity_id,
  e.doc->>'$.name' AS entity_name,
  e.type
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
WHERE 
  -- Has Brazilian cuisine
  JSON_CONTAINS(
    JSON_EXTRACT(c.doc, '$.categories.cuisine'),
    '"brazilian"'
  )
  -- Has expensive price range
  AND JSON_CONTAINS(
    JSON_EXTRACT(c.doc, '$.categories.price_range'),
    '"expensive"'
  )
  -- Has lively mood
  AND JSON_CONTAINS(
    JSON_EXTRACT(c.doc, '$.categories.mood'),
    '"lively"'
  );

-- Query 4.2: Category coverage - how many categories each entity has
SELECT 
  c.entity_id,
  e.doc->>'$.name' AS entity_name,
  JSON_LENGTH(JSON_KEYS(JSON_EXTRACT(c.doc, '$.categories'))) AS category_count,
  JSON_KEYS(JSON_EXTRACT(c.doc, '$.categories')) AS categories
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
ORDER BY category_count DESC;

-- Query 4.3: Total concepts per category (comprehensive stats)
SELECT 
  jk.category_key AS category,
  COUNT(DISTINCT jt.concept) AS unique_concepts,
  COUNT(*) AS total_usages,
  GROUP_CONCAT(DISTINCT jt.concept ORDER BY jt.concept SEPARATOR ', ') AS sample_concepts
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_KEYS(JSON_EXTRACT(c.doc, '$.categories')),
  '$[*]' COLUMNS (category_key VARCHAR(128) PATH '$')
) jk
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, CONCAT('$.categories.', jk.category_key)),
  '$[*]' COLUMNS (concept VARCHAR(512) PATH '$')
) jt
GROUP BY jk.category_key
ORDER BY unique_concepts DESC;

-- Query 4.4: Find entities suitable for business AND families
SELECT 
  c.entity_id,
  e.doc->>'$.name' AS entity_name,
  GROUP_CONCAT(DISTINCT jt.suitable) AS suitable_for
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.suitable_for'),
  '$[*]' COLUMNS (suitable VARCHAR(512) PATH '$')
) jt
WHERE jt.suitable IN ('business dinners', 'families')
GROUP BY c.entity_id, e.doc->>'$.name'
HAVING COUNT(DISTINCT jt.suitable) = 2;

-- =============================================================================
-- SECTION 5: USING VIEWS (ERGONOMIC QUERIES)
-- =============================================================================

-- Query 5.1: Use vw_entities view
SELECT 
  id,
  type,
  name,
  status,
  server_id,
  updated_at
FROM vw_entities
WHERE type = 'restaurant' AND status = 'active'
ORDER BY updated_at DESC
LIMIT 20;

-- Query 5.2: Use vw_curation_moods view
SELECT 
  cm.entity_id,
  e.name,
  cm.mood
FROM vw_curation_moods cm
JOIN vw_entities e ON e.id = cm.entity_id
WHERE cm.mood = 'lively';

-- Query 5.3: Use vw_curation_cuisines view
SELECT 
  cc.entity_id,
  e.name,
  cc.cuisine
FROM vw_curation_cuisines cc
JOIN vw_entities e ON e.id = cc.entity_id
WHERE cc.cuisine IN ('brazilian', 'barbecue');

-- Query 5.4: Use vw_curation_concepts for generic category search
SELECT DISTINCT
  vc.entity_id,
  e.name,
  vc.category,
  vc.concept
FROM vw_curation_concepts vc
JOIN vw_entities e ON e.id = vc.entity_id
WHERE vc.concept = 'valet parking'
ORDER BY e.name;

-- =============================================================================
-- SECTION 6: ENTITY + CURATION JOINS
-- =============================================================================

-- Query 6.1: Complete entity profile (entity + all curations)
SELECT 
  e.id,
  e.type,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.name')) AS name,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.status')) AS status,
  c.id AS curation_id,
  JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.name')) AS curator,
  JSON_KEYS(JSON_EXTRACT(c.doc, '$.categories')) AS categories
FROM entities_v3 e
LEFT JOIN curations_v3 c ON c.entity_id = e.id
WHERE e.id = 'rest_fogo_de_chao_jardins';

-- Query 6.2: Entities with multiple curators
SELECT 
  e.id,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.name')) AS name,
  COUNT(DISTINCT JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.id'))) AS curator_count,
  GROUP_CONCAT(DISTINCT JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.name'))) AS curators
FROM entities_v3 e
JOIN curations_v3 c ON c.entity_id = e.id
GROUP BY e.id, name
HAVING curator_count > 1;

-- Query 6.3: Entities without curations (orphaned entities)
SELECT 
  e.id,
  e.type,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.name')) AS name,
  e.created_at
FROM entities_v3 e
LEFT JOIN curations_v3 c ON c.entity_id = e.id
WHERE c.id IS NULL
ORDER BY e.created_at DESC;

-- =============================================================================
-- SECTION 7: UPDATE EXAMPLES
-- =============================================================================

-- Query 7.1: Partial update using JSON_MERGE_PATCH (change status)
UPDATE entities_v3
SET doc = JSON_MERGE_PATCH(doc, JSON_OBJECT('status', 'active')),
    updated_at = CURRENT_TIMESTAMP(3),
    version = version + 1
WHERE id = 'rest_fogo_de_chao_jardins';

-- Query 7.2: Add a mood concept to existing array using JSON_ARRAY_APPEND
UPDATE curations_v3
SET doc = JSON_ARRAY_APPEND(doc, '$.categories.mood', 'romantic'),
    updated_at = CURRENT_TIMESTAMP(3),
    version = version + 1
WHERE id = 'cur_wagner_rest_fogo_de_chao_jardins'
  AND NOT JSON_CONTAINS(JSON_EXTRACT(doc, '$.categories.mood'), '"romantic"');

-- Query 7.3: Update specific field using JSON_SET
UPDATE curations_v3
SET doc = JSON_SET(doc, '$.notes.private', 'Updated private note'),
    updated_at = CURRENT_TIMESTAMP(3),
    version = version + 1
WHERE id = 'cur_wagner_rest_fogo_de_chao_jardins';

-- Query 7.4: Optimistic locking update (with version check)
UPDATE entities_v3
SET doc = JSON_MERGE_PATCH(doc, JSON_OBJECT('status', 'inactive')),
    updated_at = CURRENT_TIMESTAMP(3),
    version = version + 1
WHERE id = 'rest_fogo_de_chao_jardins'
  AND version = 1;  -- Only update if version is still 1

-- =============================================================================
-- SECTION 8: PERFORMANCE ANALYSIS
-- =============================================================================

-- Query 8.1: Explain plan for name search (should use functional index)
EXPLAIN 
SELECT * FROM entities_v3
WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) LIKE LOWER('%fogo%');

-- Query 8.2: Explain plan for curator filter (should use functional index)
EXPLAIN
SELECT * FROM curations_v3
WHERE JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id')) = 'curator_wagner';

-- Query 8.3: Analyze table statistics
SHOW INDEX FROM entities_v3;
SHOW INDEX FROM curations_v3;

-- Query 8.4: Count entities and curations
SELECT 
  'entities' AS table_name,
  COUNT(*) AS total_rows,
  AVG(LENGTH(doc)) AS avg_doc_size_bytes
FROM entities_v3
UNION ALL
SELECT 
  'curations' AS table_name,
  COUNT(*) AS total_rows,
  AVG(LENGTH(doc)) AS avg_doc_size_bytes
FROM curations_v3;

-- =============================================================================
-- SECTION 9: DATA VALIDATION
-- =============================================================================

-- Query 9.1: Check for invalid JSON documents
SELECT 
  'entities' AS table_name,
  id,
  'Invalid JSON' AS issue
FROM entities_v3
WHERE NOT JSON_VALID(doc)
UNION ALL
SELECT 
  'curations' AS table_name,
  id,
  'Invalid JSON' AS issue
FROM curations_v3
WHERE NOT JSON_VALID(doc);

-- Query 9.2: Check for missing required fields in entities
SELECT 
  id,
  'Missing name' AS issue
FROM entities_v3
WHERE JSON_EXTRACT(doc, '$.name') IS NULL
UNION ALL
SELECT 
  id,
  'Missing metadata' AS issue
FROM entities_v3
WHERE JSON_EXTRACT(doc, '$.metadata') IS NULL;

-- Query 9.3: Check for missing required fields in curations
SELECT 
  id,
  'Missing curator' AS issue
FROM curations_v3
WHERE JSON_EXTRACT(doc, '$.curator') IS NULL
UNION ALL
SELECT 
  id,
  'Missing categories' AS issue
FROM curations_v3
WHERE JSON_EXTRACT(doc, '$.categories') IS NULL
   OR JSON_LENGTH(JSON_EXTRACT(doc, '$.categories')) = 0;

-- =============================================================================
-- END OF EXAMPLE QUERIES
-- =============================================================================
