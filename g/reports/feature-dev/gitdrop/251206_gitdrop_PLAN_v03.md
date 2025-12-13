# GitDrop Phase 1 Implementation Plan

**Feature:** Minimal Workspace Safety Layer  
**Spec:** [251206_gitdrop_SPEC_v03.md](file:///Users/icmini/02luka/g/reports/feature-dev/gitdrop/251206_gitdrop_SPEC_v03.md)  
**Date:** 2025-12-06  
**Version:** 3.0 (Final - Ready for CLC)

---

## Assumptions

> [!IMPORTANT]
> **Path Binding:**  
> `LUKA_SOT="/Users/icmini/02luka"`  
> All paths in this document use this variable.

---

## Proposed Changes

### [NEW] tools/gitdrop.py

**Purpose:** GitDrop CLI (single file, ~300 lines)

**Shebang + Version Guard:**
```python
#!/usr/bin/env python3
"""GitDrop Phase 1: Minimal workspace safety"""
import sys
if sys.version_info < (3, 6):
    sys.exit("GitDrop requires Python 3.6+")
```

**Configuration:**
```python
LUKA_SOT = "/Users/icmini/02luka"
GITDROP_DIR = f"{LUKA_SOT}/_gitdrop"
SNAPSHOTS_DIR = f"{GITDROP_DIR}/snapshots"
INDEX_FILE = f"{GITDROP_DIR}/index.jsonl"
ERROR_LOG = f"{GITDROP_DIR}/error.log"

# Backup scope
INCLUDE_PATTERNS = [
    "g/reports/**/*.md",
    "tools/*.zsh",
    "tools/*.py",
    "*.md"  # root level only
]

EXCLUDE_PATTERNS = [
    "node_modules/**",
    "__pycache__/**",
    ".DS_Store",
    "*.tmp",
    "*.log",
    "*.pyc",
    ".git/**",
    "_gitdrop/**"
]

MAX_FILE_SIZE_MB = 5
```

**Functions to implement:**
```python
def get_uncommitted_files() -> List[str]:
    """Get files from git status, filter by scope"""
    
def create_snapshot(reason: str, quiet: bool = False) -> int:
    """Create snapshot, return 0 on success, 1 on error"""
    
def list_snapshots(recent: int = None):
    """Show snapshots with desk metaphor UX"""
    
def show_snapshot(snapshot_id: str):
    """Show files in snapshot"""
    
def restore_snapshot(snapshot_id: str, overwrite: bool = False):
    """Restore files with conflict handling"""
```

---

### [MODIFY] .git/hooks/pre-checkout

**Replace existing hook:**
```bash
#!/usr/bin/env zsh
# GitDrop Phase 1: Safety before checkout
set -euo pipefail

LUKA_SOT="/Users/icmini/02luka"

python3 "$LUKA_SOT/tools/gitdrop.py" backup \
  --reason "git checkout $*" \
  --quiet || {
  echo "[GitDrop] ⚠️ Backup failed but continuing checkout"
  echo "[GitDrop] See: $LUKA_SOT/_gitdrop/error.log"
}

# Always allow checkout to proceed
exit 0
```

---

### [MODIFY] .gitignore

**Add:**
```
# GitDrop workspace safety (local only)
_gitdrop/
```

---

## Implementation Steps

### Step 1: Create gitdrop.py Core (2 hours)

**1.1 Setup structure:**
```python
#!/usr/bin/env python3
"""GitDrop Phase 1"""

import argparse
import json
import hashlib
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional

# Config (as shown above)
```

**1.2 Implement `get_uncommitted_files()`:**
```python
def get_uncommitted_files() -> List[str]:
    """Get uncommitted files matching backup scope"""
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        capture_output=True, text=True, cwd=LUKA_SOT
    )
    
    files = []
    for line in result.stdout.strip().split('\n'):
        if not line:
            continue
        status = line[:2]
        filepath = line[3:]
        
        # Only M (modified), A (added), ?? (untracked)
        if status.strip() not in ['M', 'A', '??', 'AM', 'MM']:
            continue
            
        # Check include patterns
        if not matches_include(filepath):
            continue
            
        # Check exclude patterns
        if matches_exclude(filepath):
            continue
            
        # Check file size
        full_path = Path(LUKA_SOT) / filepath
        if full_path.exists() and full_path.stat().st_size > MAX_FILE_SIZE_MB * 1024 * 1024:
            continue
            
        files.append(filepath)
    
    return files
```

**1.3 Implement `create_snapshot()`:**
```python
def create_snapshot(reason: str, quiet: bool = False) -> int:
    """Create snapshot of uncommitted files"""
    files = get_uncommitted_files()
    
    if not files:
        if not quiet:
            print("[GitDrop] No working papers to save")
        return 0
    
    # Create snapshot ID
    snapshot_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    snapshot_dir = Path(SNAPSHOTS_DIR) / snapshot_id
    files_dir = snapshot_dir / "files"
    files_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy files
    file_records = []
    for i, filepath in enumerate(files):
        file_id = f"f_{i+1:03d}"
        src = Path(LUKA_SOT) / filepath
        dst = files_dir / file_id
        
        try:
            shutil.copy2(src, dst)
            file_records.append({
                "id": file_id,
                "path": filepath,
                "size": src.stat().st_size,
                "hash": hashlib.sha256(src.read_bytes()).hexdigest()[:16]
            })
        except Exception as e:
            log_error(f"Failed to copy {filepath}: {e}")
    
    # Write meta.json
    meta = {
        "id": snapshot_id,
        "created": datetime.now().isoformat(),
        "reason": reason,
        "files": file_records,
        "total_files": len(file_records),
        "total_size": sum(f["size"] for f in file_records)
    }
    (snapshot_dir / "meta.json").write_text(json.dumps(meta, indent=2))
    
    # Append index.jsonl
    index_entry = {
        "id": snapshot_id,
        "created": meta["created"],
        "reason": reason,
        "files": len(file_records),
        "size": meta["total_size"]
    }
    with open(INDEX_FILE, "a") as f:
        f.write(json.dumps(index_entry) + "\n")
    
    if not quiet:
        print(f"[GitDrop] Saving your working papers to tray... ✓")
        print(f"[GitDrop] Snapshot {snapshot_id} created ({len(file_records)} files)")
    
    return 0
```

---

### Step 2: Implement CLI Commands (1 hour)

**2.1 `list_snapshots()`:**
```python
def list_snapshots(recent: int = None):
    """Show snapshots with desk metaphor"""
    print("\nYour Working Paper Tray")
    print("━" * 50)
    
    if not Path(INDEX_FILE).exists():
        print("(empty - no snapshots yet)")
        return
    
    entries = []
    with open(INDEX_FILE) as f:
        for i, line in enumerate(f):
            try:
                entries.append(json.loads(line))
            except:
                log_error(f"Skipping corrupt entry at line {i+1}")
    
    entries = entries[::-1]  # Newest first
    if recent:
        entries = entries[:recent]
    
    for i, entry in enumerate(entries, 1):
        reason = entry.get("reason", "unknown")[:20]
        files = entry.get("files", 0)
        print(f"#{i:<3} {entry['id']}   {reason:<20} {files} papers")
    
    print("\nUse: gitdrop show <snapshot_id>")
    print("     gitdrop restore <snapshot_id>")
```

**2.2 `show_snapshot()`:**
```python
def show_snapshot(snapshot_id: str):
    """Show snapshot details"""
    meta_path = Path(SNAPSHOTS_DIR) / snapshot_id / "meta.json"
    
    if not meta_path.exists():
        print(f"[GitDrop] Error: Snapshot {snapshot_id} not found")
        return 1
    
    try:
        meta = json.loads(meta_path.read_text())
    except:
        print(f"[GitDrop] Error: Cannot read snapshot {snapshot_id}")
        print(f"[GitDrop] meta.json corrupt")
        return 1
    
    print(f"\nSnapshot: {meta['id']}")
    print(f"Created:  {meta['created']}")
    print(f"Reason:   {meta['reason']}")
    print("━" * 50)
    print("Papers saved:")
    
    for f in meta["files"]:
        size_kb = f["size"] / 1024
        print(f"  {f['path']:<40} {size_kb:.1f}KB")
    
    print(f"\nRestore: gitdrop restore {snapshot_id}")
    return 0
```

**2.3 `restore_snapshot()`:**
```python
def restore_snapshot(snapshot_id: str, overwrite: bool = False):
    """Restore files with conflict handling"""
    meta_path = Path(SNAPSHOTS_DIR) / snapshot_id / "meta.json"
    files_dir = Path(SNAPSHOTS_DIR) / snapshot_id / "files"
    
    if not meta_path.exists():
        print(f"[GitDrop] Error: Snapshot {snapshot_id} not found")
        return 1
    
    try:
        meta = json.loads(meta_path.read_text())
    except:
        print(f"[GitDrop] Error: Cannot read snapshot {snapshot_id}")
        print(f"[GitDrop] meta.json corrupt - aborting restore")
        return 1
    
    print(f"\nRestoring snapshot {snapshot_id}...")
    print("━" * 50)
    
    restored = 0
    renamed = 0
    
    for f in meta["files"]:
        src = files_dir / f["id"]
        dst = Path(LUKA_SOT) / f["path"]
        
        # Create parent dirs
        dst.parent.mkdir(parents=True, exist_ok=True)
        
        if not dst.exists() or overwrite:
            shutil.copy2(src, dst)
            print(f"✓ {f['path']}")
            restored += 1
        else:
            # Conflict: create renamed version
            stem = dst.stem
            suffix = dst.suffix
            new_name = f"{stem}.gitdrop-restored-{snapshot_id}{suffix}"
            new_dst = dst.parent / new_name
            shutil.copy2(src, new_dst)
            print(f"⚠ {f['path']} exists")
            print(f"  → Saved as: {new_name}")
            renamed += 1
    
    print(f"\nRestored {restored + renamed} files", end="")
    if renamed:
        print(f" ({renamed} renamed to avoid conflict)")
    else:
        print()
    
    return 0
```

---

### Step 3: CLI Entry Point (30 min)

```python
def main():
    parser = argparse.ArgumentParser(description="GitDrop: Workspace safety")
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # backup
    p_backup = subparsers.add_parser('backup', help='Create snapshot')
    p_backup.add_argument('--reason', required=True)
    p_backup.add_argument('--quiet', action='store_true')
    
    # list
    p_list = subparsers.add_parser('list', help='Show snapshots')
    p_list.add_argument('--recent', type=int)
    
    # show
    p_show = subparsers.add_parser('show', help='Show snapshot details')
    p_show.add_argument('id', help='Snapshot ID (YYYYMMDD_HHMMSS)')
    
    # restore
    p_restore = subparsers.add_parser('restore', help='Restore files')
    p_restore.add_argument('id', help='Snapshot ID')
    p_restore.add_argument('--overwrite', action='store_true')
    p_restore.add_argument('--dry-run', action='store_true')
    
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
```

---

### Step 4: Hook Integration (30 min)

1. **Backup current hook:**
   ```bash
   cp /Users/icmini/02luka/.git/hooks/pre-checkout \
      /Users/icmini/02luka/.git/hooks/pre-checkout.backup
   ```

2. **Install new hook** (as shown in MODIFY section)

3. **Run sandbox check:**
   ```bash
   /Users/icmini/02luka/tools/codex_sandbox_check.zsh \
     /Users/icmini/02luka/.git/hooks/pre-checkout
   ```

---

### Step 5: CLI Installation (10 min)

**Add to `~/.zshrc`:**
```bash
# GitDrop CLI
alias gitdrop='python3 /Users/icmini/02luka/tools/gitdrop.py'
```

**Make executable:**
```bash
chmod +x /Users/icmini/02luka/tools/gitdrop.py
```

**Test:**
```bash
source ~/.zshrc
gitdrop list
```

---

### Step 6: Testing (1 hour)

**Test Matrix:**

| Test | Command | Expected |
|------|---------|----------|
| Auto-backup | `git checkout main` | Snapshot created |
| Backup scope | Create `foo.xyz`, checkout | Not backed up |
| List empty | `gitdrop list` | "(empty)" |
| List results | `gitdrop list` | Shows snapshots |
| Show | `gitdrop show <id>` | Shows files |
| Show bad ID | `gitdrop show bad` | Error message |
| Restore empty | Delete, restore | File restored |
| Restore conflict | File exists | Creates `.gitdrop-restored-<id>` |
| Restore overwrite | `--overwrite` | Overwrites |
| Corrupt meta | Corrupt meta.json | Error, abort |
| Corrupt index | Corrupt line in index | Skips line, continues |
| Backup fail | Fill disk, checkout | Git continues |

---

## Verification Plan

### E2E Test

```bash
# 1. Create work
echo "draft" > /Users/icmini/02luka/g/reports/test_gitdrop.md

# 2. Trigger backup
git checkout -b test-gitdrop-branch

# 3. Verify
gitdrop list
gitdrop show <snapshot_id>

# 4. Switch back (file disappears)
git checkout main
ls /Users/icmini/02luka/g/reports/test_gitdrop.md  # Should not exist

# 5. Restore
gitdrop restore <snapshot_id>

# 6. Verify
cat /Users/icmini/02luka/g/reports/test_gitdrop.md  # Should show "draft"

# 7. Cleanup
rm /Users/icmini/02luka/g/reports/test_gitdrop.md
git branch -D test-gitdrop-branch
```

---

## File Checklist

**New:**
- [ ] `tools/gitdrop.py` (~300 lines)

**Modified:**
- [ ] `.git/hooks/pre-checkout`
- [ ] `.gitignore`
- [ ] `~/.zshrc` (alias)

**Created at runtime:**
- [ ] `_gitdrop/`
- [ ] `_gitdrop/index.jsonl`

---

## Success Criteria

- [ ] Works for 2 weeks
- [ ] Boss uses gitdrop restore at least once
- [ ] No "checkout blocked" incidents
- [ ] UX feels like "desk metaphor"

---

## Rollback

```bash
# Restore old hook
mv /Users/icmini/02luka/.git/hooks/pre-checkout.backup \
   /Users/icmini/02luka/.git/hooks/pre-checkout

# Remove alias from ~/.zshrc
# Old backups preserved in _gitdrop/
```

---

**Status:** Ready for CLC  
**Timeline:** 4-5 hours  
**Risk:** Low
