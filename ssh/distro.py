"""Путь к дистрибутиву Full_customize_GROK (bundled / dev / override)."""

from __future__ import annotations

import sys
from pathlib import Path

DISTRO_DIR_NAME = "Full_customize_GROK"


def _repo_bundled_path() -> Path:
    root = Path(__file__).resolve().parent.parent
    candidates = [
        root / "resources" / DISTRO_DIR_NAME,
        root.parent,
    ]
    for path in candidates:
        if _is_valid_distro(path):
            return path
    return candidates[0]


def _is_valid_distro(path: Path) -> bool:
    return (path / "install.sh").is_file() and (path / "lib" / "common.sh").is_file()


def resolve_distro_path(local_override: str | None = None) -> Path:
    if local_override:
        override = Path(local_override).resolve()
        if not _is_valid_distro(override):
            raise FileNotFoundError(
                f"Некорректный каталог дистрибутива: {override}"
            )
        return override
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        bundled = Path(meipass) / "resources" / DISTRO_DIR_NAME
        if _is_valid_distro(bundled):
            return bundled
    return _repo_bundled_path()
