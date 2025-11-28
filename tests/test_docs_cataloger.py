from __future__ import annotations

import json
from pathlib import Path

from agents.docs_v4.docs_worker import DocsWorkerV4


def test_docs_worker_catalogs_files(tmp_path, monkeypatch):
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))
    (tmp_path / "g/src").mkdir(parents=True, exist_ok=True)
    (tmp_path / "g/docs").mkdir(parents=True, exist_ok=True)

    (tmp_path / "g/src/a.py").write_text("print('a')", encoding="utf-8")
    (tmp_path / "g/docs/readme.md").write_text("# docs", encoding="utf-8")

    worker = DocsWorkerV4()
    result = worker.execute_task({"operation": "catalog", "roots": ["g/src", "g/docs"]})

    assert result["status"] == "success"
    catalog_file = Path(tmp_path / "g/catalog/file_catalog.json")
    assert catalog_file.exists()
    catalog = json.loads(catalog_file.read_text(encoding="utf-8"))
    paths = [entry["path"] for entry in catalog["files"]]
    assert "g/src/a.py" in paths
    assert "g/docs/readme.md" in paths
    assert catalog["count"] == 2
