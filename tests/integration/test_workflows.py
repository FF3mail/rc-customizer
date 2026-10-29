"""Интеграционные тесты workflows (mock SSH)."""

from unittest.mock import MagicMock, call

import pytest

from logic.commands import CustomizeOptions
from ssh import workflows


@pytest.fixture
def ssh() -> MagicMock:
    client = MagicMock()
    client.connected = True
    client.remote_path_exists.return_value = True

    def collect(argv, timeout=60):
        return 0, [("stdout", "ok")]

    client.run_command_collect.side_effect = collect
    client.upload_tree = MagicMock()
    client.upload_files = MagicMock()
    return client


def test_run_test_argv(ssh: MagicMock) -> None:
    events: list[tuple[str, str]] = []
    workflows.run_test(ssh, events.append)
    assert ssh.run_command_collect.call_args_list[0][0][0] == [
        "bash",
        "/usr/local/src/Full_customize_GROK/customize_roundcube.sh",
        "--test",
    ]


def test_run_install_sequence(ssh: MagicMock) -> None:
    events: list[tuple[str, str]] = []
    workflows.run_install(ssh, events.append, "/local/distro")
    argv_calls = [c[0][0] for c in ssh.run_command_collect.call_args_list]
    assert ["rm", "-rf", "/tmp/Full_customize_GROK"] in argv_calls
    assert ["bash", "/tmp/Full_customize_GROK/install.sh"] in argv_calls
    assert [
        "bash",
        "/usr/local/src/Full_customize_GROK/customize_roundcube.sh",
        "--test",
    ] in argv_calls
    ssh.upload_tree.assert_called_once()


def test_run_rollback_argv(ssh: MagicMock) -> None:
    events: list[tuple[str, str]] = []
    workflows.run_rollback(ssh, events.append)
    assert ssh.run_command_collect.call_args_list[-1][0][0] == [
        "bash",
        "/usr/local/src/Full_customize_GROK/customize_roundcube.sh",
        "--rollback",
        "--yes",
    ]


def test_run_uninstall_flags(ssh: MagicMock) -> None:
    events: list[tuple[str, str]] = []
    workflows.run_uninstall(ssh, events.append, "/d", True, True)
    argv = ssh.run_command_collect.call_args_list[-1][0][0]
    assert argv == [
        "bash",
        "/tmp/Full_customize_GROK/uninstall.sh",
        "--yes",
        "--rollback",
        "--remove-backups",
    ]


def test_run_customize_upload_and_cleanup(ssh: MagicMock, tmp_path) -> None:
    logo = tmp_path / "logo.png"
    logo.write_bytes(b"x")
    opts = CustomizeOptions()
    events: list[tuple[str, str]] = []
    workflows.run_customize(ssh, events.append, opts, str(logo), None)
    ssh.upload_files.assert_called_once()
    last_argv = ssh.run_command_collect.call_args_list[-1][0][0]
    assert last_argv[0:2] == ["rm", "-rf"]
