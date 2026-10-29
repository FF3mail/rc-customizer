"""Блок подключения SSH."""

from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import filedialog, ttk
from typing import Callable

from logic.validators import list_key_files
from ui.widgets import LabeledEntry


class ConnectionFrame(ttk.LabelFrame):
    def __init__(
        self,
        master: tk.Misc,
        on_connect: Callable[[], None],
        on_disconnect: Callable[[], None],
        **kwargs: object,
    ) -> None:
        super().__init__(master, text="Подключение", padding=8, **kwargs)
        self.on_connect = on_connect
        self.on_disconnect = on_disconnect

        row1 = ttk.Frame(self)
        row1.pack(fill=tk.X, pady=2)
        self.host = LabeledEntry(row1, "Хост", width=28)
        self.host.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 8))
        self.port = LabeledEntry(row1, "Порт", width=6)
        self.port.var.set("22")
        self.port.pack(side=tk.LEFT)
        self.user = LabeledEntry(row1, "Пользователь", width=12)
        self.user.var.set("root")
        self.user.pack(side=tk.LEFT, padx=(8, 0))

        row2 = ttk.Frame(self)
        row2.pack(fill=tk.X, pady=2)
        self.key_folder_var = tk.StringVar()
        ttk.Label(row2, text="Каталог ключа", width=18).pack(side=tk.LEFT)
        ttk.Entry(row2, textvariable=self.key_folder_var, width=36).pack(
            side=tk.LEFT, fill=tk.X, expand=True
        )
        ttk.Button(row2, text="Обзор…", command=self._browse_folder).pack(
            side=tk.LEFT, padx=4
        )

        row3 = ttk.Frame(self)
        row3.pack(fill=tk.X, pady=2)
        ttk.Label(row3, text="Файл ключа", width=18).pack(side=tk.LEFT)
        self.key_file_var = tk.StringVar()
        self.key_combo = ttk.Combobox(
            row3, textvariable=self.key_file_var, width=34, state="readonly"
        )
        self.key_combo.pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(row3, text="Файл…", command=self._browse_key_file).pack(
            side=tk.LEFT, padx=4
        )
        self.key_folder_var.trace_add("write", lambda *_: self._refresh_keys())

        row4 = ttk.Frame(self)
        row4.pack(fill=tk.X, pady=2)
        self.passphrase = LabeledEntry(row4, "Passphrase", show="*", width=40)
        self.passphrase.pack(fill=tk.X)
        self.password = LabeledEntry(row4, "Пароль (альт.)", show="*", width=40)
        self.password.pack(fill=tk.X, pady=2)

        row5 = ttk.Frame(self)
        row5.pack(fill=tk.X, pady=4)
        self.connect_btn = ttk.Button(row5, text="Подключить", command=on_connect)
        self.connect_btn.pack(side=tk.LEFT, padx=2)
        self.disconnect_btn = ttk.Button(
            row5, text="Отключить", command=on_disconnect, state=tk.DISABLED
        )
        self.disconnect_btn.pack(side=tk.LEFT, padx=2)
        self.status_var = tk.StringVar(value="Отключено")
        ttk.Label(row5, textvariable=self.status_var, foreground="#555").pack(
            side=tk.LEFT, padx=12
        )

        self.use_local_var = tk.BooleanVar(value=False)
        local_row = ttk.Frame(self)
        local_row.pack(fill=tk.X, pady=2)
        ttk.Checkbutton(
            local_row,
            text="Использовать локальный каталог дистрибутива",
            variable=self.use_local_var,
        ).pack(side=tk.LEFT)
        self.local_distro_var = tk.StringVar()
        ttk.Entry(local_row, textvariable=self.local_distro_var, width=30).pack(
            side=tk.LEFT, padx=4, fill=tk.X, expand=True
        )
        ttk.Button(local_row, text="Обзор…", command=self._browse_distro).pack(
            side=tk.LEFT
        )

    def _browse_folder(self) -> None:
        path = filedialog.askdirectory(title="Каталог с приватным ключом")
        if path:
            self.key_folder_var.set(path)

    def _browse_key_file(self) -> None:
        path = filedialog.askopenfilename(title="Файл приватного ключа")
        if path:
            self.key_file_var.set(path)

    def _browse_distro(self) -> None:
        path = filedialog.askdirectory(title="Каталог Full_customize_GROK")
        if path:
            self.local_distro_var.set(path)

    def _refresh_keys(self) -> None:
        folder = self.key_folder_var.get().strip()
        if not folder:
            self.key_combo["values"] = ()
            return
        keys = list_key_files(Path(folder))
        values = [str(k) for k in keys]
        self.key_combo["values"] = values
        if values and not self.key_file_var.get():
            self.key_file_var.set(values[0])

    def set_connected(self, connected: bool) -> None:
        state = tk.DISABLED if connected else tk.NORMAL
        self.connect_btn.configure(state=state)
        self.disconnect_btn.configure(
            state=tk.NORMAL if connected else tk.DISABLED
        )
        for w in (
            self.host,
            self.port,
            self.user,
            self.passphrase,
            self.password,
        ):
            w.set_state(state)
        self.key_combo.configure(state="readonly" if not connected else tk.DISABLED)

    def set_status(self, text: str, error: bool = False) -> None:
        self.status_var.set(text)

    def clear_secrets(self) -> None:
        self.passphrase.clear()
        self.password.clear()

    def get_connection_params(self) -> dict[str, str | int | None]:
        return {
            "host": self.host.get().strip(),
            "port_str": self.port.get().strip(),
            "username": self.user.get().strip(),
            "key_path": self.key_file_var.get().strip() or None,
            "passphrase": self.passphrase.get() or None,
            "password": self.password.get() or None,
            "key_folder": self.key_folder_var.get().strip(),
            "local_distro": self.local_distro_var.get().strip()
            if self.use_local_var.get()
            else None,
        }
