from __future__ import annotations

import json
import mimetypes
import secrets
import tempfile
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from .constants import MODE_LABELS, MODE_LIVE, MODE_TEST, PAYMENT_METHODS, STATUS_ACTIVE, STATUS_VOID
from .excel_export import export_xls
from .storage import WeddingLedgerDB


STATIC_DIR = Path(__file__).resolve().parent / "web_static"
HOST = "127.0.0.1"


def digits_to_int(value: object) -> int:
    return int("".join(ch for ch in str(value or "") if ch.isdigit()) or 0)


def public_entry(entry: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": entry["id"],
        "mode": entry["mode"],
        "envelopeNo": entry["envelope_no"],
        "name": entry["name"],
        "groupName": entry["group_name"],
        "relationship": entry["relationship"],
        "amount": int(entry["amount"]),
        "mealTicketCount": int(entry["meal_ticket_count"]),
        "paymentMethod": entry["payment_method"],
        "paymentLabel": PAYMENT_METHODS.get(entry["payment_method"], entry["payment_method"]),
        "status": entry["status"],
        "createdAt": entry["created_at"],
        "updatedAt": entry["updated_at"],
        "memo": entry["memo"],
    }


def public_summary(summary: dict[str, Any]) -> dict[str, Any]:
    return {
        "mode": summary["mode"],
        "activeCount": summary["active_count"],
        "voidCount": summary["void_count"],
        "totalAmount": summary["total_amount"],
        "totalTickets": summary["total_tickets"],
        "paymentTotals": summary["payment_totals"],
        "groupTotals": summary["group_totals"],
        "duplicateNames": summary["duplicate_names"],
        "envelopeGaps": summary["envelope_gaps"],
    }


class LedgerHTTPServer(HTTPServer):
    def __init__(self, server_address: tuple[str, int], handler_class: type[BaseHTTPRequestHandler]) -> None:
        super().__init__(server_address, handler_class)
        self.db = WeddingLedgerDB()
        self.sessions: set[str] = set()


class LedgerRequestHandler(BaseHTTPRequestHandler):
    server: LedgerHTTPServer

    def log_message(self, _format: str, *args: object) -> None:
        return

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            self.send_static("index.html")
            return
        if parsed.path.startswith("/static/"):
            self.send_static(parsed.path.removeprefix("/static/"))
            return
        if parsed.path == "/api/state":
            self.require_state()
            return
        if parsed.path == "/api/entries":
            self.require_entries(parsed.query)
            return
        if parsed.path == "/api/export":
            self.require_export()
            return
        self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        routes = {
            "/api/setup": self.handle_setup,
            "/api/login": self.handle_login,
            "/api/lock": self.handle_lock,
            "/api/entry": self.handle_create_entry,
            "/api/mode": self.handle_mode,
            "/api/theme": self.handle_theme,
            "/api/reset/test": self.handle_reset_test,
            "/api/reset/records": self.handle_reset_records,
            "/api/reset/all": self.handle_reset_all,
            "/api/void": self.handle_void,
            "/api/restore": self.handle_restore,
        }
        handler = routes.get(parsed.path)
        if not handler:
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        handler()

    def read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0") or "0")
        if not length:
            return {}
        body = self.rfile.read(length).decode("utf-8")
        return json.loads(body or "{}")

    def send_json(self, payload: dict[str, Any], status: HTTPStatus = HTTPStatus.OK, cookie: str | None = None) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        if cookie:
            self.send_header("Set-Cookie", cookie)
        self.end_headers()
        self.wfile.write(body)

    def send_static(self, name: str) -> None:
        path = (STATIC_DIR / name).resolve()
        if not path.is_file() or STATIC_DIR not in path.parents:
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        data = path.read_bytes()
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def session_token(self) -> str | None:
        cookie = self.headers.get("Cookie", "")
        for chunk in cookie.split(";"):
            key, _, value = chunk.strip().partition("=")
            if key == "ledger_session":
                return value
        return None

    def is_unlocked(self) -> bool:
        token = self.session_token()
        return bool(token and token in self.server.sessions)

    def require_auth(self) -> bool:
        if not self.server.db.is_configured() or self.is_unlocked():
            return True
        self.send_json({"ok": False, "error": "locked"}, HTTPStatus.UNAUTHORIZED)
        return False

    def state_payload(self, unlocked: bool | None = None) -> dict[str, Any]:
        db = self.server.db
        configured = db.is_configured()
        is_unlocked = self.is_unlocked() if unlocked is None else unlocked
        payload: dict[str, Any] = {
            "ok": True,
            "configured": configured,
            "unlocked": is_unlocked,
            "themePreference": db.get_setting("theme_preference") or "system",
        }
        if not configured or not is_unlocked:
            return payload
        mode = db.get_mode()
        summary = db.summary(mode)
        payload.update(
            {
                "mode": mode,
                "modeLabel": MODE_LABELS[mode],
                "nextEnvelopeNo": db.next_envelope_no(mode),
                "groups": db.recent_groups(50),
                "relationships": db.recent_relationships(50),
                "recentEntries": [public_entry(entry) for entry in db.last_entries(mode, 8)],
                "summary": public_summary(summary),
                "paymentMethods": PAYMENT_METHODS,
            }
        )
        return payload

    def require_state(self) -> None:
        self.send_json(self.state_payload())

    def require_entries(self, query: str) -> None:
        if not self.require_auth():
            return
        params = parse_qs(query)
        filters: dict[str, Any] = {
            "mode": params.get("mode", [self.server.db.get_mode()])[0],
            "name": params.get("name", [""])[0],
            "group_name": params.get("group", [""])[0],
            "min_amount": digits_to_int(params.get("minAmount", [""])[0]) if params.get("minAmount", [""])[0] else "",
            "max_amount": digits_to_int(params.get("maxAmount", [""])[0]) if params.get("maxAmount", [""])[0] else "",
            "meal_ticket_count": params.get("tickets", [""])[0],
        }
        payment = params.get("payment", [""])[0]
        status = params.get("status", [""])[0]
        if payment in PAYMENT_METHODS:
            filters["payment_method"] = payment
        if status in (STATUS_ACTIVE, STATUS_VOID):
            filters["status"] = status
        self.send_json({"ok": True, "entries": [public_entry(entry) for entry in self.server.db.find_entries(filters)]})

    def require_export(self) -> None:
        if not self.require_auth():
            return
        db = self.server.db
        mode = db.get_mode()
        entries = db.find_entries({"mode": mode})
        summary = db.summary(mode)
        export_dir = Path(tempfile.gettempdir()) / "wedding-ledger-exports"
        export_dir.mkdir(parents=True, exist_ok=True)
        output = export_xls(export_dir / "wedding_ledger_export.xls", entries, summary, db.audit_rows())
        data = output.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/vnd.ms-excel")
        self.send_header("Content-Disposition", 'attachment; filename="wedding_ledger_export.xls"')
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_setup(self) -> None:
        data = self.read_json()
        try:
            recovery_key = self.server.db.setup_auth(str(data.get("password") or ""))
        except ValueError as exc:
            self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST)
            return
        token = secrets.token_urlsafe(32)
        self.server.sessions.add(token)
        self.send_json(
            {**self.state_payload(unlocked=True), "recoveryKey": recovery_key},
            cookie=f"ledger_session={token}; Path=/; HttpOnly; SameSite=Lax",
        )

    def handle_login(self) -> None:
        data = self.read_json()
        if not self.server.db.verify_password(str(data.get("password") or "")):
            self.send_json({"ok": False, "error": "비밀번호가 일치하지 않습니다."}, HTTPStatus.UNAUTHORIZED)
            return
        token = secrets.token_urlsafe(32)
        self.server.sessions.add(token)
        self.send_json(self.state_payload(unlocked=True), cookie=f"ledger_session={token}; Path=/; HttpOnly; SameSite=Lax")

    def handle_lock(self) -> None:
        token = self.session_token()
        if token:
            self.server.sessions.discard(token)
        self.send_json({"ok": True}, cookie="ledger_session=; Path=/; Max-Age=0; SameSite=Lax")

    def handle_create_entry(self) -> None:
        if not self.require_auth():
            return
        data = self.read_json()
        mode = self.server.db.get_mode()
        name = str(data.get("name") or "").strip()
        if self.server.db.name_exists(mode, name) and not data.get("forceDuplicate"):
            self.send_json({"ok": False, "duplicate": True, "error": "같은 이름의 정상 기록이 있습니다."}, HTTPStatus.CONFLICT)
            return
        try:
            entry = self.server.db.create_entry(
                {
                    "mode": mode,
                    "envelope_no": int(data.get("envelopeNo") or self.server.db.next_envelope_no(mode)),
                    "name": name,
                    "group_name": data.get("groupName") or "",
                    "relationship": data.get("relationship") or "",
                    "amount": digits_to_int(data.get("amount")),
                    "meal_ticket_count": int(data.get("mealTicketCount") or 0),
                    "payment_method": data.get("paymentMethod") or "cash",
                    "memo": data.get("memo") or "",
                }
            )
        except ValueError as exc:
            self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST)
            return
        self.send_json({"ok": True, "entry": public_entry(entry), "state": self.state_payload(unlocked=True)})

    def handle_mode(self) -> None:
        if not self.require_auth():
            return
        data = self.read_json()
        try:
            self.server.db.set_mode(str(data.get("mode") or MODE_TEST))
        except ValueError as exc:
            self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST)
            return
        self.send_json(self.state_payload(unlocked=True))

    def handle_theme(self) -> None:
        if not self.require_auth():
            return
        data = self.read_json()
        preference = str(data.get("themePreference") or "system")
        if preference not in {"system", "light", "dark"}:
            preference = "system"
        self.server.db.set_setting("theme_preference", preference)
        self.send_json({"ok": True, "themePreference": preference})

    def handle_reset_test(self) -> None:
        if not self.require_auth():
            return
        deleted_count = self.server.db.clear_test_data()
        self.send_json({"ok": True, "deletedCount": deleted_count, "state": self.state_payload(unlocked=True)})

    def handle_reset_records(self) -> None:
        if not self.require_auth():
            return
        self.server.db.clear_records_and_lookups()
        self.send_json({"ok": True, "state": self.state_payload(unlocked=True)})

    def handle_reset_all(self) -> None:
        if not self.require_auth():
            return
        self.server.db.reset_all_data()
        self.server.sessions.clear()
        self.send_json({"ok": True, "configured": False, "unlocked": False}, cookie="ledger_session=; Path=/; Max-Age=0; SameSite=Lax")

    def handle_void(self) -> None:
        if not self.require_auth():
            return
        data = self.read_json()
        try:
            entry = self.server.db.void_entry(str(data.get("id") or ""), str(data.get("reason") or ""))
        except ValueError as exc:
            self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST)
            return
        self.send_json({"ok": True, "entry": public_entry(entry), "state": self.state_payload(unlocked=True)})

    def handle_restore(self) -> None:
        if not self.require_auth():
            return
        data = self.read_json()
        try:
            entry = self.server.db.restore_entry(str(data.get("id") or ""), str(data.get("reason") or ""))
        except ValueError as exc:
            self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST)
            return
        self.send_json({"ok": True, "entry": public_entry(entry), "state": self.state_payload(unlocked=True)})


def main() -> None:
    server = LedgerHTTPServer((HOST, 0), LedgerRequestHandler)
    url = f"http://{HOST}:{server.server_port}/"
    print(f"축의대 장부 실행 중: {url}")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
