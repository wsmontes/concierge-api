#!/bin/bash
# =============================================================================
# Concierge Analyzer - V3 Deployment Script
# Purpose: Orchestrate V3 database and API deployment
# Dependencies: MySQL 8.0+, Python 3.8+, mysql client
# Usage: ./deploy_v3.sh [--migrate-from-v2] [--skip-backup] [--test-mode]
# =============================================================================

set -e  # Exit on error

# =============================================================================
# CONFIGURATION
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_NAME="${DB_NAME:-concierge}"
DB_PASSWORD="${DB_PASSWORD}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
MIGRATE_FROM_V2=false
SKIP_BACKUP=false
TEST_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --migrate-from-v2)
      MIGRATE_FROM_V2=true
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    --test-mode)
      TEST_MODE=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--migrate-from-v2] [--skip-backup] [--test-mode]"
      exit 1
      ;;
  esac
done

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

execute_sql() {
  local sql_file=$1
  local description=$2
  
  print_info "Executing: $description"
  
  if [ -f "$sql_file" ]; then
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$sql_file"
    print_success "$description completed"
  else
    print_error "SQL file not found: $sql_file"
    exit 1
  fi
}

check_mysql_connection() {
  print_info "Checking MySQL connection..."
  
  if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" > /dev/null 2>&1; then
    print_success "MySQL connection successful"
    return 0
  else
    print_error "Cannot connect to MySQL. Check credentials and server status."
    return 1
  fi
}

backup_database() {
  if [ "$SKIP_BACKUP" = true ]; then
    print_warning "Skipping database backup (--skip-backup flag set)"
    return 0
  fi
  
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="${SCRIPT_DIR}/backup_${DB_NAME}_${timestamp}.sql"
  
  print_info "Creating database backup..."
  
  mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" \
    --single-transaction \
    --routines \
    --triggers \
    "$DB_NAME" > "$backup_file"
  
  print_success "Backup created: $backup_file"
}

# =============================================================================
# MAIN DEPLOYMENT STEPS
# =============================================================================

main() {
  print_header "Concierge Analyzer V3 Deployment"
  
  # Step 1: Pre-flight checks
  print_header "Step 1: Pre-flight Checks"
  
  if ! check_mysql_connection; then
    exit 1
  fi
  
  # Check required files exist
  required_files=(
    "$SCRIPT_DIR/schema_v3.sql"
    "$SCRIPT_DIR/models_v3.py"
    "$SCRIPT_DIR/database_v3.py"
    "$SCRIPT_DIR/api_v3.py"
  )
  
  for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
      print_error "Required file not found: $file"
      exit 1
    fi
  done
  
  print_success "All required files present"
  
  # Step 2: Backup existing database
  if [ "$TEST_MODE" = false ]; then
    print_header "Step 2: Database Backup"
    backup_database
  else
    print_warning "Test mode: Skipping backup"
  fi
  
  # Step 3: Deploy V3 schema
  print_header "Step 3: Deploy V3 Schema"
  execute_sql "$SCRIPT_DIR/schema_v3.sql" "V3 schema creation"
  
  # Step 4: Migrate from V2 (optional)
  if [ "$MIGRATE_FROM_V2" = true ]; then
    print_header "Step 4: Migrate Data from V2"
    
    if [ -f "$SCRIPT_DIR/migrate_v2_to_v3.sql" ]; then
      print_info "Starting V2 to V3 migration..."
      execute_sql "$SCRIPT_DIR/migrate_v2_to_v3.sql" "V2 to V3 data migration"
      
      print_warning "Migration complete. Review output and execute COMMIT or ROLLBACK manually."
    else
      print_error "Migration script not found: migrate_v2_to_v3.sql"
      exit 1
    fi
  else
    print_info "Skipping V2 migration (use --migrate-from-v2 flag to enable)"
  fi
  
  # Step 5: Install Python dependencies
  print_header "Step 5: Python Environment Setup"
  
  if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    print_info "Installing Python dependencies..."
    
    # Check if virtual environment exists
    if [ -d "../mysql_api_venv" ]; then
      source ../mysql_api_venv/bin/activate
      print_info "Activated virtual environment"
    fi
    
    pip install -q pydantic mysql-connector-python flask jsonschema
    print_success "Python dependencies installed"
  else
    print_warning "requirements.txt not found, skipping pip install"
  fi
  
  # Step 6: Validate deployment
  print_header "Step 6: Validation"
  
  print_info "Checking V3 tables exist..."
  
  tables_exist=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name IN ('entities_v3', 'curations_v3');" \
    -s -N)
  
  if [ "$tables_exist" -eq 2 ]; then
    print_success "V3 tables created successfully"
  else
    print_error "V3 tables not found. Deployment may have failed."
    exit 1
  fi
  
  # Count records (if migrated)
  if [ "$MIGRATE_FROM_V2" = true ]; then
    entity_count=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
      -e "SELECT COUNT(*) FROM entities_v3;" -s -N)
    curation_count=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
      -e "SELECT COUNT(*) FROM curations_v3;" -s -N)
    
    print_info "Entities migrated: $entity_count"
    print_info "Curations migrated: $curation_count"
  fi
  
  # Step 7: Insert sample data (test mode only)
  if [ "$TEST_MODE" = true ]; then
    print_header "Step 7: Insert Sample Data (Test Mode)"
    
    print_info "Inserting sample entity..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
INSERT INTO entities_v3 (id, type, doc)
VALUES (
  'rest_test_sample',
  'restaurant',
  JSON_OBJECT(
    'name', 'Test Restaurant',
    'status', 'draft',
    'metadata', JSON_ARRAY(
      JSON_OBJECT(
        'type', 'collector',
        'source', 'manual',
        'data', JSON_OBJECT('city', 'Test City')
      )
    )
  )
);
EOF
    
    print_success "Sample entity inserted"
    
    print_info "Inserting sample curation..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" <<EOF
INSERT INTO curations_v3 (id, entity_id, doc)
VALUES (
  'cur_test_rest_test_sample',
  'rest_test_sample',
  JSON_OBJECT(
    'curator', JSON_OBJECT('id', 'curator_test', 'name', 'Test Curator'),
    'createdAt', NOW(),
    'categories', JSON_OBJECT(
      'cuisine', JSON_ARRAY('test'),
      'mood', JSON_ARRAY('sample')
    ),
    'sources', JSON_ARRAY('test deployment')
  )
);
EOF
    
    print_success "Sample curation inserted"
  fi
  
  # Step 8: Final summary
  print_header "Deployment Complete"
  
  echo -e "${GREEN}V3 deployment successful!${NC}\n"
  
  print_info "Summary:"
  echo "  - V3 schema deployed"
  echo "  - Functional indexes created"
  echo "  - Views created for analytics"
  
  if [ "$MIGRATE_FROM_V2" = true ]; then
    echo "  - V2 data migration executed (review and COMMIT/ROLLBACK)"
  fi
  
  echo ""
  print_info "Next steps:"
  echo "  1. Review migration output (if applicable)"
  echo "  2. Run example queries: mysql < $SCRIPT_DIR/queries_v3.sql"
  echo "  3. Start API server: python app_v3.py"
  echo "  4. Test endpoints: curl http://localhost:5000/api/v3/health"
  
  echo ""
  print_info "Documentation:"
  echo "  - Schema: $SCRIPT_DIR/schema_v3.sql"
  echo "  - Queries: $SCRIPT_DIR/queries_v3.sql"
  echo "  - API docs: http://localhost:5000/api/v3/info"
  
  if [ -n "$(ls ${SCRIPT_DIR}/backup_*.sql 2>/dev/null)" ]; then
    echo ""
    print_info "Backups available in: $SCRIPT_DIR/"
  fi
}

# =============================================================================
# EXECUTE MAIN
# =============================================================================

main "$@"
