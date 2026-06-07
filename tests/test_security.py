import unittest

from wedding_ledger.security import normalize_keyboard_secret


class SecurityTest(unittest.TestCase):
    def test_normalize_keyboard_secret_maps_hangul_to_qwerty_keys(self) -> None:
        self.assertEqual(normalize_keyboard_secret("비밀번호"), "qlalfqjsgh")
        self.assertEqual(normalize_keyboard_secret("ㅂㅣ밀번호"), "qlalfqjsgh")

    def test_normalize_keyboard_secret_keeps_english_and_numbers(self) -> None:
        self.assertEqual(normalize_keyboard_secret("pass123!"), "pass123!")


if __name__ == "__main__":
    unittest.main()
