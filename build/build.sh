#!/usr/bin/env bash
# Builds "WebM to MP4.app" plus a .pkg, a .dmg and a .zip of it. macOS only.
#
#   build/build.sh [version]        e.g. build/build.sh 1.0.0
#
# Output lands in dist/. Downloaded ffmpeg binaries are cached in .cache/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${VERSION:-0.0.0}}"

APP_NAME="WebM to MP4"
FILE_STEM="WebM-to-MP4"
BUNDLE_ID="com.jarediac.webm-to-mp4"
FFMPEG_RELEASE="b6.1.1"   # https://github.com/eugeneware/ffmpeg-static/releases
FFMPEG_BASE="https://github.com/eugeneware/ffmpeg-static/releases/download/$FFMPEG_RELEASE"

DIST="$ROOT/dist"
CACHE="$ROOT/.cache"
APP="$DIST/$APP_NAME.app"
RES="$APP/Contents/Resources"

[ "$(uname)" = Darwin ] || { echo "This build script needs macOS (osacompile, lipo, pkgbuild, hdiutil)." >&2; exit 1; }

rm -rf "$DIST"
mkdir -p "$DIST" "$CACHE"

echo "==> Compiling droplet"
osacompile -o "$APP" "$ROOT/src/droplet.applescript"

echo "==> Fetching static ffmpeg ($FFMPEG_RELEASE) for arm64 and x64"
for arch in arm64 x64; do
  for f in "ffmpeg-darwin-$arch" "darwin-$arch.LICENSE"; do
    if [ ! -s "$CACHE/$f" ]; then
      curl -fL --retry 3 -o "$CACHE/$f" "$FFMPEG_BASE/$f"
    fi
  done
done

echo "==> Bundling universal ffmpeg + convert.sh"
lipo -create "$CACHE/ffmpeg-darwin-arm64" "$CACHE/ffmpeg-darwin-x64" -output "$RES/ffmpeg"
chmod +x "$RES/ffmpeg"
cp "$ROOT/src/convert.sh" "$RES/convert.sh"
chmod +x "$RES/convert.sh"
cp "$CACHE/darwin-arm64.LICENSE" "$RES/ffmpeg-LICENSE.txt"
lipo -info "$RES/ffmpeg"
"$RES/ffmpeg" -version | head -n 1

echo "==> Setting bundle metadata"
PLIST="$APP/Contents/Info.plist"
setplist() { # key type value
  /usr/libexec/PlistBuddy -c "Set :$1 $3" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :$1 $2 $3" "$PLIST"
}
setplist CFBundleIdentifier string "$BUNDLE_ID"
setplist CFBundleName string "$APP_NAME"
setplist CFBundleDisplayName string "$APP_NAME"
setplist CFBundleShortVersionString string "$VERSION"
setplist CFBundleVersion string "$VERSION"
setplist LSMinimumSystemVersion string "11.0"
setplist NSHumanReadableCopyright string "ffmpeg is GPL; see ffmpeg-LICENSE.txt inside the app."

echo "==> Ad-hoc code signing (no developer certificate; Apple Silicon requires at least this)"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "==> Zipping app (used by install.sh)"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$FILE_STEM.app.zip"

echo "==> Building installer package"
pkgbuild --component "$APP" \
  --install-location /Applications \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  "$DIST/$FILE_STEM.pkg"

echo "==> Building disk image"
STAGE="$DIST/dmg-stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DIST/$FILE_STEM.dmg" >/dev/null
rm -rf "$STAGE"

echo "==> Done"
ls -la "$DIST"
