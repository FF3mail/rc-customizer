"""Unit-тесты validators."""

import pytest

from logic.validators import validate_color


@pytest.mark.parametrize(
    "value,ok",
    [
        ("#fff", True),
        ("#FFFFFF", True),
        ("#aabbcc", True),
        ("rgba(0,0,0,0.5)", True),
        ("rgb(255, 255, 255)", True),
        ("", True),
        ("red", False),
        ("#gggggg", False),
        ("rgba(0)", False),
    ],
)
def test_validate_color(value: str, ok: bool) -> None:
    assert validate_color(value) is ok
