import tempfile
import unittest
from pathlib import Path

from wedding_ledger.constants import MODE_LIVE, STATUS_ACTIVE, STATUS_VOID
from wedding_ledger.storage import WeddingLedgerDB


class StorageTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.db = WeddingLedgerDB(Path(self.tempdir.name))

    def tearDown(self) -> None:
        self.db.close()
        self.tempdir.cleanup()

    def test_auth_recovery_and_entry_flow(self) -> None:
        recovery = self.db.setup_auth("secret123")
        self.assertTrue(self.db.verify_password("secret123"))
        self.assertFalse(self.db.verify_password("wrong"))
        self.assertTrue(self.db.reset_password_with_recovery(recovery, "newsecret"))
        self.assertTrue(self.db.verify_password("newsecret"))

        self.db.set_mode(MODE_LIVE)
        entry = self.db.create_entry(
            {
                "name": "김하나",
                "group_name": "회사",
                "relationship": "동료",
                "amount": 100000,
                "meal_ticket_count": 2,
                "payment_method": "cash",
                "memo": "테스트",
            }
        )
        self.assertEqual(entry["envelope_no"], 1)
        self.assertEqual(entry["status"], STATUS_ACTIVE)

        updated = self.db.update_entry(entry["id"], {**entry, "amount": 150000}, "금액 정정")
        self.assertEqual(updated["amount"], 150000)

        voided = self.db.void_entry(entry["id"], "오입력")
        self.assertEqual(voided["status"], STATUS_VOID)

        restored = self.db.restore_entry(entry["id"], "정상 복구")
        self.assertEqual(restored["status"], STATUS_ACTIVE)

        summary = self.db.summary(MODE_LIVE)
        self.assertEqual(summary["active_count"], 1)
        self.assertEqual(summary["total_amount"], 150000)
        self.assertEqual(summary["total_tickets"], 2)
        self.assertEqual(summary["payment_totals"]["cash"], 150000)
        self.assertIn("회사", self.db.recent_groups())
        self.assertIn("동료", self.db.recent_relationships())
        self.assertGreaterEqual(len(self.db.audit_rows()), 4)

    def test_lookup_values_are_saved_from_entries(self) -> None:
        self.db.setup_auth("secret123")
        self.db.create_entry(
            {
                "name": "박수진",
                "group_name": "신부친구",
                "relationship": "고등학교",
                "amount": 100000,
                "meal_ticket_count": 1,
                "payment_method": "cash",
            }
        )
        self.assertIn("신부친구", self.db.recent_groups())
        self.assertIn("고등학교", self.db.recent_relationships())

    def test_backup_and_clear_test_data(self) -> None:
        self.db.setup_auth("secret123")
        self.db.create_entry(
            {
                "name": "테스트",
                "amount": 50000,
                "meal_ticket_count": 0,
                "payment_method": "cash",
            }
        )
        backup = self.db.clear_test_data()
        self.assertTrue(backup.exists())
        self.assertEqual(self.db.summary()["active_count"], 0)


if __name__ == "__main__":
    unittest.main()
