"""
Concierge API - V3 WSGI Entry Point
Purpose: PythonAnywhere-compatible WSGI application for V3 API
Dependencies: Works with both mysql-connector-python (local) and mysqlclient (PythonAnywhere)
Usage: Configure in PythonAnywhere Web tab as WSGI file
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

# Add project directory to path
project_home = '/home/wsmontes/concierge-api/mysql_api'
if project_home not in sys.path:
    sys.path.insert(0, project_home)

# Load environment variables
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

# Import the application with error handling
try:
    from app_v3 import create_app
    
    # PythonAnywhere configuration with improved connection pooling
    config = {
        'DB_HOST': os.getenv('DB_HOST', 'wsmontes.mysql.pythonanywhere-services.com'),
        'DB_PORT': int(os.getenv('DB_PORT', 3306)),
        'DB_USER': os.getenv('DB_USER', 'wsmontes'),
        'DB_PASSWORD': os.getenv('DB_PASSWORD', ''),  # Set in environment!
        'DB_NAME': os.getenv('DB_NAME', 'wsmontes$concierge_db'),
        # Reduced pool size for PythonAnywhere limits
        'DB_POOL_SIZE': int(os.getenv('DB_POOL_SIZE', 3)),
        'DB_POOL_NAME': 'concierge_v3_pythonanywhere'
    }
    
    logger.info(f"Creating V3 app with DB: {config['DB_HOST']}/{config['DB_NAME']}")
    
    # Create WSGI application
    application = create_app(config)
    
    logger.info("V3 application created successfully")

except Exception as e:
    # Create error response app if V3 fails to load
    from flask import Flask, jsonify
    import traceback
    
    logger.error(f"Failed to create V3 application: {e}")
    logger.error(f"Full traceback: {traceback.format_exc()}")
    
    application = Flask(__name__)
    
    # Capture error details in module scope
    error_message = str(e)
    error_type = type(e).__name__
    error_traceback = traceback.format_exc()
    
    @application.route('/')
    @application.route('/api/v3/health')
    @application.route('/api/v3/status')
    def error_handler():
        return jsonify({
            'error': 'Failed to load V3 application',
            'type': error_type,
            'message': error_message,
            'details': error_traceback,
            'timestamp': os.getenv('DEPLOYMENT_TIME', 'unknown'),
            'status': 'error',
            'config': {
                'db_host': os.getenv('DB_HOST', 'not_set'),
                'db_name': os.getenv('DB_NAME', 'not_set'),
                'project_home': project_home
            }
        }), 500
    
    @application.errorhandler(404)
    def not_found(error):
        return jsonify({
            'error': 'Endpoint not found',
            'message': 'V3 API failed to load - check logs',
            'status': 'error'
        }), 404
    
    @application.errorhandler(500)
    def internal_error(error):
        return jsonify({
            'error': 'Internal server error',
            'message': 'V3 API failed to load - check logs',
            'status': 'error'
        }), 500

# For local testing
if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    application.run(host='0.0.0.0', port=port, debug=False)
