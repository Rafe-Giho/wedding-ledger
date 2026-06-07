from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import string


PBKDF2_ITERATIONS = 310_000
RECOVERY_KEY_GROUPS = 5
RECOVERY_KEY_GROUP_SIZE = 4
RECOVERY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
CHOSEONG_KEYS = [
    "r",
    "R",
    "s",
    "e",
    "E",
    "f",
    "a",
    "q",
    "Q",
    "t",
    "T",
    "d",
    "w",
    "W",
    "c",
    "z",
    "x",
    "v",
    "g",
]
JUNGSEONG_KEYS = [
    "k",
    "o",
    "i",
    "O",
    "j",
    "p",
    "u",
    "P",
    "h",
    "hk",
    "ho",
    "hl",
    "y",
    "n",
    "nj",
    "np",
    "nl",
    "b",
    "m",
    "ml",
    "l",
]
JONGSEONG_KEYS = [
    "",
    "r",
    "R",
    "rt",
    "s",
    "sw",
    "sg",
    "e",
    "f",
    "fr",
    "fa",
    "fq",
    "ft",
    "fx",
    "fv",
    "fg",
    "a",
    "q",
    "qt",
    "t",
    "T",
    "d",
    "w",
    "c",
    "z",
    "x",
    "v",
    "g",
]
JAMO_KEYS = {
    "ㄱ": "r",
    "ㄲ": "R",
    "ㄳ": "rt",
    "ㄴ": "s",
    "ㄵ": "sw",
    "ㄶ": "sg",
    "ㄷ": "e",
    "ㄸ": "E",
    "ㄹ": "f",
    "ㄺ": "fr",
    "ㄻ": "fa",
    "ㄼ": "fq",
    "ㄽ": "ft",
    "ㄾ": "fx",
    "ㄿ": "fv",
    "ㅀ": "fg",
    "ㅁ": "a",
    "ㅂ": "q",
    "ㅃ": "Q",
    "ㅄ": "qt",
    "ㅅ": "t",
    "ㅆ": "T",
    "ㅇ": "d",
    "ㅈ": "w",
    "ㅉ": "W",
    "ㅊ": "c",
    "ㅋ": "z",
    "ㅌ": "x",
    "ㅍ": "v",
    "ㅎ": "g",
    "ㅏ": "k",
    "ㅐ": "o",
    "ㅑ": "i",
    "ㅒ": "O",
    "ㅓ": "j",
    "ㅔ": "p",
    "ㅕ": "u",
    "ㅖ": "P",
    "ㅗ": "h",
    "ㅘ": "hk",
    "ㅙ": "ho",
    "ㅚ": "hl",
    "ㅛ": "y",
    "ㅜ": "n",
    "ㅝ": "nj",
    "ㅞ": "np",
    "ㅟ": "nl",
    "ㅠ": "b",
    "ㅡ": "m",
    "ㅢ": "ml",
    "ㅣ": "l",
}


def _b64encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii")


def _b64decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value.encode("ascii"))


def generate_salt() -> str:
    return _b64encode(secrets.token_bytes(24))


def normalize_recovery_key(value: str) -> str:
    allowed = set(string.ascii_letters + string.digits)
    return "".join(ch for ch in value.upper() if ch in allowed)


def normalize_keyboard_secret(value: str) -> str:
    normalized: list[str] = []
    for char in value:
        code = ord(char)
        if 0xAC00 <= code <= 0xD7A3:
            offset = code - 0xAC00
            choseong = offset // 588
            jungseong = (offset % 588) // 28
            jongseong = offset % 28
            normalized.append(CHOSEONG_KEYS[choseong])
            normalized.append(JUNGSEONG_KEYS[jungseong])
            normalized.append(JONGSEONG_KEYS[jongseong])
            continue
        normalized.append(JAMO_KEYS.get(char, char))
    return "".join(normalized)


def hash_secret(secret: str, salt: str, iterations: int = PBKDF2_ITERATIONS) -> str:
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        secret.encode("utf-8"),
        _b64decode(salt),
        iterations,
    )
    return _b64encode(digest)


def verify_secret(secret: str, salt: str, expected_hash: str, iterations: int) -> bool:
    actual = hash_secret(secret, salt, iterations)
    return hmac.compare_digest(actual, expected_hash)


def generate_recovery_key() -> str:
    groups: list[str] = []
    for _ in range(RECOVERY_KEY_GROUPS):
        groups.append(
            "".join(secrets.choice(RECOVERY_ALPHABET) for _ in range(RECOVERY_KEY_GROUP_SIZE))
        )
    return "-".join(groups)
