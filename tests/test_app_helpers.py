import unittest

from wedding_ledger.app import parse_amount, parse_required_int


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


if __name__ == "__main__":
    unittest.main()
