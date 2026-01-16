#!/usr/bin/env python3
"""
Work Notes Digest Generator
---------------------------
Reads the main work_notes.jsonl (append-only journal) and creates a 
bounded digest (last N lines) for fast reading by intake tools.

Usage:
  python3 update_work_notes_digest.py [--lines 200]
"""

import argparse
import os
import sys
from pathlib import Path

def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]

def _work_notes_path() -> Path:
    ws_root = os.environ.get("LUKA_WS_ROOT")
    if ws_root:
        return Path(ws_root).expanduser().resolve() / "g" / "core_state" / "work_notes.jsonl"
    return _repo_root() / "g" / "core_state" / "work_notes.jsonl"

def main() -> int:
    parser = argparse.ArgumentParser(description="Update Work Notes Digest (Phase 4)")
    parser.add_argument("--lines", type=int, default=200, help="Number of recent lines to keep (default: 200)")
    parser.add_argument("--incremental", action="store_true", help="Skip update if digest is newer than journal")
    parser.add_argument("--force", action="store_true", help="Force update even if digest is fresh")
    parser.add_argument("--quiet", action="store_true", help="Suppress output messages")
    args = parser.parse_args()

    journal_path = _work_notes_path()
    digest_path = journal_path.with_name("work_notes_digest.jsonl")

    # If journal doesn't exist, create empty digest
    if not journal_path.exists():
        if digest_path.exists():
            return 0 # Already empty or stale, but if source missing, empty digest is correct
        try:
            digest_path.write_text("")
        except Exception as e:
            if not args.quiet:
                sys.stderr.write(f"Error creating empty digest: {e}\n")
            return 1
        return 0

    # Phase 4: Incremental mode - check mtime before processing
    if args.incremental and not args.force:
        try:
            if digest_path.exists():
                journal_mtime = os.path.getmtime(journal_path)
                digest_mtime = os.path.getmtime(digest_path)

                if digest_mtime >= journal_mtime:
                    # Digest is fresh, skip update
                    if not args.quiet:
                        print(f"Digest is fresh (journal mtime: {journal_mtime:.0f}, digest mtime: {digest_mtime:.0f}), skipping.")
                    return 0
        except Exception:
            pass  # If mtime check fails, proceed with update

    try:
        # Read lines efficiently (or just read all if small enough, likely < 100MB)
        # For robustness, we read all and slice. 
        # Ideally use a tail implementation for huge files, but for now readlines is fine.
        with journal_path.open("r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        
        # Slice last N
        keep = lines[-args.lines:] if args.lines > 0 else []
        
        # Atomic write
        temp_path = digest_path.with_suffix(".tmp")
        with temp_path.open("w", encoding="utf-8") as f:
            f.writelines(keep)
        
        os.replace(temp_path, digest_path)
        if not args.quiet:
            print(f"Updated digest at {digest_path} with {len(keep)} entries.")
        return 0

    except Exception as e:
        if not args.quiet:
            sys.stderr.write(f"Error updating digest: {e}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
