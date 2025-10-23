# 2025-02-14
"""IntelSphere provider for local Thai LLM routing."""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from typing import Dict, Iterable, List

BASE_ENV = "KKU_INTELSPHERE_BASE"
KEY_ENV = "KKU_INTELSPHERE_KEY"
DEFAULT_BASE = "https://api.intelsphere.kku.ac.th/v1"
DEFAULT_MODEL = "kku-llm-1"
DEFAULT_TEMPERATURE = 0.3
REQUEST_TIMEOUT = 30
MAX_RETRIES = 2


class IntelSphereError(RuntimeError):
    """Raised when IntelSphere operations fail."""


def _build_headers(api_key: str) -> Dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }


def _request(method: str, path: str, data: Dict[str, object] | None = None) -> Dict[str, object]:
    base_url = os.getenv(BASE_ENV, DEFAULT_BASE)
    api_key = os.getenv(KEY_ENV)
    if not api_key:
        raise IntelSphereError(f"Environment variable {KEY_ENV} is required")

    url = f"{base_url.rstrip('/')}/{path.lstrip('/')}"
    payload = json.dumps(data).encode("utf-8") if data is not None else None
    headers = _build_headers(api_key)

    last_error: Exception | None = None
    for attempt in range(MAX_RETRIES + 1):
        request = urllib.request.Request(url=url, data=payload, headers=headers, method=method.upper())
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:
                body = response.read().decode("utf-8")
                if not body:
                    return {}
                return json.loads(body)
        except urllib.error.HTTPError as exc:
            if 500 <= exc.code < 600 and attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)
                last_error = exc
                continue
            detail = exc.read().decode("utf-8", errors="ignore")
            raise IntelSphereError(f"IntelSphere HTTP error {exc.code}: {detail}") from exc
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = exc
            if attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)
                continue
            raise IntelSphereError(f"IntelSphere request failed: {exc}") from exc
    assert last_error is not None  # pragma: no cover
    raise IntelSphereError(f"IntelSphere request failed after retries: {last_error}")


def chat_complete(
    messages: Iterable[Dict[str, str]],
    model: str = DEFAULT_MODEL,
    temperature: float = DEFAULT_TEMPERATURE,
) -> str:
    """Send chat completion request to IntelSphere."""
    messages_list: List[Dict[str, str]] = list(messages)
    if not messages_list:
        raise IntelSphereError("messages must not be empty")

    payload = {
        "model": model,
        "messages": messages_list,
        "temperature": temperature,
    }
    response = _request("POST", "/chat/completions", data=payload)

    choices = response.get("choices") if isinstance(response, dict) else None
    if not choices:
        raise IntelSphereError("IntelSphere response missing 'choices'")

    first = choices[0]
    if not isinstance(first, dict) or "message" not in first:
        raise IntelSphereError("IntelSphere response malformed")

    message = first.get("message")
    if not isinstance(message, dict) or "content" not in message:
        raise IntelSphereError("IntelSphere message missing content")

    return str(message["content"])


def healthcheck() -> bool:
    """Return True if IntelSphere API is reachable."""
    try:
        _request("GET", "/health")
        return True
    except IntelSphereError:
        return False
