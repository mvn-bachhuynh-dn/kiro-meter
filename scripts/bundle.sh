#!/bin/bash
# Creates a macOS .app bundle from the built binary.
set -e

APP_NAME="KiroMeter"
BUILD_DIR=".build/debug"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Building..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build

echo "Creating app bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>KiroMeter</string>
    <key>CFBundleIdentifier</key>
    <string>dev.kirometer.app</string>
    <key>CFBundleName</key>
    <string>KiroMeter</string>
    <key>CFBundleDisplayName</key>
    <string>KiroMeter</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
EOF

echo "✅ Created ${BUNDLE_DIR}"
echo ""
echo "Run with:"
echo "  open ${BUNDLE_DIR}"
echo ""
echo "Or to see logs:"
echo "  ${MACOS_DIR}/${APP_NAME}"
