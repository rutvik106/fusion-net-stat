#!/bin/bash

set -e

echo "======================================"
echo "  FusionNet Stat - macOS Menu Bar App"
echo "======================================"
echo ""

# Check for Xcode Command Line Tools
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift compiler not found."
    echo "   Please install Xcode Command Line Tools by running:"
    echo "   xcode-select --install"
    echo "   Then re-run this script."
    exit 1
fi

echo "✅ Swift compiler found."
echo ""

# Get the directory where this script lives
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the binary
echo "🔨 Building SpeedTestMonitor..."
swiftc -o "$INSTALL_DIR/SpeedTestMonitor" "$INSTALL_DIR/SpeedTestMonitor.swift" -framework Cocoa -framework Foundation

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please check the error above."
    exit 1
fi

echo "✅ Build successful."
echo ""

# Kill any existing instance
pkill -f SpeedTestMonitor 2>/dev/null || true

# Create Launch Agent plist for auto-start on login
PLIST_PATH="$HOME/Library/LaunchAgents/com.speedtestmonitor.plist"
BINARY_PATH="$INSTALL_DIR/SpeedTestMonitor"

echo "📝 Setting up auto-start on login..."

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.speedtestmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/SpeedTestMonitor.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/SpeedTestMonitor.err</string>
</dict>
</plist>
EOF

# Unload if already loaded, then load fresh
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "✅ Auto-start configured."
echo ""
echo "======================================"
echo "  🎉 Installation complete!"
echo "======================================"
echo ""
echo "  FusionNet Stat is now running in your menu bar."
echo "  It will also start automatically on every login."
echo ""
echo "  Right-click the menu bar icon to:"
echo "    • View real-time network usage"
echo "    • See speed test results"
echo "    • Check your public IP"
echo "    • Configure test intervals"
echo ""
echo "  To uninstall, run: ./uninstall.sh"
echo ""
