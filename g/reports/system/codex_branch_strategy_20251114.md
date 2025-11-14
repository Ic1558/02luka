# Codex Branch Strategy
**Date:** 2025-11-14  
**Branch:** `ai/codex-review-251114`  
**Purpose:** Document branch plan and commit categorization for Codex verification

---

## Branch Overview

### Current Branch
- **Name:** `ai/codex-review-251114`
- **Base:** Current local main (includes all pending changes)
- **Purpose:** Hold all pending changes for review before sync
- **Status:** Created and active

### Branch Strategy

```
origin/main (remote)
    |
    |-- [74 commits ahead, 61 commits behind]
    |
local main (current state)
    |
    |-- ai/codex-review-251114 (review branch)
         |
         |-- Contains: Codex changes + CLS work + CLC work + Other
```

---

## Commit Categorization

### Methodology
Commits are categorized based on:
- Commit message keywords
- Author patterns
- File changes
- Context from git history

### Categories

#### 1. Codex Commits
**Criteria:**
- Contains "codex", "Codex", "CODEX" in message
- Contains "[via Claude Code]" in message
- From Codex-related PRs (#177-180, #187, etc.)
- Changes to Codex-specific files

**Examples:**
- `5c7111f1f` - ci: fix workflow triggers and permissions (minimal, workflows-only) [via Claude Code] (#187)
- `34beb5df2` - Merge pull request #180 from Ic1558/codex/fix-missing-deploy-reports-handling
- `7a740a1ec` - chore(codex): seed AGENTS.md, approvals and SOT context for 02LUKA

**Status:** Needs verification before sync

#### 2. CLS Commits
**Criteria:**
- Contains "CLS", "cls", "session" in message
- Contains "auto-commit" in message
- CLS-related work
- Session saves

**Examples:**
- `d22362271` - feat: Enhanced session save system - complete snapshot
- `1c343cf93` - session save: CLS 2025-11-13
- `00846c31e` - WIP: auto-commit work in progress - 2025-11-14 13:33:50 +0700

**Status:** Generally safe, but verify no SOT touches

#### 3. CLC Commits
**Criteria:**
- Contains "CLC", "clc", "WO" (work order) in message
- CLC-related work
- Work order processing

**Examples:**
- Commits related to WO processing
- CLC agent work
- Bridge operations

**Status:** Verify alignment with current architecture

#### 4. Other Commits
**Criteria:**
- Doesn't match Codex/CLS/CLC patterns
- Recovery work
- Infrastructure changes
- Documentation updates

**Examples:**
- Recovery-related commits
- Infrastructure improvements
- Documentation updates

**Status:** Review case-by-case

---

## Comparison: Review Branch vs Origin/Main

### File-Level Diff Summary

**Modified Files:**
- `.gitignore` - Added lukadata ignore patterns
- `02luka.md` - Master SOT (verify no Codex changes)
- `g/apps/dashboard/data/followup.json` - Dashboard data
- Various operational files

**Added Files:**
- Recovery reports
- WO files
- LaunchAgents
- Verification reports (this plan)

**Deleted Files:**
- None (Codex directory was moved, not deleted)

### Codex-Specific Changes

**From Codex Commits:**
- CI/CD workflow improvements
- Bug fixes in bridge scripts
- Documentation updates
- Agent configurations

**Risk Assessment:**
- Most changes appear safe (bug fixes, improvements)
- Need to verify: No SOT touches, no secrets, no conflicts

---

## Branch Protection Strategy

### Before Merging to Main
1. **Complete verification checklist**
   - SOT protection verified
   - Safety checks passed
   - Conflicts resolved
   - Code quality acceptable

2. **Automated analysis complete**
   - Script run successfully
   - No critical issues found
   - Warnings documented

3. **Manual review complete**
   - Boss/CLC reviewed changes
   - Architecture alignment verified
   - No unintended side effects

4. **Decision documented**
   - Verdict: Approve all / Approve partial / Reject all
   - Rationale documented
   - Next steps clear

### Merge Strategy Options

#### Option A: Approve All
- Merge entire `ai/codex-review-251114` to main
- Enable sync after merge
- Monitor first sync

#### Option B: Approve Partial
- Cherry-pick safe commits
- Create new branch with only approved changes
- Merge approved subset

#### Option C: Reject All
- Reset Codex changes
- Keep only CLS/CLC/Other work
- Create clean branch for sync

---

## Next Steps

1. **Categorize all commits** (in progress)
   - [x] Identify Codex commits
   - [x] Identify CLS commits
   - [x] Identify CLC commits
   - [x] Identify Other commits

2. **Run automated analysis**
   - [ ] Execute `tools/codex_verification_analyzer.zsh`
   - [ ] Review automated analysis report
   - [ ] Address any critical issues

3. **Manual review**
   - [ ] Review Codex changes
   - [ ] Verify architecture alignment
   - [ ] Check for unintended side effects

4. **Make decision**
   - [ ] Document verdict
   - [ ] Create sync branch (if approved)
   - [ ] Enable sync (if approved)

---

## Branch Commands Reference

### View Branch Status
```bash
git branch --show-current  # Current branch
git log --oneline origin/main..HEAD  # Commits ahead
git log --oneline HEAD..origin/main  # Commits behind
```

### Compare with Remote
```bash
git diff origin/main...HEAD --name-status  # File changes
git diff origin/main...HEAD --stat  # Summary
```

### Create Sync Branch (if approved)
```bash
git checkout -b ai/post-codex-verification-251114
# Cherry-pick approved commits or merge review branch
```

---

**Document Created:** 2025-11-14  
**Status:** Ready for commit categorization and automated analysis

