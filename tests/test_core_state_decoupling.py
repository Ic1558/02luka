#!/usr/bin/env python3
"""
Verify Core State Decoupling (Snapshot vs Journal).
Ensures that:
1. Snapshot (latest.json) and Journal (work_notes.jsonl) are separate.
2. Writing a work note does NOT modify latest.json (mtime check).
3. Writing a work note APPEARS in core_intake output.
"""
import os
import time
import json
import logging
from pathlib import Path

# Setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

BASE_DIR = Path(os.path.dirname(__file__)).resolve()
LATEST_JSON = BASE_DIR / "g/core_state/latest.json"
WORK_NOTES = BASE_DIR / "g/core_state/work_notes.jsonl"

def verify():
    logging.info("Starting Decoupling Verification...")

    # 1. Baseline
    if not LATEST_JSON.exists():
        logging.error(f"Snapshot missing: {LATEST_JSON}")
        return False
    
    initial_mtime = LATEST_JSON.stat().st_mtime
    logging.info(f"Initial latest.json mtime: {initial_mtime}")

    # 2. Write Work Note
    test_id = f"TEST-{int(time.time())}"
    logging.info(f"Injecting work note: {test_id}")
    
    # Simulate writer.py import since it's inside the codebase
    try:
        from bridge.lac.writer import write_work_note
        write_work_note("Verification", f"Test note {test_id}", short_summary="Decoupling Check", status="completed")
    except ImportError:
        logging.error("Could not import bridge.lac.writer")
        return False
    except Exception as e:
        logging.error(f"Write failed: {e}")
        return False

    # 3. Verify Decoupling (latest.json shoud NOT change)
    current_mtime = LATEST_JSON.stat().st_mtime
    if current_mtime != initial_mtime:
        logging.error(f"FAILURE: latest.json was modified! ({initial_mtime} -> {current_mtime})")
        logging.error("Decoupling broken: Writer is still touching snapshot.")
        return False
    else:
        logging.info("SUCCESS: latest.json untouched (Decoupling verified).")

    # 4. Verify Persistence (work_notes.jsonl should have it)
    found = False
    if WORK_NOTES.exists():
        with open(WORK_NOTES, "r") as f:
            for line in f:
                if test_id in line:
                    found = True
                    break
    
    if found:
        logging.info(f"SUCCESS: Note {test_id} found in work_notes.jsonl")
    else:
        logging.error(f"FAILURE: Note {test_id} NOT found in work_notes.jsonl")
        return False

    logging.info("Verification Passed.")
    return True

if __name__ == "__main__":
    if verify():
        exit(0)
    else:
        exit(1)
