# Running V3 API Locally with PythonAnywhere MySQL

This guide shows you how to run the V3 API server on your local machine while connecting to your PythonAnywhere MySQL database via SSH tunnel.

## Prerequisites

1. **Paid PythonAnywhere account** (free accounts don't support SSH tunneling)
2. **MySQL database** created on PythonAnywhere
3. **Python 3.8+** installed locally
4. **Virtual environment** with dependencies installed

## Quick Start

### Step 1: Get Your PythonAnywhere Credentials

You need the following information:

1. **PythonAnywhere username** (e.g., `myusername`)
2. **PythonAnywhere login password** (what you use to log into the website)
3. **Database name** (usually `username$databasename`, e.g., `myusername$concierge`)
4. **Database password** (your MySQL database password)
5. **Region**: Are you on US (`www.pythonanywhere.com`) or EU (`eu.pythonanywhere.com`)?

### Step 2: Configure the Tunnel Script

Edit `scripts/run_local_with_tunnel.py` and replace these values:

```python
PYTHONANYWHERE_USERNAME = 'your_username_here'  # Replace with your username
PYTHONANYWHERE_PASSWORD = 'your_password_here'  # Replace with your login password
DATABASE_NAME = 'your_username$concierge'       # Replace with your database name
DATABASE_PASSWORD = 'your_db_password_here'     # Replace with your DB password
```

If you're on EU region, also update:

```python
SSH_HOSTNAME = 'ssh.eu.pythonanywhere.com'
MYSQL_HOSTNAME = f'{PYTHONANYWHERE_USERNAME}.mysql.eu.pythonanywhere-services.com'
```

### Step 3: Run the Server

```bash
./scripts/run_local.sh
```

Or manually:

```bash
source mysql_api_venv/bin/activate
python scripts/run_local_with_tunnel.py
```

### Step 4: Test the API

Once the server starts, test it:

```bash
# Health check
curl http://localhost:5000/api/v3/health

# List entities
curl http://localhost:5000/api/v3/entities

# List curations
curl http://localhost:5000/api/v3/curations
```

## How It Works

The script:

1. **Creates an SSH tunnel** to PythonAnywhere using your credentials
2. **Forwards local port 3307** to your PythonAnywhere MySQL server
3. **Starts the Flask server** configured to use the tunneled connection
4. **Keeps the tunnel open** as long as the server is running

## Troubleshooting

### "Please edit this script and replace the placeholder credentials!"

You need to edit `scripts/run_local_with_tunnel.py` and add your actual credentials.

### "Authentication failed"

- Check your PythonAnywhere username and password
- Username is **case-sensitive**
- Make sure you're using your website login password, not your database password

### "Can't connect to MySQL server"

- Verify your database name is correct (usually `username$databasename`)
- Check your database password
- Ensure your database exists on PythonAnywhere

### "SSH timeout" or connection issues

Try increasing the timeouts in `run_local_with_tunnel.py`:

```python
sshtunnel.SSH_TIMEOUT = 20.0
sshtunnel.TUNNEL_TIMEOUT = 20.0
```

### Free PythonAnywhere Account

SSH tunneling **only works with paid accounts**. Free accounts cannot use this method.

## Alternative: Use PythonAnywhere Console

If you can't use SSH tunneling, you can:

1. Upload your code to PythonAnywhere
2. Run the server directly on PythonAnywhere
3. Access it via your PythonAnywhere web app URL

See `docs/DEPLOYMENT_PYTHONANYWHERE.md` for deployment instructions.

## Port Configuration

- **SSH Tunnel**: Local port `3307` → PythonAnywhere MySQL port `3306`
- **Flask Server**: `http://localhost:5000`

If port 3307 or 5000 is already in use, edit the values in `run_local_with_tunnel.py`:

```python
LOCAL_BIND_PORT = 3307  # Change to any free port
FLASK_PORT = 5000       # Change to any free port
```

## Security Notes

- **Never commit credentials** to version control
- The tunnel script should be in `.gitignore`
- Consider using environment variables for sensitive data
- Keep the terminal window open - closing it stops the tunnel

## What's Next?

Once the server is running:

1. Use the API to create/read entities and curations
2. Test with the example data in `examples/data/`
3. Run the test suite (when created)
4. Deploy to PythonAnywhere for production use

For full API documentation, see `docs/README_V3.md`.
