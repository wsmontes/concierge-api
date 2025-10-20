#!/usr/bin/env python3.13
"""
PythonAnywhere WSGI Configuration for Concierge API V3
Copy this file to: /var/www/wsmontes_pythonanywhere_com_wsgi.py

This file replaces any existing WSGI configuration and ensures 
the correct V3 API is loaded instead of concierge_parser.
"""

import os
import sys
import logging

# Configure logging for PythonAnywhere
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s: %(levelname)s: %(message)s'
)
logger = logging.getLogger(__name__)

# Add project directory to Python path
project_home = '/home/wsmontes/concierge-api/mysql_api'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

# Load environment variables if available
try:
    from dotenv import load_dotenv
    env_path = os.path.join(project_home, '.env')
    if os.path.exists(env_path):
        load_dotenv(env_path)
        logger.info("Environment variables loaded from .env")
    else:
        logger.info("No .env file found, using system environment")
except ImportError:
    logger.warning("python-dotenv not available, using system environment")

# Import and configure the V3 application
try:
    from app_v3 import create_app
    
    # PythonAnywhere-specific configuration
    config = {
        'DB_HOST': os.getenv('DB_HOST', 'wsmontes.mysql.pythonanywhere-services.com'),
        'DB_PORT': int(os.getenv('DB_PORT', 3306)),
        'DB_USER': os.getenv('DB_USER', 'wsmontes'),
        'DB_PASSWORD': os.getenv('DB_PASSWORD', ''),  # Must be set in environment!
        'DB_NAME': os.getenv('DB_NAME', 'wsmontes$concierge_db'),
        # Reduced pool size for PythonAnywhere constraints
        'DB_POOL_SIZE': int(os.getenv('DB_POOL_SIZE', 2)),
        'DB_POOL_NAME': 'concierge_v3_pythonanywhere'
    }
    
    logger.info(f"Creating V3 application with database: {config['DB_HOST']}/{config['DB_NAME']}")
    
    # Create the WSGI application
    application = create_app(config)
    
    logger.info("Concierge API V3 application created successfully")

except Exception as e:
    # Fallback error application if V3 fails to load
    from flask import Flask, jsonify
    import traceback
    
    logger.error(f"CRITICAL: Failed to create V3 application: {e}")
    logger.error(f"Full traceback: {traceback.format_exc()}")
    
    application = Flask(__name__)
    
    # Capture error details for debugging
    error_message = str(e)
    error_type = type(e).__name__
    error_traceback = traceback.format_exc()
    deployment_time = os.getenv('DEPLOYMENT_TIME', 'unknown')
    
    @application.route('/')
    @application.route('/api/v3/health')
    @application.route('/api/v3/status')
    def error_handler():
        """Return detailed error information for debugging"""
        return jsonify({
            'status': 'error',
            'error': 'Failed to load Concierge API V3',
            'type': error_type,
            'message': error_message,
            'details': error_traceback,
            'timestamp': deployment_time,
            'config_check': {
                'project_home': project_home,
                'db_host': os.getenv('DB_HOST', 'NOT_SET'),
                'db_name': os.getenv('DB_NAME', 'NOT_SET'),
                'db_user': os.getenv('DB_USER', 'NOT_SET'),
                'db_password_set': 'YES' if os.getenv('DB_PASSWORD') else 'NO',
                'python_path': sys.path[:3]  # First 3 entries
            },
            'help': {
                'check_environment_variables': 'Verify DB_* variables are set in PythonAnywhere Web tab',
                'check_files': 'Ensure all files are uploaded to /home/wsmontes/concierge-api/mysql_api/',
                'check_dependencies': 'Run: pip install -r requirements.txt in console',
                'check_database': 'Test connection: mysql -u wsmontes -h HOST -p "wsmontes$concierge_db"'
            }
        }), 500
    
    @application.errorhandler(404)
    def not_found_handler(error):
        return jsonify({
            'status': 'error',
            'error': 'Endpoint not found',
            'message': 'Concierge API V3 failed to load properly',
            'help': 'Check the main error endpoint at / for details'
        }), 404
    
    @application.errorhandler(500)
    def internal_error_handler(error):
        return jsonify({
            'status': 'error',
            'error': 'Internal server error',
            'message': 'Concierge API V3 failed to load properly',
            'help': 'Check the main error endpoint at / for details'
        }), 500

# For local testing (won't run on PythonAnywhere)
if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'
    application.run(host='0.0.0.0', port=port, debug=debug)