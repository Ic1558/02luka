# PR Review Checklist - PR Management Script

## 👋 For Reviewers

This PR adds `scripts/manage_prs.sh` - a production-ready automation tool for bulk PR operations. Below is a structured checklist to validate safety, functionality, and code quality.

---

## ✅ Quick Validation (5 minutes)

### 1. File Integrity
```bash
# Verify files exist and are executable
ls -lh scripts/manage_prs.sh
ls -lh g/reports/ci/{meta_pr_body.md,pr_script_quickstart.md}

# Should show:
# -rwxr-xr-x  scripts/manage_prs.sh (executable)
# -rw-r--r--  documentation files
```

### 2. Code Quality
```bash
# Shellcheck (should be clean)
shellcheck scripts/manage_prs.sh

# Check for hardcoded secrets (should return nothing)
grep -iE '(password|token|secret|key)=' scripts/manage_prs.sh | grep -v '${GH_TOKEN'

# Verify strict error handling
head -n 20 scripts/manage_prs.sh | grep 'set -euo pipefail'
```

### 3. Dry-Run Test (Non-Destructive)
```bash
# This WILL NOT modify any PRs
DRY_RUN=1 bash scripts/manage_prs.sh

# Expected output:
# - Shows [DRY-RUN] prefix for all operations
# - Lists all PRs to be merged (182, 181, 114, 113)
# - Lists all PRs for check re-runs (123-129)
# - Shows rebase plan for PR 169
# - Shows watch plan for PR 164
# - No actual gh commands executed
```

---

## 🔒 Security Review

### Authentication & Authorization
- [ ] No credentials hardcoded in script
- [ ] Uses `gh` CLI with user's existing auth (respects `GH_TOKEN` env var)
- [ ] No `sudo` or privilege escalation
- [ ] No network calls except via `gh` CLI
- [ ] Safe for execution in CI/CD (no interactive prompts)

### Git Operations Safety
- [ ] Uses `--force-with-lease` (not bare `--force`)
- [ ] No destructive operations without retry/confirmation
- [ ] Checkout operations properly scoped to script context
- [ ] No `rm -rf` or similar destructive file operations

### Input Validation
- [ ] PR numbers hardcoded (not user input) ✓
- [ ] No `eval` with user-controlled strings (only internal commands) ✓
- [ ] Environment variables properly quoted and defaulted ✓

**Security Assessment:** ✅ PASS / ⚠️ NEEDS REVIEW / ❌ FAIL

---

## 🧪 Functional Testing

### Test 1: Dry-Run Mode
```bash
DRY_RUN=1 bash scripts/manage_prs.sh
```
**Expected:** All operations shown with `[DRY-RUN]` prefix, no actual changes

**Result:** ✅ PASS / ❌ FAIL

---

### Test 2: Configuration Variables
```bash
# Test custom retry delay
DRY_RUN=1 RETRY_DELAY=5 bash scripts/manage_prs.sh

# Test skip sanity
DRY_RUN=1 SKIP_SANITY=1 bash scripts/manage_prs.sh
```
**Expected:** Script respects env vars, no errors

**Result:** ✅ PASS / ❌ FAIL

---

### Test 3: Color Output
```bash
# TTY (should show colors)
DRY_RUN=1 bash scripts/manage_prs.sh | cat -v

# Piped (should strip colors automatically)
DRY_RUN=1 bash scripts/manage_prs.sh | tee /tmp/test.log
grep -c '\[DRY-RUN\]' /tmp/test.log  # Should be > 0
```
**Expected:** Colors in TTY, plain text when piped

**Result:** ✅ PASS / ❌ FAIL

---

### Test 4: Error Handling
```bash
# Simulate gh not available
(
  PATH="/usr/bin:/bin"  # Exclude gh
  DRY_RUN=1 bash scripts/manage_prs.sh 2>&1 | grep -i 'gh.*not found'
)
```
**Expected:** Clear error message about missing `gh` CLI

**Result:** ✅ PASS / ❌ FAIL

---

## 📋 Code Review Checklist

### Script Structure
- [ ] Shebang present (`#!/bin/bash`)
- [ ] `set -euo pipefail` for error handling
- [ ] Clear comments and documentation
- [ ] Logical phase separation (Phases 1-5)
- [ ] Helper functions for reusability

### Error Handling
- [ ] Retry logic with exponential backoff
- [ ] Rate limiting between API calls
- [ ] Graceful degradation (`|| true` where appropriate)
- [ ] Sanity checks after operations
- [ ] Clear error messages with context

### User Experience
- [ ] Color-coded output (green/yellow/red/blue)
- [ ] Progress indicators for each phase
- [ ] Dry-run mode for safe preview
- [ ] Configuration via environment variables
- [ ] Timestamp in final output

### Documentation
- [ ] Usage examples in script header
- [ ] Environment variables documented
- [ ] Comprehensive `meta_pr_body.md` included
- [ ] Quick-start guide available
- [ ] Troubleshooting section provided

---

## 🎯 Operations Validation

### What This Script Does

**Phase 1: Merge PRs** (Destructive)
- Merges: #182, #181, #114, #113
- Action: Squash merge + delete branch
- Risk: ⚠️ Medium (irreversible, but safe with completed PRs)

**Phase 2: Re-run Checks** (Safe)
- Re-runs: #123, #124, #125, #126, #127, #128, #129
- Action: Trigger workflow re-runs
- Risk: ✅ Low (idempotent, non-destructive)

**Phase 3: Rebase PR** (Destructive)
- Rebases: #169 on `origin/main`
- Action: Rebase + force-with-lease push
- Risk: ⚠️ Medium (rewrites history, use --force-with-lease)

**Phase 4: Watch Checks** (Read-Only)
- Monitors: #164
- Action: Block until checks complete
- Risk: ✅ Low (read-only)

**Phase 5: Sanity Checks** (Read-Only)
- Validates: All previous operations
- Action: Query PR states via `gh pr view`
- Risk: ✅ Low (read-only)

### Risk Assessment
- **Low Risk:** Phases 2, 4, 5 (safe to run anytime)
- **Medium Risk:** Phases 1, 3 (test with DRY_RUN first)
- **Mitigation:** DRY_RUN mode, retry logic, --force-with-lease

---

## 🔍 Expected Output Samples

### Successful Execution
```
╔════════════════════════════════════════════════════════════╗
║          PR Management Script                              ║
╚════════════════════════════════════════════════════════════╝

═══ Phase 1: Merging PRs with squash ═══

→ Merging PR #182...
[EXEC] gh pr merge 182 --squash --delete-branch
✓ #182 merged

═══ Sanity Checks ═══

Merged PR states:
  PR #182: ✓ MERGED
  PR #181: ✓ MERGED
  PR #114: ✓ MERGED
  PR #113: ✓ MERGED

✓ All operations completed
Run timestamp: 2025-11-06T12:34:56+00:00
```

### Dry-Run Mode
```
⚠ DRY-RUN MODE: No changes will be made

═══ Phase 1: Merging PRs with squash ═══

→ Merging PR #182...
[DRY-RUN] gh pr merge 182 --squash --delete-branch
```

### Retry Scenario
```
→ Merging PR #182...
[EXEC] gh pr merge 182 --squash --delete-branch
  ↳ Retry 1/3 failed, waiting 2s...
[EXEC] gh pr merge 182 --squash --delete-branch
✓ #182 merged
```

---

## 📝 Final Reviewer Checklist

Before approving, confirm:

- [ ] **Dry-run test passed** - No errors, correct output
- [ ] **Shellcheck clean** - No warnings or errors
- [ ] **No hardcoded secrets** - All auth via gh CLI
- [ ] **Documentation complete** - meta_pr_body.md and quickstart present
- [ ] **Error handling robust** - Retry logic, rate limiting, sanity checks
- [ ] **Safe git operations** - Uses --force-with-lease, not bare --force
- [ ] **Idempotent design** - Safe to re-run without side effects
- [ ] **Color output works** - Visual clarity in terminal
- [ ] **Environment variables** - Properly documented and defaulted

---

## 💬 Reviewer Comments Template

Copy/paste into PR comment after validation:

```markdown
## ✅ Review Complete

**Validation Results:**
- Dry-run test: ✅ PASS
- Shellcheck: ✅ CLEAN
- Security audit: ✅ PASS
- Functional tests: ✅ PASS (4/4)
- Documentation: ✅ COMPLETE

**Testing Performed:**
- Ran `DRY_RUN=1 ./scripts/manage_prs.sh` - output looks correct
- Verified no hardcoded credentials
- Confirmed --force-with-lease usage (safe rebase)
- Validated retry logic and rate limiting

**Concerns/Questions:**
- [ ] None / [List any concerns]

**Recommendation:** ✅ APPROVE / ⚠️ REQUEST CHANGES / ❌ REJECT

**Additional Notes:**
[Any context, suggestions for future improvements, or operational notes]
```

---

## 🚀 Post-Merge Actions

After approval and merge:

1. **Tag the release:**
   ```bash
   git tag -a ci-pr-script-v1.0 -m "Initial PR automation integration"
   git push origin ci-pr-script-v1.0
   ```

2. **Test from main:**
   ```bash
   git switch main
   git pull
   DRY_RUN=1 bash scripts/manage_prs.sh
   ```

3. **Set up automation** (optional):
   - Add to cron/LaunchAgent for periodic runs
   - Configure GitHub Actions workflow
   - Add to team runbook

4. **Monitor first run:**
   ```bash
   ./scripts/manage_prs.sh | tee g/reports/ci/manage_prs_$(date +%Y%m%d_%H%M%S).log
   ```

---

## 📚 Additional Resources

- **Full Documentation:** `g/reports/ci/meta_pr_body.md`
- **Quick Reference:** `g/reports/ci/pr_script_quickstart.md`
- **Script Location:** `scripts/manage_prs.sh`
- **Troubleshooting:** See quickstart guide section

---

## ❓ Questions for PR Author

If you have concerns, ask:

1. **Why these specific PRs?** - Are 182, 181, 114, 113 ready for merge?
2. **Rebase strategy** - Is PR 169 safe to force-push?
3. **Check re-runs** - What's the issue with PRs 123-129?
4. **Monitoring** - Why watch PR 164 specifically?
5. **Rollback plan** - How to undo if something goes wrong?

---

**Time to review:** ~10 minutes
**Risk level:** Low (with DRY_RUN testing)
**Confidence:** High (well-documented, safety mechanisms in place)
