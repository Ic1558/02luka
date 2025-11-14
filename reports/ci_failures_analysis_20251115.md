# CI Failures Analysis for PR #281

**Date:** 2025-11-15  
**PR:** #281  
**Status:** ⚠️ CI Checks Failing - Action Required

---

## Failing CI Checks

1. ❌ **`ci / Path Guard (Reports)`** - FAILED
2. ❌ **`codex_sandbox / sandbox`** - FAILED  
3. ❌ **`Memory Guard / memory-guard`** - FAILED
4. ⏳ **`update / R&D - Vector Index Tests`** - IN PROGRESS

---

## Issue 1: Path Guard (Reports) Failure

### Problem
The Path Guard check enforces that report files must be in subdirectories:
- `g/reports/phase5_governance/`
- `g/reports/phase6_paula/`
- `g/reports/system/`

**Not allowed:** Files directly in `g/reports/{filename}.md`

### Solution
Move report files to appropriate subdirectories based on their content:

**System/General Reports → `g/reports/system/`:**
- Code review reports
- Security verification reports
- Deployment reports
- Status reports
- Completion summaries

**Phase-Specific Reports → Appropriate phase directory:**
- Phase 5 reports → `g/reports/phase5_governance/`
- Phase 6 reports → `g/reports/phase6_paula/`

### Files That Need Moving
All files matching `g/reports/[^/]+\.md$` in the PR diff need to be moved to subdirectories.

---

## Issue 2: Codex Sandbox Failure

### Problem
The `codex_sandbox` check scans non-documentation files for banned command patterns.

### Possible Causes
1. Files outside `reports/`, `docs/`, `telemetry/`, `analytics/` contain banned commands
2. Scripts or code files have dangerous patterns (e.g., `rm -rf`, `sudo`, etc.)

### Solution
1. Check which files are being scanned (non-docs/telemetry files)
2. Review those files for banned command patterns
3. Sanitize or move dangerous patterns to documentation-only locations

---

## Issue 3: Memory Guard Failure

### Problem
The Memory Guard check validates memory/MLS-related changes.

### Possible Causes
1. MLS ledger format issues
2. Memory hook configuration problems
3. Schema validation failures

### Solution
Review memory-related changes in the PR and ensure they comply with MLS schema.

---

## Recommended Actions

### Priority 1: Fix Path Guard
1. Identify all `g/reports/*.md` files in PR
2. Categorize them (system/phase5/phase6)
3. Move to appropriate subdirectories
4. Commit and push

### Priority 2: Fix Codex Sandbox
1. Check CI logs for specific violations
2. Identify files with banned patterns
3. Sanitize or exclude from sandbox check
4. Commit and push

### Priority 3: Fix Memory Guard
1. Review memory-related changes
2. Fix schema/format issues
3. Commit and push

---

## Quick Fix Script (Path Guard)

```bash
cd ~/02luka
git checkout ai/codex-review-251114

# Create system subdirectory if needed
mkdir -p g/reports/system

# Move recent reports to system/ (example - adjust based on actual files)
git mv g/reports/code_review_path_guard_fix_20251115.md g/reports/system/
git mv g/reports/next_steps_after_verification_20251115.md g/reports/system/
git mv g/reports/execution_complete_20251115.md g/reports/system/
git mv g/reports/final_status_20251115.md g/reports/system/
git mv g/reports/completion_summary_20251115.md g/reports/system/
git mv g/reports/ci_failures_analysis_20251115.md g/reports/system/

# Commit and push
git commit -m "fix(ci): move reports to system/ subdirectory for Path Guard compliance"
git push origin ai/codex-review-251114
```

---

## Status

**Current:** ⚠️ CI checks failing - PR cannot be merged safely  
**Action:** Fix CI failures before merging  
**Priority:** High (Path Guard is likely easiest to fix first)

---

**Next Steps:** Fix Path Guard first, then investigate other failures via CI logs.
