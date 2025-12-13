#!/usr/bin/env python3

# ~/02luka/tools/mary_dispatch.py

# Mary Router Phase 1 — Two-Worlds Traffic Control

# Logic: Checks source + path + operation -> Decides "Lane" (Fast vs Strict)

import os
import sys
import json
import argparse
from pathlib import Path

# --- CONFIG ---

# Phase 1 baseline locked zones (relative to 02luka root)
LOCKED_ZONES = [
    "core",
    "launchd",
    "bridge/core",
    "g/docs/governance",
]

def get_luka_root() -> Path:
    """Resolve 02luka root directory with fallback."""
    env_root = os.environ.get("LUKA_ROOT")
    if env_root:
        return Path(env_root).expanduser().resolve()
    return Path.home().joinpath("02luka").resolve()

def normalize_path(path_str: str) -> tuple[str, str]:
    """Return (abs_path, rel_to_luka). rel_to_luka is '' if outside root."""
    luka_root = get_luka_root()
    abs_path = Path(path_str).expanduser().resolve()
    try:
        rel = abs_path.relative_to(luka_root)
        return str(abs_path), str(rel)
    except ValueError:
        return str(abs_path), ""

def check_zone(rel_path: str) -> str:
    """Classify path into OPEN / LOCKED."""
    if not rel_path: return "EXTERNAL" # Outside 02luka
    for zone in LOCKED_ZONES:
        if rel_path.startswith(zone):
            return "LOCKED"
    return "OPEN"

def decide_route(source: str, rel_path: str, op: str) -> dict:
    zone = check_zone(rel_path)
    # RULE 1: Background world = ALWAYS STRICT
    if source == "background":
        return {
            "lane": "STRICT",
            "agent": "CLC",
            "reason": "Background ops must strictly use CLC.",
            "zone": zone,
        }
    
    # RULE 2: Interactive world (Boss/CLI)
    if source == "interactive":
        if zone == "LOCKED" and op in ("write", "delete"):
            return {
                "lane": "WARN",
                "agent": "CLC_OR_OVERRIDE",
                "reason": "LOCKED zone write. Draft WO for CLC recommended. (Override allowed per Gov v1.2)",
                "zone": zone,
            }
        else:
            return {
                "lane": "FAST",
                "agent": "GMX_CODEX",
                "reason": "Safe op / Open zone -> Direct execution allowed.",
                "zone": zone,
            }
    
    return {"lane": "UNKNOWN", "agent": "MANUAL", "reason": "Unknown source context", "zone": zone}

def main():
    parser = argparse.ArgumentParser(description="Mary Router Dispatcher (Phase 1)")
    parser.add_argument("--source", choices=["interactive", "background"], required=True)
    parser.add_argument("--path", required=True)
    parser.add_argument("--op", choices=["read", "write", "delete"], default="write")
    parser.add_argument("--json", action="store_true", help="Output JSON for agents")
    
    args = parser.parse_args()
    abs_path, rel_path = normalize_path(args.path)
    decision = decide_route(args.source, rel_path, args.op)
    
    payload = {
        "path": str(abs_path),
        "rel_path": rel_path,
        "source": args.source,
        "op": args.op,
        **decision
    }
    
    if args.json:
        print(json.dumps(payload))
    else:
        print(f"🚦 MARY ROUTER DECISION:")
        print(f"   PATH  : {payload['rel_path'] or payload['path']}")
        print(f"   ZONE  : {payload['zone']}")
        print(f"   LANE  : {payload['lane']}")
        print(f"   AGENT : {payload['agent']}")
        print(f"   NOTE  : {payload['reason']}")

if __name__ == "__main__":
    main()
