"""
Shared utilities used across agents.
"""

from .policy import (
    ALLOWED_ROOTS,
    FORBIDDEN_PATHS,
    apply_patch,
    check_write_allowed,
)

__all__ = ["ALLOWED_ROOTS", "FORBIDDEN_PATHS", "apply_patch", "check_write_allowed"]
