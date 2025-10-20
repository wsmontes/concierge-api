#!/bin/bash
#
# Purpose: Launch V3 API server locally with SSH tunnel to PythonAnywhere
# Dependencies: Python virtual environment with sshtunnel installed
#
# Usage: ./scripts/run_local.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_ROOT/mysql_api_venv"
TUNNEL_SCRIPT="$SCRIPT_DIR/run_local_with_tunnel.py"

# Check if venv exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Virtual environment not found at: $VENV_DIR"
    echo "   Please run: python3 -m venv mysql_api_venv"
    exit 1
fi

# Check if tunnel script exists
if [ ! -f "$TUNNEL_SCRIPT" ]; then
    echo "❌ Tunnel script not found at: $TUNNEL_SCRIPT"
    exit 1
fi

# Activate venv and run tunnel script
echo "🔧 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "🚀 Starting server with SSH tunnel..."
python "$TUNNEL_SCRIPT"
