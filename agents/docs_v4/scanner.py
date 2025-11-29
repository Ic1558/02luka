from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List


def scan_paths(base_dir: Path, roots: List[str]) -> List[Dict[str, object]]:
    """
    Walk the provided roots (relative to base_dir) and collect file metadata.
    Returns entries with relative path, size, and mtime.
    """
    entries: List[Dict[str, object]] = []
    for root in roots:
        root_path = (base_dir / root).resolve()
        if not root_path.exists():
            continue
        for dirpath, _, filenames in os.walk(root_path):
            for filename in filenames:
                file_path = Path(dirpath) / filename
                try:
                    stat = file_path.stat()
                except OSError:
                    continue
                rel_path = file_path.relative_to(base_dir).as_posix()
                entries.append(
                    {
                        "path": rel_path,
                        "size": stat.st_size,
                        "mtime": int(stat.st_mtime),
                    }
                )
    return entries


__all__ = ["scan_paths"]
