"""Панель журнала."""

from __future__ import annotations

import tkinter as tk
from tkinter import filedialog, scrolledtext, ttk


class LogPanel(ttk.Frame):
    def __init__(self, master: tk.Misc, **kwargs: object) -> None:
        super().__init__(master, **kwargs)
        ttk.Label(self, text="Журнал").pack(anchor=tk.W)
        self.text = scrolledtext.ScrolledText(
            self,
            height=12,
            state=tk.DISABLED,
            font=("Consolas", 9),
            wrap=tk.WORD,
        )
        self.text.pack(fill=tk.BOTH, expand=True, pady=4)
        self.text.tag_configure("stdout", foreground="#1a1a1a")
        self.text.tag_configure("stderr", foreground="#c0392b")
        self.text.tag_configure("info", foreground="#1565c0")

        btn_row = ttk.Frame(self)
        btn_row.pack(fill=tk.X)
        ttk.Button(btn_row, text="Сохранить лог…", command=self.save_log).pack(
            side=tk.LEFT, padx=2
        )
        ttk.Button(btn_row, text="Очистить", command=self.clear).pack(side=tk.LEFT, padx=2)

    def append(self, stream: str, line: str) -> None:
        tag = stream if stream in ("stdout", "stderr", "info") else "stdout"
        self.text.configure(state=tk.NORMAL)
        self.text.insert(tk.END, line + "\n", tag)
        self.text.see(tk.END)
        self.text.configure(state=tk.DISABLED)

    def clear(self) -> None:
        self.text.configure(state=tk.NORMAL)
        self.text.delete("1.0", tk.END)
        self.text.configure(state=tk.DISABLED)

    def save_log(self) -> None:
        path = filedialog.asksaveasfilename(
            title="Сохранить журнал",
            defaultextension=".txt",
            filetypes=[("Текстовые файлы", "*.txt"), ("Все файлы", "*.*")],
        )
        if not path:
            return
        content = self.text.get("1.0", tk.END)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
