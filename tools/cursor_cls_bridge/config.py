"""
Configuration utilities for CLS Cursor Wrapper.
"""

import os
from pathlib import Path
from typing import Optional


def get_base_dir(cli_base_dir: Optional[str] = None) -> Path:
    """
    Get base directory with priority:
    1. CLI --base-dir
    2. LAC_BASE_DIR env
    3. Current working directory
    """
    if cli_base_dir:
        base = Path(cli_base_dir).resolve()
    else:
        env_base = os.getenv("LAC_BASE_DIR")
        if env_base:
            base = Path(env_base).resolve()
        else:
            base = Path.cwd().resolve()
    
    if not base.exists():
        raise ValueError(f"Base directory does not exist: {base}")
    
    return base


def get_inbox_path(base_dir: Path) -> Path:
    """Get CLC inbox path."""
    inbox = base_dir / "bridge" / "inbox" / "CLC"
    inbox.mkdir(parents=True, exist_ok=True)
    return inbox


def get_outbox_path(base_dir: Path) -> Path:
    """Get CLC outbox path."""
    outbox = base_dir / "bridge" / "outbox" / "CLC"
    outbox.mkdir(parents=True, exist_ok=True)
    return outbox


def get_timeout_seconds() -> int:
    """Get timeout from env or default."""
    return int(os.getenv("CLS_CURSOR_TIMEOUT_SECONDS", "60"))


def get_poll_interval() -> float:
    """Get poll interval from env or default."""
    return float(os.getenv("CLS_CURSOR_POLL_INTERVAL_SECONDS", "1.0"))

