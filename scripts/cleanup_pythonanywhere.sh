#!/bin/bash
#
# Purpose: Clean up PythonAnywhere environment for fresh V3 deployment
# Usage: Run this in PythonAnywhere bash console
#

echo "=========================================="
echo "  PythonAnywhere Cleanup Script"
echo "=========================================="
echo ""

# Step 1: Remove old Python packages
echo "🧹 Step 1: Removing old/conflicting packages..."
pip3.10 uninstall -y pydantic pydantic-core email-validator 2>/dev/null || true
pip3.13 uninstall -y pydantic pydantic-core email-validator 2>/dev/null || true

# Step 2: Clean pip cache to free disk space
echo "🧹 Step 2: Cleaning pip cache..."
pip3.13 cache purge 2>/dev/null || true

# Step 3: Remove any leftover Rust installations
echo "🧹 Step 3: Removing Rust compiler cache (if any)..."
rm -rf ~/.cache/puccinialin 2>/dev/null || true
rm -rf ~/.rustup 2>/dev/null || true
rm -rf ~/.cargo 2>/dev/null || true

# Step 4: Check current disk usage
echo ""
echo "📊 Current disk usage:"
du -sh ~/Concierge-Analyzer 2>/dev/null || echo "  Project: Not found"
du -sh ~/.local/lib/python3.10 2>/dev/null || echo "  Python 3.10 packages: Not found"
du -sh ~/.local/lib/python3.13 2>/dev/null || echo "  Python 3.13 packages: Not found"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Install fresh packages with: pip3.13 install --user -r requirements_pythonanywhere.txt"
echo "2. Or use manual install (see PYTHONANYWHERE_FIX.txt)"
echo ""
