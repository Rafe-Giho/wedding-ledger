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


def _b64encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii")


def _b64decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value.encode("ascii"))


def generate_salt() -> str:
    return _b64encode(secrets.token_bytes(24))


def normalize_recovery_key(value: str) -> str:
    allowed = set(string.ascii_letters + string.digits)
    return "".join(ch for ch in value.upper() if ch in allowed)


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
