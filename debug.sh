#!/bin/bash

# Debug script for NetworkMonitor - logs to file
echo "Starting NetworkMonitor with debug logging..."
./NetworkMonitor > debug.log 2>&1 &
echo "NetworkMonitor started. Debug output saved to debug.log"
echo "Check the log with: tail -f debug.log"
echo "To stop: pkill -f NetworkMonitor"
