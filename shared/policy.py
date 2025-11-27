"""
Shared Policy Module - Single Source of Truth for Write Permissions.
Used by: dev_oss, dev_gmxcli, qa_v4, docs_v4, clc_local.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Tuple


FORBIDDEN_PATHS = [
    ".git/",
    "bridge/",
    "governance/",
    "secrets/",
    ".env",
    "config/secure/",
]

ALLOWED_ROOTS = [
    "g/src/",
    "g/apps/",
    "g/tools/",
    "g/docs/",
    "tests/",
    "system/antigravity/",
]


def _get_base_dir() -> Path:
    """Return the base directory for resolving paths."""
    base_dir = os.getenv("LAC_BASE_DIR")
    return Path(base_dir).resolve() if base_dir else Path.cwd().resolve()


def _normalize_path(file_path: str) -> Path:
    """
    Resolve a file path against the base directory to prevent traversal.
    """
    base_dir = _get_base_dir()
    target = Path(file_path)
    if not target.is_absolute():
        target = base_dir / target
    return target.resolve()


def _relative_to_base(normalized_path: Path) -> Tuple[bool, Path | None]:
    base_dir = _get_base_dir()
    try:
        return True, normalized_path.relative_to(base_dir)
    except ValueError:
        return False, None


def check_write_allowed(file_path: str) -> Tuple[bool, str]:
    """Check if file write is allowed per policy."""
    try:
        normalized = _normalize_path(file_path)
    except (OSError, RuntimeError, ValueError):
        return False, "INVALID_PATH"

    within_base, relative_path = _relative_to_base(normalized)
    if not within_base or relative_path is None:
        return False, "PATH_OUTSIDE_BASE"

    parts = list(relative_path.parts)

    for forbidden in FORBIDDEN_PATHS:
        fragment = forbidden.rstrip("/").replace("\\", "/")
        if fragment in parts:
            return False, f"FORBIDDEN_PATH: {fragment}"

    relative_str = relative_path.as_posix()
    for allowed in ALLOWED_ROOTS:
        allowed_path = allowed.rstrip("/").replace("\\", "/")
        # Check if path starts with allowed root AND has path separator boundary
        # This prevents prefix collision attacks (e.g., g/srcfoo/ matching g/src/)
        if relative_str.startswith(allowed_path):
            # Check boundary: either end of string or path separator follows
            if len(relative_str) == len(allowed_path) or relative_str[len(allowed_path)] == "/":
                return True, "ALLOWED"

    return False, "PATH_NOT_IN_ALLOWED_ROOTS"


def apply_patch(file_path: str, content: str, dry_run: bool = False) -> dict:
    """Apply patch after policy check."""
    allowed, reason = check_write_allowed(file_path)

    if not allowed:
        return {
            "status": "blocked",
            "reason": reason,
            "file": file_path,
        }

    target_path = _normalize_path(file_path)

    if dry_run:
        return {
            "status": "dry_run",
            "would_write": str(target_path),
            "content_length": len(content),
        }

    try:
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(content, encoding='utf-8')
    except OSError as exc:
        return {
            "status": "error",
            "reason": str(exc),
            "file": str(target_path),
        }

    return {
        "status": "success",
        "file": str(target_path),
        "bytes_written": len(content),
    }
