# Concierge API

A document-oriented REST API for restaurant and hotel curation, powered by MySQL 8.0+ JSON features.

![Status](https://img.shields.io/badge/status-private-red)
[![Python Version](https://img.shields.io/badge/python-3.8%2B-blue)](https://www.python.org/downloads/)
[![Flask](https://img.shields.io/badge/flask-2.x-green)](https://flask.palletsprojects.com/)

> **Note:** This is a private project by Wagner Montes. All rights reserved.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/wsmontes/concierge-api.git
cd concierge-api

# Create virtual environment
python3 -m venv mysql_api_venv
source mysql_api_venv/bin/activate  # On Windows: mysql_api_venv\Scripts\activate

# Install dependencies
pip install -r mysql_api/requirements.txt

# Set up environment variables
cp mysql_api/.env.template mysql_api/.env
# Edit .env with your database configuration

# Run the development server
cd mysql_api
python app_v3.py
```

The API will be available at `http://localhost:5000`

## 🚀 Deployment

This project is configured for deployment on [PythonAnywhere](https://www.pythonanywhere.com/). See the `docs/DEPLOYMENT_PYTHONANYWHERE.md` for detailed deployment instructions.

### PythonAnywhere Setup
- The repository is designed to work seamlessly with PythonAnywhere's hosting environment
- Database configuration automatically adapts for PythonAnywhere's MySQL service
- WSGI entry point configured in `mysql_api/wsgi_v3.py`

## 🗂️ Project Structure

```
Concierge-Analyzer/
├── mysql_api/              # Core V3 API application (production code)
│   ├── app_v3.py          # Flask application factory
│   ├── api_v3.py          # REST API endpoints
│   ├── models_v3.py       # Pydantic data models
│   ├── database_v3.py     # Database layer (local dev)
│   ├── database_v3_pythonanywhere.py  # DB layer (PythonAnywhere compatible)
│   ├── wsgi_v3.py         # WSGI entry point for production
│   ├── requirements.txt   # Python dependencies
│   └── .env.template      # Environment variables template
│
├── docs/                   # Documentation
│   ├── README_V3.md       # V3 API documentation
│   ├── V3_IMPLEMENTATION_SUMMARY.md  # Technical overview
│   ├── DEPLOYMENT_PYTHONANYWHERE.md  # Deployment guide
│   └── V3_DEPLOYMENT_TREE.txt        # Visual deployment guide
│
├── scripts/                # One-time setup and utility scripts
│   ├── reset_v3.sh        # Interactive database reset (bash)
│   ├── reset_v3.sql       # Database reset (pure SQL)
│   ├── deploy_v3.sh       # Production deployment automation
│   ├── quickstart_v3.sh   # 5-minute setup script
│   ├── migrate_v2_to_v3.sql  # V2 to V3 migration
│   ├── queries_v3.sql     # Example SQL queries
│   ├── export_v3_snapshot.sql  # Database snapshot export
│   └── concierge_parser.py     # Data parser utility
│
├── examples/               # Sample data and schemas
│   ├── schemas/           # JSON Schema definitions
│   │   ├── entities.schema.json   # Entity schema
│   │   └── curations.schema.json  # Curation schema
│   └── data/              # Example data files
│       ├── entities_example.json  # Sample entities
│       └── curations_example.json # Sample curations
│
├── tests/                  # Test files (to be added)
│   └── (test files here)
│
└── mysql_api_venv/         # Python virtual environment (gitignored)
```

---

## 🚀 Quick Start

### Local Development

```bash
# 1. Clone repository
git clone https://github.com/wsmontes/Concierge-Analyzer.git
cd Concierge-Analyzer

# 2. Set up Python environment
cd mysql_api
python3 -m venv ../mysql_api_venv
source ../mysql_api_venv/bin/activate
pip install -r requirements.txt

# 3. Configure database
cp .env.template .env
# Edit .env with your MySQL credentials

# 4. Create database schema
mysql -u root -p concierge < ../scripts/reset_v3.sql

# 5. Start API server
python app_v3.py
```

### PythonAnywhere Deployment

See [docs/DEPLOYMENT_PYTHONANYWHERE.md](docs/DEPLOYMENT_PYTHONANYWHERE.md) for complete deployment guide.

---

## 📚 Documentation

- **[V3 API Documentation](docs/README_V3.md)** - Complete API reference
- **[Implementation Summary](docs/V3_IMPLEMENTATION_SUMMARY.md)** - Technical architecture
- **[PythonAnywhere Deployment](docs/DEPLOYMENT_PYTHONANYWHERE.md)** - Production deployment
- **[Example Queries](scripts/queries_v3.sql)** - 50+ SQL query examples

---

## 🏗️ Architecture

### V3 Document-Oriented Design

- **2 Tables**: `entities_v3`, `curations_v3`
- **JSON Storage**: Business data in `doc` column
- **Functional Indexes**: Fast queries on JSON paths
- **No ETL**: Query nested data directly with JSON_TABLE
- **Schema Validation**: Pydantic models + MySQL CHECK constraints

### Key Features

✅ **RESTful API** - Full CRUD + Query DSL  
✅ **Document Storage** - Flexible JSON documents  
✅ **Fast Queries** - Functional indexes on JSON paths  
✅ **Array Exploration** - JSON_TABLE for categories/metadata  
✅ **Optimistic Locking** - Version control with If-Match headers  
✅ **Connection Pooling** - High-performance database access  
✅ **Dual Compatible** - Works on local + PythonAnywhere  

---

## 📊 Database Schema

### Entities Table
```sql
entities_v3 (
  id          VARCHAR(128) PRIMARY KEY,
  type        VARCHAR(64) NOT NULL,
  doc         JSON NOT NULL,
  created_at  DATETIME(3),
  updated_at  DATETIME(3),
  version     INT UNSIGNED
)
```

### Curations Table
```sql
curations_v3 (
  id          VARCHAR(128) PRIMARY KEY,
  entity_id   VARCHAR(128) REFERENCES entities_v3(id),
  doc         JSON NOT NULL,
  created_at  DATETIME(3),
  updated_at  DATETIME(3),
  version     INT UNSIGNED
)
```

---

## 🔧 Utilities

### Database Management
- `scripts/reset_v3.sql` - Fresh database with sample data
- `scripts/migrate_v2_to_v3.sql` - Migrate from V2 schema
- `scripts/export_v3_snapshot.sql` - Export complete database state

### Development Tools
- `scripts/quickstart_v3.sh` - Interactive 5-minute setup
- `scripts/deploy_v3.sh` - Production deployment automation
- `scripts/queries_v3.sql` - 50+ example queries

### Example Data
- `examples/schemas/` - JSON Schema definitions
- `examples/data/` - Sample entities and curations

---

## 🧪 Testing

```bash
# Health check
curl http://localhost:5000/api/v3/health

# List entities
curl http://localhost:5000/api/v3/entities

# List curations
curl http://localhost:5000/api/v3/curations

# Query DSL
curl -X POST http://localhost:5000/api/v3/query \
  -H "Content-Type: application/json" \
  -d '{"filters": [{"field": "type", "operator": "eq", "value": "restaurant"}]}'
```

---

## 📝 API Endpoints

### Entities
- `GET /api/v3/entities` - List entities
- `POST /api/v3/entities` - Create entity
- `GET /api/v3/entities/{id}` - Get entity
- `PATCH /api/v3/entities/{id}` - Update entity
- `DELETE /api/v3/entities/{id}` - Delete entity

### Curations
- `GET /api/v3/curations` - List curations
- `POST /api/v3/curations` - Create curation
- `GET /api/v3/curations/{id}` - Get curation
- `DELETE /api/v3/curations/{id}` - Delete curation
- `GET /api/v3/entities/{id}/curations` - List entity curations

### Query
- `POST /api/v3/query` - Execute Query DSL

---

## 🛠️ Tech Stack

- **Backend**: Python 3.8+, Flask 2.3.3
- **Database**: MySQL 8.0+
- **Validation**: Pydantic 2.5.0
- **CORS**: Flask-CORS 4.0.0
- **Database Driver**: 
  - Local: mysql-connector-python 8.2.0
  - PythonAnywhere: mysqlclient 2.2.0

---

## 📦 Dependencies

See [mysql_api/requirements.txt](mysql_api/requirements.txt) for complete list.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is private and proprietary.

---

## 👤 Author

**Wagner Montes**  
GitHub: [@wsmontes](https://github.com/wsmontes)

---

## 🔗 Links

- [GitHub Repository](https://github.com/wsmontes/Concierge-Analyzer)
- [PythonAnywhere Deployment](https://wsmontes.pythonanywhere.com)

---

## 📮 Support

For questions or issues, please open a GitHub issue.
