# Deploying V3 to PythonAnywhere

## Quick Answer: YES, with ONE file swap

Your V3 code will run on **both local and PythonAnywhere** with minimal changes.

---

## ✅ What Works Automatically

These work **identically** on both environments:

1. ✅ **app_v3.py** - Application factory (no changes needed)
2. ✅ **api_v3.py** - REST API endpoints (no changes needed)
3. ✅ **models_v3.py** - Pydantic models (no changes needed)
4. ✅ **Environment variables** - DB_HOST, DB_USER, DB_PASSWORD, DB_NAME
5. ✅ **Schema** - reset_v3.sql works on PythonAnywhere MySQL

---

## ⚠️ ONE Critical Change Required

**PythonAnywhere requires `mysqlclient` (MySQLdb) instead of `mysql-connector-python`**

### Option 1: Use the Dual-Compatible Version (Recommended)

Replace `database_v3.py` with `database_v3_pythonanywhere.py`:

```bash
# When deploying to PythonAnywhere:
cp database_v3.py database_v3_original.py  # Backup
cp database_v3_pythonanywhere.py database_v3.py

# This version auto-detects the environment and uses:
# - MySQLdb on PythonAnywhere
# - mysql-connector-python locally
```

### Option 2: Install Different Dependencies Per Environment

**Local (your Mac):**
```txt
# requirements.txt
mysql-connector-python==8.2.0
```

**PythonAnywhere:**
```txt
# requirements_pythonanywhere.txt
mysqlclient==2.2.0
```

---

## 📋 Deployment Steps

### Step 1: Upload Files to PythonAnywhere

Upload these files via **Files** tab or git:
```
mysql_api/
├── wsgi_v3.py                    # NEW - PythonAnywhere entry point
├── app_v3.py                     # Same as local
├── api_v3.py                     # Same as local
├── models_v3.py                  # Same as local
├── database_v3.py                # SWAP with database_v3_pythonanywhere.py
├── reset_v3.sql                  # Run this to create schema
└── queries_v3.sql                # Optional - for testing
```

### Step 2: Set Environment Variables

In **Web** tab → **Environment Variables** section:

```bash
DB_HOST=wsmontes.mysql.pythonanywhere-services.com
DB_USER=wsmontes
DB_PASSWORD=your_password_here
DB_NAME=wsmontes$concierge_db
```

### Step 3: Configure WSGI File

In **Web** tab → **Code** section → **WSGI configuration file**, replace contents with:

```python
import sys
import os

# Add project directory
project_home = '/home/wsmontes/Concierge-Analyzer/mysql_api'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

# Import application
from wsgi_v3 import application
```

### Step 4: Install Dependencies

In **Bash console**:

```bash
cd ~/Concierge-Analyzer/mysql_api
pip3 install --user mysqlclient==2.2.0
pip3 install --user flask==2.3.3
pip3 install --user flask-cors==4.0.0
pip3 install --user pydantic==2.5.0
```

### Step 5: Create Database Schema

In **MySQL console** (from PythonAnywhere dashboard):

```bash
# 1. Open MySQL console
# 2. Run the reset script:
source /home/wsmontes/Concierge-Analyzer/mysql_api/reset_v3.sql
```

Or via **Bash console**:

```bash
mysql -u wsmontes -p wsmontes\$concierge_db < ~/Concierge-Analyzer/mysql_api/reset_v3.sql
```

### Step 6: Reload Web App

In **Web** tab → click **Reload** button

---

## 🧪 Testing

### Test Locally (Mac):

```bash
cd mysql_api
python app_v3.py

# In another terminal:
curl http://localhost:5000/api/v3/health
curl http://localhost:5000/api/v3/entities
```

### Test on PythonAnywhere:

```bash
curl https://wsmontes.pythonanywhere.com/api/v3/health
curl https://wsmontes.pythonanywhere.com/api/v3/entities
```

---

## 🔍 Key Differences: Local vs PythonAnywhere

| Feature | Local (Mac) | PythonAnywhere |
|---------|-------------|----------------|
| **MySQL Driver** | mysql-connector-python | mysqlclient (MySQLdb) |
| **DB Host** | localhost | wsmontes.mysql.pythonanywhere-services.com |
| **DB Name** | concierge | wsmontes$concierge_db |
| **Entry Point** | app_v3.py | wsgi_v3.py |
| **Server** | Flask dev server | WSGI (production) |
| **Connection Pool** | MySQLConnectionPool | Manual connections |

---

## ✅ Verification Checklist

After deployment:

- [ ] Navigate to `https://wsmontes.pythonanywhere.com/`
- [ ] Should see: `{"name": "Concierge Analyzer API", "version": "3.0", ...}`
- [ ] Check `/api/v3/health` - should return `{"status": "healthy"}`
- [ ] Check `/api/v3/entities` - should return sample data
- [ ] Check `/api/v3/curations` - should return sample curations
- [ ] Try creating entity via POST `/api/v3/entities`

---

## 🐛 Troubleshooting

### Error: "No module named 'MySQLdb'"

**Solution:** Install mysqlclient:
```bash
pip3 install --user mysqlclient
```

### Error: "No module named 'database_v3'"

**Solution:** Ensure all files uploaded and path is correct in WSGI file

### Error: "Access denied for user"

**Solution:** Check DB_PASSWORD environment variable and MySQL user permissions

### Error: "Table 'entities_v3' doesn't exist"

**Solution:** Run `reset_v3.sql` to create schema:
```bash
mysql -u wsmontes -p wsmontes\$concierge_db < reset_v3.sql
```

### Error: "500 Internal Server Error"

**Solution:** Check error logs:
1. Web tab → Log files → Error log
2. Look for Python tracebacks
3. Common causes:
   - Missing environment variables
   - Wrong database credentials
   - Module import errors

---

## 📦 Complete File Manifest

**Files that work on BOTH environments (no changes):**
- ✅ app_v3.py
- ✅ api_v3.py
- ✅ models_v3.py
- ✅ reset_v3.sql
- ✅ queries_v3.sql

**Files specific to PythonAnywhere:**
- 🔄 database_v3.py → use database_v3_pythonanywhere.py
- ➕ wsgi_v3.py (new)

**Configuration (environment-specific):**
- Local: .env file or OS environment
- PythonAnywhere: Web tab → Environment variables

---

## 🎯 Summary

**YES**, your V3 code can run on both environments with just:

1. **ONE file swap**: `database_v3_pythonanywhere.py` → `database_v3.py`
2. **Environment variables**: Set DB credentials for each environment
3. **Entry point**: Use `app_v3.py` locally, `wsgi_v3.py` on PythonAnywhere

Everything else (API, models, schema, queries) works identically! 🚀
