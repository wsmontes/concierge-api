# Directory Structure Guide

## Purpose
This document explains the organization of the Concierge Analyzer workspace.

---

## 📂 Folder Organization Principles

### 1. **mysql_api/** - Production Application Code
**Purpose**: Core API application that runs in production  
**Contains**: Only files needed to run the API server  
**Deployment**: This entire folder is deployed to PythonAnywhere

**Files:**
- `app_v3.py` - Flask application factory
- `api_v3.py` - REST API endpoint definitions
- `models_v3.py` - Pydantic data models
- `database_v3.py` - Database layer (local development)
- `database_v3_pythonanywhere.py` - Database layer (PythonAnywhere)
- `wsgi_v3.py` - WSGI entry point for production
- `requirements.txt` - Python dependencies
- `.env` - Environment variables (gitignored)
- `.env.template` - Environment variables template

---

### 2. **docs/** - Documentation
**Purpose**: All documentation files  
**Contains**: READMEs, guides, architecture docs  
**Use**: Read to understand the system

**Files:**
- `README_V3.md` - Complete V3 API documentation
- `V3_IMPLEMENTATION_SUMMARY.md` - Technical overview and architecture
- `DEPLOYMENT_PYTHONANYWHERE.md` - PythonAnywhere deployment guide
- `V3_DEPLOYMENT_TREE.txt` - Visual deployment guide
- `DIRECTORY_STRUCTURE.md` - This file

---

### 3. **scripts/** - One-Time Utilities
**Purpose**: Scripts for setup, deployment, and utilities  
**Contains**: Bash scripts, SQL scripts for database management  
**Use**: Run once or occasionally for maintenance

**Database Scripts:**
- `reset_v3.sql` - Pure SQL database reset with sample data
- `reset_v3.sh` - Interactive bash script for database reset
- `migrate_v2_to_v3.sql` - Migration from V2 to V3 schema
- `queries_v3.sql` - 50+ example SQL queries
- `export_v3_snapshot.sql` - Export complete database state

**Deployment Scripts:**
- `deploy_v3.sh` - Production deployment automation
- `quickstart_v3.sh` - Interactive 5-minute setup

**Utility Scripts:**
- `concierge_parser.py` - Data parser utility

---

### 4. **examples/** - Sample Data & Schemas
**Purpose**: Reference data and schema definitions  
**Contains**: JSON schemas and example data  
**Use**: Reference when creating new entities/curations

**Subfolders:**

#### `examples/schemas/`
**JSON Schema Definitions:**
- `entities.schema.json` - Entity document schema
- `curations.schema.json` - Curation document schema

#### `examples/data/`
**Sample Data Files:**
- `entities_example.json` - Example entities
- `curations_example.json` - Example curations

---

### 5. **tests/** - Test Files
**Purpose**: Automated tests  
**Contains**: Unit tests, integration tests  
**Use**: Run to verify code correctness

**Status**: To be populated with test files

---

### 6. **mysql_api_venv/** - Python Virtual Environment
**Purpose**: Isolated Python dependencies  
**Contains**: Python packages installed via pip  
**Use**: Activated during development  
**Git**: Ignored (not committed to repository)

---

## 🔄 File Movement Rules

### ✅ **Production Code** → `mysql_api/`
Files that run in production:
- Python application files (*.py)
- Requirements file
- Environment templates
- WSGI entry points

### 📚 **Documentation** → `docs/`
Files that explain the system:
- README files
- Architecture docs
- Deployment guides
- API documentation

### ⚙️ **One-Time Scripts** → `scripts/`
Files run once or occasionally:
- Database setup scripts (*.sql)
- Deployment automation (*.sh)
- Migration scripts
- Utility tools

### 📊 **Reference Data** → `examples/`
Files used as reference:
- JSON schemas (`examples/schemas/`)
- Sample data (`examples/data/`)
- Templates

### 🧪 **Test Code** → `tests/`
Files for testing:
- Unit tests
- Integration tests
- Test fixtures

---

## 🎯 Quick Reference

### "Where do I put...?"

**A new Python module?**  
→ `mysql_api/` if it's core functionality  
→ `scripts/` if it's a one-time utility

**A SQL script?**  
→ `scripts/` (database scripts)

**Documentation?**  
→ `docs/`

**Example data?**  
→ `examples/data/`

**JSON schema?**  
→ `examples/schemas/`

**Test file?**  
→ `tests/`

---

## 🚫 What NOT to Mix

### Don't put in `mysql_api/`:
- ❌ One-time setup scripts
- ❌ Example data files
- ❌ Documentation
- ❌ SQL utility scripts

### Don't put in `scripts/`:
- ❌ Core application code
- ❌ API endpoint definitions
- ❌ Data models

### Don't put in `docs/`:
- ❌ Executable code
- ❌ Data files
- ❌ Configuration

---

## 📋 Deployment Checklist

### Local Development
Required folders:
- ✅ `mysql_api/` (application code)
- ✅ `mysql_api_venv/` (virtual environment)
- ✅ `scripts/` (for database setup)

### PythonAnywhere Production
Upload only:
- ✅ `mysql_api/` folder
- ✅ `scripts/reset_v3.sql` (initial setup)

Do NOT upload:
- ❌ `mysql_api_venv/` (create new venv on server)
- ❌ `docs/` (not needed in production)
- ❌ `examples/` (not needed in production)
- ❌ `tests/` (not needed in production)
- ❌ `.env` (create new on server)

---

## 🔧 Maintenance

### Adding New Features
1. Code → `mysql_api/`
2. Tests → `tests/`
3. Documentation → `docs/`
4. Examples → `examples/` (if applicable)

### Database Changes
1. Schema changes → Update `scripts/reset_v3.sql`
2. Migration script → Add to `scripts/`
3. Update documentation → `docs/README_V3.md`

---

## 📝 Notes

- **Keep it clean**: Don't mix production code with utilities
- **Document everything**: Update docs when adding features
- **One purpose per folder**: Each folder has a clear role
- **Git-friendly**: `.gitignore` excludes generated files and venvs
- **Deployment-ready**: `mysql_api/` is self-contained for deployment
