#!/usr/bin/env python3
"""
PythonAnywhere Deployment Verification Script
Run this on PythonAnywhere to verify the V3 API deployment
"""

import sys
import os

def check_git_status():
    """Check if the latest changes are pulled"""
    print("🔍 Checking Git status...")
    try:
        import subprocess
        result = subprocess.run(['git', 'log', '--oneline', '-3'], 
                              capture_output=True, text=True, cwd='/home/wsmontes/concierge-api')
        
        print("Recent commits:")
        print(result.stdout)
        
        if "fixing v3" in result.stdout:
            print("✅ Latest fixes are present")
            return True
        else:
            print("❌ Latest fixes not found - need to git pull")
            return False
    except Exception as e:
        print(f"❌ Git check failed: {e}")
        return False

def check_imports():
    """Test if the corrected imports work"""
    print("\n🔍 Testing imports...")
    
    try:
        # Change to the mysql_api directory
        sys.path.insert(0, '/home/wsmontes/concierge-api/mysql_api')
        
        # Test the specific import that was failing
        from models_v3 import EntityCreateRequest
        print("✅ EntityCreateRequest import works")
        
        # Test if EntityCreateRequest has the id attribute
        if hasattr(EntityCreateRequest, 'model_fields'):
            fields = EntityCreateRequest.model_fields
            if 'id' in fields:
                print("✅ EntityCreateRequest has 'id' field")
            else:
                print(f"❌ EntityCreateRequest fields: {list(fields.keys())}")
                
        # Test API import
        from api_v3 import api_v3
        print("✅ API blueprint import works")
        
        return True
        
    except Exception as e:
        print(f"❌ Import test failed: {e}")
        return False

def check_model_content():
    """Check the actual content of the models file"""
    print("\n🔍 Checking models_v3.py content...")
    
    try:
        with open('/home/wsmontes/concierge-api/mysql_api/models_v3.py', 'r') as f:
            content = f.read()
            
        # Check for the correct class name
        if 'class EntityCreateRequest(BaseModel):' in content:
            print("✅ EntityCreateRequest class found")
        else:
            print("❌ EntityCreateRequest class not found")
            
        # Check for the old incorrect names
        if 'class EntityCreate(BaseModel):' in content:
            print("❌ Old EntityCreate class still present")
        else:
            print("✅ Old EntityCreate class removed")
            
        return True
        
    except Exception as e:
        print(f"❌ File check failed: {e}")
        return False

def check_api_content():
    """Check the API file content"""
    print("\n🔍 Checking api_v3.py content...")
    
    try:
        with open('/home/wsmontes/concierge-api/mysql_api/api_v3.py', 'r') as f:
            content = f.read()
            
        # Check for correct import
        if 'EntityCreateRequest' in content:
            print("✅ EntityCreateRequest used in API")
        else:
            print("❌ EntityCreateRequest not found in API")
            
        # Check for old incorrect usage
        if 'EntityCreate' in content and 'EntityCreateRequest' not in content:
            print("❌ Still using old EntityCreate")
        else:
            print("✅ Using correct EntityCreateRequest")
            
        return True
        
    except Exception as e:
        print(f"❌ API file check failed: {e}")
        return False

def main():
    """Main verification function"""
    print("🚀 PythonAnywhere V3 Deployment Verification")
    print("=" * 50)
    
    all_good = True
    
    # Check each component
    all_good &= check_git_status()
    all_good &= check_imports() 
    all_good &= check_model_content()
    all_good &= check_api_content()
    
    print("\n" + "=" * 50)
    if all_good:
        print("✅ All checks passed! Try reloading the web app.")
        print("\nTo reload:")
        print("touch /var/www/wsmontes_pythonanywhere_com_wsgi.py")
        print("\nThen test:")
        print("curl https://wsmontes.pythonanywhere.com/api/v3/health")
    else:
        print("❌ Issues found. Run 'git pull origin main' and try again.")
        
    return all_good

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)