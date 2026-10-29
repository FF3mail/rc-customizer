"""Unit-тесты commands."""

from logic.commands import CustomizeOptions, build_customize_argv, to_remote_argv


def test_to_remote_argv_quotes_spaces() -> None:
    argv = ["customize_roundcube", "--text", "hello world"]
    assert to_remote_argv(argv) == "customize_roundcube --text 'hello world'"


def test_build_customize_argv_minimal() -> None:
    opts = CustomizeOptions(text="Почта", dry_run=True)
    assert build_customize_argv(opts) == [
        "customize_roundcube",
        "--text",
        "Почта",
        "--dry-run",
    ]


def test_build_customize_argv_colors() -> None:
    opts = CustomizeOptions(text_color="#fff", button_bg="#37beff")
    argv = build_customize_argv(opts)
    assert "--text-color" in argv
    assert "--button-bg" in argv
    assert "--text" not in argv
