#!/bin/bash
# start.sh — Start the Urosonic Flask backend

echo "🚀 Starting Urosonic API Server..."

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Locate virtual environment
if [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
elif [ -f "$SCRIPT_DIR/../venv/bin/activate" ]; then
    source "$SCRIPT_DIR/../venv/bin/activate"
else
    echo "⚠️  No virtual environment found at $SCRIPT_DIR/venv. Using system Python..."
fi

# Check if port 5001 is already running
EXISTING_PID=$(lsof -ti :5001 2>/dev/null)
if [ -n "$EXISTING_PID" ]; then
    echo "ℹ️  Server is already running on port 5001 (PID: $EXISTING_PID)."
    echo "   To restart, run: kill $EXISTING_PID && bash start.sh"
    echo "   Health check: http://127.0.0.1:5001/health"
    exit 0
fi

echo "🌐 API running at: http://127.0.0.1:5001"
echo "🩺 Health check:   http://127.0.0.1:5001/health"

if command -v python >/dev/null 2>&1; then
    exec python app.py
else
    exec python3 app.py
fi
