#!/bin/bash

# Launch script for NetworkMonitor - runs in background
echo "Starting NetworkMonitor in background..."
nohup ./NetworkMonitor > /dev/null 2>&1 &
echo "NetworkMonitor started. Check your menu bar for the speed indicator."
echo "To stop: pkill -f NetworkMonitor"
