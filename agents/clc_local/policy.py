# agents/clc_local/policy.py
"""
Writer Policy v3.5 — Minimal Local Implementation (v0.1)
"""
from __future__ import annotations
from typing import Tuple

# A hardcoded list of forbidden path fragments.
# In a more advanced version, this could be loaded from a central config file.
FORBIDDEN_PATH_FRAGMENTS = [
    "02luka.md",
    "AI:OP-001",
    "CLAUDE.md",
    "/.git/",
    "/bridge/",
    "/governance/",
    "/CLC/",
    "/CLS/",
    "/.venv/",
]

def check_file_allowed(file_path: str) -> Tuple[bool, str]:
    """
    Checks if a given file path is allowed to be modified based on a
    hardcoded list of forbidden path fragments.

    Returns:
        A tuple containing (allowed: bool, reason: str).
    """
    if not file_path or not isinstance(file_path, str):
        return False, "No file path provided or invalid type."

    # Normalize path for consistent checking
    normalized_path = file_path.replace("\\", "/")

    for fragment in FORBIDDEN_PATH_FRAGMENTS:
        if fragment in normalized_path:
            return False, f"Path contains a forbidden fragment: '{fragment}'"

    return True, "OK"

