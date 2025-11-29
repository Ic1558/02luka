from __future__ import annotations

import os
from pathlib import Path

from agents.docs_v4.cataloger import build_catalog, write_catalog
from agents.docs_v4.scanner import scan_paths


def run() -> dict:
    base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
    roots = ["g/src", "g/docs"]
    entries = scan_paths(base_dir, roots)
    catalog = build_catalog(base_dir, entries)
    result = write_catalog(base_dir / "g/catalog/file_catalog.json", catalog)
    return {"status": result.get("status", "success"), "count": catalog.get("count", 0)}


__all__ = ["run"]
