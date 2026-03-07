#!/bin/bash

set -e

APP_NAME="FusionNet Stat"
VERSION="1.0"
IDENTIFIER="com.fusionnetstat"
DMG_NAME="${APP_NAME} ${VERSION}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_PATH="./${DMG_NAME}.dmg"
TEMP_DIR="./dmg_temp"

echo "🔨 Creating DMG installer for ${APP_NAME}..."

# Build the app first
echo "📦 Building app..."
cd "$PROJECT_DIR"
swiftc -o SpeedTestMonitor SpeedTestMonitor.swift -framework Cocoa -framework Foundation

# Create temporary DMG contents directory
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Create proper app structure
APP_BUNDLE="$TEMP_DIR/FusionNetStat.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SpeedTestMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.fusionnetstat</string>
    <key>CFBundleName</key>
    <string>FusionNet Stat</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy binary
cp SpeedTestMonitor "$APP_BUNDLE/Contents/MacOS/"

# Create installation script
cat > "$TEMP_DIR/Install FusionNet Stat.command" << 'INSTALL_EOF'
#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="$SCRIPT_DIR/FusionNet Stat.app"
INSTALL_DIR="/Applications/FusionNetStat.app"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENT_DIR/com.fusionnetstat.plist"

echo "🔧 Installing FusionNet Stat..."

# Remove old installation
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

# Copy app to Applications
cp -R "$APP_BUNDLE" "/Applications/"

# Create LaunchAgent
mkdir -p "$LAUNCH_AGENT_DIR"
cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fusionnetstat</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/FusionNet Stat.app/Contents/MacOS/SpeedTestMonitor</string>
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
PLIST

# Load LaunchAgent
launchctl load "$PLIST_PATH" 2>/dev/null || true

echo "✅ Installation complete!"
echo "FusionNet Stat is now running in your menu bar."
echo ""
echo "To uninstall, run:"
echo "  launchctl unload ~/Library/LaunchAgents/com.fusionnetstat.plist"
echo "  rm -rf '/Applications/FusionNet Stat.app'"
echo "  rm ~/Library/LaunchAgents/com.fusionnetstat.plist"

# Open the app to show it's working
open "/Applications/FusionNet Stat.app"
INSTALL_EOF

chmod +x "$TEMP_DIR/Install FusionNet Stat.command"

# Create Applications symlink
ln -s /Applications "$TEMP_DIR/Applications"

# Create README
cat > "$TEMP_DIR/README.txt" << README_EOF
FusionNet Stat - Network Monitor for macOS

INSTALLATION:
1. Double-click "Install FusionNet Stat.command"
2. Enter your password if prompted
3. The app will install and start automatically

FEATURES:
• Real-time network usage in menu bar
• Automatic speed tests every 5 minutes
• Public IP address display
• Configurable test intervals
• Starts automatically on login

UNINSTALL:
Run these commands in Terminal:
  launchctl unload ~/Library/LaunchAgents/com.fusionnetstat.plist
  rm -rf '/Applications/FusionNet Stat.app'
  rm ~/Library/LaunchAgents/com.fusionnetstat.plist

For more information, visit: https://github.com/yourusername/fusion-net-stat
README_EOF

# Create DMG
echo "📦 Creating DMG..."
hdiutil create -volname "$DMG_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO "$DMG_PATH"

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ DMG created: $DMG_PATH"
echo ""
echo "Share this DMG file with your friends. They just need to:"
echo "  1. Open the DMG"
echo "  2. Double-click 'Install FusionNet Stat.command'"
echo "  3. Enter password if prompted"
