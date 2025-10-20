# PythonAnywhere Deployment Fixes

## Current Issues (from logs):

1. **CRITICAL: Wrong WSGI file** - PythonAnywhere is loading `/var/www/wsmontes_pythonanywhere_com_wsgi.py` which imports `concierge_parser` instead of our V3 API
2. **Missing flask_compress** - Import error for flask_compress
3. **Database connection issues** - Pool exhaustion and authentication problems
4. **Variable scope error** - `NameError: name 'e' is not defined` in error handler

## Immediate Actions Required:

### 1. Update PythonAnywhere WSGI Configuration
- Go to PythonAnywhere Web tab
- Change WSGI file to point to our V3 WSGI: `/home/wsmontes/concierge-api/mysql_api/wsgi_v3.py`
- **OR** replace content of `/var/www/wsmontes_pythonanywhere_com_wsgi.py` with our V3 WSGI content

### 2. Install Missing Dependencies
```bash
# In PythonAnywhere console, activate your virtual environment
pip install flask-compress==1.13
```

### 3. Set Environment Variables
In PythonAnywhere Web tab > Environment variables:
```
DB_HOST=wsmontes.mysql.pythonanywhere-services.com
DB_USER=wsmontes
DB_PASSWORD=[your_mysql_password]
DB_NAME=wsmontes$concierge_db
DB_POOL_SIZE=2
```

### 4. Database Connection String
According to PythonAnywhere docs, database name should be:
- Format: `username$databasename`
- Your case: `wsmontes$concierge_db`

### 5. MySQL Connection Parameters
- Host: `wsmontes.mysql.pythonanywhere-services.com` (from your Databases tab)
- User: `wsmontes`
- Password: [Set in Databases tab]
- Database: `wsmontes$concierge_db`

## Verification Steps:

1. Check Web tab shows correct WSGI file path
2. Verify environment variables are set
3. Test database connection from console:
   ```bash
   mysql -u wsmontes -h wsmontes.mysql.pythonanywhere-services.com -p 'wsmontes$concierge_db'
   ```
4. Restart web app
5. Check error logs for new issues

## Connection Pool Settings:
- Reduced pool_size to 2 for PythonAnywhere limits
- Added connection timeout handling
- Improved error recovery