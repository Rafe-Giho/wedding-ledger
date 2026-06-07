from __future__ import annotations

import re
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, font as tkfont, messagebox, simpledialog, ttk
from typing import Callable

from .constants import (
    APP_TITLE,
    DEFAULT_GROUP,
    DEFAULT_QUICK_AMOUNTS,
    LOCK_AFTER_SECONDS,
    MODE_LABELS,
    MODE_LIVE,
    MODE_TEST,
    PAYMENT_METHODS,
    STATUS_ACTIVE,
    STATUS_LABELS,
    STATUS_VOID,
)
from .excel_export import export_xls
from .storage import WeddingLedgerDB


BG = "#F5F2EC"
SURFACE = "#FFFDF8"
SURFACE_ALT = "#EDE7DC"
TEXT = "#1D1B18"
MUTED = "#756E64"
ACCENT = "#1D1B18"
ACCENT_DARK = "#0F0E0D"
ACCENT_LIGHT = "#E8E1D4"
DANGER = "#C8443D"
BORDER = "#DDD4C7"
FIELD_BG = "#FFFEFB"
INPUT_FONT = ("Apple SD Gothic Neo", 14)
BODY_FONT = ("Apple SD Gothic Neo", 12)
TITLE_FONT = ("Apple SD Gothic Neo", 28, "bold")
SECTION_FONT = ("Apple SD Gothic Neo", 19, "bold")
PASSWORD_MIN_LENGTH = 4


def format_won(value: int | str | None) -> str:
    try:
        return f"{int(value or 0):,}원"
    except ValueError:
        return "0원"


def format_number(value: int | str | None) -> str:
    try:
        return f"{int(value or 0):,}"
    except ValueError:
        return "0"


def parse_amount(value: str) -> int:
    digits = re.sub(r"[^0-9]", "", value or "")
    return int(digits or 0)


def format_amount_input(value: str) -> str:
    amount = parse_amount(value)
    return format_number(amount) if amount else ""


def is_digits_or_empty(value: str) -> bool:
    return value == "" or value.isdigit()


def is_amount_text(value: str) -> bool:
    return re.fullmatch(r"[0-9,]*", value or "") is not None


def validate_password(value: str) -> None:
    if len(value) < PASSWORD_MIN_LENGTH:
        raise ValueError(f"비밀번호는 {PASSWORD_MIN_LENGTH}자 이상이어야 합니다.")


def payment_label_to_key(label: str) -> str:
    for key, value in PAYMENT_METHODS.items():
        if value == label:
            return key
    return "cash"


def parse_required_int(value: str, label: str, minimum: int = 0) -> int:
    try:
        number = int(value)
    except ValueError as exc:
        raise ValueError(f"{label}은 숫자로 입력해야 합니다.") from exc
    if number < minimum:
        raise ValueError(f"{label}은 {minimum} 이상이어야 합니다.")
    return number


def merge_lookup_values(current: str, values: list[str]) -> list[str]:
    merged: list[str] = []
    for value in [current, *values]:
        clean = str(value or "").strip()
        if clean and clean not in merged:
            merged.append(clean)
    return merged


class RoundedButton(tk.Canvas):
    COLORS = {
        "primary": (ACCENT, ACCENT_DARK, "#FFFFFF", ACCENT),
        "secondary": (SURFACE_ALT, ACCENT_LIGHT, TEXT, BORDER),
        "ghost": (FIELD_BG, SURFACE_ALT, TEXT, BORDER),
        "chip": (FIELD_BG, ACCENT_LIGHT, TEXT, BORDER),
        "danger": ("#F7E4E0", "#F0D1CC", DANGER, "#E7BDB7"),
    }

    def __init__(
        self,
        parent: tk.Widget,
        text: str,
        command: Callable[[], None],
        variant: str = "secondary",
        width: int | None = None,
        height: int = 38,
        radius: int = 17,
        bg_color: str = SURFACE,
    ) -> None:
        self.text = text
        self.command = command
        self.variant = variant if variant in self.COLORS else "secondary"
        self.height = height
        self.radius = min(radius, height // 2)
        measured = tkfont.Font(font=BODY_FONT).measure(text) + 34
        self.button_width = max(width or measured, 52)
        self.is_hovered = False
        self.is_pressed = False
        super().__init__(
            parent,
            width=self.button_width,
            height=height,
            bg=bg_color,
            bd=0,
            highlightthickness=0,
            relief="flat",
            cursor="hand2",
        )
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<ButtonPress-1>", self._on_press)
        self.bind("<ButtonRelease-1>", self._on_release)
        self._draw()

    def _rounded_rect(self, x1: int, y1: int, x2: int, y2: int, radius: int, fill: str) -> None:
        self.create_arc(x1, y1, x1 + radius * 2, y1 + radius * 2, start=90, extent=90, fill=fill, outline=fill)
        self.create_arc(x2 - radius * 2, y1, x2, y1 + radius * 2, start=0, extent=90, fill=fill, outline=fill)
        self.create_arc(x1, y2 - radius * 2, x1 + radius * 2, y2, start=180, extent=90, fill=fill, outline=fill)
        self.create_arc(x2 - radius * 2, y2 - radius * 2, x2, y2, start=270, extent=90, fill=fill, outline=fill)
        self.create_rectangle(x1 + radius, y1, x2 - radius, y2, fill=fill, outline=fill)
        self.create_rectangle(x1, y1 + radius, x2, y2 - radius, fill=fill, outline=fill)

    def _draw(self) -> None:
        fill, hover, foreground, border = self.COLORS[self.variant]
        bg = hover if self.is_hovered or self.is_pressed else fill
        self.delete("all")
        self._rounded_rect(0, 0, self.button_width, self.height, self.radius, border)
        self._rounded_rect(1, 1, self.button_width - 1, self.height - 1, max(self.radius - 1, 1), bg)
        self.create_text(
            self.button_width // 2,
            self.height // 2,
            text=self.text,
            font=BODY_FONT,
            fill=foreground,
        )

    def _on_enter(self, _event: tk.Event) -> None:
        self.is_hovered = True
        self._draw()

    def _on_leave(self, _event: tk.Event) -> None:
        self.is_hovered = False
        self.is_pressed = False
        self._draw()

    def _on_press(self, _event: tk.Event) -> None:
        self.is_pressed = True
        self._draw()

    def _on_release(self, event: tk.Event) -> None:
        should_run = self.is_pressed and 0 <= event.x <= self.button_width and 0 <= event.y <= self.height
        self.is_pressed = False
        self._draw()
        if should_run:
            self.command()


class SuggestionEntry(ttk.Frame):
    def __init__(
        self,
        parent: tk.Widget,
        textvariable: tk.StringVar,
        width: int = 30,
        values_provider: Callable[[], list[str]] | None = None,
    ) -> None:
        super().__init__(parent, style="Card.TFrame")
        self.variable = textvariable
        self.values: list[str] = []
        self.values_provider = values_provider
        self.popup: tk.Toplevel | None = None
        self.entry = tk.Entry(
            self,
            textvariable=textvariable,
            width=width,
            font=INPUT_FONT,
            bg=FIELD_BG,
            fg=TEXT,
            insertbackground=ACCENT_DARK,
            insertwidth=2,
            relief="flat",
            bd=0,
            highlightthickness=1,
            highlightbackground=BORDER,
            highlightcolor=ACCENT,
        )
        self.entry.pack(side="left", fill="x", expand=True)
        self.button = RoundedButton(self, "목록", self.show_popup, variant="ghost", width=58, height=34)
        self.button.pack(side="left", padx=(6, 0))
        self.entry.bind("<Down>", lambda _event: self._show_popup_from_key())
        self.entry.bind("<Escape>", lambda _event: self.hide_popup())

    def configure_values(self, values: list[str]) -> None:
        seen: set[str] = set()
        self.values = []
        for value in values:
            clean = str(value).strip()
            if clean and clean not in seen:
                seen.add(clean)
                self.values.append(clean)

    def _show_popup_from_key(self) -> str:
        self.show_popup()
        return "break"

    def show_popup(self) -> None:
        self.hide_popup()
        if self.values_provider:
            self.configure_values(self.values_provider())
        if not self.values:
            self.values = ["저장된 목록이 없습니다"]
        self.popup = tk.Toplevel(self)
        self.popup.overrideredirect(True)
        self.popup.configure(bg=BORDER)
        x = self.winfo_rootx()
        y = self.winfo_rooty() + self.winfo_height() + 2
        width = max(self.winfo_width(), 220)
        height = min(max(len(self.values), 1), 8) * 30 + 4
        self.popup.geometry(f"{width}x{height}+{x}+{y}")
        listbox = tk.Listbox(
            self.popup,
            font=INPUT_FONT,
            bg=SURFACE,
            fg=TEXT,
            activebackground=ACCENT_LIGHT,
            activeforeground=TEXT,
            selectbackground=ACCENT,
            selectforeground="#FFFFFF",
            relief="flat",
            highlightthickness=0,
            exportselection=False,
        )
        listbox.pack(fill="both", expand=True, padx=1, pady=1)
        for value in self.values:
            listbox.insert("end", value)

        def choose(_event: tk.Event | None = None) -> str:
            selection = listbox.curselection()
            if selection and self.values[selection[0]] != "저장된 목록이 없습니다":
                self.variable.set(listbox.get(selection[0]))
            self.hide_popup()
            self.entry.focus_set()
            self.entry.icursor("end")
            return "break"

        listbox.bind("<ButtonRelease-1>", choose)
        listbox.bind("<Return>", choose)
        listbox.bind("<Escape>", lambda _event: self.hide_popup())
        listbox.focus_set()
        listbox.selection_set(0)

    def hide_popup(self) -> str:
        if self.popup and self.popup.winfo_exists():
            self.popup.destroy()
        self.popup = None
        return "break"


class WeddingLedgerApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.db = WeddingLedgerDB()
        self.unlocked = False
        self.last_activity = 0
        self.last_backup_at = 0
        self.title(APP_TITLE)
        self.geometry("1180x760")
        self.minsize(1020, 680)
        self.configure(bg=BG)
        self._configure_style()
        self.numeric_vcmd = (self.register(is_digits_or_empty), "%P")
        self.amount_vcmd = (self.register(is_amount_text), "%P")
        self.container = ttk.Frame(self, padding=18)
        self.container.pack(fill="both", expand=True)
        self.bind_all("<Key>", self._mark_activity)
        self.bind_all("<Button>", self._mark_activity)
        self.protocol("WM_DELETE_WINDOW", self.on_close)
        if self.db.is_configured():
            self.show_login()
        else:
            self.show_setup()

    def _button(
        self,
        parent: tk.Widget,
        text: str,
        command: Callable[[], None],
        variant: str = "secondary",
        width: int | None = None,
        height: int = 38,
        bg_color: str = SURFACE,
    ) -> RoundedButton:
        return RoundedButton(parent, text, command, variant=variant, width=width, height=height, bg_color=bg_color)

    def _configure_style(self) -> None:
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure(".", font=BODY_FONT, background=BG)
        style.configure("TFrame", background=BG)
        style.configure("TLabel", background=BG, foreground=TEXT)
        style.configure("Title.TLabel", font=TITLE_FONT, foreground=TEXT)
        style.configure("Section.TLabel", font=SECTION_FONT, foreground=TEXT)
        style.configure("Muted.TLabel", foreground=MUTED)
        style.configure("Danger.TLabel", foreground=DANGER)
        style.configure("Hero.TFrame", background=BG)
        style.configure("HeroTitle.TLabel", background=BG, foreground=TEXT, font=TITLE_FONT)
        style.configure("HeroMuted.TLabel", background=BG, foreground=MUTED, font=BODY_FONT)
        style.configure("Pill.TLabel", background=ACCENT_LIGHT, foreground=ACCENT_DARK, font=("Apple SD Gothic Neo", 12, "bold"))
        style.configure("Card.TFrame", background=SURFACE, relief="flat")
        style.configure("Card.TLabel", background=SURFACE, foreground=TEXT)
        style.configure("CardTitle.TLabel", background=SURFACE, foreground=TEXT, font=SECTION_FONT)
        style.configure("CardMuted.TLabel", background=SURFACE, foreground=MUTED)
        style.configure("CardValue.TLabel", background=SURFACE, foreground=TEXT, font=("Apple SD Gothic Neo", 18, "bold"))
        style.configure("CardDanger.TLabel", background=SURFACE, foreground=DANGER)
        style.configure("Accent.TButton", font=("Apple SD Gothic Neo", 13, "bold"), foreground="#FFFFFF", background=ACCENT)
        style.map("Accent.TButton", background=[("active", ACCENT_DARK), ("pressed", ACCENT_DARK)])
        style.configure("TButton", font=BODY_FONT, padding=(12, 8), background=SURFACE_ALT, borderwidth=0, relief="flat")
        style.map("TButton", background=[("active", ACCENT_LIGHT), ("pressed", ACCENT_LIGHT)])
        style.configure("Chip.TButton", font=("Apple SD Gothic Neo", 12, "bold"), padding=(10, 7), background=FIELD_BG, foreground=TEXT, borderwidth=0, relief="flat")
        style.map("Chip.TButton", background=[("active", ACCENT_LIGHT), ("pressed", ACCENT_LIGHT)])
        style.configure("Danger.TButton", foreground=DANGER)
        style.configure("TNotebook", background=BG, borderwidth=0)
        style.configure("TNotebook.Tab", font=("Apple SD Gothic Neo", 12, "bold"), padding=(16, 9), background=SURFACE_ALT, foreground=MUTED)
        style.map("TNotebook.Tab", background=[("selected", SURFACE)], foreground=[("selected", TEXT)])
        style.configure("Treeview", font=("Apple SD Gothic Neo", 12), rowheight=34, background=FIELD_BG, fieldbackground=FIELD_BG, foreground=TEXT)
        style.configure("Treeview.Heading", font=("Apple SD Gothic Neo", 12, "bold"), background=TEXT, foreground="#FFFFFF")

    def _bind_safe_focus_chain(
        self,
        widgets: list[tk.Widget],
        on_final_return: Callable[[], None] | None = None,
    ) -> None:
        for index, widget in enumerate(widgets):
            widget.bind("<Tab>", lambda event, i=index: self._focus_chain_later(event, widgets, i + 1))
            widget.bind("<Shift-Tab>", lambda event, i=index: self._focus_chain_later(event, widgets, i - 1))
            widget.bind("<ISO_Left_Tab>", lambda event, i=index: self._focus_chain_later(event, widgets, i - 1))
            if on_final_return and index == len(widgets) - 1:
                widget.bind("<Return>", lambda event: self._run_action_from_key(event, on_final_return))
            else:
                widget.bind("<Return>", lambda event, i=index: self._focus_chain_later(event, widgets, i + 1))

    def _focus_chain_later(self, event: tk.Event, widgets: list[tk.Widget], target_index: int) -> str:
        source = event.widget
        target = widgets[target_index % len(widgets)]

        def move_focus() -> None:
            if not target.winfo_exists():
                return
            target.focus_set()
            self._select_editable_text(target)

        # Delaying focus movement avoids a macOS Korean IME issue where the
        # composing character can be committed into the next input field.
        source.after(60, move_focus)
        return "break"

    def _run_action_from_key(self, event: tk.Event, action: Callable[[], None]) -> str:
        event.widget.after(60, action)
        return "break"

    def _select_editable_text(self, widget: tk.Widget) -> None:
        try:
            widget.selection_range(0, "end")  # type: ignore[attr-defined]
            widget.icursor("end")  # type: ignore[attr-defined]
        except tk.TclError:
            pass
        except AttributeError:
            pass

    def _make_entry(
        self,
        parent: tk.Widget,
        variable: tk.StringVar,
        width: int = 30,
        validate_digits: bool = False,
        validate_amount: bool = False,
        show: str | None = None,
    ) -> tk.Entry:
        entry = tk.Entry(
            parent,
            textvariable=variable,
            width=width,
            font=INPUT_FONT,
            bg=FIELD_BG,
            fg=TEXT,
            insertbackground=ACCENT_DARK,
            insertwidth=2,
            relief="flat",
            bd=0,
            highlightthickness=1,
            highlightbackground=BORDER,
            highlightcolor=ACCENT,
        )
        if show:
            entry.configure(show=show)
        if validate_digits:
            entry.configure(validate="key", validatecommand=self.numeric_vcmd)
        if validate_amount:
            entry.configure(validate="key", validatecommand=self.amount_vcmd)
        return entry

    def _format_amount_var(self, variable: tk.StringVar) -> None:
        variable.set(format_amount_input(variable.get()))

    def _set_amount_var(self, variable: tk.StringVar, amount: int) -> None:
        variable.set(format_number(amount))

    def _add_amount(self, variable: tk.StringVar, amount: int) -> None:
        self._set_amount_var(variable, parse_amount(variable.get()) + amount)

    def _clear(self) -> None:
        for child in self.container.winfo_children():
            child.destroy()

    def _mark_activity(self, _event: object | None = None) -> None:
        self.last_activity = int(self.tk.call("clock", "seconds"))

    def _schedule_lock_check(self) -> None:
        if not self.unlocked:
            return
        now = int(self.tk.call("clock", "seconds"))
        if self.last_activity and now - self.last_activity >= LOCK_AFTER_SECONDS:
            self.lock_app("일정 시간 사용하지 않아 자동 잠금되었습니다.")
            return
        self.after(30_000, self._schedule_lock_check)

    def show_setup(self) -> None:
        self._clear()
        frame = ttk.Frame(self.container, padding=30, style="Card.TFrame")
        frame.place(relx=0.5, rely=0.5, anchor="center")
        ttk.Label(frame, text="축의대 장부 시작하기", style="CardTitle.TLabel").grid(row=0, column=0, columnspan=2, sticky="w", pady=(0, 16))
        ttk.Label(frame, text="한/영 입력 상태와 상관없이 같은 키는 같은 비밀번호로 인식됩니다.", style="CardMuted.TLabel").grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 20))

        password_var = tk.StringVar()
        confirm_var = tk.StringVar()
        ttk.Label(frame, text="비밀번호", style="Card.TLabel").grid(row=2, column=0, sticky="e", padx=8, pady=8)
        password_entry = self._make_entry(frame, password_var, width=34, show="*")
        password_entry.grid(row=2, column=1, sticky="w")
        ttk.Label(frame, text="비밀번호 확인", style="Card.TLabel").grid(row=3, column=0, sticky="e", padx=8, pady=8)
        confirm_entry = self._make_entry(frame, confirm_var, width=34, show="*")
        confirm_entry.grid(row=3, column=1, sticky="w")

        def submit() -> None:
            password = password_var.get()
            if password != confirm_var.get():
                messagebox.showerror("확인 필요", "비밀번호 확인이 일치하지 않습니다.")
                return
            try:
                validate_password(password)
            except ValueError as exc:
                messagebox.showerror("확인 필요", str(exc))
                return
            try:
                recovery_key = self.db.setup_auth(password)
            except ValueError as exc:
                messagebox.showerror("확인 필요", str(exc))
                return
            self.show_recovery_key_once(recovery_key)
            self.unlocked = True
            self._mark_activity()
            self.show_main()

        self._button(frame, "비밀번호 설정", submit, variant="primary", width=132).grid(row=4, column=1, sticky="e", pady=(16, 0))
        self._bind_safe_focus_chain([password_entry, confirm_entry], submit)
        password_entry.focus_set()

    def show_recovery_key_once(self, recovery_key: str) -> None:
        top = tk.Toplevel(self)
        top.title("복구키 보관")
        top.geometry("560x320")
        top.configure(bg=BG)
        top.grab_set()
        ttk.Label(top, text="복구키", style="Title.TLabel").pack(anchor="w", padx=24, pady=(24, 6))
        ttk.Label(top, text="비밀번호를 잊었을 때 필요합니다. 이 창을 닫기 전에 따로 적어두세요.", style="Muted.TLabel").pack(anchor="w", padx=24)
        text = tk.Text(top, height=3, font=("Menlo", 20, "bold"), bg=FIELD_BG, relief="flat")
        text.pack(fill="x", padx=24, pady=20)
        text.insert("1.0", recovery_key)
        text.configure(state="disabled")
        self._button(top, "보관했습니다", top.destroy, variant="primary", width=124, bg_color=BG).pack(anchor="e", padx=24, pady=8)
        self.wait_window(top)

    def show_login(self, notice: str = "") -> None:
        self.unlocked = False
        self._clear()
        frame = ttk.Frame(self.container, padding=30, style="Card.TFrame")
        frame.place(relx=0.5, rely=0.5, anchor="center")
        ttk.Label(frame, text="잠금 해제", style="CardTitle.TLabel").grid(row=0, column=0, columnspan=2, sticky="w", pady=(0, 16))
        if notice:
            ttk.Label(frame, text=notice, style="CardMuted.TLabel").grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 12))
        password_var = tk.StringVar()
        ttk.Label(frame, text="비밀번호", style="Card.TLabel").grid(row=2, column=0, sticky="e", padx=8, pady=8)
        entry = self._make_entry(frame, password_var, width=34, show="*")
        entry.grid(row=2, column=1, sticky="w")

        def unlock() -> None:
            if not self.db.verify_password(password_var.get()):
                messagebox.showerror("로그인 실패", "비밀번호가 올바르지 않습니다.")
                return
            self.unlocked = True
            self._mark_activity()
            self.show_main()

        self._button(frame, "로그인", unlock, variant="primary", width=96).grid(row=3, column=1, sticky="e", pady=(16, 0))
        self._button(frame, "비밀번호를 잊으셨나요?", self.show_password_recovery, width=172).grid(row=4, column=1, sticky="e", pady=(8, 0))
        entry.focus_set()
        entry.bind("<Return>", lambda _event: unlock())

    def show_password_recovery(self) -> None:
        top = tk.Toplevel(self)
        top.title("비밀번호 복구")
        top.geometry("560x300")
        top.configure(bg=BG)
        top.grab_set()
        recovery_var = tk.StringVar()
        password_var = tk.StringVar()
        confirm_var = tk.StringVar()
        ttk.Label(top, text="복구키로 새 비밀번호 설정", style="Title.TLabel").grid(row=0, column=0, columnspan=2, sticky="w", padx=24, pady=(24, 14))
        ttk.Label(top, text="복구키").grid(row=1, column=0, sticky="e", padx=8, pady=8)
        recovery_entry = ttk.Entry(top, textvariable=recovery_var, width=44)
        recovery_entry.grid(row=1, column=1, sticky="w")
        ttk.Label(top, text="새 비밀번호").grid(row=2, column=0, sticky="e", padx=8, pady=8)
        password_entry = self._make_entry(top, password_var, width=34, show="*")
        password_entry.grid(row=2, column=1, sticky="w")
        ttk.Label(top, text="새 비밀번호 확인").grid(row=3, column=0, sticky="e", padx=8, pady=8)
        confirm_entry = self._make_entry(top, confirm_var, width=34, show="*")
        confirm_entry.grid(row=3, column=1, sticky="w")

        def reset() -> None:
            if password_var.get() != confirm_var.get():
                messagebox.showerror("확인 필요", "새 비밀번호 확인이 일치하지 않습니다.")
                return
            try:
                validate_password(password_var.get())
            except ValueError as exc:
                messagebox.showerror("확인 필요", str(exc))
                return
            try:
                ok = self.db.reset_password_with_recovery(recovery_var.get(), password_var.get())
            except ValueError as exc:
                messagebox.showerror("확인 필요", str(exc))
                return
            if not ok:
                messagebox.showerror("복구 실패", "복구키가 올바르지 않습니다.")
                return
            messagebox.showinfo("완료", "비밀번호가 변경되었습니다.")
            top.destroy()

        self._button(top, "비밀번호 재설정", reset, variant="primary", width=142, bg_color=BG).grid(row=4, column=1, sticky="e", pady=16)
        self._bind_safe_focus_chain([recovery_entry, password_entry, confirm_entry], reset)
        recovery_entry.focus_set()

    def lock_app(self, notice: str = "") -> None:
        if self.unlocked:
            try:
                self.db.create_backup("auto_lock")
            except Exception:
                pass
        self.show_login(notice)

    def auto_backup_if_due(self, label: str = "autosave", interval_seconds: int = 180) -> None:
        now = int(self.tk.call("clock", "seconds"))
        if now - self.last_backup_at < interval_seconds:
            return
        self.db.create_backup(label)
        self.last_backup_at = now

    def show_main(self) -> None:
        self._clear()
        self._mark_activity()
        header = ttk.Frame(self.container, padding=20, style="Hero.TFrame")
        header.pack(fill="x", pady=(0, 16))
        title_box = ttk.Frame(header, style="Hero.TFrame")
        title_box.pack(side="left", fill="x", expand=True)
        ttk.Label(title_box, text=APP_TITLE, style="HeroTitle.TLabel").pack(anchor="w")
        ttk.Label(title_box, text="축의금과 식권을 빠르게 기록하고 정산합니다.", style="HeroMuted.TLabel").pack(anchor="w", pady=(4, 0))
        header_actions = ttk.Frame(header, style="Hero.TFrame")
        header_actions.pack(side="right")
        self.mode_label = ttk.Label(header_actions, text="", style="Pill.TLabel", padding=(12, 7))
        self.mode_label.pack(side="left", padx=(0, 10))
        self._button(header_actions, "지금 잠금", lambda: self.lock_app("수동으로 잠금되었습니다."), width=104, bg_color=BG).pack(side="left")

        self.notebook = ttk.Notebook(self.container)
        self.notebook.pack(fill="both", expand=True)
        self.entry_tab = ttk.Frame(self.notebook, padding=12)
        self.search_tab = ttk.Frame(self.notebook, padding=12)
        self.summary_tab = ttk.Frame(self.notebook, padding=12)
        self.settings_tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(self.entry_tab, text="입력")
        self.notebook.add(self.search_tab, text="검색")
        self.notebook.add(self.summary_tab, text="정산")
        self.notebook.add(self.settings_tab, text="설정")
        self.build_entry_tab()
        self.build_search_tab()
        self.build_summary_tab()
        self.build_settings_tab()
        self.refresh_all()
        self._schedule_lock_check()

    def refresh_all(self) -> None:
        if not self.unlocked:
            return
        mode = self.db.get_mode()
        self.mode_label.configure(text=f"{MODE_LABELS[mode]} 모드")
        self.refresh_entry_defaults()
        self.refresh_last_entries()
        self.refresh_search()
        self.refresh_summary()
        self.refresh_settings()

    def build_entry_tab(self) -> None:
        form = ttk.Frame(self.entry_tab, padding=18, style="Card.TFrame")
        form.pack(side="left", fill="y", padx=(0, 16))
        self.envelope_var = tk.StringVar()
        self.name_var = tk.StringVar()
        self.group_var = tk.StringVar(value=DEFAULT_GROUP)
        self.relationship_var = tk.StringVar()
        self.amount_var = tk.StringVar()
        self.ticket_var = tk.StringVar(value="0")
        self.payment_var = tk.StringVar(value=PAYMENT_METHODS["cash"])
        self.memo_var = tk.StringVar()

        ttk.Label(form, text="빠른 입력", style="CardTitle.TLabel").grid(row=0, column=0, columnspan=3, sticky="w", pady=(0, 12))
        self.envelope_entry = self._labeled_entry(form, "봉투번호", self.envelope_var, 1, validate_digits=True)
        self.name_entry = self._labeled_entry(form, "이름 *", self.name_var, 2)
        ttk.Label(form, text="모임", style="Card.TLabel").grid(row=3, column=0, sticky="e", padx=8, pady=7)
        self.group_select = SuggestionEntry(form, self.group_var, width=24, values_provider=self.group_lookup_values)
        self.group_select.grid(row=3, column=1, columnspan=2, sticky="ew")
        ttk.Label(form, text="관계", style="Card.TLabel").grid(row=4, column=0, sticky="e", padx=8, pady=7)
        self.relationship_select = SuggestionEntry(form, self.relationship_var, width=24, values_provider=self.relationship_lookup_values)
        self.relationship_select.grid(row=4, column=1, columnspan=2, sticky="ew")

        self.amount_entry = self._labeled_entry(form, "금액 *", self.amount_var, 5, validate_amount=True)
        self.amount_entry.bind("<FocusOut>", lambda _event: self._format_amount_var(self.amount_var))
        amount_frame = ttk.Frame(form, style="Card.TFrame")
        amount_frame.grid(row=6, column=1, columnspan=2, sticky="w", pady=(0, 8))
        for index, amount in enumerate(DEFAULT_QUICK_AMOUNTS):
            self._button(amount_frame, format_number(amount), lambda value=amount: self._set_amount_var(self.amount_var, value), variant="chip", width=78, height=34).grid(row=index // 4, column=index % 4, padx=3, pady=3)
        self._button(amount_frame, "+1만원", lambda: self._add_amount(self.amount_var, 10_000), variant="chip", width=162, height=34).grid(row=2, column=0, columnspan=2, sticky="ew", padx=3, pady=3)

        ttk.Label(form, text="식권 수 *", style="Card.TLabel").grid(row=7, column=0, sticky="e", padx=8, pady=7)
        self.ticket_spinbox = ttk.Spinbox(form, textvariable=self.ticket_var, from_=0, to=20, width=8)
        self.ticket_spinbox.configure(validate="key", validatecommand=self.numeric_vcmd)
        self.ticket_spinbox.grid(row=7, column=1, sticky="w")
        ttk.Label(form, text="입금방식 *", style="Card.TLabel").grid(row=8, column=0, sticky="e", padx=8, pady=7)
        self.payment_combo = ttk.Combobox(form, textvariable=self.payment_var, values=list(PAYMENT_METHODS.values()), state="readonly", width=12)
        self.payment_combo.grid(row=8, column=1, sticky="w")
        self.memo_entry = self._labeled_entry(form, "메모", self.memo_var, 9)
        self._button(form, "저장하고 다음 봉투", self.save_entry, variant="primary", width=172).grid(row=10, column=1, sticky="ew", pady=(14, 4))
        self._button(form, "입력 초기화", self.clear_entry_form, width=118).grid(row=10, column=2, sticky="ew", pady=(14, 4), padx=(8, 0))
        self._bind_safe_focus_chain(
            [
                self.envelope_entry,
                self.name_entry,
                self.group_select.entry,
                self.relationship_select.entry,
                self.amount_entry,
                self.ticket_spinbox,
                self.payment_combo,
                self.memo_entry,
            ],
            self.save_entry,
        )

        recent_frame = ttk.Frame(self.entry_tab, padding=18, style="Card.TFrame")
        recent_frame.pack(side="left", fill="both", expand=True)
        ttk.Label(recent_frame, text="최근 입력", style="CardTitle.TLabel").pack(anchor="w", pady=(0, 12))
        self.last_tree = self._create_tree(
            recent_frame,
            ("envelope", "name", "group", "amount", "tickets", "payment", "status"),
            ("봉투", "이름", "모임", "금액", "식권", "방식", "상태"),
        )
        self.last_tree.pack(fill="both", expand=True)
        self.last_tree.bind("<Double-1>", lambda _event: self.edit_selected_from_tree(self.last_tree))

    def _labeled_entry(
        self,
        parent: ttk.Frame,
        label: str,
        variable: tk.StringVar,
        row_index: int,
        validate_digits: bool = False,
        validate_amount: bool = False,
    ) -> tk.Entry:
        ttk.Label(parent, text=label, style="Card.TLabel").grid(row=row_index, column=0, sticky="e", padx=8, pady=7)
        entry = self._make_entry(parent, variable, width=30, validate_digits=validate_digits, validate_amount=validate_amount)
        entry.grid(row=row_index, column=1, columnspan=2, sticky="w")
        return entry

    def refresh_entry_defaults(self) -> None:
        self.envelope_var.set(str(self.db.next_envelope_no()))
        self.group_select.configure_values(self.group_lookup_values())
        self.relationship_select.configure_values(self.relationship_lookup_values())

    def group_lookup_values(self) -> list[str]:
        current = self.group_var.get() if hasattr(self, "group_var") else ""
        return merge_lookup_values(current, self.db.recent_groups())

    def relationship_lookup_values(self) -> list[str]:
        current = self.relationship_var.get() if hasattr(self, "relationship_var") else ""
        return merge_lookup_values(current, self.db.recent_relationships())

    def clear_entry_form(self) -> None:
        self.name_var.set("")
        self.group_var.set(DEFAULT_GROUP)
        self.relationship_var.set("")
        self.amount_var.set("")
        self.ticket_var.set("0")
        self.payment_var.set(PAYMENT_METHODS["cash"])
        self.memo_var.set("")
        self.envelope_var.set(str(self.db.next_envelope_no()))
        if hasattr(self, "name_entry"):
            self.name_entry.focus_set()

    def save_entry(self) -> None:
        mode = self.db.get_mode()
        name = self.name_var.get().strip()
        amount = parse_amount(self.amount_var.get())
        if not name:
            messagebox.showerror("필수 입력", "이름은 필수입니다.")
            return
        if amount <= 0:
            messagebox.showerror("필수 입력", "금액은 0원보다 커야 합니다.")
            return
        if amount % 10_000 != 0 and not messagebox.askyesno("금액 확인", "만원 단위가 아닙니다. 그대로 저장할까요?"):
            return
        if self.db.name_exists(mode, name) and not messagebox.askyesno("동명이인 확인", f"{name} 이름의 정상 기록이 이미 있습니다. 계속 저장할까요?"):
            return
        try:
            self.db.create_entry(
                {
                    "mode": mode,
                    "envelope_no": parse_required_int(self.envelope_var.get(), "봉투번호", 1),
                    "name": name,
                    "group_name": self.group_var.get(),
                    "relationship": self.relationship_var.get(),
                    "amount": amount,
                    "meal_ticket_count": parse_required_int(self.ticket_var.get() or "0", "식권 수", 0),
                    "payment_method": payment_label_to_key(self.payment_var.get()),
                    "memo": self.memo_var.get(),
                }
            )
        except ValueError as exc:
            messagebox.showerror("저장 실패", str(exc))
            return
        self.auto_backup_if_due()
        self.clear_entry_form()
        self.refresh_all()

    def build_search_tab(self) -> None:
        filters = ttk.Frame(self.search_tab, padding=14, style="Card.TFrame")
        filters.pack(fill="x", pady=(0, 10))
        self.search_name_var = tk.StringVar()
        self.search_group_var = tk.StringVar()
        self.search_min_var = tk.StringVar()
        self.search_max_var = tk.StringVar()
        self.search_ticket_var = tk.StringVar()
        self.search_payment_var = tk.StringVar(value="전체")
        self.search_status_var = tk.StringVar(value="정상")
        self.search_mode_var = tk.StringVar(value="현재 모드")

        items = [
            ("이름", self.search_name_var, 0),
            ("모임", self.search_group_var, 2),
            ("최소금액", self.search_min_var, 4),
            ("최대금액", self.search_max_var, 6),
            ("식권수", self.search_ticket_var, 8),
        ]
        search_entries: list[tk.Widget] = []
        for label, variable, column in items:
            ttk.Label(filters, text=label, style="Card.TLabel").grid(row=0, column=column, padx=(0, 4))
            entry = self._make_entry(
                filters,
                variable,
                width=12,
                validate_digits=label == "식권수",
                validate_amount=label in {"최소금액", "최대금액"},
            )
            entry.grid(row=0, column=column + 1, padx=(0, 8))
            if label in {"최소금액", "최대금액"}:
                entry.bind("<FocusOut>", lambda _event, var=variable: self._format_amount_var(var))
            search_entries.append(entry)
        search_payment_combo = ttk.Combobox(filters, textvariable=self.search_payment_var, values=["전체", *PAYMENT_METHODS.values()], state="readonly", width=8)
        search_payment_combo.grid(row=1, column=1, sticky="w", pady=8)
        ttk.Label(filters, text="입금방식", style="Card.TLabel").grid(row=1, column=0, sticky="e", padx=(0, 4))
        search_status_combo = ttk.Combobox(filters, textvariable=self.search_status_var, values=["정상", "취소", "전체"], state="readonly", width=8)
        search_status_combo.grid(row=1, column=3, sticky="w")
        ttk.Label(filters, text="상태", style="Card.TLabel").grid(row=1, column=2, sticky="e", padx=(0, 4))
        search_mode_combo = ttk.Combobox(filters, textvariable=self.search_mode_var, values=["현재 모드", "테스트", "운영", "전체"], state="readonly", width=10)
        search_mode_combo.grid(row=1, column=5, sticky="w")
        ttk.Label(filters, text="모드", style="Card.TLabel").grid(row=1, column=4, sticky="e", padx=(0, 4))
        self._button(filters, "검색", self.refresh_search, variant="primary", width=78).grid(row=1, column=7, padx=4)
        self._button(filters, "초기화", self.reset_search, width=82).grid(row=1, column=8, padx=4)
        self._bind_safe_focus_chain(
            [
                *search_entries,
                search_payment_combo,
                search_status_combo,
                search_mode_combo,
            ],
            self.refresh_search,
        )

        self.search_tree = self._create_tree(
            self.search_tab,
            ("envelope", "name", "group", "relationship", "amount", "tickets", "payment", "status", "created", "memo"),
            ("봉투", "이름", "모임", "관계", "금액", "식권", "방식", "상태", "입력시간", "메모"),
        )
        self.search_tree.pack(fill="both", expand=True)
        self.search_tree.bind("<Double-1>", lambda _event: self.edit_selected_from_tree(self.search_tree))

        actions = ttk.Frame(self.search_tab, padding=(0, 8, 0, 0))
        actions.pack(fill="x", pady=(10, 0))
        self._button(actions, "선택 수정", lambda: self.edit_selected_from_tree(self.search_tree), width=104, bg_color=BG).pack(side="left", padx=(0, 6))
        self._button(actions, "선택 취소 처리", self.void_selected, variant="danger", width=132, bg_color=BG).pack(side="left", padx=6)
        self._button(actions, "선택 정상 복구", self.restore_selected, width=132, bg_color=BG).pack(side="left", padx=6)

    def _create_tree(self, parent: ttk.Frame, columns: tuple[str, ...], headings: tuple[str, ...]) -> ttk.Treeview:
        tree = ttk.Treeview(parent, columns=columns, show="headings")
        for column, heading in zip(columns, headings):
            tree.heading(column, text=heading)
            width = 90
            if column in {"name", "group", "memo"}:
                width = 140
            if column == "created":
                width = 150
            tree.column(column, width=width, anchor="w")
        return tree

    def search_filters(self) -> dict[str, object]:
        filters: dict[str, object] = {
            "name": self.search_name_var.get(),
            "group_name": self.search_group_var.get(),
            "min_amount": parse_amount(self.search_min_var.get()) if self.search_min_var.get().strip() else "",
            "max_amount": parse_amount(self.search_max_var.get()) if self.search_max_var.get().strip() else "",
            "meal_ticket_count": self.search_ticket_var.get(),
        }
        if self.search_payment_var.get() != "전체":
            filters["payment_method"] = payment_label_to_key(self.search_payment_var.get())
        status_label = self.search_status_var.get()
        if status_label == "정상":
            filters["status"] = STATUS_ACTIVE
        elif status_label == "취소":
            filters["status"] = STATUS_VOID
        mode_label = self.search_mode_var.get()
        if mode_label == "현재 모드":
            filters["mode"] = self.db.get_mode()
        elif mode_label == "테스트":
            filters["mode"] = MODE_TEST
        elif mode_label == "운영":
            filters["mode"] = MODE_LIVE
        return filters

    def refresh_search(self) -> None:
        if not hasattr(self, "search_tree"):
            return
        for item in self.search_tree.get_children():
            self.search_tree.delete(item)
        try:
            entries = self.db.find_entries(self.search_filters())
        except ValueError:
            entries = []
        for entry in entries:
            self.search_tree.insert("", "end", iid=entry["id"], values=self.entry_values(entry, include_relationship=True))

    def reset_search(self) -> None:
        self.search_name_var.set("")
        self.search_group_var.set("")
        self.search_min_var.set("")
        self.search_max_var.set("")
        self.search_ticket_var.set("")
        self.search_payment_var.set("전체")
        self.search_status_var.set("정상")
        self.search_mode_var.set("현재 모드")
        self.refresh_search()

    def refresh_last_entries(self) -> None:
        if not hasattr(self, "last_tree"):
            return
        for item in self.last_tree.get_children():
            self.last_tree.delete(item)
        for entry in self.db.last_entries(self.db.get_mode()):
            self.last_tree.insert("", "end", iid=entry["id"], values=self.entry_values(entry))

    def entry_values(self, entry: dict[str, object], include_relationship: bool = False) -> tuple[object, ...]:
        base = (
            entry["envelope_no"],
            entry["name"],
            entry["group_name"],
        )
        rest = (
            format_won(entry["amount"]),
            entry["meal_ticket_count"],
            PAYMENT_METHODS.get(str(entry["payment_method"]), entry["payment_method"]),
            STATUS_LABELS.get(str(entry["status"]), entry["status"]),
        )
        if include_relationship:
            return (
                *base,
                entry["relationship"],
                *rest,
                entry["created_at"],
                entry["memo"],
            )
        return (*base, *rest)

    def selected_entry_id(self, tree: ttk.Treeview) -> str | None:
        selected = tree.selection()
        return selected[0] if selected else None

    def edit_selected_from_tree(self, tree: ttk.Treeview) -> None:
        entry_id = self.selected_entry_id(tree)
        if not entry_id:
            messagebox.showinfo("선택 필요", "수정할 기록을 선택하세요.")
            return
        entry = self.db.get_entry(entry_id)
        if not entry:
            messagebox.showerror("오류", "기록을 찾을 수 없습니다.")
            return
        self.show_edit_dialog(entry)

    def show_edit_dialog(self, entry: dict[str, object]) -> None:
        top = tk.Toplevel(self)
        top.title("기록 수정")
        top.geometry("560x560")
        top.configure(bg=BG)
        top.grab_set()
        vars_map = {
            "envelope_no": tk.StringVar(value=str(entry["envelope_no"])),
            "name": tk.StringVar(value=str(entry["name"])),
            "group_name": tk.StringVar(value=str(entry["group_name"])),
            "relationship": tk.StringVar(value=str(entry["relationship"])),
            "amount": tk.StringVar(value=format_number(entry["amount"])),
            "meal_ticket_count": tk.StringVar(value=str(entry["meal_ticket_count"])),
            "payment_method": tk.StringVar(value=PAYMENT_METHODS.get(str(entry["payment_method"]), "현금")),
            "memo": tk.StringVar(value=str(entry["memo"])),
            "reason": tk.StringVar(),
        }
        edit_widgets: list[tk.Widget] = []
        labels = [
            ("봉투번호", "envelope_no"),
            ("이름", "name"),
            ("모임", "group_name"),
            ("관계", "relationship"),
            ("금액", "amount"),
            ("식권 수", "meal_ticket_count"),
            ("입금방식", "payment_method"),
            ("메모", "memo"),
            ("수정 사유", "reason"),
        ]
        ttk.Label(top, text="기록 수정", style="Title.TLabel").grid(row=0, column=0, columnspan=2, sticky="w", padx=24, pady=(20, 10))
        for idx, (label, key) in enumerate(labels, start=1):
            ttk.Label(top, text=label).grid(row=idx, column=0, sticky="e", padx=8, pady=7)
            if key == "payment_method":
                widget = ttk.Combobox(top, textvariable=vars_map[key], values=list(PAYMENT_METHODS.values()), state="readonly", width=12)
                widget.grid(row=idx, column=1, sticky="w")
                edit_widgets.append(widget)
            elif key == "group_name":
                select = SuggestionEntry(top, vars_map[key], width=28, values_provider=lambda var=vars_map[key]: merge_lookup_values(var.get(), self.db.recent_groups()))
                select.configure_values(merge_lookup_values(vars_map[key].get(), self.db.recent_groups()))
                select.grid(row=idx, column=1, sticky="ew")
                edit_widgets.append(select.entry)
            elif key == "relationship":
                select = SuggestionEntry(top, vars_map[key], width=28, values_provider=lambda var=vars_map[key]: merge_lookup_values(var.get(), self.db.recent_relationships()))
                select.configure_values(merge_lookup_values(vars_map[key].get(), self.db.recent_relationships()))
                select.grid(row=idx, column=1, sticky="ew")
                edit_widgets.append(select.entry)
            else:
                widget = self._make_entry(
                    top,
                    vars_map[key],
                    width=34,
                    validate_digits=key in {"envelope_no", "meal_ticket_count"},
                    validate_amount=key == "amount",
                )
                widget.grid(row=idx, column=1, sticky="w")
                if key == "amount":
                    widget.bind("<FocusOut>", lambda _event, var=vars_map[key]: self._format_amount_var(var))
                edit_widgets.append(widget)

        def save() -> None:
            if self.db.name_exists(str(entry["mode"]), vars_map["name"].get(), exclude_id=str(entry["id"])):
                if not messagebox.askyesno("동명이인 확인", "같은 이름의 정상 기록이 있습니다. 계속 수정할까요?"):
                    return
            try:
                self.db.update_entry(
                    str(entry["id"]),
                    {
                        "mode": entry["mode"],
                        "envelope_no": parse_required_int(vars_map["envelope_no"].get(), "봉투번호", 1),
                        "name": vars_map["name"].get(),
                        "group_name": vars_map["group_name"].get(),
                        "relationship": vars_map["relationship"].get(),
                        "amount": parse_amount(vars_map["amount"].get()),
                        "meal_ticket_count": parse_required_int(vars_map["meal_ticket_count"].get() or "0", "식권 수", 0),
                        "payment_method": payment_label_to_key(vars_map["payment_method"].get()),
                        "memo": vars_map["memo"].get(),
                    },
                    reason=vars_map["reason"].get(),
                )
            except ValueError as exc:
                messagebox.showerror("수정 실패", str(exc))
                return
            self.auto_backup_if_due()
            top.destroy()
            self.refresh_all()

        self._button(top, "수정 저장", save, variant="primary", width=104, bg_color=BG).grid(row=11, column=1, sticky="e", pady=16)
        self._bind_safe_focus_chain(edit_widgets, save)
        edit_widgets[1].focus_set()

    def void_selected(self) -> None:
        entry_id = self.selected_entry_id(self.search_tree)
        if not entry_id:
            messagebox.showinfo("선택 필요", "취소 처리할 기록을 선택하세요.")
            return
        reason = simpledialog.askstring("취소 사유", "취소 사유를 입력하세요.", parent=self)
        if reason is None:
            return
        if not messagebox.askyesno("취소 처리", "삭제하지 않고 취소 상태로 변경합니다. 계속할까요?"):
            return
        try:
            self.db.void_entry(entry_id, reason)
        except ValueError as exc:
            messagebox.showerror("실패", str(exc))
            return
        self.auto_backup_if_due()
        self.refresh_all()

    def restore_selected(self) -> None:
        entry_id = self.selected_entry_id(self.search_tree)
        if not entry_id:
            messagebox.showinfo("선택 필요", "복구할 기록을 선택하세요.")
            return
        reason = simpledialog.askstring("복구 사유", "복구 사유를 입력하세요.", parent=self)
        if reason is None:
            return
        try:
            self.db.restore_entry(entry_id, reason)
        except ValueError as exc:
            messagebox.showerror("실패", str(exc))
            return
        self.auto_backup_if_due()
        self.refresh_all()

    def build_summary_tab(self) -> None:
        cards = ttk.Frame(self.summary_tab)
        cards.pack(fill="x", pady=(0, 14))
        self.summary_vars = {
            "count": tk.StringVar(),
            "total": tk.StringVar(),
            "tickets": tk.StringVar(),
            "cash": tk.StringVar(),
            "transfer": tk.StringVar(),
            "other": tk.StringVar(),
            "gaps": tk.StringVar(),
            "duplicates": tk.StringVar(),
        }
        labels = [
            ("정상 기록", "count"),
            ("총 축의금", "total"),
            ("총 식권 수", "tickets"),
            ("현금 합계", "cash"),
            ("계좌 합계", "transfer"),
            ("기타 합계", "other"),
            ("누락 봉투", "gaps"),
            ("동명이인", "duplicates"),
        ]
        for index, (title, key) in enumerate(labels):
            frame = ttk.Frame(cards, padding=12, style="Card.TFrame")
            frame.grid(row=index // 4, column=index % 4, sticky="ew", padx=5, pady=5)
            ttk.Label(frame, text=title, style="CardMuted.TLabel").pack(anchor="w")
            ttk.Label(frame, textvariable=self.summary_vars[key], style="CardValue.TLabel").pack(anchor="w")

        compare = ttk.Frame(self.summary_tab, padding=14, style="Card.TFrame")
        compare.pack(fill="x", pady=(0, 12))
        self.actual_envelope_var = tk.StringVar()
        self.actual_cash_var = tk.StringVar()
        self.compare_result_var = tk.StringVar()
        ttk.Label(compare, text="실제 봉투 수", style="Card.TLabel").pack(side="left")
        actual_envelope_entry = self._make_entry(compare, self.actual_envelope_var, width=10, validate_digits=True)
        actual_envelope_entry.pack(side="left", padx=6)
        ttk.Label(compare, text="실제 현금", style="Card.TLabel").pack(side="left", padx=(12, 0))
        actual_cash_entry = self._make_entry(compare, self.actual_cash_var, width=16, validate_amount=True)
        actual_cash_entry.pack(side="left", padx=6)
        actual_cash_entry.bind("<FocusOut>", lambda _event: self._format_amount_var(self.actual_cash_var))
        self._button(compare, "검증", self.compare_actuals, variant="primary", width=78).pack(side="left", padx=8)
        ttk.Label(compare, textvariable=self.compare_result_var, style="CardDanger.TLabel").pack(side="left", padx=10)
        self._bind_safe_focus_chain([actual_envelope_entry, actual_cash_entry], self.compare_actuals)

        ttk.Label(self.summary_tab, text="모임별 합계", style="Title.TLabel").pack(anchor="w", pady=(4, 8))
        self.group_tree = self._create_tree(
            self.summary_tab,
            ("group", "count", "amount", "tickets"),
            ("모임", "건수", "총액", "식권 수"),
        )
        self.group_tree.pack(fill="both", expand=True)

    def refresh_summary(self) -> None:
        if not hasattr(self, "summary_vars"):
            return
        summary = self.db.summary()
        self.summary_vars["count"].set(f"{summary['active_count']:,}건")
        self.summary_vars["total"].set(format_won(summary["total_amount"]))
        self.summary_vars["tickets"].set(f"{summary['total_tickets']:,}장")
        self.summary_vars["cash"].set(format_won(summary["payment_totals"]["cash"]))
        self.summary_vars["transfer"].set(format_won(summary["payment_totals"]["transfer"]))
        self.summary_vars["other"].set(format_won(summary["payment_totals"]["other"]))
        gaps = summary["envelope_gaps"]
        self.summary_vars["gaps"].set(", ".join(map(str, gaps[:8])) + ("..." if len(gaps) > 8 else "") if gaps else "없음")
        duplicates = summary["duplicate_names"]
        self.summary_vars["duplicates"].set(", ".join(item["name"] for item in duplicates[:4]) if duplicates else "없음")
        for item in self.group_tree.get_children():
            self.group_tree.delete(item)
        for item in summary["group_totals"]:
            self.group_tree.insert("", "end", values=(item["group_name"], item["count"], format_won(item["total_amount"]), item["total_tickets"]))

    def compare_actuals(self) -> None:
        summary = self.db.summary()
        messages: list[str] = []
        if self.actual_envelope_var.get().strip():
            actual_count = int(parse_amount(self.actual_envelope_var.get()))
            diff = actual_count - int(summary["active_count"])
            messages.append(f"봉투 차이 {diff:+d}건")
        if self.actual_cash_var.get().strip():
            actual_cash = parse_amount(self.actual_cash_var.get())
            diff_cash = actual_cash - int(summary["payment_totals"]["cash"])
            messages.append(f"현금 차이 {diff_cash:+,}원")
        self.compare_result_var.set(" / ".join(messages) if messages else "검증값을 입력하세요.")

    def build_settings_tab(self) -> None:
        self.settings_text_var = tk.StringVar()
        settings_card = ttk.Frame(self.settings_tab, padding=18, style="Card.TFrame")
        settings_card.pack(anchor="nw", fill="x")
        ttk.Label(settings_card, text="설정/백업", style="CardTitle.TLabel").pack(anchor="w", pady=(0, 10))
        ttk.Label(settings_card, textvariable=self.settings_text_var, style="CardMuted.TLabel").pack(anchor="w", pady=(0, 14))
        buttons = ttk.Frame(settings_card, style="Card.TFrame")
        buttons.pack(anchor="w")
        self._button(buttons, "테스트 모드로 전환", lambda: self.switch_mode(MODE_TEST), width=164).grid(row=0, column=0, padx=5, pady=5, sticky="ew")
        self._button(buttons, "운영 모드로 전환", lambda: self.switch_mode(MODE_LIVE), variant="primary", width=164).grid(row=0, column=1, padx=5, pady=5, sticky="ew")
        self._button(buttons, "테스트 데이터 초기화", self.clear_test_data, variant="danger", width=164).grid(row=1, column=0, padx=5, pady=5, sticky="ew")
        self._button(buttons, "엑셀 추출", self.export_excel, width=164).grid(row=1, column=1, padx=5, pady=5, sticky="ew")
        self._button(buttons, "수동 백업 생성", self.manual_backup, width=164).grid(row=2, column=0, padx=5, pady=5, sticky="ew")
        self._button(buttons, "백업 복원", self.restore_backup, width=164).grid(row=2, column=1, padx=5, pady=5, sticky="ew")
        self._button(buttons, "비밀번호 변경", self.change_password_dialog, width=164).grid(row=3, column=0, padx=5, pady=5, sticky="ew")

    def refresh_settings(self) -> None:
        if hasattr(self, "settings_text_var"):
            self.settings_text_var.set(f"데이터 위치: {self.db.app_dir}")

    def switch_mode(self, mode: str) -> None:
        if mode == MODE_LIVE and not messagebox.askyesno("운영 모드 전환", "운영 모드에서는 실제 기록을 입력합니다. 전환할까요?"):
            return
        self.db.set_mode(mode)
        self.refresh_all()

    def clear_test_data(self) -> None:
        if self.db.get_mode() == MODE_LIVE:
            messagebox.showerror("차단됨", "운영 모드에서는 테스트 데이터 초기화를 실행할 수 없습니다.")
            return
        if not messagebox.askyesno("테스트 데이터 초기화", "테스트 모드 기록을 모두 삭제합니다. 계속할까요?"):
            return
        backup = self.db.clear_test_data()
        messagebox.showinfo("완료", f"초기화 전 백업을 생성했습니다.\n{backup}")
        self.refresh_all()

    def export_excel(self) -> None:
        default_name = "wedding_ledger_export.xls"
        path = filedialog.asksaveasfilename(
            title="엑셀 파일 저장",
            defaultextension=".xls",
            initialfile=default_name,
            filetypes=[("Excel 97-2003 Workbook", "*.xls")],
        )
        if not path:
            return
        backup = self.db.create_backup("before_export")
        mode = self.db.get_mode()
        entries = self.db.find_entries({"mode": mode})
        summary = self.db.summary(mode)
        output = export_xls(Path(path), entries, summary, self.db.audit_rows())
        messagebox.showinfo("엑셀 추출 완료", f"저장: {output}\n백업: {backup}")

    def manual_backup(self) -> None:
        backup = self.db.create_backup("manual")
        messagebox.showinfo("백업 완료", str(backup))

    def restore_backup(self) -> None:
        path = filedialog.askopenfilename(
            title="복원할 백업 선택",
            initialdir=self.db.backup_dir,
            filetypes=[("SQLite backup", "*.sqlite3"), ("All files", "*.*")],
        )
        if not path:
            return
        if not messagebox.askyesno("백업 복원", "현재 DB를 백업한 뒤 선택한 백업으로 교체합니다. 계속할까요?"):
            return
        before = self.db.restore_from_backup(path)
        messagebox.showinfo("복원 완료", f"복원 전 현재 DB 백업: {before}")
        self.refresh_all()

    def change_password_dialog(self) -> None:
        top = tk.Toplevel(self)
        top.title("비밀번호 변경")
        top.geometry("440x260")
        top.configure(bg=BG)
        top.grab_set()
        current_var = tk.StringVar()
        new_var = tk.StringVar()
        confirm_var = tk.StringVar()
        ttk.Label(top, text="비밀번호 변경", style="Title.TLabel").grid(row=0, column=0, columnspan=2, sticky="w", padx=24, pady=(24, 12))
        password_widgets: list[tk.Entry] = []
        fields = [
            ("현재 비밀번호", current_var, False),
            ("새 비밀번호", new_var, False),
            ("새 비밀번호 확인", confirm_var, False),
        ]
        for idx, (label, var, digits_only) in enumerate(fields, start=1):
            ttk.Label(top, text=label).grid(row=idx, column=0, sticky="e", padx=8, pady=8)
            entry = self._make_entry(top, var, width=28, validate_digits=digits_only, show="*")
            entry.grid(row=idx, column=1, sticky="w")
            password_widgets.append(entry)

        def submit() -> None:
            if new_var.get() != confirm_var.get():
                messagebox.showerror("확인 필요", "새 비밀번호 확인이 일치하지 않습니다.")
                return
            try:
                validate_password(new_var.get())
            except ValueError as exc:
                messagebox.showerror("확인 필요", str(exc))
                return
            try:
                ok = self.db.change_password(current_var.get(), new_var.get())
            except ValueError as exc:
                messagebox.showerror("확인 필요", str(exc))
                return
            if not ok:
                messagebox.showerror("실패", "현재 비밀번호가 올바르지 않습니다.")
                return
            messagebox.showinfo("완료", "비밀번호가 변경되었습니다.")
            top.destroy()

        self._button(top, "변경", submit, variant="primary", width=82, bg_color=BG).grid(row=4, column=1, sticky="e", pady=12)
        self._bind_safe_focus_chain(password_widgets, submit)
        password_widgets[0].focus_set()

    def on_close(self) -> None:
        try:
            if self.db.is_configured():
                self.db.create_backup("on_close")
        except Exception:
            pass
        self.db.close()
        self.destroy()


def main() -> None:
    app = WeddingLedgerApp()
    app.mainloop()
