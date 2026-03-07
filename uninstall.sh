#!/bin/bash

echo "======================================"
echo "  FusionNet Stat - Uninstaller"
echo "======================================"
echo ""

PLIST_PATH="$HOME/Library/LaunchAgents/com.speedtestmonitor.plist"

# Stop and unload the Launch Agent
if [ -f "$PLIST_PATH" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm "$PLIST_PATH"
    echo "✅ Removed auto-start entry."
else
    echo "ℹ️  No auto-start entry found."
fi

# Kill any running instance
pkill -f SpeedTestMonitor 2>/dev/null && echo "✅ Stopped SpeedTestMonitor." || echo "ℹ️  SpeedTestMonitor was not running."

echo ""
echo "✅ Uninstall complete. FusionNet Stat has been removed."
echo ""
