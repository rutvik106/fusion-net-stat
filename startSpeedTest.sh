#!/bin/bash

# Launch script for SpeedTestMonitor - runs in background
echo "Starting SpeedTestMonitor in background..."
echo "This will test actual internet speeds at configurable intervals."
echo "⚠️  Note: This consumes data during speed tests!"
echo ""
nohup ./SpeedTestMonitor > /dev/null 2>&1 &
echo "SpeedTestMonitor started. Check your menu bar for the speed indicator."
echo "Right-click the menu bar icon to configure test intervals."
echo "To stop: pkill -f SpeedTestMonitor"
