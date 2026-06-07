#!/bin/sh
set -eu

VERSION="${WEDDING_LEDGER_VERSION:-v1.1.7}"
REPO="Rafe-Giho/wedding-ledger"
case "$VERSION" in
  v*) TAG="$VERSION" ;;
  *) TAG="v$VERSION" ;;
esac
ASSET="wedding-ledger-${TAG}-macOS.zip"
URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
INSTALL_DIR="${WEDDING_LEDGER_INSTALL_DIR:-$HOME/Applications}"
APP_NAME="축의대 장부.app"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "축의대 장부 ${VERSION} 설치를 시작합니다."
mkdir -p "$INSTALL_DIR"

curl -L --fail --progress-bar "$URL" -o "$TMP_DIR/$ASSET"
ditto -x -k "$TMP_DIR/$ASSET" "$TMP_DIR"

if [ ! -d "$TMP_DIR/$APP_NAME" ]; then
  echo "앱 번들을 찾을 수 없습니다: $TMP_DIR/$APP_NAME" >&2
  exit 1
fi

rm -rf "$INSTALL_DIR/$APP_NAME"
ditto "$TMP_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME"
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true
codesign --verify --deep --strict --verbose=2 "$INSTALL_DIR/$APP_NAME"

echo "설치 완료: $INSTALL_DIR/$APP_NAME"

if [ "${WEDDING_LEDGER_SKIP_OPEN:-0}" = "1" ]; then
  echo "앱 실행은 건너뜁니다."
else
  open "$INSTALL_DIR/$APP_NAME"
fi
