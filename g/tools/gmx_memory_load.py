#!/usr/bin/env python3
# g/tools/gmx_memory_load.py
"""
Lightweight GMX Planner Memory Loader
Reads recent learnings from the gmx_memory.jsonl ledger.
"""
import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict, Any

# Define paths relative to this script's location
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parents[1]
LEDGER_FILE = PROJECT_ROOT / "g" / "memory" / "ledger" / "gmx_memory.jsonl"

def load_learnings(limit: int) -> Dict[str, List[str]]:
    """
    Reads the last N learnings from the ledger and returns them.
    """
    learnings = []
    if not LEDGER_FILE.exists():
        return {"recent_learnings": []}

    try:
        with LEDGER_FILE.open("r", encoding="utf-8") as f:
            # Read all lines and take the last 'limit' number
            lines = f.readlines()
            recent_lines = lines[-limit:]
            for line in recent_lines:
                try:
                    entry = json.loads(line)
                    if "learning" in entry:
                        learnings.append(entry["learning"])
                except json.JSONDecodeError:
                    # Skip corrupted lines
                    continue
        
        # Reverse to have the most recent learning first
        learnings.reverse()
        return {"recent_learnings": learnings}

    except Exception as e:
        # In case of any error, return an empty list to avoid breaking the agent
        print(f"ERROR: Could not read ledger file: {e}", file=sys.stderr)
        return {"recent_learnings": []}

def main():
    """Parses CLI arguments and prints the learnings as JSON."""
    parser = argparse.ArgumentParser(description="Load recent learnings from the GMX Planner memory.")
    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="The maximum number of recent learnings to load."
    )
    args = parser.parse_args()
    
    learnings_data = load_learnings(args.limit)
    sys.stdout.write(json.dumps(learnings_data, indent=2))

if __name__ == "__main__":
    main()
