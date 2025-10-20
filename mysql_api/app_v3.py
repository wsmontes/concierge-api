"""
Concierge API - V3 Application Entry Point
Purpose: Flask application factory for V3 API
Dependencies: Flask, models_v3, database_v3, api_v3
Usage: python app_v3.py
"""

import os
from flask import Flask, jsonify
from flask_cors import CORS

from database_v3 import DatabaseV3
from api_v3 import init_v3_api


def create_app(config=None):
    """
    Application factory for V3 API
    
    Args:
        config: Optional configuration dictionary
        
    Returns:
        Flask application instance
    """
    app = Flask(__name__)
    
    # Load configuration
    app.config.update(
        # Database configuration from environment
        DB_HOST=os.getenv('DB_HOST', 'localhost'),
        DB_PORT=int(os.getenv('DB_PORT', 3306)),
        DB_USER=os.getenv('DB_USER', 'root'),
        DB_PASSWORD=os.getenv('DB_PASSWORD', ''),
        DB_NAME=os.getenv('DB_NAME', 'concierge'),
        
        # Flask configuration
        JSON_SORT_KEYS=False,
        JSON_AS_ASCII=False,
    )
    
    # Override with custom config if provided
    if config:
        app.config.update(config)
    
    # Enable CORS
    CORS(app, resources={
        r"/api/*": {
            "origins": "*",
            "methods": ["GET", "POST", "PATCH", "DELETE"],
            "allow_headers": ["Content-Type", "If-Match"]
        }
    })
    
    # Initialize database connection
    db = DatabaseV3(
        host=app.config['DB_HOST'],
        port=app.config['DB_PORT'],
        user=app.config['DB_USER'],
        password=app.config['DB_PASSWORD'],
        database=app.config['DB_NAME']
    )
    
    # Register V3 API blueprint
    init_v3_api(app, db)
    
    # Root endpoint
    @app.route('/')
    def index():
        return jsonify({
            "name": "Concierge API",
            "version": "3.0",
            "description": "Document-oriented REST API for restaurant/hotel curation",
            "endpoints": {
                "api_info": "/api/v3/info",
                "health_check": "/api/v3/health",
                "entities": "/api/v3/entities",
                "curations": "/api/v3/curations"
            }
        })
    
    # Global error handler
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "Not found"}), 404
    
    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500
    
    return app


if __name__ == '__main__':
    # Create application
    app = create_app()
    
    # Get port from environment or default to 5000
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    
    print(f"""
╔═══════════════════════════════════════════╗
║   Concierge API V3 Server                ║
╚═══════════════════════════════════════════╝

Environment:
  Database: {app.config['DB_NAME']}@{app.config['DB_HOST']}:{app.config['DB_PORT']}
  Port: {port}
  Debug: {debug}

API Endpoints:
  • GET  /api/v3/info         - API information
  • GET  /api/v3/health       - Health check
  • GET  /api/v3/entities     - List entities
  • POST /api/v3/entities     - Create entity
  • GET  /api/v3/curations    - List curations
  • POST /api/v3/query        - Execute query DSL

Documentation:
  Swagger/OpenAPI: Coming soon
  Example queries: queries_v3.sql
  Schema docs: schema_v3.sql

Starting server...
    """)
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=debug
    )
