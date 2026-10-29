"""Unit-тесты resolve дистрибутива."""

from pathlib import Path

import pytest

from ssh.distro import resolve_distro_path


def test_resolve_bundled_resources() -> None:
    root = Path(__file__).resolve().parent.parent.parent
    path = resolve_distro_path(None)
    assert (path / "install.sh").is_file()
    assert (path / "lib" / "common.sh").is_file()
    assert path == root / "resources" / "Full_customize_GROK" or path == root.parent


def test_resolve_local_override(tmp_path: Path) -> None:
    (tmp_path / "install.sh").write_text("#!/bin/bash\n", encoding="utf-8")
    lib = tmp_path / "lib"
    lib.mkdir()
    (lib / "common.sh").write_text("# common\n", encoding="utf-8")
    resolved = resolve_distro_path(str(tmp_path))
    assert resolved == tmp_path.resolve()


def test_resolve_invalid_override(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        resolve_distro_path(str(tmp_path))
