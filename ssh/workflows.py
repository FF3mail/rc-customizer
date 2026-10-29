"""Высокоуровневые сценарии SSH."""

from __future__ import annotations

import os
from collections.abc import Iterator, Callable
from datetime import datetime, timezone

from logic.commands import (
    CustomizeOptions,
    build_customize_argv,
    build_install_shell_argv,
    build_rm_distro_argv,
    build_rm_upload_argv,
    build_rollback_argv,
    build_test_argv,
    build_uninstall_argv,
)
from ssh.client import SSHClientWrapper, SSHError

Event = tuple[str, str]
QueueWriter = Callable[[Event], None]

REMOTE_DISTRO = "/tmp/Full_customize_GROK"


def _emit(writer: QueueWriter, stream: str, line: str) -> None:
    writer((stream, line))


def _run_argv(
    ssh: SSHClientWrapper,
    writer: QueueWriter,
    argv: list[str],
    timeout: int = 60,
) -> None:
    tail: list[tuple[str, str]] = []
    code, lines = ssh.run_command_collect(argv, timeout=timeout)
    for stream, line in lines:
        writer((stream, line))
        tail.append((stream, line))
        if len(tail) > 20:
            tail.pop(0)
    if code != 0:
        msg = f"Код выхода: {code}"
        if tail:
            msg += "\n" + "\n".join(f"[{s}] {l}" for s, l in tail[-20:])
        raise SSHError(msg)


def run_test(ssh: SSHClientWrapper, writer: QueueWriter) -> None:
    _emit(writer, "info", "Запуск проверки окружения (customize_roundcube --test)...")
    _run_argv(ssh, writer, build_test_argv())


def _upload_distro(ssh: SSHClientWrapper, writer: QueueWriter, local_distro: str) -> None:
    _emit(writer, "info", "Очистка /tmp/Full_customize_GROK на сервере...")
    code, lines = ssh.run_command_collect(build_rm_distro_argv(), timeout=30)
    for ev in lines:
        writer(ev)
    if code not in (0, 1):
        pass
    _emit(writer, "info", "Загрузка дистрибутива по SFTP...")
    ssh.upload_tree(local_distro, REMOTE_DISTRO)
    _emit(writer, "info", "Загрузка завершена.")


def run_install(ssh: SSHClientWrapper, writer: QueueWriter, local_distro: str) -> None:
    _upload_distro(ssh, writer, local_distro)
    _emit(writer, "info", "Запуск install.sh...")
    _run_argv(ssh, writer, build_install_shell_argv(), timeout=120)
    _emit(writer, "info", "Проверка после установки...")
    _run_argv(ssh, writer, build_test_argv())


def run_customize(
    ssh: SSHClientWrapper,
    writer: QueueWriter,
    opts: CustomizeOptions,
    local_logo: str | None,
    local_bg: str | None,
) -> None:
    upload_dir: str | None = None
    try:
        if local_logo or local_bg:
            ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
            upload_dir = f"/tmp/rc_upload_{ts}"
            pairs: list[tuple[str, str]] = []
            if local_logo:
                name = os.path.basename(local_logo)
                remote = f"{upload_dir}/{name}"
                opts.logo_remote = remote
                pairs.append((local_logo, remote))
            if local_bg:
                name = os.path.basename(local_bg)
                remote = f"{upload_dir}/{name}"
                opts.background_remote = remote
                pairs.append((local_bg, remote))
            _emit(writer, "info", f"Загрузка файлов в {upload_dir}...")
            ssh.run_command_collect(["mkdir", "-p", upload_dir], timeout=15)
            ssh.upload_files(pairs)

        argv = build_customize_argv(opts)
        _emit(writer, "info", "Запуск кастомизации...")
        _run_argv(ssh, writer, argv, timeout=120)

        if upload_dir:
            _emit(writer, "info", f"Удаление временного каталога {upload_dir}...")
            _run_argv(ssh, writer, build_rm_upload_argv(upload_dir))
            upload_dir = None
    except Exception:
        if upload_dir:
            _emit(
                writer,
                "info",
                f"Временные файлы оставлены на сервере: {upload_dir}",
            )
        raise


def run_rollback(ssh: SSHClientWrapper, writer: QueueWriter) -> None:
    _emit(writer, "info", "Откат кастомизации...")
    _run_argv(ssh, writer, build_rollback_argv(), timeout=120)


def _ensure_distro(ssh: SSHClientWrapper, writer: QueueWriter, local_distro: str) -> None:
    if ssh.remote_path_exists(f"{REMOTE_DISTRO}/uninstall.sh"):
        return
    _emit(writer, "info", "Дистрибутив в /tmp отсутствует — повторная загрузка...")
    _upload_distro(ssh, writer, local_distro)


def run_uninstall(
    ssh: SSHClientWrapper,
    writer: QueueWriter,
    local_distro: str,
    rollback: bool,
    remove_backups: bool,
) -> None:
    _ensure_distro(ssh, writer, local_distro)
    _emit(writer, "info", "Запуск uninstall.sh...")
    _run_argv(
        ssh,
        writer,
        build_uninstall_argv(rollback, remove_backups),
        timeout=120,
    )


def workflow_runner(
    ssh: SSHClientWrapper,
    writer: QueueWriter,
    fn: Callable[[], None],
) -> Iterator[Event]:
    try:
        fn()
        writer(("info", "Готово."))
    except SSHError as exc:
        writer(("stderr", str(exc)))
        writer(("info", "Операция завершилась с ошибкой."))
    except Exception as exc:
        writer(("stderr", f"Необработанная ошибка: {type(exc).__name__}"))
        writer(("info", "Операция завершилась с ошибкой."))
