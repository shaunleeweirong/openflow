#!/bin/bash
# Builds OpenFlow.app from the SwiftPM executable.
# Usage: scripts/build_app.sh [--debug]
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="release"
if [[ "${1:-}" == "--debug" ]]; then
  CONFIG="debug"
fi

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="build/OpenFlow.app"

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/OpenFlow" "$APP_DIR/Contents/MacOS/OpenFlow"

# SPM resource bundles (e.g. KeyboardShortcuts localizations) must sit in
# Contents/Resources for Bundle.module lookup to succeed inside an .app.
find "$BIN_DIR" -maxdepth 1 -name "*.bundle" -exec cp -R {} "$APP_DIR/Contents/Resources/" \;

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OpenFlow</string>
    <key>CFBundleIdentifier</key>
    <string>com.shaunlee.OpenFlow</string>
    <key>CFBundleName</key>
    <string>OpenFlow</string>
    <key>CFBundleDisplayName</key>
    <string>OpenFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>OpenFlow listens while you hold the push-to-talk hotkey so it can transcribe your speech — entirely on this Mac.</string>
</dict>
</plist>
PLIST

# Sign with a stable identity so macOS TCC grants (Accessibility, Microphone) survive
# rebuilds. Ad-hoc signing changes the code hash every build and resets those grants.
# Prefer an explicit override, else the first valid code-signing identity on this machine
# (e.g. an "Apple Development" cert), else fall back to ad-hoc.
# Set OPENFLOW_HARDENED=1 (used by release.sh) to add the Hardened Runtime + secure
# timestamp that notarization requires.
SIGN_ID="${OPENFLOW_SIGN_ID:-}"
if [ -z "$SIGN_ID" ]; then
  SIGN_ID="$(security find-identity -v -p codesigning | awk -F'"' '/"/{print $2; exit}')"
fi

SIGN_ARGS=(--force --deep)
[ -f "OpenFlow.entitlements" ] && SIGN_ARGS+=(--entitlements "OpenFlow.entitlements")
if [ "${OPENFLOW_HARDENED:-0}" = "1" ]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi

if [ -n "$SIGN_ID" ]; then
  echo "==> Codesigning with: $SIGN_ID (hardened=${OPENFLOW_HARDENED:-0})"
  codesign "${SIGN_ARGS[@]}" -s "$SIGN_ID" "$APP_DIR"
else
  echo "==> Codesigning (ad-hoc — grants reset each rebuild; see README for a stable cert)"
  codesign --force --deep -s - "$APP_DIR"
fi

echo "==> Done: $APP_DIR"
echo "    Launch with: open $APP_DIR"
