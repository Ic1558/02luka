"""Deterministic prompt rendering utilities."""

from __future__ import annotations

import json
from typing import Any, Dict


def canonicalize_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Return a copy of *payload* with canonical whitespace and ordering.

    The function ensures that nested dictionaries are processed recursively
    so that the resulting JSON representation is stable across runs.
    """

    def _canonicalize(value: Any) -> Any:
        if isinstance(value, dict):
            return {key: _canonicalize(value[key]) for key in sorted(value)}
        if isinstance(value, list):
            return [_canonicalize(item) for item in value]
        if isinstance(value, str):
            return value.strip()
        return value

    return _canonicalize(dict(payload))


def render_prompt(spec: Dict[str, Any], inputs: Dict[str, Any], policy: Dict[str, Any]) -> str:
    """Render the prompt in a deterministic, canonical JSON string.

    Args:
        spec: Static specification for the prompt contract.
        inputs: Request specific inputs prepared by the orchestrator.
        policy: Guard-rail policy constraints.

    Returns:
        A UTF-8 JSON string with sorted keys and no trailing whitespace.
    """

    document = {
        "task_spec": canonicalize_payload(spec),
        "inputs": canonicalize_payload(inputs),
        "policy": canonicalize_payload(policy),
    }
    return json.dumps(document, separators=(",", ":"), sort_keys=True, ensure_ascii=False)


__all__ = ["canonicalize_payload", "render_prompt"]
