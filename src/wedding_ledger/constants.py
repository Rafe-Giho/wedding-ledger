APP_NAME = "WeddingLedger"
APP_TITLE = "축의대 장부"

MODE_TEST = "test"
MODE_LIVE = "live"
MODES = (MODE_TEST, MODE_LIVE)
MODE_LABELS = {
    MODE_TEST: "테스트",
    MODE_LIVE: "운영",
}

STATUS_ACTIVE = "active"
STATUS_VOID = "void"
STATUS_LABELS = {
    STATUS_ACTIVE: "정상",
    STATUS_VOID: "취소",
}

PAYMENT_METHODS = {
    "cash": "현금",
    "transfer": "계좌",
    "other": "기타",
}

DEFAULT_GROUP = "미분류"
DEFAULT_QUICK_AMOUNTS = [
    30_000,
    50_000,
    100_000,
    150_000,
    200_000,
    300_000,
    500_000,
    1_000_000,
]

LOCK_AFTER_SECONDS = 5 * 60
