# GitDrop Phase 1 Implementation Plan

**Feature:** Minimal Workspace Safety Layer  
**Spec:** [251206_gitdrop_SPEC_v02.md](file:///Users/icmini/02luka/g/reports/feature-dev/gitdrop/251206_gitdrop_SPEC_v02.md)  
**Date:** 2025-12-06  
**Scope:** Phase 1 ONLY

---

## User Review Required

> [!IMPORTANT]
> **Minimal Phase 1 Scope**
> - Intercept: `git checkout` ONLY
> - Backup: `g/reports/**`, `tools/*.{zsh,py}`, `*.md` (root)
> - CLI: `list`, `show`, `restore` (no cleanup/stats)
> - No compression, no auto-cleanup
> - **Goal:** Prove concept, evaluate usefulness

> [!WARNING]
> **Replaces Existing System**
> - Will REPLACE `.git/auto-backups/` (not coexist)
> - Old backups preserved but system switches to GitDrop
> - Reversible: Can uninstall cleanly

---

## Proposed Changes

### Core Implementation

#### [NEW] [tools/gitdrop.py](file:///Users/icmini/02luka/tools/gitdrop.py)

**Purpose:** GitDrop CLI tool (single file, stdlib only)

**Functions:**
```python
def backup(reason: str) -> int:
    """Create snapshot of uncommitted critical files"""
    # 1. Get untracked/modified files in scope
    # 2. Create snapshot dir: _gitdrop/snapshots/<timestamp>/
    # 3. Copy files → files/f_001, f_002, ...
    # 4. Write meta.json
    # 5. Append index.jsonl
    # Return: 0 on success, 1 on error (but don't block Git)

def list_snapshots(recent: int = None):
    """Show all snapshots (desk metaphor language)"""
    
def show_snapshot(snapshot_id: str):
    """Show files in snapshot"""
    
def restore_snapshot(snapshot_id: str, overwrite: bool = False):
    """Restore files to original paths"""
    # If file exists → create .gitdrop-restored-<id> suffix
```

**Dependencies:** `pathlib`, `json`, `hashlib`, `shutil`, `argparse` (stdlib only)

---

### Storage Structure

#### [NEW] [\_gitdrop/](file:///Users/icmini/02luka/_gitdrop/)

**Created by first backup:**
```
_gitdrop/
├── snapshots/
│   └── 20251206_192000/
│       ├── meta.json
│       └── files/
│           ├── f_001
│           └── f_002
├── index.jsonl (auto-created)
└── error.log (created if backup fails)
```

---

### Git Integration  

#### [MODIFY] [.git/hooks/pre-checkout](file:///Users/icmini/02luka/.git/hooks/pre-checkout)

**Current:** Backs up to `.git/auto-backups/`

**New:** Call GitDrop
```bash
#!/usr/bin/env zsh
# GitDrop Phase 1: Safety before checkout

python3 ~/02luka/tools/gitdrop.py backup \
  --reason "git checkout $@" \
  --quiet || {
  echo "[GitDrop] ⚠️ Backup failed but continuing checkout"
  echo "[GitDrop] See: ~/02luka/_gitdrop/error.log"
}

# Always allow checkout to proceed
exit 0
```

**Key behaviors:**
- Backup failure → log error, warn, but **don't block checkout**
- Quiet mode → only show errors
- Exit 0 always → Git never blocked

---

#### [MODIFY] [.gitignore](file:///Users/icmini/02luka/.gitignore)

**Add:**
```
# GitDrop workspace safety (local only)
_gitdrop/
```

---

## Implementation Steps

### Step 1: Core Backup Engine (2 hours)

**Create `tools/gitdrop.py`:**

```python
#!/usr/bin/env python3
"""GitDrop Phase 1: Minimal workspace safety"""

# 1. Implement backup():
#    - Get uncommitted files matching scope
#    - Filter: g/reports/**, tools/*.{zsh,py}, *.md
#    - Create snapshot directory
#    - Copy files with IDs (f_001, f_002...)
#    - Generate meta.json
#    - Append index.jsonl

# 2. Error handling:
#    - Disk full → log to error.log, return 1
#    - Permission error → log, return 1
#    - Git error → log, return 1
#    - BUT: Always return 0 to Git hook (don't block)
```

**Test:**
```bash
# Manual test
python3 tools/gitdrop.py backup --reason "test"

# Verify structure
ls -la _gitdrop/snapshots/
cat _gitdrop/index.jsonl
```

---

### Step 2: Restore Engine (1 hour)

**Add to `tools/gitdrop.py`:**

```python
def restore_snapshot(snapshot_id: str, overwrite: bool = False):
    """Restore files with conflict handling"""
    # Load meta.json
    # For each file:
    #   original_path = file['path']
    #   if not exists(original_path):
    #       copy directly
    #   elif overwrite:
    #       copy (overwrite)
    #   else:
    #       copy as .gitdrop-restored-<id>
    # Print summary
```

**Test:**
```bash
# Create test file
echo "test" > g/reports/test.md

# Backup
python3 tools/gitdrop.py backup --reason "test"

# Delete
rm g/reports/test.md

# Restore
python3 tools/gitdrop.py restore <snapshot_id>

# Verify
cat g/reports/test.md  # Should exist
```

---

### Step 3: CLI Interface (1 hour)

**Add argparse CLI:**

```python
def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest='command')
    
    # gitdrop backup
    backup_p = subparsers.add_parser('backup')
    backup_p.add_argument('--reason', required=True)
    backup_p.add_argument('--quiet', action='store_true')
    
    # gitdrop list
    list_p = subparsers.add_parser('list')
    list_p.add_argument('--recent', type=int)
    
    # gitdrop show
    show_p = subparsers.add_parser('show')
    show_p.add_argument('id')
    
    # gitdrop restore
    restore_p = subparsers.add_parser('restore')
    restore_p.add_argument('id')
    restore_p.add_argument('--overwrite', action='store_true')
    restore_p.add_argument('--dry-run', action='store_true')
```

**Test all commands:**
```bash
gitdrop list
gitdrop show 20251206_192000
gitdrop restore 20251206_192000 --dry-run
```

---

### Step 4: Hook Integration (30 minutes)

1. **Backup current hook:**
   ```bash
   cp .git/hooks/pre-checkout .git/hooks/pre-checkout.backup
   ```

2. **Replace with GitDrop version**

3. **Test with real checkout:**
   ```bash
   echo "test" > test_hook.md
   git checkout -b test-branch
   git checkout main
   
   # Verify snapshot created
   gitdrop list
   ```

---

### Step 5: Testing (1 hour)

**Test Matrix:**

| Test | Command | Expected |
|------|---------|----------|
| Auto-backup | `git checkout main` | Snapshot created |
| Backup scope | Create file outside scope | Not backed up |
| List | `gitdrop list` | Shows snapshots |
| Show | `gitdrop show <id>` | Shows files |
| Restore empty path | Delete file, restore | File restored |
| Restore conflict | File exists, restore | Creates `.gitdrop-restored-<id>` |
| Backup failure | Fill disk, checkout | Git continues, error logged |
| Hook disabled | `chmod -x hook`, checkout | Git works normally |

---

## Verification Plan

### Manual E2E Test

```bash
# 1. Create work
vim g/reports/important.md
# (write something, save, DON'T commit)

# 2. Trigger backup
git checkout -b test-branch

# 3. Verify backup
gitdrop list  # Should show snapshot
gitdrop show <id>  # Should show important.md

# 4. Switch back
git checkout main  # important.md disappears

# 5. Restore
gitdrop restore <id>

# 6. Verify restored
cat g/reports/important.md  # Should have content
```

**Expected:** Full cycle works, no data loss ✅

---

## Migration from auto-backups

**Old system:** `.git/auto-backups/`

**Migration:**
1. Keep old backups (don't delete)
2. Use GitDrop going forward
3. After 2 weeks → can delete `.git/auto-backups/` if Boss approves

**Rollback:**
```bash
# Restore old hook
mv .git/hooks/pre-checkout.backup .git/hooks/pre-checkout

# Old system back
```

---

## Success Criteria

- [ ] `git checkout` auto-creates snapshots
- [ ] Only backs up critical files (not node_modules, etc.)
- [ ] `gitdrop list` uses "desk metaphor" language
- [ ] `gitdrop restore` works with conflicts
- [ ] Backup failure doesn't break Git
- [ ] Boss uses for 2 weeks without issues
- [ ] Faster than old auto-backups system

---

## File Checklist

**New:**
- [ ] `tools/gitdrop.py` (single file, ~300 lines)

**Modified:**
- [ ] `.git/hooks/pre-checkout`
- [ ] `.gitignore`

**Created at runtime:**
- [ ] `_gitdrop/` (directory)
- [ ] `_gitdrop/index.jsonl`

---

## Dependencies

**Python:** stdlib only ✅
- pathlib
- json
- hashlib
- shutil
- argparse
- datetime

**No external packages needed**

---

## Timeline

**Total:** 4-5 hours

- Step 1 (Backup): 2h
- Step 2 (Restore): 1h
- Step 3 (CLI): 1h
- Step 4 (Hooks): 30min
- Step 5 (Testing): 1h

**Can complete in 1 work session**

---

## Rollback Plan

**If issues:**

1. **Disable GitDrop:**
   ```bash
   mv .git/hooks/pre-checkout.backup .git/hooks/pre-checkout
   ```

2. **Old backups still in:** `.git/auto-backups/`

3. **GitDrop data preserved:** `_gitdrop/` (can recover manually)

**Low risk, fully reversible** ✅

---

## What's Next (Phase 2+)

**After 2 weeks:**
- Add `git reset` interception
- Add `git clean` interception  
- Add auto-cleanup (retention policy)
- Add compression
- Add stats/analytics

**Boss decides based on Phase 1 usefulness**

---

## Comparison: v01 vs v02 Plan

| Aspect | v01 (Full) | v02 (Phase 1) |
|--------|------------|---------------|
| Scope | All operations | checkout only |
| Timeline | 6-7 hours | 4-5 hours |
| Complexity | High | Medium |
| Risk | Medium | Low |
| Features | 10+ | 3 core |
| Testing time | 2 hours | 1 hour |

---

**Status:** Ready to implement  
**Recommendation:** Approve Phase 1, execute, evaluate after 2 weeks ✅
