#!/usr/bin/env python3
"""
GitDrop Phase 1: Minimal Workspace Safety

Auto-backs up uncommitted files before git checkout.
Provides list/show/restore commands to recover "working papers".

Spec: g/reports/feature-dev/gitdrop/251206_gitdrop_SPEC_v03.md
"""

import argparse
import json
import hashlib
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional
from fnmatch import fnmatch

# Version guard
if sys.version_info < (3, 6):
    sys.exit("GitDrop requires Python 3.6+")

# =============================================================================
# Configuration
# =============================================================================

LUKA_SOT = "/Users/icmini/02luka"
GITDROP_DIR = f"{LUKA_SOT}/_gitdrop"
SNAPSHOTS_DIR = f"{GITDROP_DIR}/snapshots"
INDEX_FILE = f"{GITDROP_DIR}/index.jsonl"
ERROR_LOG = f"{GITDROP_DIR}/error.log"

# Backup scope - include patterns
INCLUDE_PATTERNS = [
    "g/reports/**/*.md",
    "tools/*.zsh",
    "tools/*.py",
    "*.md",  # root level only
]

# Exclude patterns
EXCLUDE_PATTERNS = [
    "node_modules/**",
    "__pycache__/**",
    ".DS_Store",
    "*.tmp",
    "*.log",
    "*.pyc",
    ".git/**",
    "_gitdrop/**",
]

MAX_FILE_SIZE_MB = 5

# =============================================================================
# Utility Functions
# =============================================================================

def ensure_dirs():
    """Create GitDrop directories if they don't exist"""
    Path(GITDROP_DIR).mkdir(parents=True, exist_ok=True)
    Path(SNAPSHOTS_DIR).mkdir(parents=True, exist_ok=True)


def log_error(message: str):
    """Log error to error.log"""
    ensure_dirs()
    timestamp = datetime.now().isoformat()
    with open(ERROR_LOG, "a") as f:
        f.write(f"[{timestamp}] {message}\n")


def matches_pattern(filepath: str, patterns: List[str]) -> bool:
    """Check if filepath matches any of the glob patterns"""
    for pattern in patterns:
        # Handle ** patterns
        if "**" in pattern:
            # Convert to fnmatch-compatible
            parts = pattern.split("**")
            if len(parts) == 2:
                prefix, suffix = parts
                # Check if path starts with prefix (if any) and ends with suffix (if any)
                prefix = prefix.rstrip("/")
                suffix = suffix.lstrip("/")
                if prefix and not filepath.startswith(prefix):
                    continue
                if suffix:
                    # Match the suffix pattern
                    remaining = filepath[len(prefix):].lstrip("/") if prefix else filepath
                    if fnmatch(remaining, f"*{suffix}") or fnmatch(remaining, f"**/{suffix}"):
                        return True
                    # Also try direct suffix match
                    if fnmatch(filepath, f"*/{suffix}") or filepath.endswith(suffix.lstrip("*")):
                        return True
                else:
                    return True
        else:
            # Simple pattern
            if fnmatch(filepath, pattern):
                return True
            # Also check basename for root-level patterns
            if "/" not in pattern and fnmatch(Path(filepath).name, pattern):
                # Only match root-level for *.md pattern
                if pattern == "*.md" and "/" in filepath:
                    continue
                return True
    return False


def matches_include(filepath: str) -> bool:
    """Check if file matches include patterns"""
    # Special handling for root-level *.md
    if filepath.endswith(".md") and "/" not in filepath:
        return True
    # Check g/reports/**/*.md
    if filepath.startswith("g/reports/") and filepath.endswith(".md"):
        return True
    # Check tools/*.zsh and tools/*.py
    if filepath.startswith("tools/") and "/" not in filepath[6:]:
        if filepath.endswith(".zsh") or filepath.endswith(".py"):
            return True
    return False


def matches_exclude(filepath: str) -> bool:
    """Check if file matches exclude patterns"""
    for pattern in EXCLUDE_PATTERNS:
        if "**" in pattern:
            prefix = pattern.split("**")[0].rstrip("/")
            if prefix and filepath.startswith(prefix):
                return True
        elif fnmatch(filepath, pattern) or fnmatch(Path(filepath).name, pattern):
            return True
    return False


# =============================================================================
# Core Functions
# =============================================================================

def get_uncommitted_files() -> List[str]:
    """Get uncommitted files matching backup scope"""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True,
            text=True,
            cwd=LUKA_SOT
        )
        
        if result.returncode != 0:
            log_error(f"git status failed: {result.stderr}")
            return []
        
    except Exception as e:
        log_error(f"git status exception: {e}")
        return []
    
    files = []
    for line in result.stdout.strip().split('\n'):
        if not line:
            continue
        
        status = line[:2]
        filepath = line[3:].strip()
        
        # Handle renamed files (R status shows "old -> new")
        if " -> " in filepath:
            filepath = filepath.split(" -> ")[1]
        
        # Only M (modified), A (added), ?? (untracked), AM, MM
        if status.strip() not in ['M', 'A', '??', 'AM', 'MM', 'R', 'RM']:
            continue
        
        # Check include patterns
        if not matches_include(filepath):
            continue
        
        # Check exclude patterns
        if matches_exclude(filepath):
            continue
        
        # Check file size
        full_path = Path(LUKA_SOT) / filepath
        if full_path.exists():
            try:
                size = full_path.stat().st_size
                if size > MAX_FILE_SIZE_MB * 1024 * 1024:
                    continue
            except:
                pass
        
        files.append(filepath)
    
    return files


def create_snapshot(reason: str, quiet: bool = False) -> int:
    """Create snapshot of uncommitted files"""
    ensure_dirs()
    
    files = get_uncommitted_files()
    
    if not files:
        if not quiet:
            print("[GitDrop] No working papers to save")
        return 0
    
    # Create snapshot ID
    snapshot_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    snapshot_dir = Path(SNAPSHOTS_DIR) / snapshot_id
    files_dir = snapshot_dir / "files"
    
    try:
        files_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        log_error(f"Failed to create snapshot dir: {e}")
        if not quiet:
            print(f"[GitDrop] ⚠️ BACKUP FAILED: {e}")
            print(f"[GitDrop] See: {ERROR_LOG}")
        return 1
    
    # Copy files
    file_records = []
    for i, filepath in enumerate(files):
        file_id = f"f_{i+1:03d}"
        src = Path(LUKA_SOT) / filepath
        dst = files_dir / file_id
        
        try:
            if src.exists():
                shutil.copy2(src, dst)
                content = src.read_bytes()
                file_records.append({
                    "id": file_id,
                    "path": filepath,
                    "size": src.stat().st_size,
                    "hash": hashlib.sha256(content).hexdigest()[:16]
                })
        except Exception as e:
            log_error(f"Failed to copy {filepath}: {e}")
            # Continue with other files (best-effort)
    
    if not file_records:
        # No files successfully copied
        try:
            shutil.rmtree(snapshot_dir)
        except:
            pass
        if not quiet:
            print("[GitDrop] No working papers to save")
        return 0
    
    # Write meta.json
    meta = {
        "id": snapshot_id,
        "created": datetime.now().isoformat(),
        "reason": reason,
        "files": file_records,
        "total_files": len(file_records),
        "total_size": sum(f["size"] for f in file_records)
    }
    
    try:
        (snapshot_dir / "meta.json").write_text(json.dumps(meta, indent=2))
    except Exception as e:
        log_error(f"Failed to write meta.json: {e}")
    
    # Append index.jsonl
    index_entry = {
        "id": snapshot_id,
        "created": meta["created"],
        "reason": reason,
        "files": len(file_records),
        "size": meta["total_size"]
    }
    
    try:
        with open(INDEX_FILE, "a") as f:
            f.write(json.dumps(index_entry) + "\n")
    except Exception as e:
        log_error(f"Failed to append index: {e}")
    
    if not quiet:
        print(f"[GitDrop] Saving your working papers to tray... ✓")
        print(f"[GitDrop] Snapshot {snapshot_id} created ({len(file_records)} files)")
    
    return 0


def list_snapshots(recent: Optional[int] = None):
    """Show snapshots with desk metaphor"""
    ensure_dirs()
    
    print("\nYour Working Paper Tray")
    print("━" * 60)
    
    if not Path(INDEX_FILE).exists():
        print("(empty - no snapshots yet)")
        print("\nSnapshots will appear here after git checkout operations.")
        return 0
    
    entries = []
    with open(INDEX_FILE) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                log_error(f"Skipping corrupt entry at line {i}")
    
    if not entries:
        print("(empty - no snapshots yet)")
        return 0
    
    # Newest first
    entries = entries[::-1]
    if recent:
        entries = entries[:recent]
    
    for i, entry in enumerate(entries, 1):
        snapshot_id = entry.get("id", "unknown")
        reason = entry.get("reason", "unknown")
        # Truncate reason for display
        if len(reason) > 25:
            reason = reason[:22] + "..."
        files = entry.get("files", 0)
        print(f"#{i:<3} {snapshot_id}   {reason:<25} {files} papers")
    
    print()
    print("Use: gitdrop show <snapshot_id>")
    print("     gitdrop restore <snapshot_id>")
    return 0


def show_snapshot(snapshot_id: str) -> int:
    """Show snapshot details"""
    meta_path = Path(SNAPSHOTS_DIR) / snapshot_id / "meta.json"
    
    if not meta_path.exists():
        print(f"[GitDrop] Error: Snapshot {snapshot_id} not found")
        print(f"[GitDrop] Use 'gitdrop list' to see available snapshots")
        return 1
    
    try:
        meta = json.loads(meta_path.read_text())
    except (json.JSONDecodeError, IOError) as e:
        print(f"[GitDrop] Error: Cannot read snapshot {snapshot_id}")
        print(f"[GitDrop] meta.json corrupt or unreadable")
        print(f"[GitDrop] Snapshot data may still be in: {SNAPSHOTS_DIR}/{snapshot_id}/files/")
        return 1
    
    print(f"\nSnapshot: {meta.get('id', snapshot_id)}")
    print(f"Created:  {meta.get('created', 'unknown')}")
    print(f"Reason:   {meta.get('reason', 'unknown')}")
    print("━" * 60)
    print("Papers saved:")
    
    for f in meta.get("files", []):
        size_kb = f.get("size", 0) / 1024
        print(f"  {f.get('path', 'unknown'):<45} {size_kb:.1f}KB")
    
    total_size = meta.get("total_size", 0) / 1024
    print(f"\nTotal: {meta.get('total_files', 0)} files ({total_size:.1f}KB)")
    print(f"\nRestore: gitdrop restore {snapshot_id}")
    return 0


def restore_snapshot(snapshot_id: str, overwrite: bool = False) -> int:
    """Restore files with conflict handling"""
    meta_path = Path(SNAPSHOTS_DIR) / snapshot_id / "meta.json"
    files_dir = Path(SNAPSHOTS_DIR) / snapshot_id / "files"
    
    if not meta_path.exists():
        print(f"[GitDrop] Error: Snapshot {snapshot_id} not found")
        print(f"[GitDrop] Use 'gitdrop list' to see available snapshots")
        return 1
    
    try:
        meta = json.loads(meta_path.read_text())
    except (json.JSONDecodeError, IOError) as e:
        print(f"[GitDrop] Error: Cannot read snapshot {snapshot_id}")
        print(f"[GitDrop] meta.json corrupt - aborting restore")
        print(f"[GitDrop] No files were modified")
        return 1
    
    print(f"\nRestoring snapshot {snapshot_id}...")
    print("━" * 60)
    
    restored = 0
    renamed = 0
    errors = 0
    
    for f in meta.get("files", []):
        file_id = f.get("id")
        filepath = f.get("path")
        
        if not file_id or not filepath:
            continue
        
        src = files_dir / file_id
        dst = Path(LUKA_SOT) / filepath
        
        if not src.exists():
            print(f"⚠ {filepath} - backup file missing")
            errors += 1
            continue
        
        try:
            # Create parent dirs
            dst.parent.mkdir(parents=True, exist_ok=True)
            
            if not dst.exists() or overwrite:
                shutil.copy2(src, dst)
                print(f"✓ {filepath}")
                restored += 1
            else:
                # Conflict: create renamed version
                stem = dst.stem
                suffix = dst.suffix
                new_name = f"{stem}.gitdrop-restored-{snapshot_id}{suffix}"
                new_dst = dst.parent / new_name
                shutil.copy2(src, new_dst)
                print(f"⚠ {filepath} exists")
                print(f"  → Saved as: {new_name}")
                renamed += 1
        except Exception as e:
            print(f"✗ {filepath} - {e}")
            errors += 1
    
    print()
    total = restored + renamed
    if total > 0:
        msg = f"Restored {total} files"
        if renamed:
            msg += f" ({renamed} renamed to avoid conflict)"
        print(msg)
    if errors:
        print(f"⚠ {errors} files could not be restored")
    
    return 0 if errors == 0 else 1


# =============================================================================
# CLI Entry Point
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="GitDrop: Workspace safety for your working papers",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  gitdrop list                  Show all saved snapshots
  gitdrop show 20251206_192000  Show snapshot details
  gitdrop restore 20251206_192000   Restore files from snapshot
  gitdrop restore 20251206_192000 --overwrite  Force overwrite
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # backup command
    p_backup = subparsers.add_parser('backup', help='Create snapshot (usually called by git hook)')
    p_backup.add_argument('--reason', required=True, help='Reason for backup')
    p_backup.add_argument('--quiet', action='store_true', help='Suppress output')
    
    # list command
    p_list = subparsers.add_parser('list', help='Show all snapshots')
    p_list.add_argument('--recent', type=int, help='Show only N most recent')
    
    # show command
    p_show = subparsers.add_parser('show', help='Show snapshot details')
    p_show.add_argument('id', help='Snapshot ID (YYYYMMDD_HHMMSS)')
    
    # restore command
    p_restore = subparsers.add_parser('restore', help='Restore files from snapshot')
    p_restore.add_argument('id', help='Snapshot ID')
    p_restore.add_argument('--overwrite', action='store_true', 
                          help='Overwrite existing files instead of renaming')
    
    args = parser.parse_args()
    
    if args.command == 'backup':
        return create_snapshot(args.reason, args.quiet)
    elif args.command == 'list':
        return list_snapshots(args.recent)
    elif args.command == 'show':
        return show_snapshot(args.id)
    elif args.command == 'restore':
        return restore_snapshot(args.id, args.overwrite)
    else:
        parser.print_help()
        return 0


if __name__ == '__main__':
    sys.exit(main() or 0)
