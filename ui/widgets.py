"""Общие виджеты."""

from __future__ import annotations

import tkinter as tk
from tkinter import ttk


class LabeledEntry(ttk.Frame):
    def __init__(
        self,
        master: tk.Misc,
        label: str,
        textvariable: tk.StringVar | None = None,
        show: str | None = None,
        width: int = 40,
        **kwargs: object,
    ) -> None:
        super().__init__(master, **kwargs)
        ttk.Label(self, text=label, width=18).pack(side=tk.LEFT, padx=(0, 4))
        self.var = textvariable or tk.StringVar()
        entry_kwargs: dict = {"textvariable": self.var, "width": width}
        if show:
            entry_kwargs["show"] = show
        self.entry = ttk.Entry(self, **entry_kwargs)
        self.entry.pack(side=tk.LEFT, fill=tk.X, expand=True)

    def get(self) -> str:
        return self.var.get()

    def clear(self) -> None:
        self.var.set("")

    def set_state(self, state: str) -> None:
        self.entry.configure(state=state)
