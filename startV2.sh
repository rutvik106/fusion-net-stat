#!/bin/bash

# Launch script for NetworkMonitorV2 - runs in background
echo "Starting NetworkMonitorV2 in background..."
nohup ./NetworkMonitorV2 > /dev/null 2>&1 &
echo "NetworkMonitorV2 started. Check your menu bar for the speed indicator."
echo "To stop: pkill -f NetworkMonitorV2"
