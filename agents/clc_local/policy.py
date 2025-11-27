# agents/clc_local/policy.py
"""
CLC Local Policy wrapper — delegates to shared.policy (single source of truth).
"""
from __future__ import annotations

from typing import Tuple

from shared.policy import apply_patch, check_write_allowed


def check_file_allowed(file_path: str) -> Tuple[bool, str]:
    """
    Backward-compatible wrapper for legacy CLC code paths.
    """
    return check_write_allowed(file_path)


__all__ = ["check_file_allowed", "check_write_allowed", "apply_patch"]
