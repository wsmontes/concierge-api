# Test Configuration for Concierge API

import os
import sys
import tempfile
import pytest

# Add the mysql_api directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'mysql_api'))


@pytest.fixture
def app():
    """Create and configure a test app instance."""
    from app_v3 import create_app
    
    # Create a temporary database file for testing
    db_fd, db_path = tempfile.mkstemp()
    
    app = create_app({
        'TESTING': True,
        'DATABASE': db_path,
    })
    
    with app.test_client() as client:
        with app.app_context():
            # Initialize test database if needed
            pass
        yield app
    
    os.close(db_fd)
    os.unlink(db_path)


@pytest.fixture
def client(app):
    """Create a test client for the app."""
    return app.test_client()


@pytest.fixture
def runner(app):
    """Create a test runner for the app's Click commands."""
    return app.test_cli_runner()