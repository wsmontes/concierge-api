-- =============================================================================
-- Concierge Analyzer - V3 Database Reset (SQL Only)
-- Purpose: Reset V3 database to clean state with sample data
-- Dependencies: MySQL 8.0+
-- Usage: mysql -u root -p concierge < reset_v3.sql
-- =============================================================================

-- Warning message
SELECT '⚠️  WARNING: This will DROP all V3 tables and data!' AS Warning;
SELECT 'Press Ctrl+C within 5 seconds to cancel...' AS Message;
SELECT SLEEP(5);

-- =============================================================================
-- STEP 1: DROP EXISTING V3 OBJECTS
-- =============================================================================

SELECT 'Dropping V3 views...' AS Step;

DROP VIEW IF EXISTS vw_curation_concepts;
DROP VIEW IF EXISTS vw_curation_cuisines;
DROP VIEW IF EXISTS vw_curation_moods;
DROP VIEW IF EXISTS vw_curations;
DROP VIEW IF EXISTS vw_entities;

SELECT 'Dropping V3 functions...' AS Step;

DROP FUNCTION IF EXISTS get_entity_name;
DROP FUNCTION IF EXISTS entity_has_metadata_type;

SELECT 'Dropping V3 tables...' AS Step;

DROP TABLE IF EXISTS curations_v3;
DROP TABLE IF EXISTS entities_v3;

-- =============================================================================
-- STEP 2: CREATE FRESH V3 SCHEMA
-- =============================================================================

SELECT 'Creating entities_v3 table...' AS Step;

CREATE TABLE entities_v3 (
  id          VARCHAR(128) PRIMARY KEY,
  type        VARCHAR(64) NOT NULL,
  doc         JSON NOT NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  version     INT UNSIGNED NOT NULL DEFAULT 1,
  name_ft     VARCHAR(512) GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) STORED,
  
  INDEX idx_entities_type_updated (type, updated_at DESC),
  INDEX idx_entities_created (created_at DESC),
  FULLTEXT idx_entities_name_ft (name_ft),
  
  CHECK (JSON_VALID(doc)),
  CHECK (JSON_TYPE(JSON_EXTRACT(doc, '$.name')) = 'STRING'),
  CHECK (JSON_TYPE(JSON_EXTRACT(doc, '$.metadata')) = 'ARRAY'),
  CHECK (version > 0),
  CHECK (type IN ('restaurant', 'hotel', 'attraction', 'event', 'other'))
  
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SELECT 'Creating curations_v3 table...' AS Step;

CREATE TABLE curations_v3 (
  id          VARCHAR(128) PRIMARY KEY,
  entity_id   VARCHAR(128) NOT NULL,
  doc         JSON NOT NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  version     INT UNSIGNED NOT NULL DEFAULT 1,
  
  INDEX idx_curations_entity (entity_id),
  INDEX idx_curations_updated (updated_at DESC),
  
  CHECK (JSON_VALID(doc)),
  CHECK (JSON_TYPE(JSON_EXTRACT(doc, '$.curator')) = 'OBJECT'),
  CHECK (JSON_TYPE(JSON_EXTRACT(doc, '$.categories')) = 'OBJECT'),
  CHECK (version > 0),
  
  CONSTRAINT fk_cur_entity_v3 
    FOREIGN KEY (entity_id) 
    REFERENCES entities_v3(id) 
    ON DELETE CASCADE
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SELECT 'Creating functional indexes...' AS Step;

CREATE INDEX idx_entities_name 
  ON entities_v3 ((CAST(LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) AS CHAR(255))));

CREATE INDEX idx_entities_status
  ON entities_v3 ((CAST(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) AS CHAR(32))));

CREATE INDEX idx_curations_curator
  ON curations_v3 ((CAST(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id')) AS CHAR(128))));

CREATE INDEX idx_entities_sync_status
  ON entities_v3 ((CAST(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.sync.status')) AS CHAR(32))));

CREATE INDEX idx_entities_server_id
  ON entities_v3 ((CAST(JSON_EXTRACT(doc, '$.sync.serverId') AS UNSIGNED)));

SELECT 'Creating views...' AS Step;

CREATE OR REPLACE VIEW vw_entities AS
SELECT 
  e.id,
  e.type,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.name')) AS name,
  JSON_UNQUOTE(JSON_EXTRACT(e.doc, '$.status')) AS status,
  CAST(JSON_EXTRACT(e.doc, '$.sync.serverId') AS UNSIGNED) AS server_id,
  e.created_at,
  e.updated_at,
  e.version,
  e.doc
FROM entities_v3 e;

CREATE OR REPLACE VIEW vw_curations AS
SELECT 
  c.id,
  c.entity_id,
  JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.id')) AS curator_id,
  JSON_UNQUOTE(JSON_EXTRACT(c.doc, '$.curator.name')) AS curator_name,
  c.created_at,
  c.updated_at,
  c.version,
  c.doc
FROM curations_v3 c;

CREATE OR REPLACE VIEW vw_curation_moods AS
SELECT 
  c.id AS curation_id,
  c.entity_id,
  jt.concept AS mood
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.mood'),
  '$[*]' COLUMNS (concept VARCHAR(512) PATH '$')
) jt
WHERE JSON_EXTRACT(c.doc, '$.categories.mood') IS NOT NULL;

CREATE OR REPLACE VIEW vw_curation_cuisines AS
SELECT 
  c.id AS curation_id,
  c.entity_id,
  jt.concept AS cuisine
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.cuisine'),
  '$[*]' COLUMNS (concept VARCHAR(512) PATH '$')
) jt
WHERE JSON_EXTRACT(c.doc, '$.categories.cuisine') IS NOT NULL;

CREATE OR REPLACE VIEW vw_curation_concepts AS
SELECT 
  c.id AS curation_id,
  c.entity_id,
  jk.category_key AS category,
  jt.concept
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_KEYS(JSON_EXTRACT(c.doc, '$.categories')),
  '$[*]' COLUMNS (category_key VARCHAR(128) PATH '$')
) jk
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, CONCAT('$.categories.', jk.category_key)),
  '$[*]' COLUMNS (concept VARCHAR(512) PATH '$')
) jt;

SELECT 'Creating helper functions...' AS Step;

-- Note: Function creation requires SUPER or SYSTEM_VARIABLES_ADMIN privileges
-- If you get privilege errors, you can either:
-- 1. Run as MySQL root: SET GLOBAL log_bin_trust_function_creators = 1;
-- 2. Skip functions - they're helper utilities, not required for core functionality

-- Uncomment the following lines if you have admin privileges:
/*
SET GLOBAL log_bin_trust_function_creators = 1;

DELIMITER $$

CREATE FUNCTION IF NOT EXISTS get_entity_name(entity_id VARCHAR(128))
RETURNS VARCHAR(512)
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE entity_name VARCHAR(512);
  SELECT JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))
  INTO entity_name
  FROM entities_v3
  WHERE id = entity_id;
  RETURN entity_name;
END$$

CREATE FUNCTION IF NOT EXISTS entity_has_metadata_type(
  entity_id VARCHAR(128),
  metadata_type VARCHAR(128)
)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE has_type BOOLEAN DEFAULT FALSE;
  SELECT COUNT(*) > 0
  INTO has_type
  FROM entities_v3 e,
  JSON_TABLE(
    e.doc,
    '$.metadata[*]' COLUMNS (mtype VARCHAR(128) PATH '$.type')
  ) jt
  WHERE e.id = entity_id AND jt.mtype = metadata_type;
  RETURN has_type;
END$$

DELIMITER ;
*/

SELECT 'Note: Helper functions skipped (require admin privileges)' AS Info;

-- =============================================================================
-- STEP 3: INSERT SAMPLE DATA
-- =============================================================================

SELECT 'Inserting sample entities...' AS Step;

-- Sample 1: Fogo de Chão (Complete example from curations_example.json)
INSERT INTO entities_v3 (id, type, doc)
VALUES (
  'rest_fogo_de_chao_jardins',
  'restaurant',
  JSON_OBJECT(
    'name', 'Fogo de Chão - Jardins',
    'status', 'active',
    'metadata', JSON_ARRAY(
      JSON_OBJECT(
        'type', 'google_places',
        'source', 'google-places-api',
        'importedAt', '2025-10-20T18:25:00Z',
        'data', JSON_OBJECT(
          'placeId', 'gp_abc123',
          'rating', JSON_OBJECT(
            'average', 4.5,
            'totalRatings', 1123,
            'priceLevel', 4
          ),
          'location', JSON_OBJECT(
            'latitude', -23.564,
            'longitude', -46.654,
            'formattedAddress', 'Alameda Santos, 123, São Paulo - SP, Brasil',
            'city', 'São Paulo',
            'country', 'BR'
          ),
          'hours', JSON_OBJECT('periods', JSON_ARRAY())
        )
      ),
      JSON_OBJECT(
        'type', 'collector',
        'source', 'manual',
        'importedAt', '2025-10-20T18:26:00Z',
        'data', JSON_OBJECT(
          'location', JSON_OBJECT('country', 'BR', 'city', 'São Paulo'),
          'contact', JSON_OBJECT('phone', '+55 11 0000-0000')
        )
      )
    ),
    'sync', JSON_OBJECT(
      'serverId', 123,
      'status', 'synced',
      'lastSyncedAt', '2025-10-20T18:30:00Z'
    )
  )
);

-- Sample 2: Sample Pizzeria
INSERT INTO entities_v3 (id, type, doc)
VALUES (
  'rest_sample_pizzeria',
  'restaurant',
  JSON_OBJECT(
    'name', 'Sample Pizzeria',
    'status', 'active',
    'metadata', JSON_ARRAY(
      JSON_OBJECT(
        'type', 'collector',
        'source', 'manual',
        'importedAt', NOW(),
        'data', JSON_OBJECT(
          'location', JSON_OBJECT('city', 'São Paulo', 'country', 'BR'),
          'contact', JSON_OBJECT('phone', '+55 11 1234-5678')
        )
      )
    )
  )
);

-- Sample 3: Draft Hotel
INSERT INTO entities_v3 (id, type, doc)
VALUES (
  'hotel_sample_grand',
  'hotel',
  JSON_OBJECT(
    'name', 'Grand Hotel Sample',
    'status', 'draft',
    'metadata', JSON_ARRAY(
      JSON_OBJECT(
        'type', 'collector',
        'source', 'manual',
        'importedAt', NOW(),
        'data', JSON_OBJECT(
          'location', JSON_OBJECT('city', 'Rio de Janeiro', 'country', 'BR'),
          'rooms', 250
        )
      )
    )
  )
);

SELECT 'Inserting sample curations...' AS Step;

-- Curation 1: Fogo de Chão (Complete from curations_example.json)
INSERT INTO curations_v3 (id, entity_id, doc)
VALUES (
  'cur_wagner_rest_fogo_de_chao_jardins',
  'rest_fogo_de_chao_jardins',
  JSON_OBJECT(
    'curator', JSON_OBJECT(
      'id', 'curator_wagner',
      'name', 'Wagner',
      'email', 'wagner@example.com'
    ),
    'createdAt', '2025-10-20T18:27:00Z',
    'categories', JSON_OBJECT(
      'cuisine', JSON_ARRAY('brazilian', 'barbecue'),
      'menu', JSON_ARRAY('rib-eye steak', 'barbecue', 'chicken', 'chimichurri', 'churros', 'cod', 'lamb', 'lobster', 'salmon', 'wagyu beef', 'argentinean beef', 'brazilian beef'),
      'food_style', JSON_ARRAY('classic', 'traditional', 'all you can eat'),
      'drinks', JSON_ARRAY('bourbon', 'caipirinhas', 'manhattan', 'margarita', 'signature cocktails', 'international wines', 'local wines', 'wine list'),
      'setting', JSON_ARRAY('upscale', 'classical', 'comfortable'),
      'mood', JSON_ARRAY('lively', 'executive', 'noisy'),
      'crowd', JSON_ARRAY('international', 'families', 'locals', 'executives'),
      'suitable_for', JSON_ARRAY('meetings', 'tourists', 'celebrations', 'business dinners', 'families'),
      'special_features', JSON_ARRAY('open 7x7', 'private events', 'delivery', 'valet parking', 'sommelier'),
      'covid_specials', JSON_ARRAY('masked staff', 'covid protocols', 'extra cleanliness'),
      'price_and_payment', JSON_ARRAY('credit cards accepted', 'debit cards accepted'),
      'price_range', JSON_ARRAY('expensive')
    ),
    'sources', JSON_ARRAY('audio 2025-09-09', 'site oficial'),
    'notes', JSON_OBJECT(
      'public', 'Best churrascaria in Jardins - excellent meat selection',
      'private', 'Great for business lunches, ask for corner table'
    )
  )
);

-- Curation 2: Sample Pizzeria
INSERT INTO curations_v3 (id, entity_id, doc)
VALUES (
  'cur_maria_rest_sample_pizzeria',
  'rest_sample_pizzeria',
  JSON_OBJECT(
    'curator', JSON_OBJECT('id', 'curator_maria', 'name', 'Maria'),
    'createdAt', NOW(),
    'categories', JSON_OBJECT(
      'cuisine', JSON_ARRAY('italian', 'pizza'),
      'mood', JSON_ARRAY('casual', 'family-friendly', 'relaxed'),
      'price_range', JSON_ARRAY('moderate'),
      'suitable_for', JSON_ARRAY('families', 'casual dinners', 'kids'),
      'special_features', JSON_ARRAY('delivery', 'outdoor seating')
    ),
    'sources', JSON_ARRAY('visit 2025-10-15', 'menu card'),
    'notes', JSON_OBJECT('public', 'Great thin-crust pizza!', 'private', '')
  )
);

-- Curation 3: Another view of Fogo (different curator)
INSERT INTO curations_v3 (id, entity_id, doc)
VALUES (
  'cur_joao_rest_fogo_de_chao_jardins',
  'rest_fogo_de_chao_jardins',
  JSON_OBJECT(
    'curator', JSON_OBJECT('id', 'curator_joao', 'name', 'João'),
    'createdAt', NOW(),
    'categories', JSON_OBJECT(
      'cuisine', JSON_ARRAY('brazilian', 'steakhouse'),
      'mood', JSON_ARRAY('sophisticated', 'business'),
      'suitable_for', JSON_ARRAY('corporate events', 'celebrations'),
      'price_range', JSON_ARRAY('expensive')
    ),
    'sources', JSON_ARRAY('personal experience'),
    'notes', JSON_OBJECT('public', 'Excellent service and quality', 'private', 'Reserve ahead on weekends')
  )
);

-- =============================================================================
-- STEP 4: VERIFICATION
-- =============================================================================

SELECT 'Verification Results:' AS Step;

SELECT 
  'Entities created' AS Item,
  COUNT(*) AS Count,
  GROUP_CONCAT(DISTINCT type SEPARATOR ', ') AS Types
FROM entities_v3;

SELECT 
  'Curations created' AS Item,
  COUNT(*) AS Count,
  COUNT(DISTINCT entity_id) AS Unique_Entities
FROM curations_v3;

SELECT 'Sample entity names:' AS Info;
SELECT 
  id,
  type,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status')) AS status
FROM entities_v3;

SELECT 'Sample curations:' AS Info;
SELECT 
  id,
  entity_id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.name')) AS curator,
  JSON_LENGTH(JSON_KEYS(JSON_EXTRACT(doc, '$.categories'))) AS category_count
FROM curations_v3;

SELECT 'Test functional index (search by name):' AS Info;
SELECT 
  id,
  JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')) AS name
FROM entities_v3
WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) LIKE '%fogo%';

SELECT 'Test view (vw_curation_moods):' AS Info;
SELECT * FROM vw_curation_moods LIMIT 5;

-- =============================================================================
-- COMPLETION MESSAGE
-- =============================================================================

SELECT '✅ Database reset complete!' AS Status;
SELECT 'Schema: V3 tables (2), indexes (9), views (5) created' AS Details;
SELECT 'Data: 3 entities, 3 curations inserted' AS Details;
SELECT 'Note: Helper functions require admin privileges (optional)' AS Note;
SELECT 'Next: Run queries_v3.sql for examples or start app_v3.py' AS Next_Steps;
