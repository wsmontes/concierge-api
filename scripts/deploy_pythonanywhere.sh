#!/bin/bash
# PythonAnywhere Deployment Script for Concierge API V3
# Run this in a PythonAnywhere Bash console

echo "=== Concierge API V3 - PythonAnywhere Deployment ==="
echo "Current directory: $(pwd)"
echo "Current user: $(whoami)"
echo ""

# Step 1: Navigate to project directory
echo "1. Checking project directory..."
cd /home/wsmontes/concierge-api/mysql_api
if [ $? -eq 0 ]; then
    echo "✓ In project directory: $(pwd)"
else
    echo "✗ Failed to navigate to project directory"
    echo "Make sure the project is uploaded to /home/wsmontes/concierge-api/"
    exit 1
fi

# Step 2: Check Python version
echo ""
echo "2. Checking Python version..."
python3.13 --version
if [ $? -eq 0 ]; then
    echo "✓ Python 3.13 is available"
else
    echo "✗ Python 3.13 not found"
    exit 1
fi

# Step 3: Install dependencies
echo ""
echo "3. Installing dependencies..."
pip3.13 install --user -r requirements_pythonanywhere.txt
if [ $? -eq 0 ]; then
    echo "✓ Dependencies installed successfully"
else
    echo "⚠ Some dependencies may have failed to install"
fi

# Step 4: Check critical files
echo ""
echo "4. Checking critical files..."
files=("app_v3.py" "database_v3.py" "models_v3.py" "api_v3.py" "wsgi_v3.py" "pythonanywhere_wsgi.py")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
    fi
done

# Step 5: Test database connection (if credentials are available)
echo ""
echo "5. Testing database connection..."
if [ -n "$DB_PASSWORD" ]; then
    mysql -u wsmontes -h wsmontes.mysql.pythonanywhere-services.com -p"$DB_PASSWORD" -e "USE wsmontes\$concierge_db; SHOW TABLES;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Database connection successful"
    else
        echo "⚠ Database connection failed - check credentials"
    fi
else
    echo "⚠ DB_PASSWORD not set - skipping database test"
    echo "Set DB_PASSWORD in environment variables and test manually:"
    echo "mysql -u wsmontes -h wsmontes.mysql.pythonanywhere-services.com -p 'wsmontes\$concierge_db'"
fi

# Step 6: Validate Python syntax
echo ""
echo "6. Validating Python syntax..."
python3.13 -m py_compile *.py
if [ $? -eq 0 ]; then
    echo "✓ All Python files have valid syntax"
else
    echo "✗ Syntax errors found in Python files"
fi

# Step 7: Copy WSGI file
echo ""
echo "7. WSGI file setup..."
echo "Copy the following content to /var/www/wsmontes_pythonanywhere_com_wsgi.py:"
echo "Or set WSGI file path to: /home/wsmontes/concierge-api/mysql_api/wsgi_v3.py"
echo ""
echo "Current WSGI file content:"
if [ -f "pythonanywhere_wsgi.py" ]; then
    echo "✓ PythonAnywhere WSGI file exists: pythonanywhere_wsgi.py"
    echo "File size: $(wc -l < pythonanywhere_wsgi.py) lines"
else
    echo "✗ PythonAnywhere WSGI file missing"
fi

echo ""
echo "=== MANUAL STEPS REQUIRED ==="
echo "1. Go to PythonAnywhere Web tab"
echo "2. Set WSGI file to: /home/wsmontes/concierge-api/mysql_api/wsgi_v3.py"
echo "   OR copy content of pythonanywhere_wsgi.py to /var/www/wsmontes_pythonanywhere_com_wsgi.py"
echo "3. Set environment variables:"
echo "   DB_HOST=wsmontes.mysql.pythonanywhere-services.com"
echo "   DB_USER=wsmontes"
echo "   DB_PASSWORD=[your_mysql_password]"
echo "   DB_NAME=wsmontes\$concierge_db"
echo "   DB_POOL_SIZE=2"
echo "4. Restart your web app"
echo "5. Check error logs and visit your site"
echo ""
echo "=== TROUBLESHOOTING ==="
echo "- If you see 'concierge_parser' errors, the wrong WSGI file is being used"
echo "- If you see 'flask_compress' errors, run: pip3.13 install --user flask-compress"
echo "- If database connection fails, verify password in Databases tab"
echo "- Check error logs in PythonAnywhere Web tab"
echo ""
echo "Deployment script completed!"