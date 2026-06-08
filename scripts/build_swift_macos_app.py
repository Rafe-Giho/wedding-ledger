from __future__ import annotations

import os
import plistlib
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_DIR = ROOT / "swift" / "WeddingLedgerSwift"
APP_NAME = "축의대 장부"
EXECUTABLE_NAME = "WeddingLedgerSwift"
APP_VERSION = os.environ.get("APP_VERSION", "1.1.14")
APP_BUILD = os.environ.get("APP_BUILD", "16")
ICON_PATH = ROOT / "assets" / "app-icon" / "WeddingLedger.icns"
DIST_DIR = ROOT / "dist"
APP_DIR = DIST_DIR / f"{APP_NAME}.app"
CONTENTS_DIR = APP_DIR / "Contents"
MACOS_DIR = CONTENTS_DIR / "MacOS"
RESOURCES_DIR = CONTENTS_DIR / "Resources"


def build_release_binary() -> Path:
    env = os.environ.copy()
    env.setdefault("CLANG_MODULE_CACHE_PATH", str(ROOT / ".build" / "clang-module-cache"))
    env.setdefault("SWIFT_MODULE_CACHE_PATH", str(ROOT / ".build" / "swift-module-cache"))
    subprocess.run(
        ["swift", "build", "--package-path", str(PACKAGE_DIR), "-c", "release"],
        check=True,
        env=env,
    )
    candidates = [
        PACKAGE_DIR / ".build" / "release" / EXECUTABLE_NAME,
        *PACKAGE_DIR.glob(".build/*/release/WeddingLedgerSwift"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError("Swift release binary was not created.")


def write_info_plist() -> None:
    payload = {
        "CFBundleDevelopmentRegion": "ko",
        "CFBundleDisplayName": APP_NAME,
        "CFBundleExecutable": EXECUTABLE_NAME,
        "CFBundleIdentifier": "com.local.weddingledger.swift",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleIconFile": "WeddingLedger",
        "CFBundleName": APP_NAME,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": APP_VERSION,
        "CFBundleVersion": APP_BUILD,
        "LSMinimumSystemVersion": "14.0",
        "NSHighResolutionCapable": True,
    }
    with (CONTENTS_DIR / "Info.plist").open("wb") as file:
        plistlib.dump(payload, file)


def sign_app() -> None:
    identity = os.environ.get("CODESIGN_IDENTITY", "-")
    command = ["/usr/bin/codesign", "--force", "--deep"]
    if identity != "-":
        command.extend(["--options", "runtime", "--timestamp"])
    command.extend(["--sign", identity, str(APP_DIR)])
    subprocess.run(command, check=True)
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", str(APP_DIR)], check=True)


def build_app() -> Path:
    binary = build_release_binary()
    if APP_DIR.exists():
        shutil.rmtree(APP_DIR)
    MACOS_DIR.mkdir(parents=True, exist_ok=True)
    RESOURCES_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(binary, MACOS_DIR / EXECUTABLE_NAME)
    os.chmod(MACOS_DIR / EXECUTABLE_NAME, 0o755)
    if ICON_PATH.exists():
        shutil.copy2(ICON_PATH, RESOURCES_DIR / ICON_PATH.name)
    write_info_plist()
    sign_app()
    return APP_DIR


if __name__ == "__main__":
    print(build_app())
