#!/bin/bash
# Creates a macOS app bundle from the built executable

set -e

APP_NAME="NotifyMeHow"
BUILD_DIR=".build/debug"
APP_DIR="${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build

echo "Creating app bundle..."
# Only create directories if they don't exist (preserve permissions)
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable (overwrite only the binary)
cp -f "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/"

# Create Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NotifyMeHow</string>
    <key>CFBundleDisplayName</key>
    <string>NotifyMeHow</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.notifymehow</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>NotifyMeHow</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
EOF

# Create a launcher script that runs in GUI mode
cat > "${APP_DIR}/Contents/MacOS/NotifyMeHow-launcher" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
"${DIR}/NotifyMeHow" --gui
EOF
chmod +x "${APP_DIR}/Contents/MacOS/NotifyMeHow-launcher"

# Update Info.plist to use the launcher
sed -i '' 's/<string>NotifyMeHow<\/string>/<string>NotifyMeHow-launcher<\/string>/' "${APP_DIR}/Contents/Info.plist"

echo ""
echo "App bundle created: ${APP_DIR}"
echo ""
echo "To run the GUI app:"
echo "  open ${APP_DIR}"
echo ""
echo "To run the CLI version:"
echo "  .build/debug/NotifyMeHow --help"
echo ""
echo "Note: You'll need to grant Accessibility permissions in:"
echo "  System Settings > Privacy & Security > Accessibility"
