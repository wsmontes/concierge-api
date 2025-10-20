#!/bin/bash
# =============================================================================
# Concierge Analyzer - V3 Database Reset Script
# Purpose: Safely reset V3 database to clean state
# Dependencies: MySQL 8.0+
# Usage: ./reset_v3.sh [--with-sample-data] [--drop-all]
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_NAME="${DB_NAME:-concierge}"
DB_PASSWORD="${DB_PASSWORD}"

# Parse arguments
WITH_SAMPLE_DATA=false
DROP_ALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --with-sample-data)
      WITH_SAMPLE_DATA=true
      shift
      ;;
    --drop-all)
      DROP_ALL=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--with-sample-data] [--drop-all]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   Concierge Analyzer V3 - Database Reset  ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Prompt for password if not set
if [ -z "$DB_PASSWORD" ]; then
  read -sp "MySQL password for $DB_USER: " DB_PASSWORD
  echo ""
fi

# Test connection
echo -e "\n${BLUE}Testing MySQL connection...${NC}"
if ! mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" &> /dev/null; then
  echo -e "${RED}✗ Cannot connect to MySQL. Check credentials.${NC}"
  exit 1
fi
echo -e "${GREEN}✓ MySQL connection successful${NC}"

# Warning
echo -e "\n${YELLOW}⚠️  WARNING: This will reset the V3 database!${NC}"
echo -e "${YELLOW}   The following will be DROPPED:${NC}"
echo "   • curations_v3 table (and all data)"
echo "   • entities_v3 table (and all data)"
echo "   • All V3 views"
echo "   • All V3 functions"

if [ "$DROP_ALL" = true ]; then
  echo -e "\n${RED}⚠️  DROP_ALL mode: Will also drop V2 tables!${NC}"
fi

echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo -e "${YELLOW}Reset cancelled.${NC}"
  exit 0
fi

# Create backup before reset
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_before_reset_${TIMESTAMP}.sql"

echo -e "\n${BLUE}Creating backup...${NC}"
mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  "$DB_NAME" > "$BACKUP_FILE" 2>/dev/null || true

if [ -f "$BACKUP_FILE" ]; then
  echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
else
  echo -e "${YELLOW}⚠ Backup failed, but continuing...${NC}"
fi

# Reset V3 database
echo -e "\n${BLUE}Resetting V3 database...${NC}"

mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<'EOSQL'

-- Drop V3 views
DROP VIEW IF EXISTS vw_curation_concepts;
DROP VIEW IF EXISTS vw_curation_cuisines;
DROP VIEW IF EXISTS vw_curation_moods;
DROP VIEW IF EXISTS vw_curations;
DROP VIEW IF EXISTS vw_entities;

-- Drop V3 functions
DROP FUNCTION IF EXISTS get_entity_name;
DROP FUNCTION IF EXISTS entity_has_metadata_type;

-- Drop V3 tables (CASCADE will drop curations first due to FK)
DROP TABLE IF EXISTS curations_v3;
DROP TABLE IF EXISTS entities_v3;

EOSQL

echo -e "${GREEN}✓ V3 tables, views, and functions dropped${NC}"

# Drop V2 tables if requested
if [ "$DROP_ALL" = true ]; then
  echo -e "\n${BLUE}Dropping V2 tables...${NC}"
  
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<'EOSQL'

-- Drop V2 tables (adjust names based on your actual V2 schema)
DROP TABLE IF EXISTS curations;
DROP TABLE IF EXISTS curations_v2;
DROP TABLE IF EXISTS entities;
DROP TABLE IF EXISTS entities_v2;

EOSQL
  
  echo -e "${GREEN}✓ V2 tables dropped${NC}"
fi

# Deploy fresh V3 schema
echo -e "\n${BLUE}Deploying fresh V3 schema...${NC}"

if [ -f "schema_v3.sql" ]; then
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < schema_v3.sql
  echo -e "${GREEN}✓ V3 schema deployed${NC}"
else
  echo -e "${RED}✗ schema_v3.sql not found!${NC}"
  exit 1
fi

# Insert sample data if requested
if [ "$WITH_SAMPLE_DATA" = true ]; then
  echo -e "\n${BLUE}Inserting sample data...${NC}"
  
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<'EOSQL'

-- Sample Restaurant Entity
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
          )
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

-- Sample Curation
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
      'menu', JSON_ARRAY('rib-eye steak', 'barbecue', 'chicken', 'lamb', 'lobster', 'salmon', 'wagyu beef'),
      'food_style', JSON_ARRAY('classic', 'traditional', 'all you can eat'),
      'drinks', JSON_ARRAY('caipirinhas', 'signature cocktails', 'international wines', 'wine list'),
      'setting', JSON_ARRAY('upscale', 'classical', 'comfortable'),
      'mood', JSON_ARRAY('lively', 'executive', 'noisy'),
      'crowd', JSON_ARRAY('international', 'families', 'locals', 'executives'),
      'suitable_for', JSON_ARRAY('meetings', 'celebrations', 'business dinners', 'families'),
      'special_features', JSON_ARRAY('open 7x7', 'delivery', 'valet parking', 'sommelier'),
      'price_range', JSON_ARRAY('expensive')
    ),
    'sources', JSON_ARRAY('audio 2025-09-09', 'site oficial'),
    'notes', JSON_OBJECT(
      'public', 'Best churrascaria in Jardins',
      'private', 'Great for business lunches'
    )
  )
);

-- Additional Sample Restaurant
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

-- Additional Sample Curation
INSERT INTO curations_v3 (id, entity_id, doc)
VALUES (
  'cur_sample_rest_sample_pizzeria',
  'rest_sample_pizzeria',
  JSON_OBJECT(
    'curator', JSON_OBJECT('id', 'curator_sample', 'name', 'Sample Curator'),
    'createdAt', NOW(),
    'categories', JSON_OBJECT(
      'cuisine', JSON_ARRAY('italian', 'pizza'),
      'mood', JSON_ARRAY('casual', 'family-friendly'),
      'price_range', JSON_ARRAY('moderate'),
      'suitable_for', JSON_ARRAY('families', 'casual dinners')
    ),
    'sources', JSON_ARRAY('sample data'),
    'notes', JSON_OBJECT('public', 'Great pizza and friendly service!', 'private', '')
  )
);

EOSQL

  echo -e "${GREEN}✓ Sample data inserted (2 entities, 2 curations)${NC}"
fi

# Verification
echo -e "\n${BLUE}Verification...${NC}"

ENTITY_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  -s -N -e "SELECT COUNT(*) FROM entities_v3;")

CURATION_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  -s -N -e "SELECT COUNT(*) FROM curations_v3;")

echo "  • Entities: $ENTITY_COUNT"
echo "  • Curations: $CURATION_COUNT"

# List tables
echo -e "\n${BLUE}Current tables:${NC}"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
  -e "SHOW TABLES;" 2>/dev/null | grep -v "Tables_in" | sed 's/^/  • /'

# Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Database Reset Complete!                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Summary:${NC}"
echo "  • V3 schema: ✓ Fresh deployment"
echo "  • Backup: $BACKUP_FILE"
echo "  • Entities: $ENTITY_COUNT"
echo "  • Curations: $CURATION_COUNT"

echo -e "\n${BLUE}Next steps:${NC}"
echo "  1. Start API: python app_v3.py"
echo "  2. Test health: curl http://localhost:5000/api/v3/health"
echo "  3. List entities: curl http://localhost:5000/api/v3/entities?type=restaurant"

if [ "$WITH_SAMPLE_DATA" = true ]; then
  echo "  4. View sample: curl http://localhost:5000/api/v3/entities/rest_fogo_de_chao_jardins"
fi

echo -e "\n${BLUE}Query examples:${NC}"
echo "  mysql -u $DB_USER -p $DB_NAME < queries_v3.sql"
