#!/usr/bin/env python3
"""Scan LaunchAgents and extract entrypoints for worker registry."""

import plistlib
import sys
from pathlib import Path
from typing import List, Dict, Optional

def scan_launchagents() -> List[Dict[str, str]]:
    """Scan all com.02luka.* LaunchAgents and extract entrypoints."""
    launchagents_dir = Path.home() / "Library/LaunchAgents"
    plists = list(launchagents_dir.glob("com.02luka.*.plist"))
    
    workers = []
    for plist_path in sorted(plists):
        try:
            with open(plist_path, 'rb') as f:
                plist = plistlib.load(f)
            
            label = plist.get('Label', '')
            program_args = plist.get('ProgramArguments', [])
            entrypoint = program_args[0] if program_args else None
            
            if entrypoint:
                workers.append({
                    'label': label,
                    'entrypoint': entrypoint,
                    'path': str(plist_path),
                    'disabled': '.disabled' in str(plist_path)
                })
        except Exception as e:
            print(f"Error reading {plist_path}: {e}", file=sys.stderr)
    
    return workers

if __name__ == '__main__':
    workers = scan_launchagents()
    for w in workers:
        status = "DISABLED" if w['disabled'] else "ACTIVE"
        print(f"{status:8} {w['label']:40} {w['entrypoint']}")

