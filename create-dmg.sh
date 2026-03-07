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
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ App not found at $SOURCE_DIR"
    echo "Please run ./install.sh first"
    exit 1
fi

# Create temporary DMG contents directory
DMG_TEMP="./dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temporary directory
cp -R "$SOURCE_DIR" "$DMG_TEMP/"

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
echo "  • Drags FusionNetStat to Applications folder"
echo "  • Launches from Applications or uses LaunchAgent for auto-start"
