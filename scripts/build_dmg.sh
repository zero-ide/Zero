#!/bin/bash
set -euo pipefail

APP_NAME="Zero"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
RESOURCES_DIR="Sources/Zero/Resources"
DEFAULT_ICON_SOURCE="$RESOURCES_DIR/AppIcon.iconset/icon_1024x1024.png"
ENTITLEMENTS_FILE="Zero.entitlements"

log() {
    printf "%s\n" "$1"
}

warn() {
    printf "⚠️ %s\n" "$1"
}

die() {
    printf "❌ %s\n" "$1" >&2
    exit 1
}

require_tool() {
    local tool="$1"
    local hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        die "Required tool '$tool' is missing. $hint"
    fi
}

normalize_arch() {
    local arch="$1"

    case "$arch" in
        arm64|aarch64)
            printf "arm64"
            ;;
        x86_64|amd64)
            printf "x86_64"
            ;;
        *)
            die "Unsupported architecture '$arch'. Set ZERO_DMG_ARCH to arm64 or x86_64."
            ;;
    esac
}

resolve_arch() {
    if [ -n "${ZERO_DMG_ARCH:-}" ]; then
        normalize_arch "$ZERO_DMG_ARCH"
        return
    fi

    normalize_arch "$(uname -m)"
}

if [ "$(uname -s)" != "Darwin" ]; then
    die "DMG packaging is only supported on macOS."
fi

require_tool swift "Install Xcode Command Line Tools with: xcode-select --install"
require_tool hdiutil "Run this script on macOS where hdiutil is available."
require_tool codesign "Install Xcode Command Line Tools with: xcode-select --install"

ARCH="$(resolve_arch)"
BUILD_DIR="${ZERO_DMG_BUILD_DIR:-.build/${ARCH}-apple-macosx/release}"
BINARY_PATH="$BUILD_DIR/$APP_NAME"
ICON_SOURCE="${ZERO_ICON_SOURCE:-$DEFAULT_ICON_SOURCE}"
HAS_ICON="0"

if [ "${ZERO_DMG_DRY_RUN:-0}" = "1" ]; then
    printf "dry_run=1\n"
    printf "arch=%s\n" "$ARCH"
    printf "build_dir=%s\n" "$BUILD_DIR"
    printf "icon_source=%s\n" "$ICON_SOURCE"
    exit 0
fi

log "🏗️  Building $APP_NAME (Release, arch=$ARCH)..."
swift build -c release --arch "$ARCH"

log "📦 Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

if [ ! -f "$BINARY_PATH" ]; then
    die "Binary not found at '$BINARY_PATH'. Check build output and ZERO_DMG_BUILD_DIR."
fi
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/"

log "📂 Copying resources..."
if compgen -G "$BUILD_DIR/*.bundle" >/dev/null; then
    cp -R "$BUILD_DIR"/*.bundle "$APP_BUNDLE/Contents/Resources/"
fi

if [ -f "$ICON_SOURCE" ]; then
    if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
        log "🎨 Creating AppIcon.icns from $ICON_SOURCE..."
        rm -rf AppIcon.iconset AppIcon.icns
        mkdir -p AppIcon.iconset

        sips -z 16 16 "$ICON_SOURCE" --out AppIcon.iconset/icon_16x16.png >/dev/null
        sips -z 32 32 "$ICON_SOURCE" --out AppIcon.iconset/icon_16x16@2x.png >/dev/null
        sips -z 32 32 "$ICON_SOURCE" --out AppIcon.iconset/icon_32x32.png >/dev/null
        sips -z 64 64 "$ICON_SOURCE" --out AppIcon.iconset/icon_32x32@2x.png >/dev/null
        sips -z 128 128 "$ICON_SOURCE" --out AppIcon.iconset/icon_128x128.png >/dev/null
        sips -z 256 256 "$ICON_SOURCE" --out AppIcon.iconset/icon_128x128@2x.png >/dev/null
        sips -z 256 256 "$ICON_SOURCE" --out AppIcon.iconset/icon_256x256.png >/dev/null
        sips -z 512 512 "$ICON_SOURCE" --out AppIcon.iconset/icon_256x256@2x.png >/dev/null
        sips -z 512 512 "$ICON_SOURCE" --out AppIcon.iconset/icon_512x512.png >/dev/null
        sips -z 1024 1024 "$ICON_SOURCE" --out AppIcon.iconset/icon_512x512@2x.png >/dev/null

        iconutil -c icns AppIcon.iconset
        cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
        rm -rf AppIcon.iconset AppIcon.icns
        HAS_ICON="1"
    else
        warn "Skipping icon generation because 'sips' or 'iconutil' is unavailable."
    fi
else
    warn "Icon source not found at '$ICON_SOURCE'. Packaging without a custom icon."
fi

ICON_PLIST_SECTION=""
if [ "$HAS_ICON" = "1" ]; then
    ICON_PLIST_SECTION="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
$ICON_PLIST_SECTION
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
    <key>CFBundleURLTypes</key>
    <array>
      <dict>
        <key>CFBundleURLName</key>
        <string>com.zero.ide.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
          <string>zero</string>
        </array>
      </dict>
    </array>
</dict>
</plist>
EOF

cat > "$ENTITLEMENTS_FILE" <<EOF
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

log "🔏 Signing app with entitlements..."
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_FILE" "$APP_BUNDLE"

log "💿 Creating $DMG_NAME..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_NAME"

log "✅ Done! Created $DMG_NAME"
log "👉 You can now upload this file to GitHub Releases."
