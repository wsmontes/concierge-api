#!/bin/bash
# Quick cleanup - copy/paste this entire block into PythonAnywhere bash

echo "🧹 Starting cleanup..."
rm -rf ~/.cache/puccinialin ~/.rustup ~/.cargo
pip3.13 cache purge 2>/dev/null
pip3.10 cache purge 2>/dev/null
find ~/Concierge-Analyzer -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null
find ~/Concierge-Analyzer -name "*.pyc" -delete 2>/dev/null
echo "✅ Cleanup done! Checking quota..."
quota
