#!/usr/bin/env python3
"""
Purpose: Run V3 API server locally with SSH tunnel to PythonAnywhere MySQL.
Dependencies: sshtunnel, mysql.connector, flask

This script creates an SSH tunnel to PythonAnywhere and runs the Flask server
with the tunneled connection. Replace the placeholders with your actual credentials.
"""

import os
import sys
from pathlib import Path
import sshtunnel
import time

# Add mysql_api to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'mysql_api'))

# =============================================================================
# CONFIGURATION - REPLACE THESE WITH YOUR PYTHONANYWHERE CREDENTIALS
# =============================================================================
PYTHONANYWHERE_USERNAME = 'wsmontes'           # Your PythonAnywhere username
PYTHONANYWHERE_PASSWORD = 'YOUR_PYTHONANYWHERE_LOGIN_PASSWORD'  # Your PythonAnywhere login password
DATABASE_NAME = 'wsmontes$concierge_db'        # Database name from PythonAnywhere
DATABASE_PASSWORD = 'YOUR_MYSQL_DATABASE_PASSWORD'  # Your MySQL database password

# SSH/MySQL hostnames (US region - pythonanywhere.com)
SSH_HOSTNAME = 'ssh.pythonanywhere.com'
MYSQL_HOSTNAME = 'wsmontes.mysql.pythonanywhere-services.com'

# Local configuration
LOCAL_BIND_PORT = 3307  # Use 3307 to avoid conflicts with local MySQL
FLASK_PORT = 5000
# =============================================================================

def main():
    """Start SSH tunnel and run Flask server."""
    
    # Validate configuration
    if 'YOUR_PYTHONANYWHERE_LOGIN_PASSWORD' in PYTHONANYWHERE_PASSWORD or 'YOUR_MYSQL_DATABASE_PASSWORD' in DATABASE_PASSWORD:
        print("ERROR: Please edit this script and add your passwords!")
        print("Update these lines in the script:")
        print("  PYTHONANYWHERE_PASSWORD = 'YOUR_PYTHONANYWHERE_LOGIN_PASSWORD'  # Website login password")
        print("  DATABASE_PASSWORD = 'YOUR_MYSQL_DATABASE_PASSWORD'              # MySQL database password")
        print(f"\nEdit: {__file__}")
        sys.exit(1)
    
    # Set timeouts to avoid connection issues
    sshtunnel.SSH_TIMEOUT = 10.0
    sshtunnel.TUNNEL_TIMEOUT = 10.0
    
    print(f"🔐 Connecting to {SSH_HOSTNAME} as {PYTHONANYWHERE_USERNAME}...")
    print(f"📡 Tunneling to {MYSQL_HOSTNAME}:3306")
    print(f"🔌 Local bind port: {LOCAL_BIND_PORT}")
    
    try:
        with sshtunnel.SSHTunnelForwarder(
            (SSH_HOSTNAME,),
            ssh_username=PYTHONANYWHERE_USERNAME,
            ssh_password=PYTHONANYWHERE_PASSWORD,
            remote_bind_address=(MYSQL_HOSTNAME, 3306),
            local_bind_address=('127.0.0.1', LOCAL_BIND_PORT)
        ) as tunnel:
            print(f"✅ SSH tunnel established!")
            print(f"   Local port {tunnel.local_bind_port} -> {MYSQL_HOSTNAME}:3306")
            
            # Update environment for Flask app
            os.environ['DB_HOST'] = '127.0.0.1'
            os.environ['DB_PORT'] = str(tunnel.local_bind_port)
            os.environ['DB_USER'] = PYTHONANYWHERE_USERNAME
            os.environ['DB_PASSWORD'] = DATABASE_PASSWORD
            os.environ['DB_NAME'] = DATABASE_NAME
            os.environ['FLASK_DEBUG'] = 'true'
            os.environ['PORT'] = str(FLASK_PORT)
            
            print(f"\n🚀 Starting Flask server on port {FLASK_PORT}...")
            print(f"   API will be available at: http://localhost:{FLASK_PORT}/api/v3/")
            print(f"   Health check: http://localhost:{FLASK_PORT}/api/v3/health")
            print("\n⚠️  Keep this terminal open - closing it will stop the tunnel and server!")
            print("   Press Ctrl+C to stop\n")
            
            # Import and run Flask app
            from app_v3 import create_app
            app = create_app()
            app.run(host='0.0.0.0', port=FLASK_PORT, debug=True)
            
    except KeyboardInterrupt:
        print("\n\n👋 Shutting down gracefully...")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nTroubleshooting:")
        print("1. Check your PythonAnywhere username/password")
        print("2. Verify you have a paid PythonAnywhere account (free accounts can't use SSH)")
        print("3. Ensure your database exists on PythonAnywhere")
        print("4. Check your database password is correct")
        sys.exit(1)

if __name__ == '__main__':
    main()
