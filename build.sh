#!/bin/bash

# Build script for NetworkMonitor macOS menu bar app

echo "Building NetworkMonitor..."

# Compile the Swift application
swiftc -o NetworkMonitor NetworkMonitor.swift -framework Cocoa -framework Foundation

if [ $? -eq 0 ]; then
    echo "Build successful! Run ./NetworkMonitor to start the app."
    echo "Note: You may need to grant permissions for network monitoring."
else
    echo "Build failed!"
    exit 1
fi
