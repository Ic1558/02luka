# ADR-001: Repository/Workspace Split Architecture

**Status:** Accepted  
**Date:** 2025-12-13  
**Context:** Phase A Complete

---

## Context

The 02luka system needs to separate:
- **Repository (Git-tracked):** Source code, scripts, documentation
- **Workspace (Runtime data):** Telemetry, logs, followup data, MLS ledger

**Problem:** Git operations (`git clean -fd`, `git reset --hard`) were destroying runtime data stored in the repository.

---

## Decision

**Separate repository from workspace using symlinks:**

1. **Repository:** `/Users/icmini/02luka` (Git-tracked)
2. **Workspace:** `/Users/icmini/02luka_ws` (NOT in Git, external directory)
3. **Symlinks:** Workspace paths in repo are symlinks pointing to workspace

**Workspace paths (must be symlinks):**
- `g/data/` → `~/02luka_ws/g/data/`
- `g/telemetry/` → `~/02luka_ws/g/telemetry/`
- `g/followup/` → `~/02luka_ws/g/followup/`
- `mls/ledger/` → `~/02luka_ws/mls/ledger/`
- `bridge/processed/` → `~/02luka_ws/bridge/processed/`
- `g/apps/dashboard/data/followup.json` → `~/02luka_ws/g/apps/dashboard/data/followup.json`

---

## Consequences

### ✅ Benefits

- **Data Safety:** `git clean -fd` and `git reset --hard` won't delete workspace data
- **Git Hygiene:** Repository stays clean (no runtime data tracked)
- **Separation of Concerns:** Code vs. data clearly separated
- **Backup Strategy:** Workspace can be backed up independently

### ⚠️ Requirements

- **Pre-commit Hook:** Enforces workspace paths are symlinks (not real directories)
- **Guard Script:** `tools/guard_workspace_inside_repo.zsh` validates before commits
- **Safe Clean:** Use `tools/safe_git_clean.zsh` instead of `git clean -fd`
- **Bootstrap:** Run `tools/bootstrap_workspace.zsh` to setup symlinks

### 🚫 Prohibited Operations

- **NEVER:** `git clean -fd` (use `safe_git_clean.zsh` instead)
- **NEVER:** Create real directories at workspace paths (must be symlinks)
- **NEVER:** Track workspace data in Git (already in `.gitignore`)

---

## Implementation

**Phase A (Complete):**
- ✅ Guard script (`tools/guard_workspace_inside_repo.zsh`)
- ✅ Pre-commit hook (enforces guard)
- ✅ Bootstrap script (`tools/bootstrap_workspace.zsh`)
- ✅ Safe clean script (`tools/safe_git_clean.zsh`)
- ✅ All workspace paths migrated to symlinks

**Phase B (Recommended):**
- CI check for workspace guard
- Documentation updates
- Alias for safe clean

---

## References

- `.cursorrules` - Workspace split rules
- `tools/guard_workspace_inside_repo.zsh` - Guard implementation
- `tools/bootstrap_workspace.zsh` - Setup script
- `tools/safe_git_clean.zsh` - Safe clean wrapper

---

**Tag:** `ws-split-phase-a-ok` (2025-12-13)
