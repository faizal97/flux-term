#!/bin/bash
set -euo pipefail

# FluxTerm .app bundle builder
# Usage: ./scripts/bundle.sh [arm64|x86_64|universal]

ARCH="${1:-universal}"
APP_NAME="FluxTerm"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS="$BUNDLE_DIR/Contents"
ICON_SRC="$ROOT_DIR/Sources/FluxTerm/Resources/AppIcon.png"

echo "==> Building FluxTerm ($ARCH)..."

# Clean previous bundle
rm -rf "$BUNDLE_DIR"

# Build
if [ "$ARCH" = "universal" ]; then
    swift build -c release --arch arm64 --package-path "$ROOT_DIR"
    swift build -c release --arch x86_64 --package-path "$ROOT_DIR"
    lipo -create \
        "$ROOT_DIR/.build/arm64-apple-macosx/release/FluxTerm" \
        "$ROOT_DIR/.build/x86_64-apple-macosx/release/FluxTerm" \
        -output /tmp/FluxTerm-universal
    BINARY="/tmp/FluxTerm-universal"
    # Use arm64 resource bundle (identical across architectures)
    RESOURCE_BUNDLE="$ROOT_DIR/.build/arm64-apple-macosx/release/FluxTerm_FluxTerm.bundle"
else
    swift build -c release --arch "$ARCH" --package-path "$ROOT_DIR"
    BINARY="$ROOT_DIR/.build/${ARCH}-apple-macosx/release/FluxTerm"
    RESOURCE_BUNDLE="$ROOT_DIR/.build/${ARCH}-apple-macosx/release/FluxTerm_FluxTerm.bundle"
fi

echo "==> Generating .icns..."

ICONSET_DIR="/tmp/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all required icon sizes from 1024x1024 source
sips -z 16 16     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
sips -z 128 128   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

iconutil -c icns "$ICONSET_DIR" -o /tmp/AppIcon.icns

echo "==> Creating .app bundle..."

mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Copy binary
cp "$BINARY" "$CONTENTS/MacOS/FluxTerm"
chmod +x "$CONTENTS/MacOS/FluxTerm"

# Copy Info.plist
cp "$ROOT_DIR/Info.plist" "$CONTENTS/Info.plist"

# Copy icon
cp /tmp/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

# Copy SPM resource bundle (contains Metal shaders + AppIcon.png)
cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/FluxTerm_FluxTerm.bundle"

echo "==> Done: $BUNDLE_DIR"
echo ""
file "$CONTENTS/MacOS/FluxTerm"
du -sh "$BUNDLE_DIR"
