# Save vs Seal Aliases

**Date:** 2025-12-07  
**Status:** ✅ Implemented

---

## Overview

Two distinct commands for different use cases:

| Command | What It Does | When to Use | Weight |
|---------|--------------|-------------|--------|
| **`save`** | Only `session_save.zsh` | Mid-session saves, memory/diary updates | Light ⚡ |
| **`seal`** | Review → GitDrop → Save | Final safety before push/merge/deploy | Heavy 🔒 |

---

## `save` - Lightweight Save

**Command:** `save`  
**Function:** `dev_save()`  
**Script:** `tools/session_save.zsh`

### Purpose
- Snapshot memory between sessions
- Update `02luka.md`
- Commit memory repo
- Quick state preservation

### Characteristics
- ✅ Fast (no review overhead)
- ✅ No forced review
- ✅ Can use frequently
- ✅ Lightweight
- ✅ Perfect for "บันทึก" (recording)

### Usage
```bash
save
# or with arguments
save --option value
```

---

## `seal` - Full Workflow Chain

**Command:** `seal`  
**Function:** `dev_seal()`  
**Script:** `tools/workflow_dev_review_save.py`

### Purpose
- Close work session
- Review code before finalizing
- Safety check before push/merge/deployment
- Complete workflow: Review → GitDrop → Save

### Characteristics
- ✅ Meaningful name ("seal" = ปิดผนึกงาน)
- ✅ Intuitive
- ✅ Used less frequently (final step)
- ✅ Covers 3 critical parts: review, safety, save
- ✅ Clear final step of work cycle

### Workflow
1. **Review:** Local Agent Review on staged/unstaged changes
2. **GitDrop:** Create snapshot of working papers
3. **Save:** Run session_save.zsh

### Usage
```bash
seal
# or with options
seal --mode staged --strict
seal --offline --skip-gitdrop
```

### Options
- `--mode`: staged, unstaged, last-commit, branch, range
- `--offline`: Run review without API calls
- `--strict`: Treat warnings as failures
- `--skip-gitdrop`: Skip GitDrop step
- `--skip-save`: Skip save step

---

## Status Commands

### View Recent Runs
```bash
seal-status
# or
drs-status
```

### Summary Mode
```bash
seal-status --summary
```

---

## Legacy Compatibility

**`drs`** (dev review save) is kept for backward compatibility:
- `drs` → calls `dev_seal()` → same as `seal`
- `drs-status` → same as `seal-status`

**Recommendation:** Use `seal` for new workflows.

---

## Why This Naming is "Best"

### ✅ AI-Friendly
- Distinct keywords (`save` vs `seal`)
- No ambiguity in interpretation
- Clear separation of concerns

### ✅ Human-Friendly
- Intuitive meaning
- `save` = quick record
- `seal` = finalize/close

### ✅ No Conflicts
- `save` is specific (not generic "save")
- `seal` is unique in system context
- Low risk of misinterpretation

### ✅ Semantic Clarity
- `save`: Lightweight, frequent use
- `seal`: Heavy, final step, safety-focused

---

## Implementation

**File:** `tools/git_safety_aliases.zsh`

**Functions:**
- `dev_save()` → runs `tools/session_save.zsh`
- `dev_seal()` → runs `tools/workflow_dev_review_save.py` (preferred) or `.zsh` (fallback)

**Aliases:**
- `alias save='dev_save'`
- `alias seal='dev_seal'`
- `alias drs='dev_review_save'` (legacy, calls `dev_seal`)
- `alias seal-status='dev_review_save_status'`
- `alias drs-status='dev_review_save_status'`

---

## Examples

### Daily Workflow
```bash
# Mid-session: quick save
save

# Continue working...

# End of session: final seal
seal

# Check status
seal-status
```

### Before Push
```bash
# Review, snapshot, save everything
seal --mode staged --strict

# If OK, push
git push
```

### Quick Memory Update
```bash
# Just update memory/diary, no review
save
```

---

## Telemetry

Both commands log to telemetry:
- `save`: Logs to `g/telemetry/save_sessions.jsonl`
- `seal`: Logs to `g/telemetry/dev_workflow_chain.jsonl`

View with:
```bash
seal-status
```

---

**Last Updated:** 2025-12-07
