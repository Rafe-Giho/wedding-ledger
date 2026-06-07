from __future__ import annotations

import json
import os
import shutil
import sqlite3
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from .constants import (
    APP_NAME,
    DEFAULT_GROUP,
    MODE_LIVE,
    MODE_TEST,
    MODES,
    PAYMENT_METHODS,
    STATUS_ACTIVE,
    STATUS_VOID,
)
from .security import (
    PBKDF2_ITERATIONS,
    generate_recovery_key,
    generate_salt,
    hash_secret,
    normalize_recovery_key,
    verify_secret,
)


def now_iso() -> str:
    return datetime.now().replace(microsecond=0).isoformat(sep=" ")


def default_app_dir() -> Path:
    override = os.environ.get("WEDDING_LEDGER_HOME")
    if override:
        return Path(override).expanduser()
    return Path.home() / "Library" / "Application Support" / APP_NAME


def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return dict(row)


class WeddingLedgerDB:
    def __init__(self, app_dir: Path | str | None = None) -> None:
        self.app_dir = Path(app_dir) if app_dir else default_app_dir()
        self.app_dir.mkdir(parents=True, exist_ok=True)
        try:
            os.chmod(self.app_dir, 0o700)
        except OSError:
            pass
        self.db_path = self.app_dir / "wedding_ledger.sqlite3"
        self.backup_dir = self.app_dir / "backups"
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.conn = self._connect()
        self._initialize()
        self._secure_db_file()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA journal_mode = WAL")
        return conn

    def _secure_db_file(self) -> None:
        if self.db_path.exists():
            try:
                os.chmod(self.db_path, 0o600)
            except OSError:
                pass

    def close(self) -> None:
        self.conn.close()

    def _initialize(self) -> None:
        self.conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                mode TEXT NOT NULL CHECK (mode IN ('test', 'live')),
                envelope_no INTEGER NOT NULL,
                name TEXT NOT NULL,
                group_name TEXT NOT NULL DEFAULT '미분류',
                relationship TEXT DEFAULT '',
                amount INTEGER NOT NULL CHECK (amount > 0),
                meal_ticket_count INTEGER NOT NULL DEFAULT 0 CHECK (meal_ticket_count >= 0),
                payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'transfer', 'other')),
                memo TEXT DEFAULT '',
                status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'void')),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(mode, envelope_no)
            );

            CREATE INDEX IF NOT EXISTS idx_entries_name ON entries(name);
            CREATE INDEX IF NOT EXISTS idx_entries_group_name ON entries(group_name);
            CREATE INDEX IF NOT EXISTS idx_entries_amount ON entries(amount);
            CREATE INDEX IF NOT EXISTS idx_entries_status ON entries(status);
            CREATE INDEX IF NOT EXISTS idx_entries_mode ON entries(mode);

            CREATE TABLE IF NOT EXISTS lookup_items (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL CHECK (kind IN ('group', 'relationship')),
                value TEXT NOT NULL,
                usage_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(kind, value)
            );

            CREATE INDEX IF NOT EXISTS idx_lookup_items_kind ON lookup_items(kind);

            CREATE TABLE IF NOT EXISTS audit_logs (
                id TEXT PRIMARY KEY,
                entry_id TEXT,
                action TEXT NOT NULL,
                before_json TEXT,
                after_json TEXT,
                reason TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                FOREIGN KEY(entry_id) REFERENCES entries(id)
            );
            """
        )
        if self.get_setting("schema_version") is None:
            self.set_setting("schema_version", "1")
        if self.get_setting("current_mode") is None:
            self.set_setting("current_mode", MODE_TEST)
        self._seed_lookup_items_from_entries()
        self.conn.commit()

    def get_setting(self, key: str) -> str | None:
        row = self.conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
        return row["value"] if row else None

    def set_setting(self, key: str, value: str) -> None:
        self.conn.execute(
            """
            INSERT INTO settings(key, value)
            VALUES(?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            """,
            (key, value),
        )
        self.conn.commit()

    def is_configured(self) -> bool:
        return self.get_setting("password_hash") is not None

    def setup_auth(self, password: str) -> str:
        if self.is_configured():
            raise ValueError("이미 비밀번호가 설정되어 있습니다.")
        if len(password) < 6:
            raise ValueError("비밀번호는 6자 이상이어야 합니다.")

        password_salt = generate_salt()
        recovery_salt = generate_salt()
        recovery_key = generate_recovery_key()
        normalized_recovery_key = normalize_recovery_key(recovery_key)

        self.set_setting("password_salt", password_salt)
        self.set_setting("password_hash", hash_secret(password, password_salt))
        self.set_setting("password_iterations", str(PBKDF2_ITERATIONS))
        self.set_setting("recovery_salt", recovery_salt)
        self.set_setting("recovery_hash", hash_secret(normalized_recovery_key, recovery_salt))
        self.set_setting("recovery_iterations", str(PBKDF2_ITERATIONS))
        self.set_setting("configured_at", now_iso())
        return recovery_key

    def verify_password(self, password: str) -> bool:
        salt = self.get_setting("password_salt")
        expected = self.get_setting("password_hash")
        iterations = int(self.get_setting("password_iterations") or PBKDF2_ITERATIONS)
        if not salt or not expected:
            return False
        return verify_secret(password, salt, expected, iterations)

    def reset_password_with_recovery(self, recovery_key: str, new_password: str) -> bool:
        if len(new_password) < 6:
            raise ValueError("새 비밀번호는 6자 이상이어야 합니다.")
        salt = self.get_setting("recovery_salt")
        expected = self.get_setting("recovery_hash")
        iterations = int(self.get_setting("recovery_iterations") or PBKDF2_ITERATIONS)
        if not salt or not expected:
            return False
        normalized = normalize_recovery_key(recovery_key)
        if not verify_secret(normalized, salt, expected, iterations):
            return False
        password_salt = generate_salt()
        self.set_setting("password_salt", password_salt)
        self.set_setting("password_hash", hash_secret(new_password, password_salt))
        self.set_setting("password_iterations", str(PBKDF2_ITERATIONS))
        self.set_setting("password_reset_at", now_iso())
        return True

    def change_password(self, current_password: str, new_password: str) -> bool:
        if not self.verify_password(current_password):
            return False
        if len(new_password) < 6:
            raise ValueError("새 비밀번호는 6자 이상이어야 합니다.")
        password_salt = generate_salt()
        self.set_setting("password_salt", password_salt)
        self.set_setting("password_hash", hash_secret(new_password, password_salt))
        self.set_setting("password_iterations", str(PBKDF2_ITERATIONS))
        self.set_setting("password_changed_at", now_iso())
        return True

    def get_mode(self) -> str:
        mode = self.get_setting("current_mode") or MODE_TEST
        return mode if mode in MODES else MODE_TEST

    def set_mode(self, mode: str) -> None:
        if mode not in MODES:
            raise ValueError("지원하지 않는 모드입니다.")
        self.set_setting("current_mode", mode)

    def _seed_lookup_items_from_entries(self) -> None:
        self.add_lookup_value("group", DEFAULT_GROUP, increment=False)
        rows = self.conn.execute(
            """
            SELECT 'group' AS kind, group_name AS value FROM entries WHERE group_name != ''
            UNION
            SELECT 'relationship' AS kind, relationship AS value FROM entries WHERE relationship != ''
            """
        ).fetchall()
        for row in rows:
            self.add_lookup_value(row["kind"], row["value"], increment=False)

    def add_lookup_value(self, kind: str, value: str, increment: bool = True) -> None:
        if kind not in ("group", "relationship"):
            raise ValueError("지원하지 않는 목록 종류입니다.")
        clean_value = str(value or "").strip()
        if not clean_value:
            return
        timestamp = now_iso()
        usage_increment = 1 if increment else 0
        self.conn.execute(
            """
            INSERT INTO lookup_items(id, kind, value, usage_count, created_at, updated_at)
            VALUES(?, ?, ?, ?, ?, ?)
            ON CONFLICT(kind, value) DO UPDATE SET
                usage_count = lookup_items.usage_count + ?,
                updated_at = excluded.updated_at
            """,
            (
                str(uuid.uuid4()),
                kind,
                clean_value,
                usage_increment,
                timestamp,
                timestamp,
                usage_increment,
            ),
        )

    def remember_entry_lookup_values(self, data: dict[str, Any]) -> None:
        self.add_lookup_value("group", data.get("group_name") or DEFAULT_GROUP)
        self.add_lookup_value("relationship", data.get("relationship") or "")

    def lookup_values(self, kind: str, limit: int = 50) -> list[str]:
        if kind not in ("group", "relationship"):
            raise ValueError("지원하지 않는 목록 종류입니다.")
        rows = self.conn.execute(
            """
            SELECT value
            FROM lookup_items
            WHERE kind = ?
            ORDER BY usage_count DESC, updated_at DESC, value ASC
            LIMIT ?
            """,
            (kind, limit),
        ).fetchall()
        values = [row["value"] for row in rows]
        if kind == "group" and DEFAULT_GROUP not in values:
            values.insert(0, DEFAULT_GROUP)
        return values

    def next_envelope_no(self, mode: str | None = None) -> int:
        mode = mode or self.get_mode()
        row = self.conn.execute(
            "SELECT COALESCE(MAX(envelope_no), 0) + 1 AS next_no FROM entries WHERE mode = ?",
            (mode,),
        ).fetchone()
        return int(row["next_no"])

    def name_exists(self, mode: str, name: str, exclude_id: str | None = None) -> bool:
        params: list[Any] = [mode, name.strip(), STATUS_ACTIVE]
        sql = """
            SELECT 1 FROM entries
            WHERE mode = ? AND name = ? AND status = ?
        """
        if exclude_id:
            sql += " AND id != ?"
            params.append(exclude_id)
        return self.conn.execute(sql, params).fetchone() is not None

    def _validate_entry_data(self, data: dict[str, Any]) -> dict[str, Any]:
        mode = data.get("mode") or self.get_mode()
        if mode not in MODES:
            raise ValueError("지원하지 않는 모드입니다.")
        name = str(data.get("name", "")).strip()
        if not name:
            raise ValueError("이름은 필수입니다.")
        amount = int(data.get("amount") or 0)
        if amount <= 0:
            raise ValueError("금액은 0원보다 커야 합니다.")
        meal_ticket_count = int(data.get("meal_ticket_count") or 0)
        if meal_ticket_count < 0:
            raise ValueError("식권 수는 0 이상이어야 합니다.")
        payment_method = data.get("payment_method") or "cash"
        if payment_method not in PAYMENT_METHODS:
            raise ValueError("지원하지 않는 입금방식입니다.")
        envelope_no = int(data.get("envelope_no") or self.next_envelope_no(mode))
        if envelope_no <= 0:
            raise ValueError("봉투번호는 1 이상이어야 합니다.")

        return {
            "mode": mode,
            "envelope_no": envelope_no,
            "name": name,
            "group_name": str(data.get("group_name") or DEFAULT_GROUP).strip() or DEFAULT_GROUP,
            "relationship": str(data.get("relationship") or "").strip(),
            "amount": amount,
            "meal_ticket_count": meal_ticket_count,
            "payment_method": payment_method,
            "memo": str(data.get("memo") or "").strip(),
        }

    def _insert_audit(
        self,
        entry_id: str | None,
        action: str,
        before: dict[str, Any] | None,
        after: dict[str, Any] | None,
        reason: str = "",
    ) -> None:
        self.conn.execute(
            """
            INSERT INTO audit_logs(id, entry_id, action, before_json, after_json, reason, created_at)
            VALUES(?, ?, ?, ?, ?, ?, ?)
            """,
            (
                str(uuid.uuid4()),
                entry_id,
                action,
                json.dumps(before, ensure_ascii=False) if before else None,
                json.dumps(after, ensure_ascii=False) if after else None,
                reason,
                now_iso(),
            ),
        )

    def create_entry(self, data: dict[str, Any]) -> dict[str, Any]:
        clean = self._validate_entry_data(data)
        entry_id = str(uuid.uuid4())
        created_at = now_iso()
        try:
            self.conn.execute(
                """
                INSERT INTO entries (
                    id, mode, envelope_no, name, group_name, relationship, amount,
                    meal_ticket_count, payment_method, memo, status, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    entry_id,
                    clean["mode"],
                    clean["envelope_no"],
                    clean["name"],
                    clean["group_name"],
                    clean["relationship"],
                    clean["amount"],
                    clean["meal_ticket_count"],
                    clean["payment_method"],
                    clean["memo"],
                    STATUS_ACTIVE,
                    created_at,
                    created_at,
                ),
            )
        except sqlite3.IntegrityError as exc:
            raise ValueError("봉투번호가 이미 사용되었습니다.") from exc
        entry = self.get_entry(entry_id)
        self.remember_entry_lookup_values(clean)
        self._insert_audit(entry_id, "create", None, entry)
        self.conn.commit()
        return entry or {}

    def get_entry(self, entry_id: str) -> dict[str, Any] | None:
        row = self.conn.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
        return row_to_dict(row)

    def update_entry(self, entry_id: str, updates: dict[str, Any], reason: str = "") -> dict[str, Any]:
        before = self.get_entry(entry_id)
        if not before:
            raise ValueError("기록을 찾을 수 없습니다.")
        clean = self._validate_entry_data({**before, **updates})
        updated_at = now_iso()
        try:
            self.conn.execute(
                """
                UPDATE entries
                SET mode = ?, envelope_no = ?, name = ?, group_name = ?, relationship = ?,
                    amount = ?, meal_ticket_count = ?, payment_method = ?, memo = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                (
                    clean["mode"],
                    clean["envelope_no"],
                    clean["name"],
                    clean["group_name"],
                    clean["relationship"],
                    clean["amount"],
                    clean["meal_ticket_count"],
                    clean["payment_method"],
                    clean["memo"],
                    updated_at,
                    entry_id,
                ),
            )
        except sqlite3.IntegrityError as exc:
            raise ValueError("봉투번호가 이미 사용되었습니다.") from exc
        after = self.get_entry(entry_id)
        self.remember_entry_lookup_values(clean)
        self._insert_audit(entry_id, "update", before, after, reason)
        self.conn.commit()
        return after or {}

    def void_entry(self, entry_id: str, reason: str = "") -> dict[str, Any]:
        before = self.get_entry(entry_id)
        if not before:
            raise ValueError("기록을 찾을 수 없습니다.")
        self.conn.execute(
            "UPDATE entries SET status = ?, updated_at = ? WHERE id = ?",
            (STATUS_VOID, now_iso(), entry_id),
        )
        after = self.get_entry(entry_id)
        self._insert_audit(entry_id, "void", before, after, reason)
        self.conn.commit()
        return after or {}

    def restore_entry(self, entry_id: str, reason: str = "") -> dict[str, Any]:
        before = self.get_entry(entry_id)
        if not before:
            raise ValueError("기록을 찾을 수 없습니다.")
        self.conn.execute(
            "UPDATE entries SET status = ?, updated_at = ? WHERE id = ?",
            (STATUS_ACTIVE, now_iso(), entry_id),
        )
        after = self.get_entry(entry_id)
        self._insert_audit(entry_id, "restore", before, after, reason)
        self.conn.commit()
        return after or {}

    def find_entries(self, filters: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        filters = filters or {}
        clauses: list[str] = []
        params: list[Any] = []

        mode = filters.get("mode")
        if mode in MODES:
            clauses.append("mode = ?")
            params.append(mode)

        status = filters.get("status")
        if status in (STATUS_ACTIVE, STATUS_VOID):
            clauses.append("status = ?")
            params.append(status)

        name = str(filters.get("name") or "").strip()
        if name:
            clauses.append("name LIKE ?")
            params.append(f"%{name}%")

        group_name = str(filters.get("group_name") or "").strip()
        if group_name:
            clauses.append("group_name LIKE ?")
            params.append(f"%{group_name}%")

        payment_method = filters.get("payment_method")
        if payment_method in PAYMENT_METHODS:
            clauses.append("payment_method = ?")
            params.append(payment_method)

        min_amount = filters.get("min_amount")
        if min_amount not in (None, ""):
            clauses.append("amount >= ?")
            params.append(int(min_amount))

        max_amount = filters.get("max_amount")
        if max_amount not in (None, ""):
            clauses.append("amount <= ?")
            params.append(int(max_amount))

        ticket_count = filters.get("meal_ticket_count")
        if ticket_count not in (None, ""):
            clauses.append("meal_ticket_count = ?")
            params.append(int(ticket_count))

        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        rows = self.conn.execute(
            f"""
            SELECT * FROM entries
            {where}
            ORDER BY mode DESC, envelope_no ASC, created_at ASC
            """,
            params,
        ).fetchall()
        return [dict(row) for row in rows]

    def recent_groups(self, limit: int = 20) -> list[str]:
        return self.lookup_values("group", limit)

    def recent_relationships(self, limit: int = 20) -> list[str]:
        return self.lookup_values("relationship", limit)

    def last_entries(self, mode: str, limit: int = 10) -> list[dict[str, Any]]:
        rows = self.conn.execute(
            """
            SELECT * FROM entries
            WHERE mode = ?
            ORDER BY created_at DESC, envelope_no DESC
            LIMIT ?
            """,
            (mode, limit),
        ).fetchall()
        return [dict(row) for row in rows]

    def summary(self, mode: str | None = None) -> dict[str, Any]:
        mode = mode or self.get_mode()
        rows = self.find_entries({"mode": mode})
        active = [row for row in rows if row["status"] == STATUS_ACTIVE]
        void = [row for row in rows if row["status"] == STATUS_VOID]
        payment_totals = {key: 0 for key in PAYMENT_METHODS}
        for row in active:
            payment_totals[row["payment_method"]] += int(row["amount"])

        group_rows = self.conn.execute(
            """
            SELECT group_name,
                   COUNT(*) AS count,
                   SUM(amount) AS total_amount,
                   SUM(meal_ticket_count) AS total_tickets
            FROM entries
            WHERE mode = ? AND status = ?
            GROUP BY group_name
            ORDER BY total_amount DESC, group_name ASC
            """,
            (mode, STATUS_ACTIVE),
        ).fetchall()

        duplicate_rows = self.conn.execute(
            """
            SELECT name, COUNT(*) AS count
            FROM entries
            WHERE mode = ? AND status = ?
            GROUP BY name
            HAVING COUNT(*) > 1
            ORDER BY count DESC, name ASC
            """,
            (mode, STATUS_ACTIVE),
        ).fetchall()

        envelope_numbers = sorted(int(row["envelope_no"]) for row in rows)
        gaps: list[int] = []
        if envelope_numbers:
            existing = set(envelope_numbers)
            gaps = [num for num in range(min(existing), max(existing) + 1) if num not in existing]

        return {
            "mode": mode,
            "active_count": len(active),
            "void_count": len(void),
            "total_amount": sum(int(row["amount"]) for row in active),
            "total_tickets": sum(int(row["meal_ticket_count"]) for row in active),
            "payment_totals": payment_totals,
            "group_totals": [dict(row) for row in group_rows],
            "duplicate_names": [dict(row) for row in duplicate_rows],
            "envelope_gaps": gaps,
        }

    def audit_rows(self) -> list[dict[str, Any]]:
        rows = self.conn.execute(
            """
            SELECT audit_logs.*, entries.envelope_no, entries.name
            FROM audit_logs
            LEFT JOIN entries ON entries.id = audit_logs.entry_id
            ORDER BY audit_logs.created_at ASC
            """
        ).fetchall()
        return [dict(row) for row in rows]

    def create_backup(self, label: str = "auto") -> Path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        safe_label = "".join(ch for ch in label if ch.isalnum() or ch in ("_", "-")) or "auto"
        target = self.backup_dir / f"wedding_ledger_{safe_label}_{timestamp}.sqlite3"
        self.conn.commit()
        self.conn.execute("PRAGMA wal_checkpoint(FULL)")
        shutil.copy2(self.db_path, target)
        try:
            os.chmod(target, 0o600)
        except OSError:
            pass
        return target

    def _remove_wal_files(self) -> None:
        for suffix in ("-wal", "-shm"):
            path = Path(f"{self.db_path}{suffix}")
            if path.exists():
                path.unlink()

    def restore_from_backup(self, backup_path: Path | str) -> Path:
        backup_path = Path(backup_path)
        if not backup_path.exists():
            raise ValueError("백업 파일을 찾을 수 없습니다.")
        before_restore = self.create_backup("before_restore")
        self.conn.close()
        self._remove_wal_files()
        shutil.copy2(backup_path, self.db_path)
        self.conn = self._connect()
        self._initialize()
        self._secure_db_file()
        return before_restore

    def clear_test_data(self) -> Path:
        backup = self.create_backup("before_clear_test")
        test_ids = [row["id"] for row in self.conn.execute("SELECT id FROM entries WHERE mode = ?", (MODE_TEST,))]
        if test_ids:
            placeholders = ",".join("?" for _ in test_ids)
            self.conn.execute(f"DELETE FROM audit_logs WHERE entry_id IN ({placeholders})", test_ids)
        self.conn.execute("DELETE FROM entries WHERE mode = ?", (MODE_TEST,))
        self.conn.commit()
        return backup
