#!/bin/bash
#
# Purpose: Test V3 API endpoints on PythonAnywhere
# Dependencies: curl, jq (optional for pretty printing)
#
# Usage: ./scripts/test_v3_api.sh [base_url]
#

set -e

# Configuration
BASE_URL="${1:-https://wsmontes.pythonanywhere.com}"
API_V3="${BASE_URL}/api/v3"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if jq is available for pretty printing
if command -v jq &> /dev/null; then
    JQ_CMD="jq ."
else
    JQ_CMD="python3 -m json.tool 2>/dev/null || cat"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Testing V3 API: ${BASE_URL}${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local description=$3
    local data=$4
    
    echo -e "${YELLOW}→ ${description}${NC}"
    echo -e "  ${method} ${endpoint}"
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n__HTTP_CODE__:%{http_code}" -X ${method} "${endpoint}")
    else
        response=$(curl -s -w "\n__HTTP_CODE__:%{http_code}" -X ${method} \
            -H "Content-Type: application/json" \
            -d "${data}" \
            "${endpoint}")
    fi
    
    http_code=$(echo "$response" | grep "__HTTP_CODE__" | cut -d: -f2)
    body=$(echo "$response" | sed '/__HTTP_CODE__/d')
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo -e "  ${GREEN}✓ Status: ${http_code}${NC}"
        echo "$body" | eval $JQ_CMD | head -20
    else
        echo -e "  ${RED}✗ Status: ${http_code}${NC}"
        echo "$body" | eval $JQ_CMD
    fi
    echo ""
}

# Test 1: Health Check
test_endpoint "GET" "${API_V3}/health" "Health Check"

# Test 2: Database Info
test_endpoint "GET" "${API_V3}/info" "Database Info"

# Test 3: List Entities
test_endpoint "GET" "${API_V3}/entities" "List All Entities"

# Test 4: List Entities with Limit
test_endpoint "GET" "${API_V3}/entities?limit=5" "List Entities (limit 5)"

# Test 5: Search Entities by Type
test_endpoint "GET" "${API_V3}/entities?type=restaurant" "Search Entities by Type"

# Test 6: List Curations
test_endpoint "GET" "${API_V3}/curations" "List All Curations"

# Test 7: List Curations with Limit
test_endpoint "GET" "${API_V3}/curations?limit=5" "List Curations (limit 5)"

# Test 8: Create Entity (if you want to test POST)
# Uncomment to test entity creation
# ENTITY_JSON='{
#   "entity_id": "test_restaurant_001",
#   "type": "restaurant",
#   "name": "Test Restaurant",
#   "metadata": {
#     "cuisine": "Italian",
#     "location": "New York"
#   }
# }'
# test_endpoint "POST" "${API_V3}/entities" "Create Test Entity" "$ENTITY_JSON"

# Test 9: Query Entities (POST with JSON query)
QUERY_JSON='{
  "filters": {
    "type": "restaurant"
  },
  "limit": 3
}'
test_endpoint "POST" "${API_V3}/entities/query" "Query Entities" "$QUERY_JSON"

# Test 10: Get Schema
test_endpoint "GET" "${API_V3}/schema/entities" "Get Entities Schema"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Test Complete!${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Summary
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Check error logs if any tests failed"
echo "2. Review the response data structure"
echo "3. Test with your actual data"
echo ""
echo -e "${YELLOW}Install jq for better output:${NC}"
echo "  brew install jq    # macOS"
echo "  apt install jq     # Linux"
