from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List


def run(expected_files: List[str] | None = None) -> Dict[str, object]:
    base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
    expected = expected_files or []
    missing = []
    for f in expected:
        if not (base_dir / f).exists():
            missing.append(f)
    return {"status": "success" if not missing else "warn", "missing": missing, "checked": expected}


__all__ = ["run"]
