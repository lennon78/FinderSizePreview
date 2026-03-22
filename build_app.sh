#!/bin/bash
set -e

APP_NAME="FinderSizePreview"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "Building Swift package..."
swift build -c release

echo "Creating App Bundle Structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

echo "Copying executable..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

echo "Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.kuiper.$APP_NAME.v2</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>This app requires permission to control Finder to get the selected file paths for size calculation.</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>Toggle HUD</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>findersizepreview</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "App Bundle created at $PWD/$APP_BUNDLE"
