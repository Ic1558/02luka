from __future__ import annotations

import json
import os
from pathlib import Path
from typing import List

from g.maintenance import catalog_rebuild, health_check, pattern_learning, structure_scan
from shared.scheduler import Scheduler


def run_all() -> List[dict]:
    base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
    scheduler = Scheduler()
    scheduler.register("catalog_rebuild", catalog_rebuild.run)
    scheduler.register("structure_scan", lambda: structure_scan.run(expected_files=[]))
    scheduler.register("pattern_learning", pattern_learning.run)
    scheduler.register("health_check", health_check.run)
    results = scheduler.run_all()
    _write_telemetry(base_dir, results)
    return results


def _write_telemetry(base_dir: Path, results: List[dict]) -> None:
    path = base_dir / "g/telemetry/background_tasks.jsonl"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            for record in results:
                handle.write(json.dumps(record) + "\n")
    except Exception:
        return


if __name__ == "__main__":
    run_all()
