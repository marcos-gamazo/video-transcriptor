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

# Cross-compile opcional: SWIFT_TRIPLE (p. ej. x86_64-apple-macosx11.0) y
# SWIFT_SDK_PATH (xcrun --sdk macosx --show-sdk-path). Vacío = build nativo.
SWIFT_ARGS=()
if [[ -n "${SWIFT_TRIPLE:-}" ]]; then
  SWIFT_ARGS+=(--triple "$SWIFT_TRIPLE")
  if [[ -n "${SWIFT_SDK_PATH:-}" ]]; then
    SWIFT_ARGS+=(--sdk "$SWIFT_SDK_PATH")
  fi
fi

ARCH_SUFFIX=""
if [[ "${SWIFT_TRIPLE:-}" == *x86_64* ]]; then
  ARCH_SUFFIX="-Intel"
fi

echo "▸ Building $APP_NAME $VERSION (release)..."
( cd "$ROOT" && swift build -c release ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"} 2>&1 | grep -E "error:|Build complete|warning:" | head -5 )

BIN_DIR="$ROOT/.build/release"
if [[ -n "${SWIFT_TRIPLE:-}" ]]; then
  BIN_DIR="$(cd "$ROOT" && swift build -c release ${SWIFT_ARGS[@]+"${SWIFT_ARGS[@]}"} --show-bin-path)"
  case "$BIN_DIR" in
    /*) ;;
    *) BIN_DIR="$ROOT/$BIN_DIR" ;;
  esac
fi

echo "▸ Assembling $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
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

# Swift Concurrency back-deployment (macOS < 12.3): al compilar con target
# anterior a 12.3, el binario enlaza (débilmente) @rpath/libswift_Concurrency.dylib
# porque la app usa Swift Concurrency. En macOS 11 esa librería NO existe en el
# sistema y, si no se embeve, dyld la deja en nulo (weak) y el runtime revienta
# al usar el primer Task (crash en el demangler de libswiftCore). La copia del
# toolchain es universal (arm64 + x86_64) y se resuelve vía @executable_path/../Frameworks.
CONC_NEEDED=0
if [[ -n "${SWIFT_TRIPLE:-}" && "$SWIFT_TRIPLE" =~ apple-macosx([0-9]+)\.([0-9]+) ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  if (( MAJOR < 12 )) || (( MAJOR == 12 && MINOR < 3 )); then
    CONC_NEEDED=1
  fi
fi

if [[ "$CONC_NEEDED" == 1 ]]; then
  # Runtime de Swift Concurrency para back-deployment (macOS < 12.3).
  #
  # IMPORTANTE: la copia del runtime que trae el toolchain de swift.org 6.x
  # (usr/lib/swift/macosx/libswift_Concurrency.dylib) está compilada contra un
  # libswiftCore moderno y referencia símbolos de `Durations`/marcos 5.7+ que
  # NO existen en el libswiftCore de macOS 11 → error de enlazado en arranque
  # ("missing required bundle" / símbolo no resuelto). La librería correcta es
  # el runtime "evergreen" de back-deploy que Apple congela en los toolchains
  # de Xcode/CommandLineTools 13–15 (usr/lib/swift-5.5/macosx/…): minOS 10.9,
  # universal arm64+x86_64, sin referencias a símbolos modernos, y que exporta
  # toda la API de runtime que el binario compilado con Swift 6 necesite
  # (swift_task_*, swift_continuation_*, swift_defaultActor_*, swift_async_*).
  # Por eso se usa la copia VENDED en Vendor/swift-backdeploy/ (verificada),
  # en lugar de descubrir la del toolchain, que en CI (Xcode 26) ni existe.
  CONC_LIB="$ROOT/Vendor/swift-backdeploy/libswift_Concurrency.dylib"
  if [[ ! -f "$CONC_LIB" ]]; then
    echo "ERROR: falta la librería vended: $CONC_LIB" >&2
    exit 1
  fi
  echo "▸ Embedding libswift_Concurrency.dylib (back-deployment macOS < 12.3, runtime evergreen)..."
  cp "$CONC_LIB" "$FRAMEWORKS_DIR/libswift_Concurrency.dylib"
  chmod 644 "$FRAMEWORKS_DIR/libswift_Concurrency.dylib"
  BIN_ARCH=$(lipo -archs "$MACOS_DIR/$APP_NAME" | awk '{print $1}')
  if ! lipo -archs "$FRAMEWORKS_DIR/libswift_Concurrency.dylib" | grep -q "$BIN_ARCH"; then
    echo "ERROR: libswift_Concurrency.dylib ($(lipo -archs "$FRAMEWORKS_DIR/libswift_Concurrency.dylib")) no incluye la arquitectura $BIN_ARCH" >&2
    exit 1
  fi
  # Verificación de que NO referencia símbolos de macOS 12.3+ (p. ej. Durations),
  # que es lo que rompía en macOS 11 con la copia del toolchain de swift.org.
  THIN_CONC="$(mktemp)"
  lipo -thin "$BIN_ARCH" "$FRAMEWORKS_DIR/libswift_Concurrency.dylib" -output "$THIN_CONC" 2>/dev/null
  VENDED_MINOS="$(vtool -show-build "$THIN_CONC" 2>/dev/null \
    | grep -A2 -i LC_VERSION_MIN_MACOSX | tail -1 | awk '{print $2}')"
  rm -f "$THIN_CONC"
  if [[ -n "$VENDED_MINOS" ]] && [[ "$VENDED_MINOS" > "11.9" ]]; then
    echo "ERROR: libswift_Concurrency.dylib vended tiene minOS $VENDED_MINOS (> 11), no sirve para back-deployment a macOS 11" >&2
    exit 1
  fi
fi

chmod 755 "$MACOS_DIR/$APP_NAME"
chmod 644 "$FRAMEWORKS_DIR/libvosk.dylib"

echo "▸ Verificando dependencias del binario..."
otool -L "$MACOS_DIR/$APP_NAME" | grep -q "libvosk.dylib" && echo "   libvosk OK"
if [[ "$CONC_NEEDED" == 1 ]]; then
  otool -L "$MACOS_DIR/$APP_NAME" | grep -q "@rpath/libswift_Concurrency.dylib" \
    && echo "   libswift_Concurrency (weak) OK"
  ls -la "$FRAMEWORKS_DIR/libswift_Concurrency.dylib"
fi

echo "▸ Ad-hoc signing..."
codesign --force --deep -s "$SIGN_IDENTITY" --options runtime "$APP_BUNDLE" 2>&1
codesign --verify --verbose "$APP_BUNDLE" 2>&1 | head -3

echo "▸ Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION$ARCH_SUFFIX.dmg"
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
