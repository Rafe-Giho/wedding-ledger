import tempfile
import unittest
from pathlib import Path
from xml.etree import ElementTree

from wedding_ledger.excel_export import export_xls
from wedding_ledger.storage import WeddingLedgerDB


class ExcelExportTest(unittest.TestCase):
    def test_export_contains_required_sheets_and_formulas(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            db = WeddingLedgerDB(Path(temp) / "app")
            db.setup_auth("secret123")
            db.create_entry(
                {
                    "name": "이민지",
                    "group_name": "친구",
                    "amount": 100000,
                    "meal_ticket_count": 1,
                    "payment_method": "cash",
                }
            )
            path = export_xls(
                Path(temp) / "export.xls",
                db.find_entries({}),
                db.summary(),
                db.audit_rows(),
            )
            text = path.read_text(encoding="utf-8")
            self.assertIn('ss:Name="전체내역"', text)
            self.assertIn('ss:Name="요약"', text)
            self.assertIn('ss:Name="모임별"', text)
            self.assertIn('ss:Name="검색용"', text)
            self.assertIn('ss:Name="수정이력"', text)
            self.assertIn("SUMIF", text)
            self.assertIn("COUNTIF", text)
            ElementTree.fromstring(text)
            db.close()


if __name__ == "__main__":
    unittest.main()
