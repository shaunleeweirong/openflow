#!/bin/bash
# Builds a Developer ID-signed, notarized, stapled DMG for direct (non-App-Store)
# distribution. Recipients just download and double-click — no Gatekeeper warning.
#
# Prerequisites (one-time, see README):
#   - A "Developer ID Application" certificate in your keychain.
#   - Notarization credentials stored as a keychain profile:
#       xcrun notarytool store-credentials "openflow-notary" \
#         --apple-id <you> --team-id <TEAMID>   (it prompts for an app-specific password)
#
# Usage: scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"                       # keep in sync with build_app.sh Info.plist
APP_DIR="build/OpenFlow.app"
DMG_PATH="build/OpenFlow-${VERSION}.dmg"
ZIP_PATH="build/OpenFlow-notarize.zip"
VOL_NAME="OpenFlow"
NOTARY_PROFILE="${OPENFLOW_NOTARY_PROFILE:-openflow-notary}"

# Pick the Developer ID Application identity (override with OPENFLOW_SIGN_ID).
DEV_ID="${OPENFLOW_SIGN_ID:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
if [ -z "$DEV_ID" ]; then
  echo "ERROR: no 'Developer ID Application' identity found in the keychain." >&2
  echo "Create one: Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application." >&2
  exit 1
fi
echo "==> Release signing identity: $DEV_ID"

# 1. Build the .app signed with Developer ID + Hardened Runtime + entitlements.
OPENFLOW_SIGN_ID="$DEV_ID" OPENFLOW_HARDENED=1 bash scripts/build_app.sh

# 2. Sanity-check the signature before spending time on notarization.
echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP_DIR"

# 3. Zip the .app for submission (notarytool takes .zip/.dmg/.pkg).
echo "==> Zipping for notarization"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

# 4. Submit to Apple's notary service and wait for the result (~minutes).
echo "==> Notarizing (uploading to Apple; this can take a few minutes)…"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

# 5. Staple the ticket onto the .app so it verifies offline / after being copied out.
echo "==> Stapling ticket to the app"
xcrun stapler staple "$APP_DIR"

# 6. Package the stapled app into a drag-to-Applications DMG.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG_PATH"

# Sign the DMG with Developer ID (so Gatekeeper's open assessment finds a usable
# signature), then notarize + staple it so the downloaded image verifies offline too.
echo "==> Signing + notarizing the DMG (second pass)…"
codesign --force --timestamp -s "$DEV_ID" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
echo "==> Stapling ticket to the DMG"
xcrun stapler staple "$DMG_PATH"

# 7. Confirm Gatekeeper will accept it.
echo "==> Gatekeeper assessment"
spctl -a -vvv "$APP_DIR"
xcrun stapler validate "$DMG_PATH"

rm -f "$ZIP_PATH"
echo "==> Done: $DMG_PATH (Developer ID signed + notarized + stapled)"
echo "    Share this file. Recipients download it, open, and drag OpenFlow to Applications."
