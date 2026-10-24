#!/bin/bash
# stop.sh — Stop the Urosonic Flask backend server

echo "🛑 Stopping Urosonic API Server..."

# Find PID on port 5001
PID=$(lsof -ti :5001 2>/dev/null)

if [ -z "$PID" ]; then
    # Fallback: check if app.py is running
    PID=$(pgrep -f "python.*app.py" 2>/dev/null)
fi

if [ -n "$PID" ]; then
    echo "Found running server with PID: $PID"
    kill $PID 2>/dev/null
    sleep 1

    # Check if process is still running, force kill if necessary
    if kill -0 $PID 2>/dev/null; then
        echo "Server did not terminate gracefully; forcing shutdown..."
        kill -9 $PID 2>/dev/null
        sleep 1
    fi

    # Verify
    CHECK_PID=$(lsof -ti :5001 2>/dev/null)
    if [ -z "$CHECK_PID" ]; then
        echo "✅ Urosonic API Server stopped successfully. Port 5001 is now free."
    else
        echo "⚠️  Failed to free port 5001. Current process: $CHECK_PID"
        exit 1
    fi
else
    echo "ℹ️  No Urosonic server was found running on port 5001."
fi
