"""Валидация полей формы."""

from __future__ import annotations

import re
from pathlib import Path

COLOR_RE = re.compile(
    r"^(#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}|rgba?\([0-9,.\s]+\))$"
)
USERNAME_RE = re.compile(r"^[a-zA-Z0-9._-]+$")

KEY_PATTERNS = ("id_rsa", "id_ed25519")
KEY_SUFFIXES = (".pem", ".key")


def validate_host(host: str) -> str | None:
    h = host.strip()
    if not h:
        return "Укажите хост"
    if ".." in h:
        return "Недопустимый хост"
    return None


def validate_port(port_str: str) -> tuple[int | None, str | None]:
    try:
        port = int(port_str.strip())
    except ValueError:
        return None, "Порт должен быть числом"
    if port < 1 or port > 65535:
        return None, "Порт должен быть от 1 до 65535"
    return port, None


def validate_username(username: str) -> str | None:
    u = username.strip()
    if not u:
        return "Укажите имя пользователя"
    if not USERNAME_RE.fullmatch(u):
        return "Недопустимые символы в имени пользователя"
    return None


def validate_color(value: str) -> bool:
    if not value.strip():
        return True
    v = value.strip()
    if not COLOR_RE.fullmatch(v):
        return False
    if v.lower().startswith("rgb") and "," not in v:
        return False
    return True


def list_key_files(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    found: list[Path] = []
    for p in sorted(folder.iterdir()):
        if not p.is_file():
            continue
        name = p.name.lower()
        if name in KEY_PATTERNS or name.endswith(KEY_SUFFIXES):
            found.append(p)
    return found


def validate_key_folder(folder: str) -> tuple[list[Path], str | None]:
    if not folder.strip():
        return [], None
    path = Path(folder.strip())
    if not path.is_dir():
        return [], "Каталог ключей не найден"
    keys = list_key_files(path)
    if not keys and not any(p.is_file() for p in path.iterdir()):
        return [], "В каталоге нет файлов"
    return keys, None
