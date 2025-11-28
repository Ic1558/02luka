from __future__ import annotations

import os
import time
from pathlib import Path


def run() -> dict:
    base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
    return {
        "status": "success",
        "timestamp": int(time.time()),
        "base_dir": str(base_dir),
    }


__all__ = ["run"]
