"""Построение argv для удалённых команд."""

from __future__ import annotations

import shlex
from dataclasses import dataclass

# Путь после install.sh (не symlink — иначе старые версии ломали SCRIPT_DIR)
INSTALLED_CUSTOMIZE = "/usr/local/src/Full_customize_GROK/customize_roundcube.sh"


@dataclass
class CustomizeOptions:
    logo_remote: str | None = None
    background_remote: str | None = None
    text: str | None = None
    text_color: str | None = None
    form_bg: str | None = None
    input_bg: str | None = None
    input_color: str | None = None
    input_border: str | None = None
    input_focus: str | None = None
    button_bg: str | None = None
    button_color: str | None = None
    dry_run: bool = False


def to_remote_argv(argv: list[str]) -> str:
    return " ".join(shlex.quote(a) for a in argv)


def build_customize_argv(opts: CustomizeOptions) -> list[str]:
    argv: list[str] = ["bash", INSTALLED_CUSTOMIZE]
    pairs: list[tuple[str, str | None]] = [
        ("--logo", opts.logo_remote),
        ("--background", opts.background_remote),
        ("--text", opts.text),
        ("--text-color", opts.text_color),
        ("--form-bg", opts.form_bg),
        ("--input-bg", opts.input_bg),
        ("--input-color", opts.input_color),
        ("--input-border", opts.input_border),
        ("--input-focus", opts.input_focus),
        ("--button-bg", opts.button_bg),
        ("--button-color", opts.button_color),
    ]
    for flag, value in pairs:
        if value:
            argv.extend([flag, value])
    if opts.dry_run:
        argv.append("--dry-run")
    return argv


def build_test_argv() -> list[str]:
    return ["bash", INSTALLED_CUSTOMIZE, "--test"]


def build_rollback_argv() -> list[str]:
    return ["bash", INSTALLED_CUSTOMIZE, "--rollback", "--yes"]


def build_install_shell_argv() -> list[str]:
    return ["bash", "/tmp/Full_customize_GROK/install.sh"]


def build_uninstall_argv(rollback: bool, remove_backups: bool) -> list[str]:
    argv = ["bash", "/tmp/Full_customize_GROK/uninstall.sh", "--yes"]
    if rollback:
        argv.append("--rollback")
    if remove_backups:
        argv.append("--remove-backups")
    return argv


def build_rm_distro_argv() -> list[str]:
    return ["rm", "-rf", "/tmp/Full_customize_GROK"]


def build_rm_upload_argv(remote_dir: str) -> list[str]:
    return ["rm", "-rf", remote_dir]
