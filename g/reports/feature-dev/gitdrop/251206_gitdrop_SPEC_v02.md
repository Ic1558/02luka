# GitDrop Phase 1: Minimal Workspace Safety

**Feature ID:** GITDROP-001  
**Version:** 2.0 (Revised - Minimal Scope)  
**Date:** 2025-12-06  
**Status:** Proposed

---

## Problem Statement

**Pain Point:** Files created locally disappear on `git checkout`

Boss creates reports, scripts, notes on local machine. Forgets to commit. Switches branch → files gone forever.

**Current Workaround:** `.git/auto-backups/` (basic, hard to browse/restore)

**Needed:** "Desk metaphor" - papers stay on desk until you file them.

---

## Solution: GitDrop Phase 1

**What:** Minimal safety layer that:
1. Auto-snapshots critical files before `git checkout`
2. Stores in browsable `_gitdrop/` structure
3. One-command restore to original paths

**Philosophy:** 
```
"Your desk papers stay there until YOU file them.
 Git is just a filing cabinet, not your boss."
```

---

## Phase 1 Scope (MINIMAL)

### What's Included ✅

**Intercept:**
- `git checkout` ONLY
- Not reset/clean (future phases)

**Backup:**
- `g/reports/**/*.md`
- `tools/*.zsh`
- `tools/*.py`
- Root `*.md` files

**Exclude:**
- `node_modules/`, `__pycache__/`, `.DS_Store`
- Binary files, images, videos
- Logs, temp files

**CLI:**
- `gitdrop list` - Show snapshots
- `gitdrop show <id>` - View snapshot details
- `gitdrop restore <id>` - Restore files

**Storage:**
```
_gitdrop/
  snapshots/
    20251206_192000/
      meta.json
      files/
        f_001  (g/reports/analysis.md)
        f_002  (tools/script.zsh)
  index.jsonl
```

### What's NOT Included ❌

- Compression/deduplication
- Auto-cleanup (manual only)
- `git reset`/`git clean` interception
- VSCode integration
- Cloud sync
- Stats/analytics
- Conflict resolution UI

---

## Requirements

### FR-1: Auto-Backup on Checkout

**Trigger:** `.git/hooks/pre-checkout`

**Behavior:**
```bash
$ git checkout main

[GitDrop] Saving your working papers to tray... ✓
[GitDrop] Snapshot #42 created (5 files)
[GitDrop] Continue with checkout

Switched to branch 'main'
```

**If backup fails:**
```bash
[GitDrop] ⚠️ BACKUP FAILED (disk full/permission)
[GitDrop] Git continuing WITHOUT safety net!
[GitDrop] See: _gitdrop/error.log

Switched to branch 'main'
```

→ Git **continues anyway** (graceful degradation)

---

### FR-2: Snapshot Storage

**Structure:**
```json
// meta.json
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
  ]
}
```

**Index:**
```jsonl
{"id":"20251206_192000","created":"...","reason":"git checkout main","files":5}
```

---

### FR-3: List & Show

**List:**
```bash
$ gitdrop list

Your Working Paper Tray
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#42  Dec 6, 19:20  checkout main    5 papers
#41  Dec 6, 15:30  checkout dev     2 papers
#40  Dec 5, 10:00  checkout feat    12 papers
```

**Show:**
```bash
$ gitdrop show 42

Snapshot #42 (Dec 6, 19:20)
Saved before: git checkout main
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Papers saved:
  g/reports/analysis_draft.md        12KB
  tools/experimental.zsh              2KB
  README_wip.md                       5KB
  (+ 2 more)

Restore: gitdrop restore 42
```

---

### FR-4: Restore

**Default behavior:**
```bash
$ gitdrop restore 42

Restoring snapshot #42...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ g/reports/analysis_draft.md
⚠ tools/experimental.zsh exists
  → Saved as: experimental.gitdrop-restored-42.zsh
✓ README_wip.md

Restored 5 files (1 renamed to avoid conflicts)
```

**No prompts, no overwrites by default.**

**Force overwrite:**
```bash
$ gitdrop restore 42 --overwrite
```

---

## Architecture

### Components

```
GitDrop Layer
├── Backup Engine (snapshot creator)
├── Index (JSONL database)
└── Restore Engine (file recovery)

Hooks into:
└── .git/hooks/pre-checkout
```

### Data Flow

**Backup:**
```
pre-checkout hook
  → gitdrop.py backup
  → scan for untracked/modified in scope
  → copy to _gitdrop/snapshots/<timestamp>/files/
  → write meta.json
  → append index.jsonl
  → exit 0 (allow checkout)
```

**Restore:**
```
gitdrop restore 42
  → load meta.json
  → for each file:
      if path empty → copy
      if path exists → copy as .gitdrop-restored-<id>
  → report summary
```

---

## File Structure

```
02luka/
├── _gitdrop/
│   ├── snapshots/
│   │   └── 20251206_192000/
│   │       ├── meta.json
│   │       └── files/
│   │           ├── f_001
│   │           └── f_002
│   ├── index.jsonl
│   └── error.log (if any)
├── .git/
│   └── hooks/
│       └── pre-checkout (REPLACE existing)
├── .gitignore (add: _gitdrop/)
└── tools/
    └── gitdrop.py (NEW)
```

---

## API

### CLI Commands

```bash
# List all snapshots
gitdrop list [--recent N]

# Show snapshot details  
gitdrop show <id>

# Restore snapshot
gitdrop restore <id> [--overwrite] [--dry-run]

# Manual backup (for testing)
gitdrop backup --reason "manual test"
```

---

## Integration

### Git Hook

**Replace** `.git/hooks/pre-checkout`:
```bash
#!/usr/bin/env zsh
python3 ~/02luka/tools/gitdrop.py backup \
  --reason "git checkout $@" \
  --quiet || true

exit 0  # Always allow checkout
```

### Exclude from Git

Add to `.gitignore`:
```
# GitDrop (local workspace safety)
_gitdrop/
```

---

## Success Criteria

- [ ] Boss forgets to commit, switches branch → snapshot auto-created
- [ ] `gitdrop list` shows "desk metaphor" language
- [ ] `gitdrop restore` recovers files to exact original paths
- [ ] Backup failure doesn't break Git
- [ ] Works for 2 weeks without issues
- [ ] Boss approves UX

---

## Non-Goals (Future Phases)

- Intercept `git reset`/`git clean`
- Compression/dedup
- Auto-cleanup by retention
- Cloud sync
- Team sharing
- Web UI

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Backup slow | Only critical files (<3s) |
| Disk space | Manual cleanup, Boss controls |
| Restore conflicts | Suffix, no overwrite |
| Hook breaks Git | Graceful degradation ✓ |

---

## Implementation Estimate

**Total:** 4-5 hours

- Backup engine: 2h
- Restore engine: 1h  
- CLI + hooks: 1h
- Testing: 1h

---

## Comparison: v01 vs v02

| Feature | v01 (Full) | v02 (Phase 1) |
|---------|------------|---------------|
| Intercept | checkout/reset/clean | checkout only |
| Backup scope | Entire repo | Critical files |
| Compression | Yes | No |
| Auto-cleanup | Yes | Manual only |
| CLI commands | 5 | 3 |
| Timeline | 6-7h | 4-5h |

---

**Status:** Ready for approval (revised minimal scope)  
**Recommendation:** Proceed with Phase 1, evaluate, then expand ✅
