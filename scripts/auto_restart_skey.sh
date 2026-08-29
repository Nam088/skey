#!/usr/bin/env bash
# ==============================================================================
# Auto-restart SKey every 60 seconds to prevent keyboard freeze during testing
# Usage: ./scripts/auto_restart_skey.sh
# Stop with: Ctrl+C or kill the script process
# ==============================================================================

set -euo pipefail

APP_NAME="SKey"
APP_PATH="/Applications/SKey.app"
INTERVAL=60  # seconds

echo "🔄 Auto-restart script for $APP_NAME"
echo "️  Restarting every $INTERVAL seconds"
echo "🛑 Press Ctrl+C to stop"
echo ""

cleanup() {
    echo ""
    echo " Stopping auto-restart script..."
    exit 0
}

trap cleanup SIGINT SIGTERM

while true; do
    TIMESTAMP=$(date +"%H:%M:%S")
    
    # Kill SKey if running
    if pgrep -x "$APP_NAME" > /dev/null; then
        echo "[$TIMESTAMP] 🔄 Killing $APP_NAME..."
        pkill -x "$APP_NAME" || true
        sleep 2
    fi
    
    # Launch SKey
    echo "[$TIMESTAMP] ▶️  Launching $APP_NAME..."
    open "$APP_PATH" &>/dev/null || true
    
    # Wait for interval
    echo "[$TIMESTAMP] ⏳ Waiting ${INTERVAL}s before next restart..."
    sleep "$INTERVAL"
done
