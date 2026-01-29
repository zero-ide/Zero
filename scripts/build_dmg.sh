#!/bin/bash
set -e

APP_NAME="Zero"
# SwiftPM 빌드 경로는 아키텍처에 따라 다를 수 있음
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"

# 1. Build
echo "🏗️  Building $APP_NAME (Release)..."
swift build -c release --arch arm64

# 2. Create .app bundle
echo "📦 Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 실행 파일 복사
if [ -f "$BUILD_DIR/$APP_NAME" ]; then
    cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
else
    echo "Error: Binary not found at $BUILD_DIR/$APP_NAME"
    exit 1
fi

# 리소스 번들 복사 (Highlightr 등)
echo "📂 Copying resources..."
cp -r "$BUILD_DIR"/*.bundle "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

# 아이콘 생성 및 복사
ICON_SOURCE="/Users/ktown4u/.clawdbot/media/inbound/d18e0e5c-6879-461a-b9ac-9718ea99481c.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Creating AppIcon.icns..."
    mkdir -p AppIcon.iconset
    sips -z 16 16     "$ICON_SOURCE" --out AppIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out AppIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out AppIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out AppIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out AppIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
    
    iconutil -c icns AppIcon.iconset
    cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
    rm -rf AppIcon.iconset AppIcon.icns
else
    echo "⚠️ Warning: Icon source not found at $ICON_SOURCE"
fi

# Info.plist 생성 (앱 실행 필수)
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.zero.ide</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

# Entitlements 생성 (권한 부여)
cat > "Zero.entitlements" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
EOF

# Code Signing (Ad-hoc + Entitlements)
echo "🔏 Signing app with entitlements..."
codesign --force --deep --sign - --entitlements "Zero.entitlements" "$APP_BUNDLE"

# 3. Create DMG
echo "💿 Creating $DMG_NAME..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"

echo "✅ Done! Created $DMG_NAME"
echo "👉 You can now upload this file to GitHub Releases."
