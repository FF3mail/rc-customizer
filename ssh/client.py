"""Обёртка Paramiko для SSH/SFTP."""

from __future__ import annotations

import hashlib
import os
import re
import stat
import threading
from collections.abc import Iterator
from typing import Any

import paramiko

from logic.commands import to_remote_argv

CONNECT_TIMEOUT = 15
COMMAND_TIMEOUT = 60


def _load_private_key(path: str, passphrase: str | None) -> paramiko.PKey:
    loaders = (
        paramiko.RSAKey.from_private_key_file,
        paramiko.Ed25519Key.from_private_key_file,
        paramiko.ECDSAKey.from_private_key_file,
    )
    last_exc: Exception | None = None
    for loader in loaders:
        try:
            return loader(path, password=passphrase)
        except paramiko.PasswordRequiredException:
            raise SSHError("Ключ зашифрован — укажите passphrase") from None
        except Exception as exc:
            last_exc = exc
    raise SSHError(
        scrub_message(str(last_exc) if last_exc else "Не удалось загрузить ключ", [])
    )


class SSHError(Exception):
    """Ошибка SSH без чувствительных данных."""


def scrub_message(msg: str, secrets: list[str]) -> str:
    out = msg
    for secret in secrets:
        if secret:
            out = out.replace(secret, "***")
    out = re.sub(r"(?i)(password|passphrase|secret)[^\s]*", r"\1=***", out)
    return out


def _host_key_fingerprints(key: paramiko.PKey) -> tuple[str, str]:
    blob = key.asbytes()
    md5 = hashlib.md5(blob).hexdigest()
    md5_fp = ":".join(md5[i : i + 2] for i in range(0, len(md5), 2))
    sha256 = hashlib.sha256(blob).digest()
    import base64

    sha256_fp = base64.b64encode(sha256).decode().rstrip("=")
    return md5_fp, f"SHA256:{sha256_fp}"


class SSHClientWrapper:
    def __init__(self) -> None:
        self._client: paramiko.SSHClient | None = None
        self._lock = threading.Lock()
        self._connected = False
        self._secrets: list[str] = []

    @property
    def connected(self) -> bool:
        return self._connected and self._client is not None

    def connect(
        self,
        host: str,
        port: int,
        username: str,
        key_path: str | None,
        passphrase: str | None,
        password: str | None,
    ) -> tuple[str, str]:
        self.disconnect()
        secrets: list[str] = []
        if passphrase:
            secrets.append(passphrase)
        if password:
            secrets.append(password)
        self._secrets = secrets

        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        connect_kwargs: dict[str, Any] = {
            "hostname": host,
            "port": port,
            "username": username,
            "timeout": CONNECT_TIMEOUT,
            "allow_agent": False,
            "look_for_keys": False,
        }

        if key_path:
            pkey = _load_private_key(key_path, passphrase)
            connect_kwargs["pkey"] = pkey
            pkey = None
        elif password:
            connect_kwargs["password"] = password
        else:
            raise SSHError("Укажите ключ или пароль")

        try:
            client.connect(**connect_kwargs)
        except Exception as exc:
            msg = scrub_message(str(exc), secrets)
            if key_path and password:
                raise SSHError(
                    f"Аутентификация по ключу не удалась: {msg}. "
                    "Пароль не используется как запасной вариант."
                ) from None
            raise SSHError(msg) from None
        finally:
            connect_kwargs.pop("password", None)
            connect_kwargs.pop("pkey", None)

        transport = client.get_transport()
        if transport is None or not transport.is_active():
            client.close()
            raise SSHError("Не удалось установить транспорт SSH")

        host_key = transport.get_remote_server_key()
        md5_fp, sha256_fp = _host_key_fingerprints(host_key)

        self._client = client
        self._connected = True
        return md5_fp, sha256_fp

    def disconnect(self) -> None:
        with self._lock:
            if self._client is not None:
                try:
                    self._client.close()
                except Exception:
                    pass
            self._client = None
            self._connected = False
            self._secrets.clear()

    def _require_client(self) -> paramiko.SSHClient:
        if not self._client or not self._connected:
            raise SSHError("Нет активного соединения")
        transport = self._client.get_transport()
        if transport is None or not transport.is_active():
            self._connected = False
            raise SSHError("Соединение потеряно")
        return self._client

    def run_command(
        self, argv: list[str], timeout: int = COMMAND_TIMEOUT
    ) -> Iterator[tuple[str, str]]:
        client = self._require_client()
        cmd = to_remote_argv(argv)
        with self._lock:
            client = self._require_client()
            stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
            stdin.close()
            for line in iter(stdout.readline, ""):
                yield ("stdout", line.rstrip("\n\r"))
            for line in iter(stderr.readline, ""):
                yield ("stderr", line.rstrip("\n\r"))
            exit_status = stdout.channel.recv_exit_status()
        if exit_status != 0:
            raise SSHError(f"Команда завершилась с кодом {exit_status}")

    def run_command_collect(
        self, argv: list[str], timeout: int = COMMAND_TIMEOUT
    ) -> tuple[int, list[tuple[str, str]]]:
        lines: list[tuple[str, str]] = []
        client = self._require_client()
        cmd = to_remote_argv(argv)
        with self._lock:
            client = self._require_client()
            stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
            stdin.close()
            for line in iter(stdout.readline, ""):
                lines.append(("stdout", line.rstrip("\n\r")))
            for line in iter(stderr.readline, ""):
                lines.append(("stderr", line.rstrip("\n\r")))
            code = stdout.channel.recv_exit_status()
        return code, lines

    def remote_path_exists(self, path: str) -> bool:
        code, _ = self.run_command_collect(["test", "-e", path], timeout=15)
        return code == 0

    def upload_tree(self, local_root: str, remote_root: str) -> None:
        client = self._require_client()
        sftp = client.open_sftp()

        def mkdir_p(remote_dir: str) -> None:
            parts: list[str] = []
            for part in remote_dir.strip("/").split("/"):
                parts.append(part)
                cur = "/" + "/".join(parts)
                try:
                    sftp.stat(cur)
                except OSError:
                    sftp.mkdir(cur)

        mkdir_p(remote_root)
        for dirpath, _dirnames, filenames in os.walk(local_root):
            rel = os.path.relpath(dirpath, local_root)
            remote_dir = remote_root if rel == "." else f"{remote_root}/{rel.replace(os.sep, '/')}"
            mkdir_p(remote_dir)
            for name in filenames:
                local_file = os.path.join(dirpath, name)
                remote_file = f"{remote_dir}/{name}"
                sftp.put(local_file, remote_file)
                mode = os.stat(local_file).st_mode
                sftp.chmod(remote_file, stat.S_IMODE(mode))
        sftp.close()

    def upload_files(self, pairs: list[tuple[str, str]]) -> None:
        """pairs: (local_path, remote_path)."""
        client = self._require_client()
        sftp = client.open_sftp()
        for local, remote in pairs:
            remote_dir = os.path.dirname(remote).replace("\\", "/")
            try:
                sftp.stat(remote_dir)
            except OSError:
                self.run_command_collect(["mkdir", "-p", remote_dir], timeout=15)
            sftp.put(local, remote)
            mode = os.stat(local).st_mode
            sftp.chmod(remote, stat.S_IMODE(mode))
        sftp.close()
