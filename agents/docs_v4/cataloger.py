from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List

from shared.policy import apply_patch


def build_catalog(base_dir: Path, entries: List[Dict[str, object]]) -> Dict[str, object]:
    return {
        "base_dir": base_dir.as_posix(),
        "count": len(entries),
        "files": entries,
    }


def write_catalog(path: Path, catalog: Dict[str, object]) -> Dict[str, object]:
    content = json.dumps(catalog, indent=2)
    return apply_patch(str(path), content)


__all__ = ["build_catalog", "write_catalog"]
