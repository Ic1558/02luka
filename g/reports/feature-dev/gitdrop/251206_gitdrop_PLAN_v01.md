# GitDrop Implementation Plan

**Feature:** GitDrop - Human-Centric Workspace Safety  
**Spec:** [251206_gitdrop_SPEC_v01.md](file:///Users/icmini/02luka/g/reports/feature-dev/gitdrop/251206_gitdrop_SPEC_v01.md)  
**Date:** 2025-12-06

---

## User Review Required

> [!IMPORTANT]
> **Design Decision:** GitDrop operates as a separate layer wrapping Git operations
> - Does NOT modify Git internals
> - Uses hooks to intercept dangerous operations
> - Stores backups in `_gitdrop/` (excluded from Git)
> - Fully reversible (can uninstall cleanly)

> [!WARNING]
> **Storage Impact:** Expect ~100-500MB for 30 days of snapshots
> - Auto-cleanup configurable
> - Compression enabled by default
> - Can manually clean anytime

---

## Proposed Changes

### Phase 1: Core Infrastructure

#### [NEW] [gitdrop.py](file:///Users/icmini/02luka/tools/gitdrop.py)

**Purpose:** Main GitDrop CLI tool

**Functions:**
- `backup()` - Create snapshot of uncommitted files
- `list_snapshots()` - Browse saved snapshots
- `show_snapshot(id)` - View snapshot details
- `restore_snapshot(id)` - Restore files to original paths
- `clean_old()` - Remove old snapshots

**Dependencies:** Python stdlib only (pathlib, json, hashlib, shutil)

---

#### [NEW] [\_gitdrop/](file:///Users/icmini/02luka/_gitdrop/)

**Structure:**
```
_gitdrop/
├── snapshots/
│   └── 2025-12-06T13-20-01/
│       ├── meta.json
│       └── files/
│           ├── f_001
│           └── f_002
├── index.jsonl
└── config.json
```

**Storage Strategy:**
- Each snapshot = timestamped directory
- Files stored by ID (f_001, f_002, ...)
- Metadata tracks original paths
- JSONL index for fast lookup

---

#### [MODIFY] [.gitignore](file:///Users/icmini/02luka/.gitignore)

**Add:**
```
# GitDrop backups (never commit)
_gitdrop/
```

---

### Phase 2: Git Integration

#### [MODIFY] [.git/hooks/pre-checkout](file:///Users/icmini/02luka/.git/hooks/pre-checkout)

**Current:** Basic backup to `.git/auto-backups/`

**New:** Call gitdrop.py
```bash
#!/usr/bin/env zsh
# GitDrop integration
python3 ~/02luka/tools/gitdrop.py backup \
  --reason "git checkout $@" \
  --auto \
  --quiet

exit 0
```

---

#### [NEW] [.git/hooks/pre-reset](file:///Users/icmini/02luka/.git/hooks/pre-reset)

**Purpose:** Backup before `git reset --hard`

```bash
#!/usr/bin/env zsh
python3 ~/02luka/tools/gitdrop.py backup \
  --reason "git reset $@" \
  --auto \
  --quiet

exit 0
```

---

### Phase 3: CLI & Aliases

#### [NEW] [tools/gitdrop_aliases.zsh](file:///Users/icmini/02luka/tools/gitdrop_aliases.zsh)

**Safe Git wrappers:**
```bash
alias gitdrop='python3 ~/02luka/tools/gitdrop.py'
alias gd='gitdrop'

# Quick commands
alias gdl='gitdrop list'
alias gds='gitdrop show'
alias gdr='gitdrop restore'
```

---

### Phase 4: Configuration

#### [NEW] [\_gitdrop/config.json](file:///Users/icmini/02luka/_gitdrop/config.json)

**Default settings:**
```json
{
  "retention_days": 30,
  "max_snapshots": 100,
  "compression_enabled": false,
  "auto_cleanup": true,
  "excluded_patterns": [
    "*.tmp",
    "node_modules/**",
    ".DS_Store",
    "__pycache__/**"
  ]
}
```

---

## Verification Plan

### Automated Tests

**Test 1: Snapshot Creation**
```bash
cd ~/02luka
python3 -m pytest tools/test_gitdrop.py::test_create_snapshot -v
```

**Expected:** Snapshot created with correct metadata

---

**Test 2: File Backup & Restore**
```bash
# Create test file
echo "test" > /tmp/test_gitdrop.txt
cd ~/02luka

# Backup
python3 tools/gitdrop.py backup --auto

# Delete original
rm /tmp/test_gitdrop.txt

# Restore
python3 tools/gitdrop.py restore <snapshot_id>

# Verify
test -f /tmp/test_gitdrop.txt && echo "✅ PASS"
```

---

**Test 3: Hook Integration**
```bash
cd ~/02luka

# Create untracked file
echo "important work" > test_hook.md

# Trigger hook via checkout
git checkout -b test-gitdrop-branch
git checkout main

# Verify snapshot created
python3 tools/gitdrop.py list | grep "git checkout"

# Restore
python3 tools/gitdrop.py restore <snapshot_id>

# Verify file recovered
cat test_hook.md
```

**Expected:** File backed up automatically, restored successfully

---

### Manual Verification

**Test 4: End-to-End Workflow**

**Steps:**
1. Create new report: `vim g/reports/test_report.md`
2. Write some content, save
3. DON'T commit
4. Switch branch: `git checkout feature-branch`
5. Verify gitdrop backed up file
6. List snapshots: `gitdrop list`
7. Restore: `gitdrop restore <id>`
8. Verify file back in place

**Expected:**
- Report automatically backed up
- Restore puts it back exactly where it was
- No data loss

---

**Test 5: Cleanup**
```bash
# Create old snapshot (modify timestamp)
# ... (manual test)

# Run cleanup
gitdrop clean --older-than 30d

# Verify old snapshots gone
gitdrop list
```

---

## Implementation Steps

### Step 1: Create Core (2 hours)

1. Create `_gitdrop/` directory structure
2. Implement `tools/gitdrop.py`:
   - `backup()` function
   - Snapshot creation logic
   - Metadata generation
   - Index updates

3. Test manual backup:
   ```bash
   python3 tools/gitdrop.py backup --reason "manual test"
   ```

---

### Step 2: Add Restore (1 hour)

1. Implement `restore_snapshot()` in gitdrop.py
2. Add conflict detection
3. Test restore to original paths
4. Test restore to custom location

---

### Step 3: CLI Interface (1 hour)

1. Add argparse CLI
2. Implement `list`, `show`, `restore`, `clean`
3. Add pretty formatting
4. Test all commands

---

### Step 4: Git Integration (30 minutes)

1. Modify `.git/hooks/pre-checkout`
2. Create `.git/hooks/pre-reset`
3. Make hooks executable
4. Test with real git operations

---

### Step 5: Aliases & Polish (30 minutes)

1. Create `tools/gitdrop_aliases.zsh`
2. Add to `~/.zshrc` (optional)
3. Test quick commands
4. Update documentation

---

### Step 6: Testing (1 hour)

1. Create `tools/test_gitdrop.py`
2. Write unit tests for core functions
3. Write integration tests
4. Run full test suite

---

## File Checklist

**New Files:**
- [ ] `tools/gitdrop.py` (main CLI tool)
- [ ] `tools/test_gitdrop.py` (test suite)
- [ ] `tools/gitdrop_aliases.zsh` (shell aliases)
- [ ] `_gitdrop/config.json` (configuration)
- [ ] `_gitdrop/index.jsonl` (snapshot index)
- [ ] `.git/hooks/pre-reset` (new hook)

**Modified Files:**
- [ ] `.gitignore` (add `_gitdrop/`)
- [ ] `.git/hooks/pre-checkout` (call gitdrop.py)

**Documentation:**
- [ ] Create `_gitdrop/README.md` (usage guide)
- [ ] Update main README with GitDrop section

---

## Dependencies

**Python:**
- Standard library only ✅
- No external packages needed

**Shell:**
- zsh (already used)
- chmod for hooks

---

## Rollback Plan

**If issues arise:**

1. Unload hooks:
   ```bash
   chmod -x .git/hooks/pre-checkout
   chmod -x .git/hooks/pre-reset
   ```

2. Old backups still in `.git/auto-backups/`

3. GitDrop data in `_gitdrop/` preserved

4. Can restore manually:
   ```bash
   cp _gitdrop/snapshots/<id>/files/f_001 <original_path>
   ```

---

## Success Criteria

- [ ] Snapshots created automatically on git operations
- [ ] `gitdrop list` shows all snapshots
- [ ] `gitdrop restore` recovers files correctly
- [ ] No data loss during testing
- [ ] Performance <3 seconds for backup
- [ ] Boss approves UX (feels like "desk metaphor")

---

## Timeline

**Total Estimate:** 6-7 hours

- Phase 1 (Core): 2 hours
- Phase 2 (Restore): 1 hour
- Phase 3 (CLI): 1 hour
- Phase 4 (Integration): 30 min
- Phase 5 (Polish): 30 min
- Phase 6 (Testing): 1 hour
- Buffer: 1 hour

---

## Next Steps

1. **Boss Review** - Approve spec & plan
2. **Implementation** - Execute phases 1-6
3. **Testing** - Run verification plan
4. **Deployment** - Install hooks, test with real workflow
5. **Documentation** - Update guides

---

**Status:** Ready for Boss approval  
**Recommendation:** Proceed with implementation ✅
