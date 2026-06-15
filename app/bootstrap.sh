#!/bin/sh
# Generate and open the Glance iOS + Watch Xcode project.
# Requires: Xcode installed, Homebrew (for xcodegen).
set -e
cd "$(dirname "$0")"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "==> Checking toolchain"
xcodebuild -version

# One-time: accept the license + install platform runtimes if missing.
if ! xcrun simctl list runtimes available 2>/dev/null | grep -qi "iOS"; then
  echo "==> iOS runtime not found. Installing platforms (large, one-time)..."
  echo "    If this fails on licensing, run once:  sudo xcodebuild -license accept"
  xcodebuild -downloadPlatform iOS || true
  xcodebuild -downloadPlatform watchOS || true
fi

echo "==> Ensuring xcodegen"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

echo "==> Generating Glance.xcodeproj"
# Default to the original free personal team; a paid builder overrides with
#   DEVELOPMENT_TEAM=XXXXXXXXXX ./bootstrap.sh
export DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-MW45P4B969}"
echo "    Signing team: $DEVELOPMENT_TEAM"
xcodegen generate

echo ""
echo "Done. Next:"
echo "  1. open Glance.xcodeproj"
echo "  2. Select the GlanceApp target > Signing & Capabilities > set your Team"
echo "     (a free Apple ID works; the build then runs on your iPhone for 7 days)"
echo "  3. Plug in your iPhone, pick it as the run destination, and Run."
echo "  4. On your Mac, run:  glance sync-serve   and paste ~/.glance/key into the app to pair."
open Glance.xcodeproj
