# GitDrop: Human-Centric Workspace Safety System

**Feature ID:** GITDROP-001  
**Version:** 1.0.0  
**Date:** 2025-12-06  
**Status:** Proposed

---

## Problem Statement

### Current Pain Points

**Problem 1: Git is Repo-Centric, Not Human-Centric**
- Git treats uncommitted files as "temporary trash"
- `git checkout` deletes untracked files without warning
- No concept of "work in progress on my desk"
- Users lose reports, scripts, and analysis accidentally

**Problem 2: Files Hostage to Git/GitHub**
- Local files shouldn't depend on GitHub
- GitHub should be backup only, not master
- Current system: forget to commit = permanent loss
- Feels like "files held hostage" by version control

**Problem 3: No "Desk/Tray" Metaphor**
- Physical desk: papers stay until you file them
- Git workspace: files vanish on branch switch
- No safe parking for "work in progress"
- No easy way to recover uncommitted work

---

## Solution Overview

**GitDrop** = A human-centric layer wrapping Git that:
1. Auto-backs up uncommitted files before dangerous operations
2. Indexes them with original paths and metadata
3. Allows one-click restore to original locations
4. Works like "parking tray for unfinished work"

**Philosophy:**
```
"Files belong to YOU, not Git.
 Git is just a tool, not the master."
```

---

## Requirements

### Functional Requirements

**FR-1: Auto-Backup Before Danger**
- MUST intercept: `git checkout`, `git reset`, `git clean`
- MUST backup ALL untracked + modified files
- MUST preserve original path information
- MUST do this automatically (no user action)

**FR-2: Safe Parking Structure**
```
_gitdrop/
  snapshots/
    2025-12-06T13-20-01/
      meta.json          # Snapshot metadata
      files/
        f_001            # Actual file content
        f_002
  index.jsonl           # Global index of all snapshots
```

**FR-3: Metadata Tracking**
```json
{
  "snapshot_id": "2025-12-06T13-20-01",
  "taken_at": "2025-12-06T13:20:01+07:00",
  "reason": "git checkout main",
  "files": [
    {
      "id": "f_001",
      "original_path": "g/reports/analysis_draft.md",
      "type": "report",
      "size": 12345,
      "hash": "sha256:...",
      "tags": ["uncommitted", "auto-backup"]
    }
  ]
}
```

**FR-4: CLI Interface**
```bash
gitdrop list                    # Show all snapshots
gitdrop show 42                 # Show snapshot details
gitdrop restore 42              # Restore to original paths
gitdrop restore 42 --path ~/Desktop  # Restore to custom location
gitdrop clean --older-than 30d  # Clean old snapshots
```

**FR-5: Smart Restore**
- IF original path empty → restore directly
- IF file exists → ask user or create `.restored` version
- MUST log all restores to audit log
- MUST show diff if conflicts

---

### Non-Functional Requirements

**NFR-1: Performance**
- Backup creation: <3 seconds for typical workspace
- Index search: <100ms
- Restore: <1 second per file

**NFR-2: Storage**
- Compression for large files
- De-duplication by hash
- Auto-cleanup of old snapshots (configurable)
- Disk usage: <500MB for 30 days of snapshots

**NFR-3: Integration**
- Zero Git configuration changes
- Works with existing hooks
- Compatible with VSCode/editors
- No external dependencies

**NFR-4: Reliability**
- Atomic snapshot creation
- Corruption-resistant (JSONL format)
- Failed restore doesn't lose data
- Graceful degradation if _gitdrop missing

---

## Architecture

### System Components

```
┌─────────────────────────────────────┐
│        GitDrop Layer                │
│  (Wraps Git Operations)             │
└─────────────────────────────────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
┌───▼───┐ ┌──▼──┐  ┌──▼───┐
│Backup │ │Index│  │Restore│
│Engine │ │ DB  │  │Engine │
└───┬───┘ └──┬──┘  └──┬───┘
    │        │        │
    └────────┼────────┘
             │
   ┌─────────▼─────────┐
   │   _gitdrop/       │
   │   Storage         │
   └───────────────────┘
```

### Data Flow

**Backup Flow:**
```
1. Git hook triggered (pre-checkout)
   ↓
2. Scan for uncommitted files
   ↓
3. Create snapshot directory
   ↓
4. Copy files → _gitdrop/snapshots/<timestamp>/files/
   ↓
5. Generate metadata → meta.json
   ↓
6. Append to index.jsonl
   ↓
7. Allow Git operation to proceed
```

**Restore Flow:**
```
1. User: gitdrop restore 42
   ↓
2. Load meta.json from snapshot
   ↓
3. For each file:
   - Check if original_path exists
   - If empty → copy directly
   - If exists → prompt or create .restored
   ↓
4. Log restore operation
   ↓
5. Report success/conflicts
```

---

## File Structure

```
02luka/
├── _gitdrop/
│   ├── snapshots/
│   │   └── 2025-12-06T13-20-01/
│   │       ├── meta.json
│   │       └── files/
│   │           ├── f_001
│   │           └── f_002
│   ├── index.jsonl
│   └── config.json
├── .git/
│   └── hooks/
│       └── pre-checkout    [MODIFIED]
└── tools/
    └── gitdrop.py         [NEW]
```

---

## API Specification

### CLI Commands

**1. List Snapshots**
```bash
gitdrop list [--recent N] [--since DATE]

# Output:
ID   Date                Reason              Files  Size
─────────────────────────────────────────────────────────
42   2025-12-06 13:20   git checkout main   5      124KB
41   2025-12-06 10:15   git reset --hard    12     1.2MB
```

**2. Show Snapshot**
```bash
gitdrop show 42

# Output:
Snapshot: 2025-12-06T13-20-01
Reason: git checkout main
Files (5):
  f_001  g/reports/analysis_draft.md        45KB
  f_002  tools/test_script.zsh              2KB
  ...
```

**3. Restore**
```bash
gitdrop restore 42                    # Restore all to original paths
gitdrop restore 42 --file f_001       # Restore specific file
gitdrop restore 42 --path ~/Desktop   # Custom location
gitdrop restore 42 --dry-run          # Show what would happen
```

**4. Cleanup**
```bash
gitdrop clean --older-than 30d        # Delete snapshots >30 days
gitdrop clean --keep-recent 10        # Keep only last 10
gitdrop stats                         # Show storage usage
```

---

## Schema Definitions

### meta.json
```json
{
  "snapshot_id": "string (ISO8601 timestamp)",
  "taken_at": "string (ISO8601)",
  "reason": "string (git command that triggered)",
  "git_branch_before": "string",
  "git_commit_before": "string (SHA)",
  "files": [
    {
      "id": "string (f_NNN)",
      "original_path": "string (relative to repo root)",
      "type": "string (report|script|code|config|other)",
      "size": "integer (bytes)",
      "hash": "string (sha256:...)",
      "tags": ["string"],
      "note": "string (optional)"
    }
  ],
  "total_files": "integer",
  "total_size": "integer"
}
```

### index.jsonl (one entry per snapshot)
```json
{"snapshot_id": "2025-12-06T13-20-01", "taken_at": "...", "files": 5, "size": 124000, "reason": "git checkout main"}
{"snapshot_id": "2025-12-06T10-15-00", "taken_at": "...", "files": 12, "size": 1200000, "reason": "git reset --hard"}
```

### config.json
```json
{
  "retention_days": 30,
  "max_snapshots": 100,
  "compression_enabled": true,
  "auto_cleanup": true,
  "excluded_patterns": [
    "*.tmp",
    "node_modules/**",
    ".DS_Store"
  ]
}
```

---

## Integration Points

### 1. Git Hooks

**Modified: `.git/hooks/pre-checkout`**
```bash
#!/usr/bin/env zsh
# Call gitdrop backup before checkout
python3 ~/02luka/tools/gitdrop.py backup \
  --reason "git checkout $@" \
  --auto

# Then allow checkout to proceed
exit 0
```

**New: `.git/hooks/pre-reset`** (similar logic)

### 2. Shell Aliases

```bash
# Safe git commands use gitdrop
alias git-checkout='gitdrop backup --auto && git checkout'
alias git-reset='gitdrop backup --auto && git reset'
alias git-clean='gitdrop backup --auto && git clean'
```

### 3. VSCode Integration (Future)

- Show gitdrop status in status bar
- Quick restore from sidebar
- Diff before restore

---

## Use Cases

### Use Case 1: Accidental Checkout

**Scenario:**
```bash
$ vim g/reports/analysis_draft.md   # Working on report
$ git checkout feature-branch       # Oops! Forgot to commit
```

**Without GitDrop:**
- analysis_draft.md → DELETED
- Work lost forever

**With GitDrop:**
```bash
$ git checkout feature-branch
⚠️  Found uncommitted files - backing up...
✅ Snapshot created: 2025-12-06T13-20-01
✅ Checkout completed

$ gitdrop list
ID   Date                Files
42   2025-12-06 13:20   1 file

$ gitdrop restore 42
✅ Restored: g/reports/analysis_draft.md
```

### Use Case 2: Review Old Work

**Scenario:** "What was that script I wrote last week?"

```bash
$ gitdrop list --since 7d
40   2025-11-29 15:30   tools/experimental.zsh
...

$ gitdrop show 40
$ gitdrop restore 40 --path ~/Desktop/recovered.zsh
```

### Use Case 3: Regular Cleanup

```bash
# Weekly cleanup
$ gitdrop clean --older-than 30d
Deleted 15 snapshots, freed 2.3GB
```

---

## Implementation Strategy

### Phase 1: Core Infrastructure (Week 1)
- Create `tools/gitdrop.py`
- Implement backup engine
- Create snapshot structure
- Build index system

### Phase 2: CLI Interface (Week 1)
- `gitdrop list`
- `gitdrop show`
- `gitdrop restore`
- `gitdrop clean`

### Phase 3: Git Integration (Week 2)
- Modify `.git/hooks/pre-checkout`
- Add other hooks (pre-reset, pre-clean)
- Test with real workflows

### Phase 4: Polish (Week 2)
- Add compression
- De-duplication
- Auto-cleanup
- Performance optimization

---

## Security & Privacy

**Data Safety:**
- Snapshots stored locally only
- No network transmission
- Excluded from Git (in `.gitignore`)
- User controls retention

**Access Control:**
- Same permissions as repo
- No special privileges needed
- Atomic operations

---

## Success Metrics

- ✅ Zero data loss from Git operations
- ✅ <3 second backup time
- ✅ 100% restore success rate
- ✅ Boss never loses uncommitted work
- ✅ "Desk metaphor" feels natural

---

## Future Enhancements

**v2.0:**
- Cloud sync of snapshots (optional)
- Smart tagging (ML-based file categorization)
- Integration with Liam for auto-recovery suggestions
- Web UI for browsing snapshots

**v3.0:**
- Real-time file watching
- Continuous snapshots (every 5 minutes)
- Conflict resolution UI
- Team sharing of snapshots

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Large repo = slow backup | Medium | Exclude patterns, compression |
| Disk space exhaustion | High | Auto-cleanup, configurable retention |
| Restore conflicts | Medium | Prompt user, create .restored versions |
| Hook failures | High | Graceful degradation, error logging |

---

## Appendix

### Comparison with Alternatives

**vs. Git Stash:**
- GitDrop: Automatic, indexed, easy browse
- Git Stash: Manual, stack-based, hard to find old work

**vs. Time Machine:**
- GitDrop: Instant, indexed by Git operations
- Time Machine: Hourly, file-system level

**vs. Manual Backups:**
- GitDrop: Automatic, no discipline needed
- Manual: Easy to forget

---

**Status:** Ready for implementation approval  
**Recommendation:** Proceed with Phase 1 (Core Infrastructure)
