# Quick Start Guide

## 🚀 5-Minute Setup

### 1. Clone & Navigate
```bash
git clone https://github.com/wsmontes/Concierge-Analyzer.git
cd Concierge-Analyzer
```

### 2. Setup Python Environment
```bash
cd mysql_api
python3 -m venv ../mysql_api_venv
source ../mysql_api_venv/bin/activate  # Mac/Linux
# OR: ..\mysql_api_venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### 3. Configure Database
```bash
cp .env.template .env
# Edit .env with your MySQL credentials
nano .env  # or use your favorite editor
```

### 4. Create Database
```bash
mysql -u root -p concierge < ../scripts/reset_v3.sql
```

### 5. Start Server
```bash
python app_v3.py
```

### 6. Test API
```bash
# In another terminal:
curl http://localhost:5000/api/v3/health
curl http://localhost:5000/api/v3/entities
```

---

## 📚 What's Where?

- **Production Code**: `mysql_api/` folder
- **Documentation**: `docs/` folder  
- **Database Scripts**: `scripts/` folder
- **Examples**: `examples/` folder
- **Tests**: `tests/` folder

---

## 📖 Next Steps

1. Read [docs/README_V3.md](docs/README_V3.md) for complete API docs
2. Try [scripts/queries_v3.sql](scripts/queries_v3.sql) for SQL examples
3. Check [examples/](examples/) for sample data

---

## 🐛 Troubleshooting

**Can't connect to database?**
- Check `.env` file has correct credentials
- Ensure MySQL is running: `mysql.server start`

**Import errors?**
- Activate virtual environment: `source ../mysql_api_venv/bin/activate`
- Reinstall deps: `pip install -r requirements.txt`

**Port already in use?**
- Change port in `.env`: `PORT=5001`

---

## 🔗 Links

- [Full README](README.md)
- [V3 Documentation](docs/README_V3.md)
- [PythonAnywhere Deployment](docs/DEPLOYMENT_PYTHONANYWHERE.md)
- [Directory Structure](docs/DIRECTORY_STRUCTURE.md)
