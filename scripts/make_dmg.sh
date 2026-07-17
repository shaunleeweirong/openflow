#!/bin/bash
# Packages OpenFlow.app into a distributable disk image (build/OpenFlow-<ver>.dmg).
# Builds a fresh release .app first, then wraps it in a drag-to-Applications DMG.
# Uses only macOS built-ins (hdiutil) — no extra tooling required.
# Usage: scripts/make_dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_DIR="build/OpenFlow.app"
VERSION="0.3.0"                      # keep in sync with build_app.sh Info.plist
DMG_PATH="build/OpenFlow-${VERSION}.dmg"
VOL_NAME="OpenFlow"

# 1. Build a fresh, ad-hoc-signed release .app (reuse existing build script).
echo "==> Building app"
scripts/build_app.sh

# 2. Stage DMG contents: the app + an /Applications alias to drag into.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 3. Build a compressed disk image from the staging folder.
echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" \
  -fs HFS+ -format UDZO -ov "$DMG_PATH"

echo "==> Done: $DMG_PATH"
echo "    Share this file. On the other Mac: open it, drag OpenFlow to Applications."
