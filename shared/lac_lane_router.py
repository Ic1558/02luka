from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict

import yaml


def _config_path() -> Path:
    base_dir = os.getenv("LAC_BASE_DIR")
    root = Path(base_dir) if base_dir else Path.cwd()
    return root / "g/config/lac_dev_lanes_v4.yaml"


def _load_config() -> Dict[str, Any]:
    path = _config_path()
    if not path.exists():
        return {"version": "4.0", "default_lane": "dev_oss", "lanes": {}, "routing_rules": []}
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:
        return {"version": "4.0", "default_lane": "dev_oss", "lanes": {}, "routing_rules": []}


def choose_dev_lane(source: str = "unknown", complexity: str = "moderate", cost_sensitivity: str = "normal") -> str:
    """
    Choose a dev lane based on source, complexity, and cost hints.
    Default rules:
      - source=liam -> dev_gmx
      - source=cls -> dev_codex
      - else default_lane (dev_oss)
    """
    cfg = _load_config()
    default_lane = cfg.get("default_lane", "dev_oss")
    rules = cfg.get("routing_rules", []) or []

    if not rules:
        # Built-in defaults when config is missing or empty
        if source == "liam":
            return _normalize_lane("dev_gmx")
        if source == "cls":
            return _normalize_lane("dev_codex")
        return _normalize_lane(default_lane)

    for rule in rules:
        when = rule.get("when", {})
        if when.get("source") and when["source"] == source:
            return _normalize_lane(rule.get("lane", default_lane))

    # Optional: promote complex tasks to gmx unless cost sensitive
    if complexity in {"moderate", "complex"} and cost_sensitivity != "low":
        # Lane key is the identifier (dev_gmx), not a nested name field
        return _normalize_lane("dev_gmx")

    return _normalize_lane(default_lane)


def _normalize_lane(lane: str) -> str:
    """
    Normalize lane identifiers to align with determine_lane hints.
    dev_gmx -> dev_gmxcli
    """
    if lane == "dev_gmx":
        return "dev_gmxcli"
    return lane


__all__ = ["choose_dev_lane"]
