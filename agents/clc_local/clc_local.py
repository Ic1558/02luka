#!/usr/bin/env python3
"""
CLC Local Executor — CLI Entrypoint & Bridge Monitor (v0.2)

Usage:
    # Run a single spec file
    python agents/clc_local/clc_local.py --spec-file /path/to/spec.json

    # Monitor a Bridge inbox for new Work Orders
    python agents/clc_local/clc_local.py --watch-inbox LIAM
"""
import json
import argparse
import sys
import time
import os
import logging
from pathlib import Path

# Configure logging to a file, bypassing stdout/stderr for debug
LOG_FILE = Path("clc_local_debug.log")
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE)
    ]
)
logger = logging.getLogger(__name__)

# Add project root to path for imports
try:
    SCRIPT_DIR = Path(__file__).resolve().parent
    PROJECT_ROOT = SCRIPT_DIR.parents[1] # Assumes agents/clc_local/clc_local.py (2 levels up)
    logger.info(f"DEBUG: SCRIPT_DIR = {SCRIPT_DIR}")
    logger.info(f"DEBUG: PROJECT_ROOT = {PROJECT_ROOT}")
    sys.path.insert(0, str(PROJECT_ROOT))
    logger.info(f"DEBUG: sys.path after insert = {sys.path}")
    from agents.clc_local.executor import execute_task
except (ImportError, IndexError) as e:
    logger.error(f"FATAL: Could not set up paths or import executor. Ensure script is in 'agents/clc_local/'. Error: {e}")
    sys.exit(1)


def load_spec(path: Path) -> dict:
    """Loads a JSON specification file."""
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)

def watch_inbox(inbox_name: str):
    """Monitors a Bridge inbox and processes new Work Order files."""
    inbox_path = PROJECT_ROOT / "bridge" / "inbox" / inbox_name
    processed_path = inbox_path / "processed"
    
    inbox_path.mkdir(parents=True, exist_ok=True)
    processed_path.mkdir(exist_ok=True)
    
    logger.info(f"--- CLC Local Executor: Watching Inbox '{inbox_name}' ---")
    logger.info(f"Path: {inbox_path}")
    
    while True:
        # Find the oldest .json or .yaml file in the inbox
        work_orders = sorted(
            list(inbox_path.glob("*.json")) + list(inbox_path.glob("*.yaml")),
            key=os.path.getmtime
        )
        
        if not work_orders:
            time.sleep(5)  # Wait if no work
            continue

        wo_file = work_orders[0]
        logger.info(f"\n[+] Found Work Order: {wo_file.name}")
        
        try:
            spec = load_spec(wo_file)
            # The actual task_spec is usually nested inside the WO
            task_spec = spec.get("task_spec", spec)
            
            result = execute_task(task_spec)
            
            logger.info(f"    -> Task {result.get('task_id')} finished with status: {result.get('status')}")
            
            # Move processed file to archive
            wo_file.rename(processed_path / wo_file.name)
            logger.info(f"    -> Archived Work Order: {wo_file.name}")

        except Exception as e:
            logger.error(f"    -> ERROR processing {wo_file.name}: {e}")
            # Move corrupted/failed file to avoid loop
            wo_file.rename(processed_path / f"ERROR_{wo_file.name}")
        
        time.sleep(1) # Small delay to prevent tight loop on multiple files

def main():
    """Main entrypoint for the CLC Local Executor."""
    parser = argparse.ArgumentParser(description="CLC Local Executor v0.2")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--spec-file",
        help="Path to a single TASK_SPEC v4 JSON file to execute."
    )
    group.add_argument(
        "--watch-inbox",
        help="The name of the Bridge inbox to monitor (e.g., LIAM, CLC)."
    )
    args = parser.parse_args()

    if args.spec_file:
        try:
            spec = load_spec(Path(args.spec_file))
            result = execute_task(spec)
            logger.info(json.dumps(result, indent=2))
        except FileNotFoundError:
            error_result = {"status": "failed", "summary": f"Error: Spec file not found at {args.spec_file}"}
            logger.error(json.dumps(error_result, indent=2))
            sys.exit(1)
        except Exception as e:
            error_result = {"status": "failed", "summary": f"An unexpected error occurred: {e}"}
            logger.error(json.dumps(error_result, indent=2))
            sys.exit(1)
    elif args.watch_inbox:
        watch_inbox(args.watch_inbox)

if __name__ == "__main__":
    main()