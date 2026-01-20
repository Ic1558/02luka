"""Shared numeric helpers for rules engine."""

from __future__ import annotations

from decimal import Decimal, ROUND_DOWN, ROUND_HALF_EVEN, ROUND_HALF_UP, ROUND_UP
from typing import Any


ROUNDING_MODES = {
    "half_up": ROUND_HALF_UP,
    "half_even": ROUND_HALF_EVEN,
    "down": ROUND_DOWN,
    "up": ROUND_UP,
}


def to_decimal(value: Any) -> Decimal:
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


def round_decimal(value: Any, decimals: int, mode: str) -> Decimal:
    quant = Decimal("1").scaleb(-decimals)
    rounding = ROUNDING_MODES.get(mode, ROUND_HALF_UP)
    return to_decimal(value).quantize(quant, rounding=rounding)
