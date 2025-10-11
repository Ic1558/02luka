"""Telemetry helpers for delegation pipeline."""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

ISO_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"


def compute_prompt_hash(rendered_prompt: str) -> str:
    """Return a SHA256 hex digest for *rendered_prompt*."""

    return hashlib.sha256(rendered_prompt.encode("utf-8")).hexdigest()


def build_idempotency_key(prompt_hash: str, user_intent: str, inputs: Dict[str, Any]) -> str:
    """Generate a stable idempotency key from prompt hash, intent, and inputs."""

    canonical_inputs = json.dumps(inputs, separators=(",", ":"), sort_keys=True, ensure_ascii=False)
    seed = f"{prompt_hash}:{user_intent}:{canonical_inputs}"
    return hashlib.sha256(seed.encode("utf-8")).hexdigest()


def log_request_event(path: Path, request: Dict[str, Any]) -> None:
    """Append a JSON log line for the outgoing request."""

    path.parent.mkdir(parents=True, exist_ok=True)
    event = {
        **request,
        "logged_at": datetime.now(timezone.utc).strftime(ISO_FORMAT),
    }
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, separators=(",", ":"), sort_keys=True, ensure_ascii=False))
        handle.write("\n")


__all__ = ["compute_prompt_hash", "build_idempotency_key", "log_request_event", "ISO_FORMAT"]
