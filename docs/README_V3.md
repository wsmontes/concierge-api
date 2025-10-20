# Concierge API V3 - Document-Oriented Database

## 🎯 Overview

V3 is a **complete redesign** using a **document-oriented architecture** within MySQL 8.0+. This approach:

- ✅ **Minimizes schema complexity** - Only 2 tables with JSON documents
- ✅ **Eliminates ETL** - No derived tables or materialized views
- ✅ **Enables flexible queries** - JSON_TABLE for array exploration
- ✅ **Supports NoSQL migration** - Documents are portable to MongoDB/Cosmos
- ✅ **Maintains ACID guarantees** - Full MySQL transaction support

---

## 📋 Table of Contents

- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Database Schema](#database-schema)
- [API Reference](#api-reference)
- [Query Examples](#query-examples)
- [Migration Guide](#migration-guide)
- [Performance Tips](#performance-tips)

---

## 🏗️ Architecture

### Design Principles

1. **Document-Oriented Storage**
   - Business data stored as JSON documents in `doc` column
   - Structural metadata (id, type, timestamps) as regular columns
   - Functional indexes on JSON paths (no materialized columns)

2. **Two-Table Design**
   ```
   entities_v3
   ├── id (PK)
   ├── type (restaurant|hotel|attraction|event|other)
   ├── doc (JSON) → complete entity document
   ├── created_at, updated_at, version
   └── Functional indexes on doc.name, doc.status, etc.
   
   curations_v3
   ├── id (PK)
   ├── entity_id (FK → entities_v3.id, CASCADE DELETE)
   ├── doc (JSON) → complete curation document
   ├── created_at, updated_at, version
   └── Functional indexes on doc.curator.id, etc.
   ```

3. **JSON Schema Validation**
   - Pydantic models enforce schema at application layer
   - Database CHECK constraints for critical fields
   - Backward compatible with existing `entities.schema.json` and `curations.schema.json`

4. **Optimistic Locking**
   - `version` column incremented on every update
   - `If-Match` header or request body version for conflict detection

---

## 🚀 Quick Start

### Prerequisites

- MySQL 8.0+
- Python 3.8+
- pip packages: `pydantic`, `mysql-connector-python`, `flask`, `flask-cors`

### Installation

```bash
# 1. Navigate to mysql_api directory
cd mysql_api

# 2. Install Python dependencies
pip install pydantic mysql-connector-python flask flask-cors jsonschema

# 3. Set database credentials (optional - defaults to localhost)
export DB_HOST=localhost
export DB_PORT=3306
export DB_USER=root
export DB_PASSWORD=your_password
export DB_NAME=concierge

# 4. Deploy V3 schema
mysql -u root -p concierge < schema_v3.sql

# 5. (Optional) Migrate from V2
mysql -u root -p concierge < migrate_v2_to_v3.sql
# Review output, then execute: COMMIT; or ROLLBACK;

# 6. Start API server
python app_v3.py
```

### Using the Deployment Script

```bash
# Make script executable
chmod +x deploy_v3.sh

# Deploy with V2 migration
./deploy_v3.sh --migrate-from-v2

# Test mode (inserts sample data)
./deploy_v3.sh --test-mode

# Skip backup (for testing)
./deploy_v3.sh --skip-backup
```

---

## 🗄️ Database Schema

### Entities Table

```sql
CREATE TABLE entities_v3 (
  id          VARCHAR(128) PRIMARY KEY,
  type        VARCHAR(64) NOT NULL,
  doc         JSON NOT NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  version     INT UNSIGNED NOT NULL DEFAULT 1,
  name_ft     VARCHAR(512) GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) STORED,
  -- Indexes and constraints...
);
```

**Document Structure** (`doc` column):
```json
{
  "name": "Fogo de Chão - Jardins",
  "status": "active",
  "metadata": [
    {
      "type": "google_places",
      "source": "google-places-api",
      "importedAt": "2025-10-20T18:25:00Z",
      "data": {
        "placeId": "gp_abc123",
        "rating": {"average": 4.5, "totalRatings": 1123},
        "location": {"city": "São Paulo", "country": "BR"}
      }
    }
  ],
  "sync": {
    "serverId": 123,
    "status": "synced",
    "lastSyncedAt": "2025-10-20T18:30:00Z"
  }
}
```

### Curations Table

```sql
CREATE TABLE curations_v3 (
  id          VARCHAR(128) PRIMARY KEY,
  entity_id   VARCHAR(128) NOT NULL,
  doc         JSON NOT NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  version     INT UNSIGNED NOT NULL DEFAULT 1,
  -- Foreign key with CASCADE DELETE
  CONSTRAINT fk_cur_entity_v3 FOREIGN KEY (entity_id) REFERENCES entities_v3(id) ON DELETE CASCADE
);
```

**Document Structure** (`doc` column):
```json
{
  "curator": {
    "id": "curator_wagner",
    "name": "Wagner",
    "email": "wagner@example.com"
  },
  "createdAt": "2025-10-20T18:27:00Z",
  "updatedAt": "2025-10-20T19:00:00Z",
  "categories": {
    "cuisine": ["brazilian", "barbecue"],
    "mood": ["lively", "executive"],
    "price_range": ["expensive"]
  },
  "sources": ["audio 2025-09-09", "site oficial"],
  "notes": {
    "public": "Best churrascaria in Jardins",
    "private": "Owner is a friend"
  }
}
```

### Functional Indexes

```sql
-- Entity name (case-insensitive)
CREATE INDEX idx_entities_name ON entities_v3 
  ((LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name')))));

-- Entity status
CREATE INDEX idx_entities_status ON entities_v3 
  ((JSON_UNQUOTE(JSON_EXTRACT(doc, '$.status'))));

-- Curator ID
CREATE INDEX idx_curations_curator ON curations_v3 
  ((JSON_UNQUOTE(JSON_EXTRACT(doc, '$.curator.id'))));
```

---

## 🌐 API Reference

### Base URL
```
http://localhost:5000/api/v3
```

### Endpoints

#### Entities

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/entities` | Create entity |
| `GET` | `/entities/<id>` | Get entity by ID |
| `PATCH` | `/entities/<id>` | Update entity (partial) |
| `DELETE` | `/entities/<id>` | Delete entity |
| `GET` | `/entities?type=X` | List entities by type |
| `GET` | `/entities?name=X` | Search entities by name |

#### Curations

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/curations` | Create curation |
| `GET` | `/curations/<id>` | Get curation by ID |
| `PATCH` | `/curations/<id>` | Update curation (partial) |
| `DELETE` | `/curations/<id>` | Delete curation |
| `GET` | `/entities/<id>/curations` | Get entity's curations |
| `GET` | `/curations/search?category=X&concept=Y` | Search curations |

#### Query DSL

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/query` | Execute flexible query |

### Example Requests

#### Create Entity
```bash
curl -X POST http://localhost:5000/api/v3/entities \
  -H "Content-Type: application/json" \
  -d '{
    "id": "rest_example",
    "type": "restaurant",
    "doc": {
      "name": "Example Restaurant",
      "status": "draft",
      "metadata": [{
        "type": "collector",
        "data": {"city": "São Paulo"}
      }]
    }
  }'
```

#### Update Entity (Partial)
```bash
curl -X PATCH http://localhost:5000/api/v3/entities/rest_example \
  -H "Content-Type: application/json" \
  -H "If-Match: 1" \
  -d '{
    "doc": {
      "status": "active"
    }
  }'
```

#### Search Curations by Category
```bash
curl "http://localhost:5000/api/v3/curations/search?category=mood&concept=lively"
```

#### Query DSL Example
```bash
curl -X POST http://localhost:5000/api/v3/query \
  -H "Content-Type: application/json" \
  -d '{
    "from": "curations",
    "explode": {"path": "$.categories.mood", "as": "mood"},
    "filters": [
      {"path": "mood", "operator": "=", "value": "lively"}
    ],
    "limit": 20
  }'
```

---

## 🔍 Query Examples

See **`queries_v3.sql`** for 50+ examples. Highlights:

### Find Entities with Specific Mood

```sql
SELECT DISTINCT c.entity_id, e.doc->>'$.name' AS name
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.mood'),
  '$[*]' COLUMNS (mood VARCHAR(512) PATH '$')
) jt
WHERE jt.mood = 'lively';
```

### Top 10 Most Common Cuisines

```sql
SELECT jt.cuisine, COUNT(*) AS frequency
FROM curations_v3 c
CROSS JOIN JSON_TABLE(
  JSON_EXTRACT(c.doc, '$.categories.cuisine'),
  '$[*]' COLUMNS (cuisine VARCHAR(512) PATH '$')
) jt
GROUP BY jt.cuisine
ORDER BY frequency DESC
LIMIT 10;
```

### Entities with Multiple Criteria (Brazilian + Expensive + Lively)

```sql
SELECT DISTINCT c.entity_id, e.doc->>'$.name' AS name
FROM curations_v3 c
JOIN entities_v3 e ON e.id = c.entity_id
WHERE JSON_CONTAINS(JSON_EXTRACT(c.doc, '$.categories.cuisine'), '"brazilian"')
  AND JSON_CONTAINS(JSON_EXTRACT(c.doc, '$.categories.price_range'), '"expensive"')
  AND JSON_CONTAINS(JSON_EXTRACT(c.doc, '$.categories.mood'), '"lively"');
```

### Update with Optimistic Locking

```sql
UPDATE entities_v3
SET doc = JSON_MERGE_PATCH(doc, JSON_OBJECT('status', 'active')),
    updated_at = CURRENT_TIMESTAMP(3),
    version = version + 1
WHERE id = 'rest_example' AND version = 1;
```

---

## 🔄 Migration Guide

### From V2 to V3

1. **Backup your database**
   ```bash
   mysqldump -u root -p concierge > backup_v2.sql
   ```

2. **Run migration script**
   ```bash
   mysql -u root -p concierge < migrate_v2_to_v3.sql
   ```

3. **Review migration output**
   - Check entity/curation counts
   - Validate sample documents
   - Verify no orphaned curations

4. **Commit or rollback**
   ```sql
   -- If everything looks good:
   COMMIT;
   
   -- If issues found:
   ROLLBACK;
   ```

5. **Update application code**
   - Switch from `models_v2.py` to `models_v3.py`
   - Update API endpoints to `/api/v3/*`
   - Use new query helpers from `database_v3.py`

---

## ⚡ Performance Tips

### 1. **Index Only What You Query**
Don't create functional indexes for every JSON path. Start minimal, add based on `EXPLAIN` output.

```sql
-- Check if index is used
EXPLAIN SELECT * FROM entities_v3 
WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(doc, '$.name'))) LIKE '%fogo%';
```

### 2. **Use Views for Common Patterns**
Pre-built views like `vw_curation_moods` simplify queries:

```sql
-- Instead of complex JSON_TABLE every time:
SELECT entity_id, mood FROM vw_curation_moods WHERE mood = 'lively';
```

### 3. **Batch Updates with JSON_MERGE_PATCH**
```sql
-- Update multiple fields at once
UPDATE curations_v3
SET doc = JSON_MERGE_PATCH(doc, JSON_OBJECT(
  'notes', JSON_OBJECT('private', 'Updated note'),
  'categories', JSON_OBJECT('mood', JSON_ARRAY('lively', 'romantic'))
)),
version = version + 1
WHERE id = 'cur_example';
```

### 4. **Optimize Deep Paths**
Frequently-queried fields should be near JSON root:

```json
// ✅ Good (shallow)
{"name": "...", "city": "São Paulo"}

// ❌ Slower (deep)
{"metadata": [{"data": {"location": {"city": "São Paulo"}}}]}
```

### 5. **Use Connection Pooling**
The `DatabaseV3` class already implements pooling. Reuse instances:

```python
# ✅ Singleton pattern
db = DatabaseV3(...)  # Create once

# ❌ Don't do this in loops
for i in range(100):
    db = DatabaseV3(...)  # Creates 100 pools!
```

---

## 📚 Additional Resources

- **Schema Definition**: `schema_v3.sql`
- **Example Queries**: `queries_v3.sql`
- **Migration Script**: `migrate_v2_to_v3.sql`
- **Python Models**: `models_v3.py`
- **Database Layer**: `database_v3.py`
- **API Layer**: `api_v3.py`
- **Application Entry**: `app_v3.py`

---

## 🤝 Contributing

When adding new features to V3:

1. **Update JSON Schema** first (`entities.schema.json`, `curations.schema.json`)
2. **Add Pydantic models** in `models_v3.py`
3. **Create database methods** in `database_v3.py`
4. **Expose API endpoints** in `api_v3.py`
5. **Document with examples** in `queries_v3.sql`

---

## 📝 License

Same as parent project.

---

**Built with ❤️ using MySQL 8.0 JSON features**
