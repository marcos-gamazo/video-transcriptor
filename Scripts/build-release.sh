#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="Transcriptor"
VERSION="${1:-1.0.0}"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

echo "▸ Building $APP_NAME $VERSION (release)..."
(cd "$ROOT" && swift build -c release 2>&1 | grep -E "error:|Build complete|warning:" | head -5)

echo "▸ Assembling $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES"

cp "$ROOT/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT/Assets/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"

echo "▸ Embedding libvosk.dylib (Vosk engine) in Contents/Frameworks..."
FRAMEWORKS_DIR="$CONTENTS/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"
cp "$ROOT/Vendor/vosk/libvosk.dylib" "$FRAMEWORKS_DIR/libvosk.dylib"
# El install name del dylib prebuilt es @rpath/libvosk.dylib (verificado con
# otool -D). El binario resuelve @rpath a @executable_path/../Frameworks, que
# se añade en Package.swift. Si alguna build futura enlaza con otro nombre,
# forzar ambos:
#   install_name_tool -id @rpath/libvosk.dylib "$FRAMEWORKS_DIR/libvosk.dylib"
#   install_name_tool -change libvosk.dylib @rpath/libvosk.dylib "$MACOS_DIR/$APP_NAME"

chmod 755 "$MACOS_DIR/$APP_NAME"
chmod 644 "$FRAMEWORKS_DIR/libvosk.dylib"

echo "▸ Verificando dependencias del binario..."
otool -L "$MACOS_DIR/$APP_NAME" | grep -q "libvosk.dylib" && echo "   libvosk OK"

echo "▸ Ad-hoc signing..."
codesign --force --deep -s "$SIGN_IDENTITY" --options runtime "$APP_BUNDLE" 2>&1
codesign --verify --verbose "$APP_BUNDLE" 2>&1 | head -3

echo "▸ Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
rm -f "$DMG_PATH"

hdiutil create -srcfolder "$APP_BUNDLE" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" 2>&1 | tail -1

echo ""
echo "✓ Build complete!"
echo "  App:   $APP_BUNDLE"
echo "  DMG:   $DMG_PATH"

echo ""
echo "⚠  NOTA: Firma ad-hoc sin Developer ID."
echo "   Gatekeeper bloqueará la app al abrir desde DMG."
echo "   Soluciones:"
echo "     1. Botón derecho → Abrir en el Finder"
echo "     2. O ejecutar: xattr -cr /Applications/Transcriptor.app"
echo "   Para firma real + notarización, define:"
echo "     export CODE_SIGN_IDENTITY='Developer ID Application: TU NOMBRE (TEAM_ID)'"
echo "   y ejecuta el script 'scripts/notarize.sh' después."
