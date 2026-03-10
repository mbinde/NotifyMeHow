#!/bin/bash
# Creates a signed, notarized release build of NotifyMeHow
#
# BEFORE RUNNING THIS SCRIPT:
#   1. Update the version number in Sources/MenuBarApp.swift (appVersion constant)
#   2. Update CFBundleVersion and CFBundleShortVersionString in this script (below)
#   3. Commit your changes
#   4. After uploading, create a git tag: git tag v0.X && git push --tags
#
# Prerequisites (one-time setup):
#   1. Apple Developer ID Application certificate installed in Keychain
#   2. App-specific password stored in Keychain:
#
#   xcrun notarytool store-credentials "NotifyMeHow" \
#     --apple-id "your@email.com" \
#     --team-id "YOUR_TEAM_ID" \
#     --password "xxxx-xxxx-xxxx-xxxx"
#
# This stores credentials in your Keychain under the profile name "NotifyMeHow"
# The script will use this profile, so no secrets are in the script itself.

set -e

APP_NAME="NotifyMeHow"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
RELEASE_DIR="release"
ZIP_NAME="${APP_NAME}.zip"

# Version number - UPDATE THIS FOR EACH RELEASE
# Must match appVersion in Sources/MenuBarApp.swift
VERSION="0.1"

# Your Developer ID - change this to match your certificate name
DEVELOPER_ID="Developer ID Application: Melissa Binde (755FYD4YJY)"

# Notarytool credential profile name (stored in Keychain)
NOTARY_PROFILE="NotifyMeHow"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_step() {
    echo -e "${GREEN}==>${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

echo_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Check for required tools
if ! command -v xcrun &> /dev/null; then
    echo_error "xcrun not found. Make sure Xcode Command Line Tools are installed."
    exit 1
fi

# Verify version matches MenuBarApp.swift
SWIFT_VERSION=$(grep -o 'let appVersion = "[^"]*"' Sources/MenuBarApp.swift | cut -d'"' -f2)
if [ "$SWIFT_VERSION" != "$VERSION" ]; then
    echo_error "Version mismatch!"
    echo "  release.sh VERSION: $VERSION"
    echo "  MenuBarApp.swift appVersion: $SWIFT_VERSION"
    echo ""
    echo "Update both to match before releasing."
    exit 1
fi

echo_step "Building version $VERSION"

# Check if credentials are stored
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &> /dev/null 2>&1; then
    echo_error "Notarization credentials not found in Keychain."
    echo ""
    echo "Run this command to store your credentials (one-time setup):"
    echo ""
    echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\"
    echo "    --apple-id \"your@email.com\" \\"
    echo "    --team-id \"YOUR_TEAM_ID\" \\"
    echo "    --password \"your-app-specific-password\""
    echo ""
    echo "Get an app-specific password at: https://appleid.apple.com/account/manage"
    exit 1
fi

# Step 1: Build release version
echo_step "Building release version..."
swift build -c release

# Step 2: Create app bundle
echo_step "Creating app bundle..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp -f "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/"
cp -f "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/" 2>/dev/null || true
cp -f "Resources/MenuBarIcon.png" "${APP_DIR}/Contents/Resources/" 2>/dev/null || true
cp -f "Resources/MenuBarIcon@2x.png" "${APP_DIR}/Contents/Resources/" 2>/dev/null || true

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
    <string>com.motleywoods.NotifyMeHow</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}.0</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>NotifyMeHow needs accessibility permissions to detect and reposition notifications on your screen.</string>
</dict>
</plist>
EOF

# Step 3: Sign with Developer ID and hardened runtime
echo_step "Signing with Developer ID..."
codesign --force --sign "$DEVELOPER_ID" --options runtime --deep "${APP_DIR}"

# Verify signature
echo_step "Verifying signature..."
codesign --verify --verbose=2 "${APP_DIR}"

# Step 4: Create zip for notarization
echo_step "Creating zip for notarization..."
rm -f "${ZIP_NAME}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_NAME}"

# Step 5: Submit for notarization
echo_step "Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "${ZIP_NAME}" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# Step 6: Staple the ticket
echo_step "Stapling notarization ticket..."
xcrun stapler staple "${APP_DIR}"

# Step 7: Re-create zip with stapled app
echo_step "Creating final release zip..."
mkdir -p "${RELEASE_DIR}"
rm -f "${ZIP_NAME}"
rm -f "${RELEASE_DIR}/${ZIP_NAME}"
ditto -c -k --keepParent "${APP_DIR}" "${RELEASE_DIR}/${ZIP_NAME}"

# Cleanup intermediate zip
rm -f "${ZIP_NAME}"

# Verify everything
echo_step "Verifying final build..."
spctl --assess --verbose=2 "${APP_DIR}"

echo ""
echo -e "${GREEN}Success!${NC} Release build ready at: ${RELEASE_DIR}/${ZIP_NAME}"
echo ""
echo "Next steps:"
echo "  1. Test the app: open ${APP_DIR}"
echo "  2. Commit any final changes"
echo "  3. Create a git tag: git tag v${VERSION} && git push --tags"
echo "  4. Create a GitHub release for v${VERSION} and upload ${RELEASE_DIR}/${ZIP_NAME}"
echo ""
