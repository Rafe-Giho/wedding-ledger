#!/bin/sh
set -eu

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: scripts/create_macos_dmg.sh v1.1.5" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="축의대 장부.app"
APP_PATH="$ROOT/dist/$APP_NAME"
DMG_PATH="$ROOT/dist/wedding-ledger-${VERSION}-macOS.dmg"
STAGING_DIR="$ROOT/dist/dmg-staging"

if [ ! -d "$APP_PATH" ]; then
  echo "앱 번들을 찾을 수 없습니다: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "축의대 장부" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
