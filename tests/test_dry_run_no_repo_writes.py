from __future__ import annotations

from pathlib import Path
from textwrap import dedent

import pytest

from agents.ai_manager.ai_manager import AIManager
from agents.dev_common.dry_run_guard import DryRunBlockedWrite, dry_run_context


def _snapshot_files(root: Path) -> dict[Path, float]:
    if not root.exists():
        return {}
    files: dict[Path, float] = {}
    for path in root.rglob("*"):
        if path.is_file():
            files[path] = path.stat().st_mtime
    return files


def test_dry_run_no_repo_writes():
    repo_root = Path(__file__).resolve().parents[1]
    g_root = repo_root / "g"
    mls_root = repo_root / "mls"

    before_g = _snapshot_files(g_root)
    before_mls = _snapshot_files(mls_root)

    wo_id = "WO-TEST-DRYRUN-0001"
    wo = {"wo_id": wo_id, "dry_run": True}
    ctx = dry_run_context(wo, lane="dev_lac_manager")

    requirement = dedent(
        f"""
        ```yaml
        wo_id: "{wo_id}"
        objective: "Dry run health check"
        source: "CODEX"
        complexity: "simple"
        files: []
        ```
        """
    ).strip()

    with ctx:
        result = AIManager().run_self_complete(requirement)
        assert result.get("status") in {"failed", "success", "merged"}

        blocked_path = repo_root / "g/src/should_not_write.txt"
        with pytest.raises(DryRunBlockedWrite):
            blocked_path.write_text("nope", encoding="utf-8")

    after_g = _snapshot_files(g_root)
    after_mls = _snapshot_files(mls_root)

    assert before_g == after_g
    assert before_mls == after_mls

    dryrun_root = Path("/tmp/02luka-dryrun") / wo_id
    assert dryrun_root.exists()
    assert any(p.is_file() for p in dryrun_root.rglob("*"))
    assert (dryrun_root / "g/src/pipeline_output.txt").exists()
    for touched in result.get("files_touched", []):
        assert str(dryrun_root) in str(touched)
