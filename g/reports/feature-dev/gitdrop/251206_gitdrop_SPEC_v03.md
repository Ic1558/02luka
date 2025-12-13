# GitDrop Phase 1: Minimal Workspace Safety

**Feature ID:** GITDROP-001  
**Version:** 3.0 (Final Phase 1 - Ready for CLC)  
**Date:** 2025-12-06  
**Status:** Approved

---

## Assumptions

> [!IMPORTANT]
> **Path Assumption:**  
> GitDrop Phase 1 is bound to SOT repo at:  
> `LUKA_SOT="/Users/icmini/02luka"`  
> 
> Does NOT support other paths/clones in Phase 1.

---

## Problem Statement

**Pain Point:** Uncommitted files disappear on `git checkout`

Boss creates reports, scripts, notes. Forgets to commit. Switches branch → files gone forever.

**Solution:** GitDrop = "desk metaphor" safety layer

---

## Phase 1 Scope

### Intercept ✅
- `git checkout` ONLY
- Not reset/clean (future phases)

### Backup Scope (Exact) ✅

**Include patterns:**
```
g/reports/**/*.md
tools/*.zsh
tools/*.py
*.md (root level only)
```

**Exclude patterns:**
```
node_modules/**
__pycache__/**
.DS_Store
*.tmp
*.log
*.pyc
.git/**
_gitdrop/**
```

**Max file size:** 5MB (skip larger files)

**Source of truth:** `git status --porcelain` → filter by patterns

### CLI Commands ✅
- `gitdrop list` - Show snapshots
- `gitdrop show <snapshot_id>` - View snapshot details  
- `gitdrop restore <snapshot_id>` - Restore files

---

## Snapshot ID Format

**Format:** `YYYYMMDD_HHMMSS` (timestamp-based)

**Example:** `20251206_192000`

**CLI Usage:**
```bash
# Use full snapshot_id (timestamp)
gitdrop show 20251206_192000
gitdrop restore 20251206_192000
```

**Display in `list`:**
```
Your Working Paper Tray
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#1   20251206_192000   checkout main     5 papers
#2   20251206_153000   checkout dev      2 papers
#3   20251205_100000   checkout feat    12 papers

Use: gitdrop show <snapshot_id>
```

**Rule:** `#N` = display index (for reference), `snapshot_id` = actual ID for commands

---

## Storage Structure

```
/Users/icmini/02luka/
└── _gitdrop/
    ├── snapshots/
    │   └── 20251206_192000/
    │       ├── meta.json
    │       └── files/
    │           ├── f_001
    │           └── f_002
    ├── index.jsonl
    └── error.log (if errors occur)
```

### meta.json Schema
```json
{
  "id": "20251206_192000",
  "created": "2025-12-06T19:20:00+07:00",
  "reason": "git checkout main",
  "files": [
    {
      "id": "f_001",
      "path": "g/reports/analysis_draft.md",
      "size": 12345,
      "hash": "sha256:abc..."
    }
  ],
  "total_files": 2,
  "total_size": 14567
}
```

### index.jsonl Schema (append-only)
```jsonl
{"id":"20251206_192000","created":"...","reason":"git checkout main","files":5,"size":14567}
```

---

## CLI Requirements

### FR-1: `gitdrop list`

**Output:**
```
Your Working Paper Tray
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#1   20251206_192000   checkout main     5 papers
#2   20251206_153000   checkout dev      2 papers

Use: gitdrop show <snapshot_id>
     gitdrop restore <snapshot_id>
```

**If index.jsonl has corrupt lines:** Skip them, log warning, continue

### FR-2: `gitdrop show <snapshot_id>`

**Output:**
```
Snapshot: 20251206_192000
Created:  Dec 6, 2025 19:20
Reason:   git checkout main
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Papers saved:
  g/reports/analysis_draft.md        12KB
  tools/experimental.zsh              2KB
  README_wip.md                        5KB

Restore: gitdrop restore 20251206_192000
```

**If meta.json corrupt/missing:** Show error, do not crash

### FR-3: `gitdrop restore <snapshot_id>`

**Behavior:**
- If path empty → copy directly
- If file exists → create `<name>.gitdrop-restored-<id>.<ext>`
- **No prompts** (script-safe)
- Optional: `--overwrite` flag

**Output:**
```
Restoring snapshot 20251206_192000...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ g/reports/analysis_draft.md
⚠ tools/experimental.zsh exists
  → Saved as: experimental.gitdrop-restored-20251206_192000.zsh
✓ README_wip.md

Restored 3 files (1 renamed to avoid conflict)
```

**If meta.json corrupt:** Show error, abort, do nothing

---

## Auto-Backup Behavior

### Trigger: `.git/hooks/pre-checkout`

**Normal case:**
```
[GitDrop] Saving your working papers to tray... ✓
[GitDrop] Snapshot 20251206_192000 created (5 files)
Switched to branch 'main'
```

**No files to backup:**
```
[GitDrop] No working papers to save
Switched to branch 'main'
```

**Backup failure:**
```
[GitDrop] ⚠️ BACKUP FAILED: disk full
[GitDrop] Git continuing WITHOUT safety net!
[GitDrop] See: /Users/icmini/02luka/_gitdrop/error.log

Switched to branch 'main'
```

**Rule:** Backup failure → Git continues, do not block

---

## Corruption Handling

### index.jsonl corrupt

**Behavior:**
- Read line by line
- Skip lines that fail JSON parse
- Log: `"Skipping corrupt entry at line N"`
- Continue with valid entries

**Not implemented:** Index rebuild (future phase)

### meta.json missing/corrupt

**Behavior:**
- `gitdrop list`: Skip snapshot, show warning
- `gitdrop show`: Print error, exit 1
- `gitdrop restore`: Print error, exit 1, do nothing

**Example:**
```
[GitDrop] Error: Cannot read snapshot 20251206_192000
[GitDrop] meta.json missing or corrupt
[GitDrop] Snapshot data may still be in: _gitdrop/snapshots/20251206_192000/files/
```

---

## CLI Installation

**Add to `~/.zshrc`:**
```bash
# GitDrop CLI
alias gitdrop='python3 /Users/icmini/02luka/tools/gitdrop.py'
```

**Make script executable:**
```bash
chmod +x /Users/icmini/02luka/tools/gitdrop.py
```

**Alternative (direct call):**
```bash
python3 /Users/icmini/02luka/tools/gitdrop.py list
```

---

## Success Criteria

- [ ] `git checkout` auto-creates snapshot (critical files only)
- [ ] `gitdrop list` shows "desk metaphor" output
- [ ] `gitdrop restore` works without prompts
- [ ] Backup failure doesn't block Git
- [ ] Corrupt index/meta handled gracefully
- [ ] Works for 2 weeks without issues
- [ ] Boss approves UX

---

## Non-Goals (Phase 1)

- Intercept `git reset`/`git clean`
- Compression/deduplication
- Auto-cleanup
- Cloud sync
- VSCode integration

---

## Manual Cleanup (Phase 1)

**Guide for Boss:**
```bash
# List snapshots older than 7 days
ls -la /Users/icmini/02luka/_gitdrop/snapshots/ | head -20

# Delete specific snapshot
rm -rf /Users/icmini/02luka/_gitdrop/snapshots/20251201_*

# Delete all snapshots (start fresh)
rm -rf /Users/icmini/02luka/_gitdrop/snapshots/*
rm /Users/icmini/02luka/_gitdrop/index.jsonl
```

**Recommendation:** Clean up if `_gitdrop/` exceeds 500MB

---

**Status:** Ready for CLC implementation  
**Timeline:** 4-5 hours  
**Risk:** Low (minimal scope, graceful degradation)
