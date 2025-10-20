#!/bin/bash
# =============================================================================
# Concierge Analyzer V3 - Quick Start Script
# Purpose: Get V3 up and running in 5 minutes
# Usage: ./quickstart_v3.sh
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   Concierge Analyzer V3 - Quick Start    ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Step 1: Check MySQL
echo -e "${BLUE}[1/5] Checking MySQL connection...${NC}"
if command -v mysql &> /dev/null; then
    echo -e "${GREEN}✓ MySQL client found${NC}"
else
    echo -e "${YELLOW}⚠ MySQL client not found. Please install MySQL 8.0+${NC}"
    exit 1
fi

# Step 2: Check Python
echo -e "\n${BLUE}[2/5] Checking Python environment...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo -e "${GREEN}✓ Python $PYTHON_VERSION found${NC}"
else
    echo -e "${YELLOW}⚠ Python 3 not found. Please install Python 3.8+${NC}"
    exit 1
fi

# Step 3: Install dependencies
echo -e "\n${BLUE}[3/5] Installing Python dependencies...${NC}"
pip3 install -q pydantic mysql-connector-python flask flask-cors jsonschema
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Step 4: Database setup
echo -e "\n${BLUE}[4/5] Setting up database...${NC}"
echo -e "${YELLOW}Please enter your MySQL credentials:${NC}"
read -p "MySQL host [localhost]: " DB_HOST
DB_HOST=${DB_HOST:-localhost}

read -p "MySQL port [3306]: " DB_PORT
DB_PORT=${DB_PORT:-3306}

read -p "MySQL user [root]: " DB_USER
DB_USER=${DB_USER:-root}

read -sp "MySQL password: " DB_PASSWORD
echo ""

read -p "Database name [concierge]: " DB_NAME
DB_NAME=${DB_NAME:-concierge}

# Export for app
export DB_HOST DB_PORT DB_USER DB_PASSWORD DB_NAME

# Test connection
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" &> /dev/null; then
    echo -e "${GREEN}✓ MySQL connection successful${NC}"
else
    echo -e "${YELLOW}✗ Cannot connect to MySQL. Please check credentials.${NC}"
    exit 1
fi

# Create database if doesn't exist
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" \
    -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null

echo -e "${GREEN}✓ Database ready${NC}"

# Deploy schema
echo -e "\n${BLUE}Deploying V3 schema...${NC}"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < schema_v3.sql
echo -e "${GREEN}✓ V3 schema deployed${NC}"

# Insert sample data
echo -e "\n${BLUE}Inserting sample data...${NC}"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
-- Sample entity
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
        'source', 'quickstart',
        'importedAt', NOW(),
        'data', JSON_OBJECT(
          'location', JSON_OBJECT('city', 'São Paulo', 'country', 'BR'),
          'contact', JSON_OBJECT('phone', '+55 11 1234-5678')
        )
      )
    )
  )
) ON DUPLICATE KEY UPDATE id=id;

-- Sample curation
INSERT INTO curations_v3 (id, entity_id, doc)
VALUES (
  'cur_quickstart_rest_sample_pizzeria',
  'rest_sample_pizzeria',
  JSON_OBJECT(
    'curator', JSON_OBJECT('id', 'curator_quickstart', 'name', 'QuickStart Bot'),
    'createdAt', NOW(),
    'categories', JSON_OBJECT(
      'cuisine', JSON_ARRAY('italian', 'pizza'),
      'mood', JSON_ARRAY('casual', 'family-friendly'),
      'price_range', JSON_ARRAY('moderate'),
      'suitable_for', JSON_ARRAY('families', 'casual dinners')
    ),
    'sources', JSON_ARRAY('quickstart script'),
    'notes', JSON_OBJECT('public', 'Great pizza!', 'private', 'Sample data')
  )
) ON DUPLICATE KEY UPDATE id=id;
EOF
echo -e "${GREEN}✓ Sample data inserted${NC}"

# Step 5: Start server
echo -e "\n${BLUE}[5/5] Starting API server...${NC}"
echo -e "${GREEN}✓ V3 setup complete!${NC}\n"

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}Server starting on http://localhost:5000${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}\n"

echo "Test endpoints:"
echo "  • API Info:      curl http://localhost:5000/api/v3/info"
echo "  • Health Check:  curl http://localhost:5000/api/v3/health"
echo "  • List Entities: curl http://localhost:5000/api/v3/entities?type=restaurant"
echo "  • Get Sample:    curl http://localhost:5000/api/v3/entities/rest_sample_pizzeria"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start Flask app
python3 app_v3.py
