#!/bin/bash
# Sign Flusso with a Developer ID, notarize it with Apple, and staple the
# ticket, so it opens on any Mac with no warning, distributed as a direct
# download (NOT the App Store, which cannot host an app that pastes into
# other apps and watches the Fn key globally).
#
# This needs an Apple Developer account. Fill in scripts/notarize.config first
# (see scripts/notarize.config.example). Nothing here runs without it.
#
# Bonus: a stable Developer ID signature also fixes the "Accessibility grant
# breaks on every rebuild" annoyance, because macOS then keys the permission
# to your Team ID instead of the ad-hoc build hash.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="scripts/notarize.config"
if [ ! -f "$CONFIG" ]; then
    echo "Missing $CONFIG."
    echo "Copy scripts/notarize.config.example to $CONFIG and fill in your"
    echo "Apple Developer details. You need a paid Apple Developer account."
    exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

for tool in codesign xcrun ditto; do
    command -v "$tool" >/dev/null || { echo "Missing required tool: $tool"; exit 1; }
done
if ! security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID"; then
    echo "Signing identity not found in your keychain:"
    echo "  $DEVELOPER_ID"
    echo "Install your Developer ID Application certificate, then retry."
    exit 1
fi

APP="build/Flusso.app"
ENTITLEMENTS="scripts/entitlements.plist"

echo "1/5  Building a fresh release bundle..."
scripts/bundle.sh >/dev/null

echo "2/5  Signing with hardened runtime and Developer ID..."
# Sign the executable first, then the bundle, deep, with a secure timestamp.
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID" \
    "$APP/Contents/MacOS/Flusso"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID" \
    "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "3/5  Zipping for submission..."
ZIP="build/Flusso-notarize.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "4/5  Submitting to Apple for notarization (this can take a few minutes)..."
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "5/5  Stapling the notarization ticket to the app..."
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP" || true

# Produce a clean distributable zip with the stapled app.
DIST="build/Flusso-signed.zip"
rm -f "$DIST"
ditto -c -k --keepParent "$APP" "$DIST"
echo
echo "Done. Distributable, notarized app: $DIST"
echo "It will open on any Mac with no security warning."
