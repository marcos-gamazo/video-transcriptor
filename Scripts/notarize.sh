#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT/build"
APP_NAME="Transcriptor"

DMG_PATH="$BUILD_DIR/$APP_NAME-1.0.0.dmg"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "ERROR: DMG not found at $DMG_PATH"
    echo "Run: bash Scripts/build-release.sh 1.0.0"
    exit 1
fi

if [[ -z "${APPLE_ID:-}" || -z "${TEAM_ID:-}" || -z "${APPLE_ID_PASSWORD:-}" ]]; then
    echo "ERROR: Requiere credenciales Apple para notarizar."
    echo ""
    echo "Requisitos:"
    echo "  - Developer ID Application certificate (Keychain)"
    echo "  - Apple ID con acceso a notarytool"
    echo ""
    echo "Exporta:"
    echo "  export APPLE_ID=tu@email.com"
    echo "  export TEAM_ID=XXXXXXXXXX"
    echo "  export APPLE_ID_PASSWORD='app-specific-password'"
    echo ""
    echo "Genera la contraseña de app específica en:"
    echo "  https://appleid.apple.com/account/manage → Security → App-Specific Passwords"
    echo ""
    echo "Si no tienes Developer ID, puedes firmar ad-hoc (sin notarizar):"
    echo "  codesign --force --deep -s - --options runtime build/$APP_NAME.app"
    exit 1
fi

echo "▸ Notarizando $DMG_PATH..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APPLE_ID_PASSWORD" \
    --wait

echo "▸ Añadiendo stapling al DMG (para distribución offline)..."
xcrun stapler staple "$DMG_PATH" 2>&1 || {
    echo "  Stapling no soportado en DMG; staple en el .app dentro:"
    xcrun stapler staple "$BUILD_DIR/$APP_NAME.app" 2>&1
}

echo ""
echo "✓ Notarización completada."
echo "  DMG: $DMG_PATH"
