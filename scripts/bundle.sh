#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Flusso.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Flusso "$APP/Contents/MacOS/Flusso"
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
    <key>NSMicrophoneUsageDescription</key>
    <string>Flusso needs the microphone to transcribe your dictation, entirely on this Mac.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    osascript -e 'tell application "Flusso" to quit' 2>/dev/null || true
    sleep 1
    rm -rf "/Applications/Flusso.app"
    cp -R "$APP" "/Applications/Flusso.app"
    open "/Applications/Flusso.app"
    echo "Installed to /Applications (re-grant permissions if macOS asks, the signature changed)"
fi
