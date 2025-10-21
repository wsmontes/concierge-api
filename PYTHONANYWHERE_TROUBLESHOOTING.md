# 🚨 PythonAnywhere V3 API Troubleshooting Guide

## Current Status: 500 Internal Server Error

The API is returning HTTP 500 errors, indicating the Python code is crashing on PythonAnywhere.

## 🔧 Step-by-Step Fix

### 1. SSH into PythonAnywhere
```bash
ssh wsmontes@ssh.pythonanywhere.com
```

### 2. Navigate to Your Project
```bash
cd ~/concierge-api
```

### 3. Pull Latest Changes from GitHub
```bash
git pull origin main
```

### 4. Check What Changed
```bash
git log --oneline -3
# Should show:
# 930d031 📝 Add V3 import fixes documentation  
# ba288e9 fixing v3
# 1064637 fixes
```

### 5. Test the Import Fixes
```bash
cd ~/concierge-api/mysql_api
python3.13 -c "
try:
    from api_v3 import api_v3
    print('✅ API imports working!')
except Exception as e:
    print(f'❌ Import error: {e}')
"
```

### 6. Check Database Connection
```bash
cd ~/concierge-api/mysql_api
python3.13 -c "
import os
os.environ['DB_HOST'] = 'wsmontes.mysql.pythonanywhere-services.com'
os.environ['DB_USER'] = 'wsmontes'
os.environ['DB_NAME'] = 'wsmontes\$concierge_db'
try:
    from app_v3 import create_app
    app = create_app()
    print('✅ App creation successful!')
except Exception as e:
    print(f'❌ App creation failed: {e}')
"
```

### 7. Check Error Logs
```bash
# Check web app error log
tail -50 ~/.pythonanywhere/logs/error.log

# Check server logs  
tail -50 ~/.pythonanywhere/logs/access.log
```

### 8. Reload Web Application
**Method 1 - Web Interface:**
1. Go to https://www.pythonanywhere.com/user/wsmontes/webapps/
2. Click the green "Reload wsmontes.pythonanywhere.com" button

**Method 2 - Command Line:**
```bash
touch /var/www/wsmontes_pythonanywhere_com_wsgi.py
```

### 9. Test the API
```bash
curl https://wsmontes.pythonanywhere.com/api/v3/health
# Should return: {"status": "healthy", "version": "3.0", "database": "connected"}
```

## 🔍 Common Issues & Fixes

### Issue 1: Import Errors
**Symptom:** ImportError or ModuleNotFoundError
**Fix:** Verify the import fixes are present in the files:
```bash
cd ~/concierge-api/mysql_api
grep "EntityCreateRequest" api_v3.py
grep "QueryFilter" database_v3.py
# Should find the corrected import names
```

### Issue 2: Database Connection
**Symptom:** MySQL connection errors
**Fix:** Check environment variables and database password:
```bash
echo $DB_PASSWORD  # Should have your MySQL password
```

### Issue 3: Python Version Issues
**Symptom:** Module compatibility errors  
**Fix:** Ensure using Python 3.13:
```bash
which python3.13
python3.13 --version
```

### Issue 4: Package Dependencies
**Symptom:** Missing module errors
**Fix:** Reinstall packages:
```bash
cd ~/concierge-api/mysql_api
pip3.13 install --user -r requirements_pythonanywhere.txt
```

## 📞 Quick Test Commands

After making changes, test these in order:

```bash
# 1. Test imports
python3.13 -c "from api_v3 import api_v3; print('OK')"

# 2. Test app creation (will fail without DB, but should show import works)
python3.13 -c "from app_v3 import create_app; print('OK')"  

# 3. Test API health
curl https://wsmontes.pythonanywhere.com/api/v3/health

# 4. Test API info
curl https://wsmontes.pythonanywhere.com/api/v3/info
```

## 🎯 Expected Results

After successful deployment:
- ✅ `curl` commands return JSON (not HTML error pages)
- ✅ Health endpoint returns `{"status": "healthy"}`  
- ✅ Validation HTML shows 80%+ success rate
- ✅ No more "Failed to fetch" errors

## 📧 Next Steps

1. Follow this guide step-by-step
2. Copy any error messages you encounter
3. Test the validation HTML again after fixes
4. Report back with results or error messages

---
*Created: October 20, 2025*  
*For: PythonAnywhere V3 API Deployment Issues*