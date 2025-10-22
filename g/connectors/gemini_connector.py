#!/usr/bin/env python3
"""Gemini connector for 02LUKA bridges.

This module provides a minimal wrapper around the Gemini Generative
Language API so shell tooling can forward prompts to Gemini using a
simple CLI interface. The connector defaults to the `gemini-1.5-pro`
model but the model can be overridden by exporting ``GEMINI_MODEL``.
"""
from __future__ import annotations

import json
import os
import sys
from typing import Any

import requests


DEFAULT_MODEL = "gemini-1.5-pro"
BASE_URL = "https://generativelanguage.googleapis.com"


class GeminiError(RuntimeError):
    """Raised when the Gemini API returns an error payload."""


def _build_endpoint(model: str) -> str:
    return f"{BASE_URL}/v1beta/models/{model}:generateContent"


def call_gemini(prompt: str, *, model: str | None = None, timeout: int = 60) -> str:
    """Send ``prompt`` to Gemini and return the first candidate response."""

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise GeminiError("GEMINI_API_KEY not set")

    chosen_model = model or os.getenv("GEMINI_MODEL", DEFAULT_MODEL)
    endpoint = _build_endpoint(chosen_model)

    headers = {"Content-Type": "application/json"}
    params = {"key": api_key}
    payload: dict[str, Any] = {"contents": [{"parts": [{"text": prompt}]}]}

    response = requests.post(
        endpoint,
        headers=headers,
        params=params,
        data=json.dumps(payload),
        timeout=timeout,
    )
    response.raise_for_status()
    data: Any = response.json()

    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except Exception as exc:  # pragma: no cover - defensive path
        raise GeminiError("Unexpected Gemini response format") from exc


def _main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: gemini_connector.py \"your prompt here\"", file=sys.stderr)
        return 1

    prompt = argv[1]
    try:
        print(call_gemini(prompt))
    except GeminiError as err:
        print(str(err), file=sys.stderr)
        return 2
    except requests.HTTPError as err:
        print(f"Gemini HTTP error: {err}", file=sys.stderr)
        return 3
    except requests.RequestException as err:
        print(f"Gemini request failed: {err}", file=sys.stderr)
        return 4
    return 0


if __name__ == "__main__":  # pragma: no cover - CLI entry
    sys.exit(_main(sys.argv))
