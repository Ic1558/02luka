from __future__ import annotations

import json
import os
from pathlib import Path
from typing import List

from g.maintenance import catalog_rebuild, health_check, pattern_learning, structure_scan
from shared.scheduler import Scheduler


def get_base_dir() -> Path:
    env = os.getenv("LAC_BASE_DIR")
    if env:
        return Path(env)
    return Path.cwd()


def run_all() -> List[dict]:
    base_dir = get_base_dir()
    scheduler = Scheduler()
    scheduler.register("catalog_rebuild", catalog_rebuild.run)
    scheduler.register("structure_scan", lambda: structure_scan.run(expected_files=[]))
    scheduler.register("pattern_learning", pattern_learning.run)
    scheduler.register("health_check", health_check.run)
    try:
        results = scheduler.run_all()
    except Exception as exc:  # defensive: should not crash background loop
        results = [{"task": "scheduler_entrypoint", "status": "error", "reason": str(exc)}]
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


def main() -> None:
    run_all()


if __name__ == "__main__":
    main()
