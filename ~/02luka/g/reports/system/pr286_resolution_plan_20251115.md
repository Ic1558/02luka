# Conflict Resolution Plan for PR #286

**Date:** 2025-11-15  
**PR:** #286 (`ai/codex-review-251114`)  
**Status:** ⏳ **PLAN CREATED - AWAITING EXECUTION**

---

## Executive Summary

PR #286 is a large, old WIP branch (97 commits, 1,618 files changed) with significant conflicts. The important pieces have already been extracted into dedicated PRs (#280, #287, #288, #289, #290). This plan treats PR #286 as a cleanup/salvage operation: rebase onto main, remove junk, preserve only what's truly needed, and create clean commits.

---

## Strategy

**Base Truth:** Current `main` branch (with security fixes from PR #280, #289, #290)

**Approach:** Full cleanup - rebase, remove runtime files, squash WIP commits, resolve conflicts favoring main

**Outcome:** Clean, focused PR with 1-3 meaningful commits on top of current main

---

## Phase 1: Preparation & Analysis

### 1.1 Backup Current State
- Create backup branch: `backup/pr286-original-$(date +%Y%m%d)`
- Document current PR state

### 1.2 Identify What's Already Merged
- Check if PR #286 content overlaps with:
  - PR #280: WO Dashboard Hardening
  - PR #287: Multi-Agent Contract
  - PR #288: Telemetry Schema Fix
  - PR #289: CI Infrastructure Fixes
  - PR #290: Orchestrator Fix

### 1.3 Identify Runtime/Junk Files
Files to remove from tracking:
- `g/.DS_Store` (macOS system file)
- `g/logs/*.log` (runtime logs)
- `logs/n8n.launchd.err` (runtime log)
- `g/apps/dashboard/data/followup.json` (runtime data)
- `g/telemetry_unified/unified.jsonl` (runtime data)
- `g/reports/mcp_health/` (generated telemetry, if applicable)
- `g/reports/gh_failures/.seen_runs` (runtime tracking)
- `memory/cls/wo_status.jsonl` (runtime data)
- Any other `.log`, `.jsonl` runtime files

### 1.4 Identify Critical Files (Keep Main's Version)
Files where main's version must be preserved:
- `.github/workflows/bridge-selfcheck.yml`
- `.github/workflows/codex_sandbox.yml`
- `.github/workflows/memory-guard.yml`
- `g/apps/dashboard/security/woId.js`
- `g/tools/claude_subagents/orchestrator.zsh`
- `tools/codex_sandbox_check.zsh`

---

## Phase 2: Rebase Onto Main

### 2.1 Create Clean Branch from Main
```bash
git checkout main
git pull origin main
git checkout -b pr286-cleanup
```

### 2.2 Identify Unique Content from PR #286
- Compare PR #286 branch with main
- List files that exist only in PR #286 (not in main)
- Identify meaningful changes (not WIP noise)

### 2.3 Cherry-Pick or Re-apply Only Needed Changes
- For each unique/valuable change:
  - Determine if it's still relevant
  - If yes, re-apply on top of main's secure base
  - If no, document why it's not needed

---

## Phase 3: Remove Runtime Files

### 3.1 Update .gitignore
Add patterns to `.gitignore`:
```
# Runtime logs
logs/*.log
logs/*.err
*.log

# macOS system files
.DS_Store
**/.DS_Store

# Runtime data
g/apps/dashboard/data/followup.json
g/telemetry_unified/unified.jsonl
memory/cls/*.jsonl

# Generated telemetry (if applicable)
g/reports/mcp_health/
g/reports/gh_failures/.seen_runs

# Temporary files
*.tmp
*.temp
```

### 3.2 Remove Runtime Files from Tracking
```bash
# Remove from index (keep local files)
git rm --cached g/.DS_Store
git rm --cached logs/n8n.launchd.err
git rm --cached g/apps/dashboard/data/followup.json
git rm --cached g/telemetry_unified/unified.jsonl
# ... (other runtime files)
```

### 3.3 Commit .gitignore Updates
```bash
git add .gitignore
git commit -m "chore(gitignore): exclude runtime files and system artifacts"
```

---

## Phase 4: Resolve Conflicts (Favor Main)

### 4.1 Merge Main into PR Branch (for conflict detection)
```bash
git checkout ai/codex-review-251114
git fetch origin main
git merge origin/main --no-edit
```

### 4.2 Resolve Each Conflict Category

#### Category A: Security Files (Always Keep Main)
- `g/apps/dashboard/security/woId.js` → Keep main's version
- `apps/dashboard/wo_dashboard_server.js` → Keep main's version (if conflicts)

#### Category B: CI Workflows (Always Keep Main)
- `.github/workflows/bridge-selfcheck.yml` → Keep main's version
- `.github/workflows/codex_sandbox.yml` → Keep main's version
- `.github/workflows/memory-guard.yml` → Keep main's version

#### Category C: Tooling (Keep Main, Re-apply if Needed)
- `g/tools/claude_subagents/orchestrator.zsh` → Keep main's version
- `tools/codex_sandbox_check.zsh` → Keep main's version
- If PR #286 has unique logic, re-apply on top of main's version

#### Category D: Documentation/Reports
- Review each conflict individually
- Keep main's version if it's more recent/complete
- Merge if both have unique valuable content

#### Category E: Runtime Files (Remove)
- Remove all runtime files from conflicts
- Add to .gitignore if not already there

### 4.3 Conflict Resolution Commands
```bash
# Security files - keep main
git checkout --theirs g/apps/dashboard/security/woId.js

# CI workflows - keep main
git checkout --theirs .github/workflows/bridge-selfcheck.yml
git checkout --theirs .github/workflows/codex_sandbox.yml
git checkout --theirs .github/workflows/memory-guard.yml

# Tooling - keep main
git checkout --theirs g/tools/claude_subagents/orchestrator.zsh
git checkout --theirs tools/codex_sandbox_check.zsh

# Runtime files - remove
git rm g/.DS_Store
git rm logs/n8n.launchd.err
git rm g/apps/dashboard/data/followup.json
git rm g/telemetry_unified/unified.jsonl
# ... (other runtime files)
```

---

## Phase 5: Create Clean Commits

### 5.1 Squash Strategy
After resolving all conflicts, create 1-3 clean commits:

**Option 1: Single Clean Commit**
```bash
git reset --soft origin/main
git commit -m "feat(codex): salvage remaining codex review changes

- Preserve unique documentation and tooling improvements
- Remove runtime files and system artifacts
- Align with main's security and CI fixes"
```

**Option 2: Multiple Focused Commits**
```bash
# Commit 1: Documentation
git add docs/ tools/codex_prompt_helper.zsh
git commit -m "docs(codex): add codex safety onboarding and prompt library"

# Commit 2: Tooling improvements (if any)
git add tools/
git commit -m "feat(tools): codex prompt helper improvements"

# Commit 3: Cleanup
git add .gitignore
git commit -m "chore(gitignore): exclude runtime files"
```

### 5.2 Force Push (After Review)
```bash
git push origin ai/codex-review-251114 --force-with-lease
```

---

## Phase 6: Verification

### 6.1 Verify Security Fixes Preserved
- ✅ `woId.js` has path traversal protection
- ✅ `orchestrator.zsh` is ZSH (not Node.js)
- ✅ CI workflows have latest fixes
- ✅ No security regressions

### 6.2 Verify Runtime Files Removed
- ✅ Runtime files not in PR
- ✅ .gitignore updated
- ✅ No .DS_Store, logs, or runtime data

### 6.3 Verify Clean History
- ✅ 1-3 meaningful commits
- ✅ No WIP commits
- ✅ Clear commit messages

### 6.4 Run Tests
```bash
# Codex sandbox check
tools/codex_sandbox_check.zsh

# Orchestrator syntax
zsh -n g/tools/claude_subagents/orchestrator.zsh

# CI workflows (check syntax)
yamllint .github/workflows/*.yml
```

---

## Phase 7: Update PR Description

Update PR #286 description to reflect:
- What was salvaged from the original 97 commits
- What was removed (runtime files, WIP commits)
- What was preserved (main's security fixes)
- Link to related PRs (#280, #287, #288, #289, #290)

---

## Decision Rules

### Always Keep Main's Version For:
1. **Security files:**
   - `g/apps/dashboard/security/woId.js`
   - `apps/dashboard/wo_dashboard_server.js` (if conflicts)

2. **CI workflows:**
   - `.github/workflows/bridge-selfcheck.yml`
   - `.github/workflows/codex_sandbox.yml`
   - `.github/workflows/memory-guard.yml`

3. **Core tooling:**
   - `g/tools/claude_subagents/orchestrator.zsh`
   - `tools/codex_sandbox_check.zsh`

### Always Remove:
1. Runtime files (logs, .DS_Store, followup.json, etc.)
2. WIP commits (squash into clean commits)
3. Duplicate content already in main

### Review Individually:
1. Documentation files
2. Report files
3. Configuration files (if not security-related)

---

## Rollback Plan

If issues arise:
1. Restore from backup branch: `backup/pr286-original-$(date)`
2. Or reset to original: `git reset --hard origin/ai/codex-review-251114`

---

## Success Criteria

- ✅ PR #286 rebased onto current main
- ✅ All conflicts resolved (favoring main for security/CI)
- ✅ Runtime files removed and ignored
- ✅ Clean commit history (1-3 commits)
- ✅ Security fixes preserved
- ✅ No regressions
- ✅ PR ready for review/merge

---

## Timeline Estimate

- **Phase 1 (Preparation):** 10 minutes
- **Phase 2 (Rebase):** 15 minutes
- **Phase 3 (Remove Runtime Files):** 10 minutes
- **Phase 4 (Resolve Conflicts):** 20 minutes
- **Phase 5 (Clean Commits):** 10 minutes
- **Phase 6 (Verification):** 10 minutes
- **Phase 7 (Update PR):** 5 minutes

**Total:** ~80 minutes

---

## Notes

- This is a salvage operation, not a full merge
- Main's security fixes are non-negotiable
- If PR #286 has unique valuable content, it should be small and focused
- Consider closing PR #286 and opening a new, focused PR if cleanup reveals very little unique content

---

**Plan Created:** 2025-11-15  
**Status:** ⏳ **READY FOR EXECUTION**  
**Next Step:** Execute phases 1-7 in sequence
