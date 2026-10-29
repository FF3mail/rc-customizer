"""Главное окно приложения."""

from __future__ import annotations

import queue
import threading
import tkinter as tk
from tkinter import messagebox, ttk
from typing import Any, Callable

from logic.commands import CustomizeOptions
from logic.validators import (
    validate_host,
    validate_key_folder,
    validate_port,
    validate_username,
)
from ssh import workflows
from ssh.client import SSHClientWrapper, SSHError
from ssh.distro import resolve_distro_path
from ui.actions_frame import ActionsFrame
from ui.connection_frame import ConnectionFrame
from ui.customize_dialog import CustomizeDialog
from ui.log_panel import LogPanel


class App(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("RC Customizer — Full_customize_GROK")
        self.geometry("800x640")
        self.minsize(720, 560)

        style = ttk.Style()
        style.configure("Invalid.TEntry", fieldbackground="#ffdddd")

        self.event_queue: queue.Queue[tuple[str, Any]] = queue.Queue()
        self.ssh = SSHClientWrapper()
        self._worker: threading.Thread | None = None
        self._connected = False
        self._test_ok = False
        self._distro_path: str | None = None

        self.connection = ConnectionFrame(
            self, on_connect=self.connect, on_disconnect=self.disconnect
        )
        self.connection.pack(fill=tk.X, padx=8, pady=8)

        self.actions = ActionsFrame(
            self,
            on_test=self.run_test,
            on_install=self.run_install,
            on_customize=self.open_customize,
            on_rollback=self.run_rollback,
            on_uninstall=self.run_uninstall,
        )
        self.actions.pack(fill=tk.X, padx=8, pady=4)

        self.log = LogPanel(self)
        self.log.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)

        self.protocol("WM_DELETE_WINDOW", self.on_close)
        threading.excepthook = self._thread_excepthook
        self.after(100, self._poll_queue)

    def _thread_excepthook(self, args: threading.ExceptHookArgs) -> None:
        self.event_queue.put(
            (
                "log",
                (
                    "stderr",
                    f"Необработанное исключение в потоке: {args.exc_type.__name__}",
                ),
            )
        )

    def _poll_queue(self) -> None:
        try:
            while True:
                kind, payload = self.event_queue.get_nowait()
                if kind == "log":
                    stream, line = payload
                    self.log.append(stream, line)
                elif kind == "connect_ok":
                    md5_fp, sha256_fp, user, host = payload
                    self._on_connect_success(user, host, md5_fp, sha256_fp)
                elif kind == "connect_fail":
                    self._on_connect_fail(payload)
                elif kind == "workflow_done":
                    self._on_workflow_done(payload)
                elif kind == "connection_lost":
                    self._on_connection_lost()
        except queue.Empty:
            pass
        self.after(100, self._poll_queue)

    def _writer(self, event: tuple[str, str]) -> None:
        self.event_queue.put(("log", event))

    def _refresh_actions(self) -> None:
        self.actions.set_enabled(self._connected, self._test_ok)

    def connect(self) -> None:
        params = self.connection.get_connection_params()
        err = validate_host(str(params["host"]))
        if err:
            messagebox.showerror("Подключение", err)
            return
        port, err = validate_port(str(params["port_str"]))
        if err or port is None:
            messagebox.showerror("Подключение", err or "Неверный порт")
            return
        err = validate_username(str(params["username"]))
        if err:
            messagebox.showerror("Подключение", err)
            return
        key_path = params["key_path"]
        password = params["password"]
        if not key_path and not password:
            messagebox.showerror(
                "Подключение", "Укажите файл ключа или пароль (альт.)"
            )
            return
        folder = str(params["key_folder"] or "")
        if folder:
            _keys, kerr = validate_key_folder(folder)
            if kerr:
                messagebox.showerror("Подключение", kerr)
                return
        try:
            local = params.get("local_distro")
            distro = resolve_distro_path(str(local) if local else None)
            self._distro_path = str(distro)
        except FileNotFoundError as exc:
            messagebox.showerror("Подключение", str(exc))
            return

        self.log.append(
            "info",
            f"Подключение к {params['username']}@{params['host']}:{port}...",
        )
        self.connection.set_connected(True)

        def task() -> None:
            try:
                md5_fp, sha256_fp = self.ssh.connect(
                    str(params["host"]),
                    port,
                    str(params["username"]),
                    str(key_path) if key_path else None,
                    str(params["passphrase"]) if params["passphrase"] else None,
                    str(password) if password else None,
                )
                self.event_queue.put(
                    (
                        "connect_ok",
                        (
                            md5_fp,
                            sha256_fp,
                            params["username"],
                            params["host"],
                        ),
                    )
                )
            except SSHError as exc:
                self.event_queue.put(("connect_fail", str(exc)))
            except Exception as exc:
                self.event_queue.put(
                    ("connect_fail", f"{type(exc).__name__}: ошибка подключения")
                )

        threading.Thread(target=task, daemon=True).start()

    def _on_connect_success(
        self, user: str, host: str, md5_fp: str, sha256_fp: str
    ) -> None:
        self._connected = True
        self._test_ok = False
        self.connection.set_status(f"Подключено: {user}@{host}")
        self.log.append("info", f"Отпечаток MD5 host key: {md5_fp}")
        self.log.append("info", f"Отпечаток SHA256 host key: {sha256_fp}")
        self._refresh_actions()
        self.log.append(
            "info", "Выполните «Проверка окружения» для доступа к остальным действиям."
        )

    def _on_connect_fail(self, msg: str) -> None:
        self.ssh.disconnect()
        self._connected = False
        self._test_ok = False
        self.connection.set_connected(False)
        self.connection.set_status("Ошибка", error=True)
        self.log.append("stderr", msg)
        self._refresh_actions()

    def disconnect(self) -> None:
        self.ssh.disconnect()
        self._connected = False
        self._test_ok = False
        self.connection.clear_secrets()
        self.connection.set_connected(False)
        self.connection.set_status("Отключено")
        self._refresh_actions()
        self.log.append("info", "Отключено. Учётные данные очищены.")

    def on_close(self) -> None:
        self.disconnect()
        self.destroy()

    def _on_connection_lost(self) -> None:
        self._connected = False
        self._test_ok = False
        self.connection.set_status("Соединение потеряно")
        self._refresh_actions()
        self.log.append("stderr", "Соединение потеряно")

    def _start_workflow(self, name: str, fn: Callable[[], None]) -> None:
        if self._worker and self._worker.is_alive():
            return
        if not self._connected:
            return

        self.actions.set_busy(True, f"Выполняется: {name}…")

        def task() -> None:
            success = True
            try:
                fn()
            except SSHError:
                success = False
                if not self.ssh.connected:
                    self.event_queue.put(("connection_lost", None))
            except Exception:
                success = False
                self.event_queue.put(
                    ("log", ("stderr", "Ошибка выполнения сценария"))
                )
            self.event_queue.put(("workflow_done", (name, success)))

        self._worker = threading.Thread(target=task, daemon=True)
        self._worker.start()

    def _on_workflow_done(self, payload: tuple[str, bool]) -> None:
        name, success = payload
        if success and name in ("test", "install"):
            self._test_ok = True
        elif name == "test" and not success:
            self._test_ok = False
        self.actions.set_busy(False)
        self._refresh_actions()

    def run_test(self) -> None:
        self._start_workflow(
            "test", lambda: workflows.run_test(self.ssh, self._writer)
        )

    def run_install(self) -> None:
        if not self._distro_path:
            return
        path = self._distro_path

        def fn() -> None:
            workflows.run_install(self.ssh, self._writer, path)

        self._start_workflow("install", fn)

    def open_customize(self) -> None:
        CustomizeDialog(self, on_apply=self._apply_customize)

    def _apply_customize(
        self,
        opts: CustomizeOptions,
        logo: str | None,
        bg: str | None,
    ) -> None:
        def fn() -> None:
            workflows.run_customize(self.ssh, self._writer, opts, logo, bg)

        self._start_workflow("customize", fn)

    def run_rollback(self) -> None:
        if not messagebox.askyesno(
            "Откат", "Откатить кастомизацию Roundcube к предыдущей резервной копии?"
        ):
            return
        self._start_workflow(
            "rollback", lambda: workflows.run_rollback(self.ssh, self._writer)
        )

    def run_uninstall(self) -> None:
        dlg = tk.Toplevel(self)
        dlg.title("Удаление с сервера")
        dlg.transient(self)
        dlg.grab_set()
        rollback_var = tk.BooleanVar(value=False)
        backups_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            dlg, text="Сначала откатить кастомизации", variable=rollback_var
        ).pack(anchor=tk.W, padx=12, pady=8)
        ttk.Checkbutton(
            dlg, text="Удалить резервные копии", variable=backups_var
        ).pack(anchor=tk.W, padx=12, pady=4)

        def confirm() -> None:
            dlg.destroy()
            if not self._distro_path:
                return
            path = self._distro_path

            def fn() -> None:
                workflows.run_uninstall(
                    self.ssh,
                    self._writer,
                    path,
                    rollback_var.get(),
                    backups_var.get(),
                )

            self._start_workflow("uninstall", fn)

        btn_row = ttk.Frame(dlg)
        btn_row.pack(pady=12)
        ttk.Button(btn_row, text="Удалить", command=confirm).pack(
            side=tk.LEFT, padx=4
        )
        ttk.Button(btn_row, text="Отмена", command=dlg.destroy).pack(side=tk.LEFT)


def run_app() -> None:
    app = App()
    app.mainloop()
