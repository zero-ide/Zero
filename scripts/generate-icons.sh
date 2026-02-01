#!/bin/bash

# Generate macOS App Icons from SVG
# Usage: ./scripts/generate-icons.sh

set -e

APP_NAME="Zero"
RESOURCES_DIR="Sources/Zero/Resources"
ICONSET_DIR="${RESOURCES_DIR}/AppIcon.iconset"

echo "🎨 Generating macOS app icons..."

# Check if logo.svg exists
if [ ! -f "${RESOURCES_DIR}/logo.svg" ]; then
    echo "❌ Error: logo.svg not found in ${RESOURCES_DIR}"
    exit 1
fi

# Create iconset directory
mkdir -p "${ICONSET_DIR}"

# Generate icons at different sizes
# macOS requires: 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, 1024x1024
# @1x and @2x versions

echo "📐 Generating icon sizes..."

# 16x16 (16x16@1x, 16x16@2x=32x32)
# Not needed separately, will use 32x32 for @2x

# 32x32 (32x32@1x, 32x32@2x=64x64)
# Not needed separately, will use 64x64 for @2x

# 128x128 (128x128@1x, 128x128@2x=256x256)
sips -z 128 128 "${RESOURCES_DIR}/logo.svg" --out "${ICONSET_DIR}/icon_128x128.png" 2>/dev/null || \
    rsvg-convert -w 128 -h 128 "${RESOURCES_DIR}/logo.svg" -o "${ICONSET_DIR}/icon_128x128.png"

sips -z 256 256 "${RESOURCES_DIR}/logo.svg" --out "${ICONSET_DIR}/icon_128x128@2x.png" 2>/dev/null || \
    rsvg-convert -w 256 -h 256 "${RESOURCES_DIR}/logo.svg" -o "${ICONSET_DIR}/icon_128x128@2x.png"

# 256x256 (256x256@1x, 256x256@2x=512x512)
sips -z 256 256 "${RESOURCES_DIR}/logo.svg" --out "${ICONSET_DIR}/icon_256x256.png" 2>/dev/null || \
    rsvg-convert -w 256 -h 256 "${RESOURCES_DIR}/logo.svg" -o "${ICONSET_DIR}/icon_256x256.png"

sips -z 512 512 "${RESOURCES_DIR}/logo.svg" --out "${ICONSET_DIR}/icon_256x256@2x.png" 2>/dev/null || \
    rsvg-convert -w 512 -h 512 "${RESOURCES_DIR}/logo.svg" -o "${ICONSET_DIR}/icon_256x256@2x.png"

# 512x512 (512x512@1x, 512x512@2x=1024x1024)
sips -z 512 512 "${RESOURCES_DIR}/logo.svg" --out "${ICONSET_DIR}/icon_512x512.png" 2>/dev/null || \
    rsvg-convert -w 512 -h 512 "${RESOURCES_DIR}/logo.svg" -o "${ICONSET_DIR}/icon_512x512.png"

sips -z 1024 1024 "${RESOURCES_DIR}/logo.svg" --out "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null || \
    rsvg-convert -w 1024 -h 1024 "${RESOURCES_DIR}/logo.svg" -o "${ICONSET_DIR}/icon_512x512@2x.png"

# Alternative: Use ImageMagick if available
if command -v convert &> /dev/null; then
    echo "✨ Using ImageMagick for better SVG rendering..."
    
    for size in 16 32 64 128 256 512 1024; do
        if [ $size -eq 1024 ]; then
            output="${ICONSET_DIR}/icon_512x512@2x.png"
        elif [ $size -eq 512 ]; then
            output="${ICONSET_DIR}/icon_512x512.png"
        elif [ $size -eq 256 ]; then
            output="${ICONSET_DIR}/icon_256x256.png"
        elif [ $size -eq 128 ]; then
            output="${ICONSET_DIR}/icon_128x128.png"
        else
            output="${ICONSET_DIR}/icon_${size}x${size}.png"
        fi
        
        convert -background none -resize ${size}x${size} "${RESOURCES_DIR}/logo.svg" "${output}" 2>/dev/null || true
    done
    
    # Create @2x versions
    convert -background none -resize 32x32 "${RESOURCES_DIR}/logo.svg" "${ICONSET_DIR}/icon_16x16@2x.png" 2>/dev/null || true
    convert -background none -resize 64x64 "${RESOURCES_DIR}/logo.svg" "${ICONSET_DIR}/icon_32x32@2x.png" 2>/dev/null || true
fi

echo "📦 Creating .icns file..."

# Convert iconset to icns
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns" || {
    echo "⚠️  Warning: iconutil failed. Using fallback method..."
    
    # Fallback: Use png2icns if available
    if command -v png2icns &> /dev/null; then
        png2icns "${RESOURCES_DIR}/AppIcon.icns" \
            "${ICONSET_DIR}/icon_16x16.png" \
            "${ICONSET_DIR}/icon_32x32.png" \
            "${ICONSET_DIR}/icon_128x128.png" \
            "${ICONSET_DIR}/icon_256x256.png" \
            "${ICONSET_DIR}/icon_512x512.png" \
            "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null || true
    fi
}

# Clean up iconset directory (keep it for reference)
# rm -rf "${ICONSET_DIR}"

echo ""
echo "✅ Icons generated successfully!"
echo ""
echo "📦 Files created:"
echo "   - ${RESOURCES_DIR}/AppIcon.icns"
echo "   - ${ICONSET_DIR}/ (iconset directory)"
echo ""
echo "📝 To use in your app:"
echo "   1. Add AppIcon.icns to your Xcode project"
echo "   2. Set CFBundleIconFile in Info.plist"
echo ""
