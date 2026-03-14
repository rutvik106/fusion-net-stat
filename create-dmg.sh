#!/bin/bash

set -e

APP_NAME="FusionNet Stat"
VERSION="1.0"
IDENTIFIER="com.fusionnetstat"
DMG_NAME="${APP_NAME} ${VERSION}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMG_PATH="./${DMG_NAME}.dmg"
VOLUME_PATH="/Volumes/${DMG_NAME}"

echo "🔨 Creating DMG installer for ${APP_NAME}..."

# Ensure the app is built and installed first
if [ ! -f "$SOURCE_DIR/SpeedTestMonitor" ]; then
    echo "❌ App binary not found at $SOURCE_DIR/SpeedTestMonitor"
    echo "Please run ./install.sh first"
    exit 1
fi

# Create temporary DMG contents directory
DMG_TEMP="./dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Create proper .app bundle
APP_BUNDLE="$DMG_TEMP/FusionNet Stat.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

# Create Info.plist
cat > "$APP_CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>FusionNet Stat</string>
    <key>CFBundleExecutable</key>
    <string>SpeedTestMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.fusionnetstat</string>
    <key>CFBundleName</key>
    <string>FusionNet Stat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Copy the binary to the app bundle
cp "$SOURCE_DIR/SpeedTestMonitor" "$APP_MACOS/"
chmod +x "$APP_MACOS/SpeedTestMonitor"

# Create Applications symlink for easy drag-and-drop installation
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
echo "📦 Creating DMG..."
hdiutil create -volname "$DMG_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

echo "✅ DMG created: $DMG_PATH"
echo ""
echo "To distribute:"
echo "  • Share the ${DMG_NAME}.dmg file"
echo "  • User opens the DMG"
echo "  • Drags FusionNet Stat.app to Applications folder"
echo "  • Launches from Applications or uses LaunchAgent for auto-start"
