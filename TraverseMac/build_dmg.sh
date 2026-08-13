#!/bin/bash

# Exit on error
set -e

echo "🚀 Building TraverseMac in Release mode..."

# Clear any previous builds
rm -rf Build/
rm -f Traverse.dmg

# Build the Release scheme using xcodebuild
xcodebuild -scheme TraverseMac -configuration Release -derivedDataPath Build/

# Path to the compiled app
APP_PATH="Build/Build/Products/Release/TraverseMac.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Release build failed. TraverseMac.app not found."
    exit 1
fi

echo "📦 Creating DMG layout..."
mkdir -p dmg_temp
cp -R "$APP_PATH" dmg_temp/
ln -s /Applications dmg_temp/Applications

echo "💾 Generating read-only Disk Image (DMG)..."
hdiutil create -volname "Traverse" -srcfolder dmg_temp -ov -format UDZO Traverse.dmg

echo "🧹 Cleaning up temporary files..."
rm -rf dmg_temp
rm -rf Build/

echo "✨ Success! Traverse.dmg is ready."
