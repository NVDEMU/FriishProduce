#!/usr/bin/env bash
set -Eeuo pipefail

# Build a Gatekeeper-ready macOS DMG from an already-built .app bundle.
# This script deliberately fails closed: unsigned or unnotarized apps are never
# emitted as a public release artifact.

APP_PATH="${1:-}"
DMG_PATH="${2:-}"
SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${APPLE_NOTARY_PROFILE:-}"
VOLUME_NAME="${DMG_VOLUME_NAME:-FriishProduce}"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -n "$APP_PATH" ]] || fail "Usage: $0 /path/to/FriishProduce.app /path/to/FriishProduce.dmg"
[[ -n "$DMG_PATH" ]] || fail "A DMG output path is required."
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "Input must be a .app bundle."
[[ -f "$APP_PATH/Contents/Info.plist" ]] || fail "Missing Contents/Info.plist."
[[ -n "$SIGNING_IDENTITY" ]] || fail "APPLE_SIGNING_IDENTITY is not set."
[[ -n "$NOTARY_PROFILE" ]] || fail "APPLE_NOTARY_PROFILE is not set."

command -v codesign >/dev/null || fail "codesign is unavailable (run on macOS)."
command -v xcrun >/dev/null || fail "xcrun is unavailable (install Xcode Command Line Tools)."
command -v hdiutil >/dev/null || fail "hdiutil is unavailable (run on macOS)."
command -v ditto >/dev/null || fail "ditto is unavailable (run on macOS)."

IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
grep -Fq "$SIGNING_IDENTITY" <<<"$IDENTITIES" || fail "Signing identity was not found in the keychain: $SIGNING_IDENTITY"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "Notary profile '$NOTARY_PROFILE' is unavailable or invalid."

APP_PATH="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")"
DMG_DIR="$(mkdir -p "$(dirname "$DMG_PATH")" && cd "$(dirname "$DMG_PATH")" && pwd)"
DMG_PATH="$DMG_DIR/$(basename "$DMG_PATH")"

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Sign embedded native code from deepest file to outer app. Managed .NET assemblies
# are not Mach-O files and are intentionally left to the app bundle signature.
while IFS= read -r -d '' candidate; do
  description="$(file -b "$candidate" 2>/dev/null || true)"
  if grep -q 'Mach-O' <<<"$description"; then
    echo "Signing nested native code: $candidate"
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$candidate"
  fi
done < <(find "$APP_PATH/Contents" -type f -print0)

codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

# Submit the app first so its notarization ticket can be stapled into the app
# before it is placed inside the disk image.
APP_ZIP="$WORK_DIR/FriishProduce-notary.zip"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

STAGING="$WORK_DIR/dmg-root"
mkdir -p "$STAGING"
ditto "$APP_PATH" "$STAGING/$(basename "$APP_PATH")"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "Created notarized, stapled, validated DMG: $DMG_PATH"
