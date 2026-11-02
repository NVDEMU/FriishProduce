#!/usr/bin/env bash
set -Eeuo pipefail

# Create an unsigned/ad-hoc-signed DMG. This does not require a paid Apple
# Developer ID certificate and does not pretend to provide notarization.
# For Internet-downloaded apps, Gatekeeper may require the user to remove the
# quarantine attribute or use Finder's right-click > Open flow.

APP_PATH="${1:-}"
DMG_PATH="${2:-}"
VOLUME_NAME="${DMG_VOLUME_NAME:-FriishProduce}"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -n "$APP_PATH" && -n "$DMG_PATH" ]] || fail "Usage: $0 /path/to/FriishProduce.app /path/to/FriishProduce.dmg"
[[ -d "$APP_PATH" && "$APP_PATH" == *.app ]] || fail "Input must be an existing .app bundle."
[[ -f "$APP_PATH/Contents/Info.plist" ]] || fail "App bundle is missing Contents/Info.plist."
[[ -x "$APP_PATH/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")" ]]   || fail "App's CFBundleExecutable is missing or not executable."

command -v hdiutil >/dev/null || fail "hdiutil is required; run this script on macOS."
command -v ditto >/dev/null || fail "ditto is required; run this script on macOS."
command -v codesign >/dev/null || fail "codesign is required; run this script on macOS."

APP_PATH="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")"
DMG_DIR="$(mkdir -p "$(dirname "$DMG_PATH")" && cd "$(dirname "$DMG_PATH")" && pwd)"
DMG_PATH="$DMG_DIR/$(basename "$DMG_PATH")"
WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Add an ad-hoc signature. This catches malformed nested code/signature
# structure but does not establish a Developer ID identity or notarization.
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

STAGING="$WORK_DIR/dmg-root"
mkdir -p "$STAGING"
ditto "$APP_PATH" "$STAGING/$(basename "$APP_PATH")"
ln -s /Applications "$STAGING/Applications"

cat > "$STAGING/First Launch.command" <<'LAUNCHER'
#!/bin/bash
set -e
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$APP_DIR/FriishProduce.app"
if [[ ! -d "$APP" ]]; then
  echo "FriishProduce.app was not found beside this launcher."
  read -r -p "Press Return to close..."
  exit 1
fi
echo "Removing the macOS download quarantine attribute from this app..."
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "Opening FriishProduce..."
open "$APP"
LAUNCHER
chmod +x "$STAGING/First Launch.command"

cat > "$STAGING/READ ME - FIRST LAUNCH.txt" <<'README'
FriishProduce for macOS — first launch

This community build is not signed with an Apple Developer ID and is not notarized.
macOS may block it when downloaded from the Internet.

Recommended:
1. Drag FriishProduce.app to Applications.
2. Open Terminal and paste:
   xattr -dr com.apple.quarantine "/Applications/FriishProduce.app"
3. Open FriishProduce from Applications.

Alternatively, in Finder, Control-click FriishProduce.app, choose Open, then choose Open
again in the confirmation dialog. If macOS still blocks it, use the Terminal command
above. Do not run this workaround on an app you do not trust.

The included First Launch.command only clears quarantine from the copy of FriishProduce.app
beside it on the mounted disk image. It does not install the app into Applications.
README

rm -f "$DMG_PATH"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
codesign --force --sign - "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "Created unsigned/ad-hoc-signed DMG: $DMG_PATH"
