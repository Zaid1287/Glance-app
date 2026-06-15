#!/bin/sh
# Sign + notarize the Glance Mac binaries for Gatekeeper-clean distribution.
# Needs a paid Apple Developer account (the builder's), set up once:
#   1. A "Developer ID Application" certificate in the login keychain.
#   2. A stored notary credential profile:
#        xcrun notarytool store-credentials glance-notary \
#          --apple-id you@example.com --team-id XXXXXXXXXX \
#          --password <app-specific-password>
#
# Usage:
#   GLANCE_SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
#   GLANCE_NOTARY_PROFILE=glance-notary \
#   scripts/sign-notarize.sh <dir-containing-glance-and-glance-bar> [out.zip]
#
# Produces a notarized zip to publish as the release asset. With a notarized
# release, install.sh can be run with GLANCE_NOTARIZED=1 to skip the quarantine
# strip entirely.
set -eu

ID="${GLANCE_SIGN_ID:?set GLANCE_SIGN_ID to your 'Developer ID Application: …' identity}"
PROFILE="${GLANCE_NOTARY_PROFILE:-glance-notary}"
DIR="${1:?usage: sign-notarize.sh <dir with glance + glance-bar> [out.zip]}"
OUT="${2:-glance-macos-arm64.zip}"

[ -x "$DIR/glance" ] && [ -x "$DIR/glance-bar" ] || {
  echo "✗ expected executables $DIR/glance and $DIR/glance-bar" >&2; exit 1; }

echo "==> Codesigning with hardened runtime"
for bin in glance glance-bar; do
  codesign --force --timestamp --options runtime --sign "$ID" "$DIR/$bin"
  codesign --verify --strict "$DIR/$bin"
done

echo "==> Zipping for notarization"
( cd "$DIR" && ditto -c -k --keepParent . "$OUT" ) || \
  ( cd "$DIR" && /usr/bin/zip -qr "$OLDPWD/$OUT" . )
[ -f "$OUT" ] || OUT="$DIR/$OUT"

echo "==> Submitting to Apple notary service (waits for the result)"
xcrun notarytool submit "$OUT" --keychain-profile "$PROFILE" --wait

# Bare CLI executables can't be stapled (stapler supports .app/.dmg/.pkg only);
# the notarization ticket is verified online by Gatekeeper on first run. This is
# best-effort and expected to be a no-op for raw binaries.
for bin in glance glance-bar; do
  xcrun stapler staple "$DIR/$bin" 2>/dev/null || true
done

echo "✓ Notarized. Publish '$OUT' as the release asset."
echo "  Users can then install trust-clean with:  GLANCE_NOTARIZED=1 sh install.sh"
