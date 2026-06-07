import tempfile
import unittest
from pathlib import Path

from wedding_ledger.constants import MODE_LIVE, MODE_TEST, STATUS_ACTIVE, STATUS_VOID
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

    def test_lookup_values_fall_back_to_saved_entries(self) -> None:
        self.db.setup_auth("secret123")
        self.db.create_entry(
            {
                "name": "김민수",
                "group_name": "가족",
                "relationship": "사촌",
                "amount": 100000,
                "meal_ticket_count": 1,
                "payment_method": "cash",
            }
        )
        self.db.conn.execute("DELETE FROM lookup_items")
        self.db.conn.commit()

        self.assertIn("가족", self.db.recent_groups())
        self.assertIn("사촌", self.db.recent_relationships())

    def test_lookup_values_survive_reopen(self) -> None:
        app_dir = Path(self.tempdir.name)
        self.db.setup_auth("secret123")
        self.db.create_entry(
            {
                "name": "최유나",
                "group_name": "대학교",
                "relationship": "동기",
                "amount": 100000,
                "meal_ticket_count": 1,
                "payment_method": "cash",
            }
        )
        self.db.close()

        reopened = WeddingLedgerDB(app_dir)
        try:
            self.assertIn("대학교", reopened.recent_groups())
            self.assertIn("동기", reopened.recent_relationships())
        finally:
            reopened.close()
            self.db = WeddingLedgerDB(app_dir)

    def test_duplicate_envelope_is_rejected(self) -> None:
        self.db.setup_auth("secret123")
        payload = {
            "envelope_no": 7,
            "name": "한지민",
            "amount": 50000,
            "meal_ticket_count": 0,
            "payment_method": "cash",
        }
        self.db.create_entry(payload)
        with self.assertRaisesRegex(ValueError, "봉투번호"):
            self.db.create_entry({**payload, "name": "한지민2"})

    def test_search_filters_by_name_group_amount_ticket_and_payment(self) -> None:
        self.db.setup_auth("secret123")
        rows = [
            {
                "name": "강민지",
                "group_name": "회사",
                "amount": 100000,
                "meal_ticket_count": 1,
                "payment_method": "cash",
            },
            {
                "name": "강수연",
                "group_name": "친구",
                "amount": 200000,
                "meal_ticket_count": 2,
                "payment_method": "transfer",
            },
            {
                "name": "이서연",
                "group_name": "회사",
                "amount": 300000,
                "meal_ticket_count": 2,
                "payment_method": "cash",
            },
        ]
        for row in rows:
            self.db.create_entry(row)

        result = self.db.find_entries(
            {
                "name": "강",
                "min_amount": 150000,
                "max_amount": 250000,
                "meal_ticket_count": 2,
                "payment_method": "transfer",
            }
        )
        self.assertEqual([row["name"] for row in result], ["강수연"])

        company_rows = self.db.find_entries({"group_name": "회사", "payment_method": "cash"})
        self.assertEqual({row["name"] for row in company_rows}, {"강민지", "이서연"})

    def test_backup_restore_recovers_previous_state(self) -> None:
        self.db.setup_auth("secret123")
        original = self.db.create_entry(
            {
                "name": "원본",
                "amount": 50000,
                "meal_ticket_count": 1,
                "payment_method": "cash",
            }
        )
        backup = self.db.create_backup("test")
        self.db.update_entry(original["id"], {**original, "amount": 100000}, "복원 테스트")
        self.db.create_entry(
            {
                "name": "추가",
                "amount": 30000,
                "meal_ticket_count": 0,
                "payment_method": "cash",
            }
        )

        before_restore = self.db.restore_from_backup(backup)
        self.assertTrue(before_restore.exists())
        restored_rows = self.db.find_entries({})
        self.assertEqual(len(restored_rows), 1)
        self.assertEqual(restored_rows[0]["name"], "원본")
        self.assertEqual(restored_rows[0]["amount"], 50000)

    def test_backups_do_not_overwrite_within_same_second(self) -> None:
        self.db.setup_auth("secret123")
        first = self.db.create_backup("same_second")
        second = self.db.create_backup("same_second")
        self.assertNotEqual(first, second)
        self.assertTrue(first.exists())
        self.assertTrue(second.exists())

    def test_clear_test_data_does_not_create_backup(self) -> None:
        self.db.setup_auth("secret123")
        self.db.create_entry(
            {
                "name": "테스트",
                "amount": 50000,
                "meal_ticket_count": 0,
                "payment_method": "cash",
            }
        )
        backups_before = list(self.db.backup_dir.glob("*.sqlite3"))
        deleted_count = self.db.clear_test_data()
        backups_after = list(self.db.backup_dir.glob("*.sqlite3"))

        self.assertEqual(deleted_count, 1)
        self.assertEqual(backups_after, backups_before)
        self.assertEqual(self.db.summary()["active_count"], 0)

    def test_clear_records_and_lookups_keeps_auth_settings(self) -> None:
        self.db.setup_auth("secret123")
        self.db.create_entry(
            {
                "name": "운영",
                "group_name": "회사",
                "relationship": "동료",
                "amount": 100000,
                "meal_ticket_count": 1,
                "payment_method": "cash",
            }
        )

        self.db.clear_records_and_lookups()

        self.assertTrue(self.db.is_configured())
        self.assertEqual(self.db.summary()["active_count"], 0)
        self.assertNotIn("회사", self.db.recent_groups())
        self.assertNotIn("동료", self.db.recent_relationships())

    def test_reset_all_data_removes_auth_and_records(self) -> None:
        self.db.setup_auth("secret123")
        self.db.create_entry(
            {
                "name": "전체",
                "group_name": "가족",
                "relationship": "친척",
                "amount": 100000,
                "meal_ticket_count": 1,
                "payment_method": "cash",
            }
        )

        self.db.reset_all_data()

        self.assertFalse(self.db.is_configured())
        self.assertEqual(self.db.summary()["active_count"], 0)
        self.assertEqual(self.db.get_mode(), MODE_TEST)


if __name__ == "__main__":
    unittest.main()
