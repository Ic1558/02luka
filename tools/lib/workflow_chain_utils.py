from __future__ import annotations

import datetime as _dt
import os
import re
import uuid
from typing import Optional


def iso_now() -> str:
    """Return current UTC timestamp in ISO8601 format."""
    return _dt.datetime.now(_dt.timezone.utc).isoformat()


def generate_run_id() -> str:
    """Generate run identifier: run_YYYYMMDD_HHMMSS_<6hex>."""
    ts = _dt.datetime.now(_dt.timezone.utc).strftime("%Y%m%d_%H%M%S")
    suffix = uuid.uuid4().hex[:6]
    return f"run_{ts}_{suffix}"


def determine_caller(env: Optional[dict[str, str]] = None) -> str:
    """Determine caller based on environment markers."""
    env = env or os.environ
    if env.get("CI"):
        return "ci"
    if env.get("LOCAL_REVIEW_ENABLED") or env.get("GIT_HOOK"):
        return "hook"
    return "manual"


def parse_gitdrop_snapshot_id(output: str) -> Optional[str]:
    """Extract snapshot ID from gitdrop output."""
    match = re.search(r"Snapshot\s+(\d{8}_\d{6})", output)
    if match:
        return match.group(1)
    match = re.search(r"Created\s+(\d{8}_\d{6})", output)
    if match:
        return match.group(1)
    return None
