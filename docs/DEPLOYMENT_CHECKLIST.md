# PythonAnywhere V3 Deployment - Complete Checklist

Follow these steps in order to clean up and deploy V3 successfully.

## 📋 Phase 1: Cleanup (Run on PythonAnywhere Bash Console)

```bash
# 1. Navigate to project
cd ~/Concierge-Analyzer/mysql_api

# 2. Check current disk usage
quota

# 3. Remove Rust compiler cache (frees the most space)
rm -rf ~/.cache/puccinialin
rm -rf ~/.rustup
rm -rf ~/.cargo

# 4. Uninstall conflicting packages
pip3.10 uninstall -y pydantic pydantic-core email-validator dnspython
pip3.13 uninstall -y pydantic pydantic-core email-validator dnspython

# 5. Clean pip cache
pip3.13 cache purge

# 6. Verify cleanup
pip3.13 list | grep pydantic  # Should show nothing
quota  # Should show more free space
```

**✅ Checkpoint**: You should have ~100-200MB freed from Rust cache removal.

---

## 📋 Phase 2: Upload Files (From Your Local Machine)

Upload these NEW files to `~/Concierge-Analyzer/mysql_api/`:

- [ ] `requirements_pythonanywhere.txt`
- [ ] `models_v3_pythonanywhere.py`
- [ ] `app_v3.py` (if not already there)
- [ ] `api_v3.py` (if not already there)
- [ ] `database_v3_pythonanywhere.py` (if not already there)
- [ ] `wsgi_v3.py` (updated version)
- [ ] `.env` (with your DB password)

**Upload Method Options:**
1. PythonAnywhere Files tab (web interface)
2. Git push/pull
3. SCP/SFTP

---

## 📋 Phase 3: Install Packages (Run on PythonAnywhere)

```bash
cd ~/Concierge-Analyzer/mysql_api

# Install V3 dependencies for Python 3.13
pip3.13 install Flask==2.3.3
pip3.13 install Flask-CORS==4.0.0
pip3.13 install mysql-connector-python==8.2.0
pip3.13 install python-dotenv==1.0.0
pip3.13 install jsonschema==4.19.2
pip3.13 install python-dateutil==2.8.2
pip3.13 install "pydantic>=2.9.0,<3.0.0"

# Verify installation
pip3.13 list | grep -E "pydantic|Flask|mysql"
```

**Expected output:**
```
Flask                   2.3.3
Flask-CORS              4.0.0
mysql-connector-python  8.2.0
pydantic                2.9.x (or higher)
python-dateutil         2.8.2
python-dotenv           1.0.0
```

---

## 📋 Phase 4: Configure Models (Run on PythonAnywhere)

```bash
cd ~/Concierge-Analyzer/mysql_api

# Backup original
cp models_v3.py models_v3_original.py 2>/dev/null || true

# Use PythonAnywhere-compatible version
cp models_v3_pythonanywhere.py models_v3.py

# Verify
head -20 models_v3.py | grep -E "Purpose|EmailStr"
```

**✅ Checkpoint**: Should see "PythonAnywhere Compatible" in header, no EmailStr import.

---

## 📋 Phase 5: Database Setup (Run on PythonAnywhere)

### Option A: If database already exists
```bash
# Just verify connection
mysql -u wsmontes -p -h wsmontes.mysql.pythonanywhere-services.com wsmontes\$concierge_db -e "SHOW TABLES;"
```

### Option B: If need to create V3 tables
```bash
# Upload reset_v3.sql from scripts/ folder first
# Then run:
mysql -u wsmontes -p -h wsmontes.mysql.pythonanywhere-services.com wsmontes\$concierge_db < ~/Concierge-Analyzer/scripts/reset_v3.sql
```

**✅ Checkpoint**: Should see `entities_v3` and `curations_v3` tables.

---

## 📋 Phase 6: Configure WSGI (PythonAnywhere Web Tab)

1. Go to **Web** tab
2. Find **WSGI configuration file** link (usually `/var/www/wsmontes_pythonanywhere_com_wsgi.py`)
3. Click to edit
4. Replace contents with your `wsgi_v3.py` content, OR
5. Update the path to point to: `/home/wsmontes/Concierge-Analyzer/mysql_api/wsgi_v3.py`

**Key WSGI settings to verify:**
```python
project_home = '/home/wsmontes/Concierge-Analyzer/mysql_api'
DB_HOST = 'wsmontes.mysql.pythonanywhere-services.com'
DB_NAME = 'wsmontes$concierge_db'
```

---

## 📋 Phase 7: Environment Variables (PythonAnywhere Web Tab)

Still in **Web** tab, scroll to **Environment variables** section.

Add these (if not using .env file):
- `DB_PASSWORD` = your_mysql_password
- `FLASK_DEBUG` = true (for testing)

**OR** ensure `.env` file exists with:
```
DB_HOST=wsmontes.mysql.pythonanywhere-services.com
DB_PORT=3306
DB_USER=wsmontes
DB_PASSWORD=your_mysql_password_here
DB_NAME=wsmontes$concierge_db
```

---

## 📋 Phase 8: Reload and Test

1. In **Web** tab, click green **Reload** button
2. Wait 10 seconds
3. Test from your local machine:

```bash
# Health check
curl https://wsmontes.pythonanywhere.com/api/v3/health | python3 -m json.tool

# Should return:
# {
#   "status": "healthy",
#   "database": "connected",
#   ...
# }
```

---

## 📋 Phase 9: Full API Tests

```bash
# Run the test script
./scripts/test_v3_api.sh

# Or manual tests:
curl https://wsmontes.pythonanywhere.com/api/v3/entities | python3 -m json.tool
curl https://wsmontes.pythonanywhere.com/api/v3/curations | python3 -m json.tool
curl https://wsmontes.pythonanywhere.com/api/v3/info | python3 -m json.tool
```

---

## ✅ Success Criteria

- [ ] Health endpoint returns `"status": "healthy"`
- [ ] No "ModuleNotFoundError" errors
- [ ] Entities endpoint returns JSON (even if empty array)
- [ ] Curations endpoint returns JSON (even if empty array)
- [ ] No 500 errors in PythonAnywhere error log

---

## 🚨 Troubleshooting

### Still getting "No module named 'pydantic'"
- Verify Python version: `python3 --version` should match web app (3.13)
- Check packages: `pip3.13 list | grep pydantic`
- Reload web app again

### "Can't connect to MySQL"
- Check .env file has correct password
- Verify DB name: `wsmontes$concierge_db` (with $ not escaped)
- Test connection: `mysql -u wsmontes -p -h wsmontes.mysql.pythonanywhere-services.com`

### "Disk quota exceeded"
- Run cleanup again: `rm -rf ~/.cache/puccinialin`
- Check quota: `quota`
- Delete old __pycache__ dirs: `find ~/Concierge-Analyzer -name __pycache__ -exec rm -rf {} +`

### 500 Error but no details
- Check PythonAnywhere error log (Web tab → Error log link)
- Check server log (Web tab → Server log link)
- Add debug to wsgi_v3.py error handler

---

## 📚 Reference Documents

- **PYTHONANYWHERE_CLEANUP.txt** - Detailed cleanup instructions
- **PYTHONANYWHERE_FIX.txt** - Package installation guide  
- **PYTHONANYWHERE_DEPLOYMENT_SUMMARY.md** - Technical overview
- **docs/DEPLOYMENT_PYTHONANYWHERE.md** - Full deployment guide
- **scripts/test_v3_api.sh** - Automated API tests

---

## 🎯 Quick Commands Summary

```bash
# Cleanup
rm -rf ~/.cache/puccinialin && pip3.13 cache purge

# Install
cd ~/Concierge-Analyzer/mysql_api
pip3.13 install --user Flask==2.3.3 Flask-CORS==4.0.0 mysql-connector-python==8.2.0 python-dotenv==1.0.0 jsonschema==4.19.2 python-dateutil==2.8.2 pydantic==2.5.0

# Configure
cp models_v3_pythonanywhere.py models_v3.py

# Test
curl https://wsmontes.pythonanywhere.com/api/v3/health
```

Good luck! 🚀
