#!/usr/bin/env bash
# One-line installer for WebM to MP4 (macOS).
#
#   curl -fsSL https://raw.githubusercontent.com/jarediac/webm-to-mp4/main/install.sh | bash
#
# Downloads the latest release and puts "WebM to MP4.app" in /Applications.
# Files fetched with curl are not quarantined, so there is no Gatekeeper warning afterwards.
set -euo pipefail

REPO="jarediac/webm-to-mp4"
APP_NAME="WebM to MP4"
URL="https://github.com/$REPO/releases/latest/download/WebM-to-MP4.app.zip"
DEST="/Applications/$APP_NAME.app"

[ "$(uname)" = Darwin ] || { echo "This installer is for macOS."; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $APP_NAME…"
curl -fL --progress-bar -o "$TMP/app.zip" "$URL"

echo "Unpacking…"
ditto -x -k "$TMP/app.zip" "$TMP/unpacked"

echo "Installing into /Applications…"
if [ -w /Applications ]; then
  rm -rf "$DEST"
  mv "$TMP/unpacked/$APP_NAME.app" "$DEST"
else
  echo "(your password is needed to write to /Applications)"
  sudo rm -rf "$DEST"
  sudo mv "$TMP/unpacked/$APP_NAME.app" "$DEST"
fi
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo
echo "Done! \"$APP_NAME\" is in your Applications folder."
echo "Drop .webm files onto it, or double-click it to pick files."
open -R "$DEST" 2>/dev/null || true
