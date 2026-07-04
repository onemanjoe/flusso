#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Flusso.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Flusso "$APP/Contents/MacOS/Flusso"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.giuseppe.flusso</string>
    <key>CFBundleName</key><string>Flusso</string>
    <key>CFBundleExecutable</key><string>Flusso</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Flusso needs the microphone to transcribe your dictation, entirely on this Mac.</string>
</dict>
</plist>
PLIST
# Prefer a stable local signing identity so macOS keeps the TCC permissions
# (Accessibility, Input Monitoring) across rebuilds. The certificate hash is
# constant, so the app's designated requirement does not change when the code
# does. Falls back to ad-hoc signing when the cert is absent (another Mac).
SIGN_HASH="$(security find-certificate -c 'Flusso Local Signing' -Z 2>/dev/null | awk '/SHA-1 hash:/{print $3; exit}')" || SIGN_HASH=""
if [ -n "$SIGN_HASH" ]; then
    codesign --force --sign "$SIGN_HASH" "$APP"
    echo "Signed with stable local identity, permissions persist across rebuilds."
else
    codesign --force --sign - "$APP"
    echo "Ad-hoc signed, no local signing identity found."
fi
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    osascript -e 'tell application "Flusso" to quit' 2>/dev/null || true
    for i in $(seq 1 10); do
        pgrep -x Flusso >/dev/null 2>&1 || break
        sleep 1
    done
    pkill -x Flusso 2>/dev/null || true
    sleep 1
    rm -rf "/Applications/Flusso.app"
    cp -R "$APP" "/Applications/Flusso.app"
    open "/Applications/Flusso.app"
    echo "Installed to /Applications (re-grant permissions if macOS asks, the signature changed)"
fi
