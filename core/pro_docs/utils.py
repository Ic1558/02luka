"""Shared helpers for rules engine determinism."""

from __future__ import annotations

import hashlib
import json
from decimal import Decimal, ROUND_DOWN, ROUND_HALF_EVEN, ROUND_HALF_UP, ROUND_UP
from typing import Any


ROUNDING_MODES = {
    "half_up": ROUND_HALF_UP,
    "half_even": ROUND_HALF_EVEN,
    "down": ROUND_DOWN,
    "up": ROUND_UP,
}

ENGINE_VERSION = "pro_docs_engine_v1"


def to_decimal(value: Any) -> Decimal:
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


def round_decimal(value: Any, decimals: int, mode: str) -> Decimal:
    quant = Decimal("1").scaleb(-decimals)
    if mode not in ROUNDING_MODES:
        raise ValueError(f"Unsupported rounding mode: {mode}")
    rounding = ROUNDING_MODES[mode]
    return to_decimal(value).quantize(quant, rounding=rounding)


def _normalize_for_json(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, dict):
        return {str(key): _normalize_for_json(val) for key, val in value.items()}
    if isinstance(value, list):
        return [_normalize_for_json(item) for item in value]
    if hasattr(value, "to_dict"):
        return _normalize_for_json(value.to_dict())
    return value


def canonical_json_dumps(value: Any) -> str:
    normalized = _normalize_for_json(value)
    return json.dumps(normalized, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def sha256_digest(value: Any) -> str:
    payload = canonical_json_dumps(value).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()
