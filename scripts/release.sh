#!/bin/bash

# Zero Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 0.1.0

set -e

VERSION=${1:-"0.1.0"}
APP_NAME="Zero"
BUILD_DIR=".build/release"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
RELEASE_DIR="releases"

echo "🚀 Starting release process for ${APP_NAME} v${VERSION}"

# Step 1: Clean build
echo "📦 Cleaning previous builds..."
rm -rf ${BUILD_DIR}
rm -rf ${RELEASE_DIR}
mkdir -p ${RELEASE_DIR}

# Step 2: Build release
echo "🔨 Building release version..."
swift build -c release

# Step 3: Create app bundle structure
echo "📁 Creating app bundle..."
APP_BUNDLE="${RELEASE_DIR}/${APP_NAME}.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy resources
cp -R "Sources/Zero/Resources/" "${APP_BUNDLE}/Contents/Resources/" || true

# Step 4: Generate Info.plist
echo "📝 Generating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>logo</string>
    <key>CFBundleIdentifier</key>
    <string>com.zero.ide</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Step 5: Code signing (if available, otherwise ad-hoc sign)
echo "🔏 Signing app..."
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID"; then
    codesign --force --deep --sign "Developer ID Application" "${APP_BUNDLE}" 2>/dev/null || \
    codesign --force --deep --sign - "${APP_BUNDLE}"
else
    echo "⚠️  Using ad-hoc signing (no Developer ID certificate)"
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
fi

# Step 6: Verify signature
echo "✅ Verifying signature..."
codesign -v "${APP_BUNDLE}" 2>/dev/null || echo "⚠️  Signature verification skipped"

# Step 7: Create DMG
echo "💿 Creating DMG..."

# Create temporary directory for DMG layout
DMG_TEMP=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"

# Create symbolic link to Applications
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG using hdiutil
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDZO \
    "${RELEASE_DIR}/${DMG_NAME}" || {
        echo "❌ DMG creation failed"
        rm -rf "${DMG_TEMP}"
        exit 1
    }

# Clean up temp directory
rm -rf "${DMG_TEMP}"

# Step 8: Generate checksum
echo "🔐 Generating checksums..."
cd ${RELEASE_DIR}
shasum -a 256 "${DMG_NAME}" > "${DMG_NAME}.sha256"
cd ..

# Step 9: Generate release notes template
echo "📝 Generating release notes template..."
cat > "${RELEASE_DIR}/RELEASE_NOTES.md" << EOF
# Zero ${VERSION}

## What's New
- Initial release of Zero IDE
- Docker-based development environment
- GitHub integration
- Git operations (commit, branch, push, pull)
- Java support with Maven/Gradle

## Download
- [${DMG_NAME}](https://github.com/ori0o0p/Zero/releases/download/v${VERSION}/${DMG_NAME})
- SHA256: \`$(cat ${RELEASE_DIR}/${DMG_NAME}.sha256 | cut -d ' ' -f 1)\`

## Requirements
- macOS 14.0 or later
- Docker Desktop installed and running

## Installation
1. Download the DMG file
2. Open the DMG and drag Zero to Applications
3. Launch Zero from Applications
4. On first launch, allow Zero in System Preferences > Security & Privacy

## Known Issues
- 

## Feedback
Please report issues at: https://github.com/ori0o0p/Zero/issues
EOF

echo ""
echo "✅ Release ${VERSION} prepared successfully!"
echo ""
echo "📦 Files in ${RELEASE_DIR}/:"
ls -lh ${RELEASE_DIR}/
echo ""
echo "📝 Next steps:"
echo "   1. Test the app: open ${RELEASE_DIR}/${APP_NAME}.app"
echo "   2. Review ${RELEASE_DIR}/RELEASE_NOTES.md"
echo "   3. Create a new release on GitHub: https://github.com/ori0o0p/Zero/releases/new"
echo "   4. Upload ${RELEASE_DIR}/${DMG_NAME}"
echo ""
