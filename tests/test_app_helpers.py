import unittest

from wedding_ledger.app import is_digits_or_empty, parse_amount, parse_required_int, validate_password


class AppHelperTest(unittest.TestCase):
    def test_parse_amount_accepts_commas_and_won_text(self) -> None:
        self.assertEqual(parse_amount("100,000원"), 100000)
        self.assertEqual(parse_amount(" 50,000 "), 50000)

    def test_parse_required_int_rejects_invalid_text(self) -> None:
        with self.assertRaisesRegex(ValueError, "식권 수"):
            parse_required_int("한장", "식권 수", 0)

    def test_parse_required_int_rejects_value_below_minimum(self) -> None:
        with self.assertRaisesRegex(ValueError, "봉투번호"):
            parse_required_int("0", "봉투번호", 1)

    def test_digits_only_validator_allows_only_digits_or_empty(self) -> None:
        self.assertTrue(is_digits_or_empty(""))
        self.assertTrue(is_digits_or_empty("100000"))
        self.assertFalse(is_digits_or_empty("100,000"))
        self.assertFalse(is_digits_or_empty("십만원"))

    def test_validate_password_requires_min_length(self) -> None:
        validate_password("abcd")
        validate_password("비번12")
        with self.assertRaisesRegex(ValueError, "4자"):
            validate_password("123")


if __name__ == "__main__":
    unittest.main()
