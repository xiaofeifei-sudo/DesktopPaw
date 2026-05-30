#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swift build -c release --product DesktopPet
BIN_PATH="$(swift build --show-bin-path -c release)"

DIST_DIR="$ROOT_DIR/build"
APP_DIR="$DIST_DIR/DesktopPet.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RESOURCE_BUNDLE_NAME="DesktopPet_DesktopPet.bundle"

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BIN_PATH/DesktopPet" "$MACOS_DIR/DesktopPet"
chmod 755 "$MACOS_DIR/DesktopPet"

ditto "$BIN_PATH/$RESOURCE_BUNDLE_NAME" "$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME"

ICON_SOURCE="$ROOT_DIR/Sources/DesktopPet/Resources/starter-pet-preview.png"
ICON_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/desktop-pet-icon.XXXXXX")"

ICONSET_DIR="$ICON_TEMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

rm -rf "$ICON_TEMP_DIR"

# Codesign with standard layout (bundle in Contents/Resources)
codesign --force --sign - --entitlements "$ROOT_DIR/Packaging/DesktopPet.entitlements" "$APP_DIR" >/dev/null

# Copy resource bundle to app root for SPM runtime lookup (breaks seal, but needed)
ditto "$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME" "$APP_DIR/$RESOURCE_BUNDLE_NAME"

# --- Create DMG ---
DMG_NAME="DesktopPet.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
DMG_STAGING="$(mktemp -d "${TMPDIR:-/tmp}/desktop-pet-dmg.XXXXXX")"

cp -R "$APP_DIR" "$DMG_STAGING/DesktopPet.app"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "Desktop Pet" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

# Clear quarantine on the DMG so Gatekeeper doesn't block it on this machine
xattr -cr "$DMG_PATH" 2>/dev/null || true

echo ""
echo "Done: $DMG_PATH"
echo ""
echo "⚠️  在另一台 Mac 上首次打开时，需要右键点击 app → 「打开」，或在终端执行："
echo "    xattr -cr /Applications/DesktopPet.app"
