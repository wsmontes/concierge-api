"""
Concierge API - V3 WSGI Entry Point
Purpose: PythonAnywhere-compatible WSGI application for V3 API
Dependencies: Works with both mysql-connector-python (local) and mysqlclient (PythonAnywhere)
Usage: Configure in PythonAnywhere Web tab as WSGI file
"""

import os
import sys

# Add project directory to path
project_home = '/home/wsmontes/concierge-api/mysql_api'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

# Load environment variables
from dotenv import load_dotenv
env_path = os.path.join(project_home, '.env')
if os.path.exists(env_path):
    load_dotenv(env_path)

# Import the application with error handling
try:
    from app_v3 import create_app
    
    # PythonAnywhere configuration
    # Set these in PythonAnywhere Web tab > Environment variables OR in .env file
    config = {
        'DB_HOST': os.getenv('DB_HOST', 'wsmontes.mysql.pythonanywhere-services.com'),
        'DB_PORT': int(os.getenv('DB_PORT', 3306)),
        'DB_USER': os.getenv('DB_USER', 'wsmontes'),
        'DB_PASSWORD': os.getenv('DB_PASSWORD', ''),  # Set in environment!
        'DB_NAME': os.getenv('DB_NAME', 'wsmontes$concierge_db'),
    }
    
    # Create WSGI application
    application = create_app(config)

except Exception as e:
    # Create error response app if V3 fails to load
    from flask import Flask, jsonify
    application = Flask(__name__)
    
    error_message = str(e)
    error_type = type(e).__name__
    
    @application.route('/')
    @application.route('/api/v3/health')
    def error_handler():
        return jsonify({
            'error': 'Failed to load V3 application',
            'type': error_type,
            'message': error_message
        }), 500

# For local testing
if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    application.run(host='0.0.0.0', port=port, debug=False)
