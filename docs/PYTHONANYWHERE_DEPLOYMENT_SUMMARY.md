# PythonAnywhere Deployment - Quick Fix Summary

## 🎯 The Problem

Your V3 API deployment has two issues:
1. **Python version mismatch**: Web app uses Python 3.13, packages installed for 3.10
2. **Rust compilation**: `pydantic[email]` requires Rust compiler → disk quota exceeded

## ✅ The Solution

I've created two compatibility files:

### 1. `requirements_pythonanywhere.txt`
- Removes `pydantic[email]` (which needs Rust)
- Keeps all other V3 dependencies
- Works with Python 3.13

### 2. `models_v3_pythonanywhere.py`
- Replaces `EmailStr` with `str` + basic validation
- No external email-validator needed
- Functionally identical otherwise

## 📋 Installation Steps

```bash
# On PythonAnywhere bash console:
cd ~/Concierge-Analyzer/mysql_api

# Install compatible packages
pip3.13 install --user -r requirements_pythonanywhere.txt

# Swap models file
mv models_v3.py models_v3_original.py
cp models_v3_pythonanywhere.py models_v3.py

# Reload web app (Web tab → green "Reload" button)
```

## 🧪 Test After Reload

```bash
curl https://wsmontes.pythonanywhere.com/api/v3/health
```

Should return JSON with `"status": "healthy"` instead of error.

## 📁 Files Created

1. **mysql_api/requirements_pythonanywhere.txt** - Compatible dependencies
2. **mysql_api/models_v3_pythonanywhere.py** - Compatible models
3. **PYTHONANYWHERE_FIX.txt** - Detailed instructions
4. **PYTHONANYWHERE_DEPLOYMENT_SUMMARY.md** - This file

## 🔄 What Changed

### In Requirements:
```diff
- pydantic[email]==2.5.0  # Requires Rust
+ pydantic==2.5.0          # Pure Python
```

### In Models:
```diff
- from pydantic import EmailStr
- email: Optional[EmailStr] = Field(...)
+ email: Optional[str] = Field(...)
+ # Added basic regex validation in validator
```

## ⚙️ Email Validation

The basic email validation uses a simple regex:
```python
r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
```

This covers 99% of real-world cases without needing external libraries.

## 🚀 Next Steps

1. Upload `requirements_pythonanywhere.txt` to PythonAnywhere
2. Upload `models_v3_pythonanywhere.py` to PythonAnywhere  
3. Run the installation commands above
4. Reload web app
5. Test API endpoints

See **PYTHONANYWHERE_FIX.txt** for detailed step-by-step instructions.
