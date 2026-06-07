from __future__ import annotations

import os
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_NAME = "축의대 장부"
EXECUTABLE_NAME = "WeddingLedger"
LEGACY_APP_NAME = "WeddingLedger"
DIST_DIR = ROOT / "dist"
APP_DIR = DIST_DIR / f"{APP_NAME}.app"
LEGACY_APP_DIR = DIST_DIR / f"{LEGACY_APP_NAME}.app"
CONTENTS_DIR = APP_DIR / "Contents"
MACOS_DIR = CONTENTS_DIR / "MacOS"
RESOURCES_DIR = CONTENTS_DIR / "Resources"
APP_RESOURCES_DIR = RESOURCES_DIR / "app"


def ignore_generated(_directory: str, names: list[str]) -> set[str]:
    ignored = {"__pycache__", ".pytest_cache", ".mypy_cache"}
    return {name for name in names if name in ignored or name.endswith((".pyc", ".pyo"))}


def write_info_plist() -> None:
    plist = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>ko</string>
  <key>CFBundleDisplayName</key>
  <string>축의대 장부</string>
  <key>CFBundleExecutable</key>
  <string>WeddingLedger</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.weddingledger</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>축의대 장부</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
"""
    (CONTENTS_DIR / "Info.plist").write_text(plist, encoding="utf-8")


def write_launcher() -> None:
    launcher = """#!/bin/sh
set -eu

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SOURCE="$APP_ROOT/Resources/app"

PYTHON_BIN="${PYTHON3:-}"
if [ -z "$PYTHON_BIN" ]; then
  for candidate in \
    /Library/Frameworks/Python.framework/Versions/3.11/bin/python3 \
    /opt/homebrew/bin/python3 \
    /usr/local/bin/python3 \
    /usr/bin/python3
  do
    if [ -x "$candidate" ]; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "$PYTHON_BIN" ]; then
  osascript -e 'display dialog "축의대 장부 실행에는 Python 3가 필요합니다." buttons {"확인"} default button 1' >/dev/null 2>&1 || true
  exit 1
fi

cd "$APP_SOURCE"
exec "$PYTHON_BIN" run.py
"""
    launcher_path = MACOS_DIR / EXECUTABLE_NAME
    launcher_path.write_text(launcher, encoding="utf-8")
    os.chmod(launcher_path, 0o755)


def copy_app_sources() -> None:
    APP_RESOURCES_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "run.py", APP_RESOURCES_DIR / "run.py")
    shutil.copytree(ROOT / "src", APP_RESOURCES_DIR / "src", ignore=ignore_generated)
    shutil.copy2(ROOT / "README.md", APP_RESOURCES_DIR / "README.md")


def build() -> Path:
    if APP_DIR.exists():
        shutil.rmtree(APP_DIR)
    if LEGACY_APP_DIR.exists():
        shutil.rmtree(LEGACY_APP_DIR)
    MACOS_DIR.mkdir(parents=True, exist_ok=True)
    RESOURCES_DIR.mkdir(parents=True, exist_ok=True)
    copy_app_sources()
    write_info_plist()
    write_launcher()
    return APP_DIR


if __name__ == "__main__":
    app_path = build()
    print(app_path)
