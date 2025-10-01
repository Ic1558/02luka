"""Thin client for invoking Codex-like models with schema validation."""

from __future__ import annotations

import json
from typing import Any, Dict

SYSTEM_PROMPT = """You are CODE-IMPLEMENTER. Output ONLY valid JSON that matches the provided JSON Schema.\nForbidden: shell execution, network calls, commentary outside JSON.\nConstraints:\n- Shebangs must target /bin/sh on macOS; no zsh.\n- Paths must be relative to the provided workspace root.\n- If information is missing, emit a \"clarifications\" list and stop."""


def build_request(prompt_json: str, schema: Dict[str, Any], model: str, idempotency_key: str) -> Dict[str, Any]:
    """Construct the API payload for a Codex-style completion."""

    return {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt_json},
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": schema,
        },
        "extra_headers": {
            "Idempotency-Key": idempotency_key,
        },
    }


def call_model(prompt_json: str, schema: Dict[str, Any], model: str, api_client: Any, idempotency_key: str) -> Dict[str, Any]:
    """Send the request via *api_client* and return the parsed JSON response."""

    request = build_request(prompt_json, schema, model, idempotency_key)
    response = api_client.create(json=request)
    if isinstance(response, str):
        return json.loads(response)
    return response


__all__ = ["SYSTEM_PROMPT", "build_request", "call_model"]
