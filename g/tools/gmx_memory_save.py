#!/usr/bin/env python3
# g/tools/gmx_memory_save.py
"""
Lightweight GMX Planner Memory Saver
Appends a new learning to the gmx_memory.jsonl ledger.
"""
import argparse
import json
from datetime import datetime
from pathlib import Path

# Define paths relative to this script's location for robustness
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parents[1]
LEDGER_FILE = PROJECT_ROOT / "g" / "memory" / "ledger" / "gmx_memory.jsonl"

def save_learning(outcome: str, learning: str):
    """
    Creates a memory entry and appends it to the GMX ledger.
    """
    if not learning:
        print("ERROR: --learning argument cannot be empty.")
        return

    # Ensure parent directory exists
    LEDGER_FILE.parent.mkdir(parents=True, exist_ok=True)

    memory_entry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "outcome": outcome,
        "learning": learning.strip()
    }

    try:
        with LEDGER_FILE.open("a", encoding="utf-8") as f:
            f.write(json.dumps(memory_entry) + "\n")
        print(f"✅ SUCCESS: Memory entry saved to {LEDGER_FILE.name}")
    except Exception as e:
        print(f"ERROR: Failed to write to ledger file: {e}")

def main():
    """Parses CLI arguments and saves a learning."""
    parser = argparse.ArgumentParser(description="Save a new learning to the GMX Planner memory.")
    parser.add_argument(
        "--outcome",
        type=str,
        required=True,
        choices=["success", "failure", "info"],
        help="The outcome of the event related to the learning."
    )
    parser.add_argument(
        "--learning",
        type=str,
        required=True,
        help="The concise learning string to be saved."
    )
    args = parser.parse_args()
    save_learning(args.outcome, args.learning)

if __name__ == "__main__":
    main()
