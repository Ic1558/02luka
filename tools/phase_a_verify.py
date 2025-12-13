#!/usr/bin/env python3
"""Verify Phase A status - check symlinks"""
from pathlib import Path

REPO = Path.home() / "02luka"
WS = Path.home() / "02luka_ws"

paths = [
    "g/followup",
    "mls/ledger",
    "bridge/processed",
    "g/apps/dashboard/data/followup.json",
]

print("=== Phase A Status Check ===\n")

all_ok = True
for path in paths:
    repo_path = REPO / path
    ws_path = WS / path
    
    if not repo_path.exists():
        print(f"⚠️  {path}: Does not exist")
        all_ok = False
    elif repo_path.is_symlink():
        target = repo_path.readlink()
        if str(target) == str(ws_path):
            print(f"✅ {path} -> {target}")
        else:
            print(f"⚠️  {path} -> {target} (expected {ws_path})")
            all_ok = False
    else:
        print(f"❌ {path}: Real {'directory' if repo_path.is_dir() else 'file'} (should be symlink)")
        all_ok = False

print()
if all_ok:
    print("✅ All paths are correct symlinks")
else:
    print("⚠️  Some paths need migration")
