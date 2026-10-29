"""Диалог параметров кастомизации."""

from __future__ import annotations

import tkinter as tk
from tkinter import filedialog, ttk
from typing import Callable

from logic.commands import CustomizeOptions
from logic.validators import validate_color

COLOR_FIELDS: list[tuple[str, str, str]] = [
    ("text_color", "Цвет надписи", "#ffffff"),
    ("form_bg", "Фон формы", "rgba(255,255,255,0.92)"),
    ("input_bg", "Фон полей", "#ffffff"),
    ("input_color", "Текст полей", "#212529"),
    ("input_border", "Рамка полей", "#ced4da"),
    ("input_focus", "Рамка (фокус)", "#37beff"),
    ("button_bg", "Фон кнопки", "#37beff"),
    ("button_color", "Текст кнопки", "#ffffff"),
]


class CustomizeDialog(tk.Toplevel):
    def __init__(
        self,
        master: tk.Misc,
        on_apply: Callable[[CustomizeOptions, str | None, str | None], None],
    ) -> None:
        super().__init__(master)
        self.title("Кастомизация Roundcube")
        self.geometry("600x560")
        self.resizable(True, True)
        self.transient(master)
        self.grab_set()
        self.on_apply = on_apply

        self.logo_path: str | None = None
        self.bg_path: str | None = None
        self.color_vars: dict[str, tk.StringVar] = {}
        self.color_entries: dict[str, ttk.Entry] = {}
        self._invalid_colors: set[str] = set()

        body = ttk.Frame(self, padding=10)
        body.pack(fill=tk.BOTH, expand=True)

        self._file_row(body, "Логотип", self._pick_logo, self._clear_logo)
        self.logo_label = ttk.Label(body, text="—", wraplength=520)
        self.logo_label.pack(anchor=tk.W, pady=(0, 8))

        self._file_row(body, "Фон", self._pick_bg, self._clear_bg)
        self.bg_label = ttk.Label(body, text="—", wraplength=520)
        self.bg_label.pack(anchor=tk.W, pady=(0, 8))

        ttk.Label(body, text="Название продукта").pack(anchor=tk.W)
        self.text_var = tk.StringVar()
        ttk.Entry(body, textvariable=self.text_var, width=50).pack(
            fill=tk.X, pady=(0, 8)
        )

        ttk.Label(body, text="Цвета").pack(anchor=tk.W, pady=(4, 2))
        colors_frame = ttk.Frame(body)
        colors_frame.pack(fill=tk.X)
        for key, label, default in COLOR_FIELDS:
            row = ttk.Frame(colors_frame)
            row.pack(fill=tk.X, pady=1)
            ttk.Label(row, text=label, width=22).pack(side=tk.LEFT)
            var = tk.StringVar(value=default)
            self.color_vars[key] = var
            ent = ttk.Entry(row, textvariable=var, width=32)
            ent.pack(side=tk.LEFT, fill=tk.X, expand=True)
            ent.bind("<FocusOut>", lambda _e, k=key: self._validate_color_field(k))
            self.color_entries[key] = ent

        self.dry_run_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(body, text="Dry-run (без изменений на сервере)", variable=self.dry_run_var).pack(
            anchor=tk.W, pady=8
        )

        btn_row = ttk.Frame(body)
        btn_row.pack(fill=tk.X, pady=8)
        self.apply_btn = ttk.Button(btn_row, text="Применить", command=self._apply)
        self.apply_btn.pack(side=tk.RIGHT, padx=4)
        ttk.Button(btn_row, text="Отмена", command=self.destroy).pack(side=tk.RIGHT)

        self._update_apply_state()

    def _file_row(
        self, parent: ttk.Frame, title: str, pick_cmd: Callable[[], None], clear_cmd: Callable[[], None]
    ) -> None:
        row = ttk.Frame(parent)
        row.pack(fill=tk.X, pady=2)
        ttk.Label(row, text=title, width=12).pack(side=tk.LEFT)
        ttk.Button(row, text="Выбрать…", command=pick_cmd).pack(side=tk.LEFT, padx=2)
        ttk.Button(row, text="Очистить", command=clear_cmd).pack(side=tk.LEFT)

    def _pick_logo(self) -> None:
        path = filedialog.askopenfilename(
            title="Логотип",
            filetypes=[
                ("Изображения", "*.png *.jpg *.jpeg *.svg *.webp"),
                ("Все файлы", "*.*"),
            ],
        )
        if path:
            self.logo_path = path
            self.logo_label.configure(text=path)

    def _clear_logo(self) -> None:
        self.logo_path = None
        self.logo_label.configure(text="—")

    def _pick_bg(self) -> None:
        path = filedialog.askopenfilename(
            title="Фон",
            filetypes=[
                ("Изображения", "*.png *.jpg *.jpeg *.webp"),
                ("Все файлы", "*.*"),
            ],
        )
        if path:
            self.bg_path = path
            self.bg_label.configure(text=path)

    def _clear_bg(self) -> None:
        self.bg_path = None
        self.bg_label.configure(text="—")

    def _validate_color_field(self, key: str) -> None:
        value = self.color_vars[key].get()
        ent = self.color_entries[key]
        if validate_color(value):
            self._invalid_colors.discard(key)
            ent.configure(style="TEntry")
        else:
            self._invalid_colors.add(key)
            ent.configure(style="Invalid.TEntry")
        self._update_apply_state()

    def _update_apply_state(self) -> None:
        if self._invalid_colors:
            self.apply_btn.configure(state=tk.DISABLED)
        else:
            self.apply_btn.configure(state=tk.NORMAL)

    def _apply(self) -> None:
        for key in self.color_vars:
            self._validate_color_field(key)
        if self._invalid_colors:
            return
        opts = CustomizeOptions(dry_run=self.dry_run_var.get())
        text = self.text_var.get().strip()
        if text:
            opts.text = text
        defaults = {k: d for k, _l, d in COLOR_FIELDS}
        for key, var in self.color_vars.items():
            val = var.get().strip()
            if val and val != defaults.get(key):
                setattr(opts, key, val)
            elif val and key in defaults and val == defaults[key]:
                setattr(opts, key, val)
        self.on_apply(opts, self.logo_path, self.bg_path)
        self.destroy()
