from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List

from agents.rnd.rnd_agent import RnDAgent


def run(failures: List[Dict[str, object]] | None = None) -> Dict[str, object]:
    base_dir = Path(os.getenv("LAC_BASE_DIR") or Path.cwd())
    agent = RnDAgent(pattern_db_path=base_dir / "agents/rnd/pattern_db.yaml")
    return agent.run(failures or [])


__all__ = ["run"]
