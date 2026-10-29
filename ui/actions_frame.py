"""Блок действий на сервере."""

from __future__ import annotations

import tkinter as tk
from tkinter import ttk
from typing import Callable


class ActionsFrame(ttk.LabelFrame):
    def __init__(
        self,
        master: tk.Misc,
        on_test: Callable[[], None],
        on_install: Callable[[], None],
        on_customize: Callable[[], None],
        on_rollback: Callable[[], None],
        on_uninstall: Callable[[], None],
        **kwargs: object,
    ) -> None:
        super().__init__(master, text="Действия", padding=8, **kwargs)
        self._buttons: list[ttk.Button] = []
        self._test_btn: ttk.Button | None = None
        self._install_btn: ttk.Button | None = None
        self._busy = False
        self._connected = False
        self._test_ok = False

        specs = [
            ("Проверка окружения", on_test, "test"),
            ("Установить / обновить на сервере", on_install, "install"),
            ("Кастомизация…", on_customize, "full"),
            ("Откат кастомизации", on_rollback, "full"),
            ("Удалить с сервера…", on_uninstall, "full"),
        ]
        for text, cmd, group in specs:
            btn = ttk.Button(self, text=text, command=cmd, state=tk.DISABLED)
            btn.pack(fill=tk.X, pady=2)
            self._buttons.append(btn)
            if group == "test":
                self._test_btn = btn
            elif group == "install":
                self._install_btn = btn

        self.busy_var = tk.StringVar(value="")
        ttk.Label(self, textvariable=self.busy_var, foreground="#1565c0").pack(
            anchor=tk.W, pady=4
        )

    def _apply_button_states(self) -> None:
        if self._busy:
            for btn in self._buttons:
                btn.configure(state=tk.DISABLED)
            return
        for btn in self._buttons:
            btn.configure(state=tk.DISABLED)
        if self._connected and self._test_btn:
            self._test_btn.configure(state=tk.NORMAL)
        if self._connected and self._install_btn:
            self._install_btn.configure(state=tk.NORMAL)
        if self._connected and self._test_ok:
            for btn in self._buttons:
                btn.configure(state=tk.NORMAL)

    def set_enabled(self, connected: bool, test_ok: bool) -> None:
        self._connected = connected
        self._test_ok = test_ok
        self._apply_button_states()

    def set_busy(self, busy: bool, message: str = "") -> None:
        self._busy = busy
        self.busy_var.set(message)
        self._apply_button_states()
