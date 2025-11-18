#!/usr/bin/env python3
"""
Multi-engine quota tracker for dashboard metrics.

Reads engine configuration and raw usage, computes ratios and status,
and writes normalized metrics JSON for the dashboard widget.
"""

import datetime as dt
import importlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
G_DIR = ROOT / "g"
CONFIG_PATH = G_DIR / "config" / "quota_config.yaml"
RAW_USAGE_PATH = G_DIR / "apps" / "dashboard" / "data" / "quota_usage_raw.json"
METRICS_PATH = G_DIR / "apps" / "dashboard" / "data" / "quota_metrics.json"


def _load_yaml_module():
    spec = importlib.util.find_spec("yaml")
    if spec is None:
        return None
    return importlib.import_module("yaml")


def load_config():
    yaml = _load_yaml_module()
    if yaml is None:
        raise SystemExit("[quota_tracker] PyYAML not installed; cannot parse config")

    if not CONFIG_PATH.exists():
        raise SystemExit(f"[quota_tracker] config not found: {CONFIG_PATH}")

    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def load_raw_usage():
    if not RAW_USAGE_PATH.exists():
        # placeholder: zero usage if no file yet
        return {}
    with RAW_USAGE_PATH.open("r", encoding="utf-8") as handle:
        try:
            return json.load(handle)
        except json.JSONDecodeError:
            return {}


def build_metrics(config, raw_usage):
    engines_cfg = config.get("engines", {})
    engines_out = {}
    for key, cfg in engines_cfg.items():
        used = float(raw_usage.get(key, {}).get("used", 0))
        limit = float(cfg.get("monthly_limit", 0) or 0)
        warn_ratio = float(cfg.get("warn_ratio", 0.8))
        stop_ratio = float(cfg.get("stop_ratio", 0.95))

        ratio = used / limit if limit > 0 else 0.0
        if limit <= 0:
            status = "unknown"
        elif ratio >= stop_ratio:
            status = "stop"
        elif ratio >= warn_ratio:
            status = "warn"
        else:
            status = "ok"

        engines_out[key] = {
            "label": cfg.get("label", key),
            "used": used,
            "limit": limit,
            "ratio": ratio,
            "status": status,
            "warn_ratio": warn_ratio,
            "stop_ratio": stop_ratio,
        }

    now = dt.datetime.now(dt.timezone.utc)
    return {
        "updated_at": now.isoformat(),
        "month": now.strftime("%Y-%m"),
        "engines": engines_out,
    }


def main():
    config = load_config()
    raw_usage = load_raw_usage()
    metrics = build_metrics(config, raw_usage)

    METRICS_PATH.parent.mkdir(parents=True, exist_ok=True)
    with METRICS_PATH.open("w", encoding="utf-8") as handle:
        json.dump(metrics, handle, ensure_ascii=False, indent=2)
    print(f"[quota_tracker] wrote metrics to {METRICS_PATH}")


if __name__ == "__main__":
    main()
