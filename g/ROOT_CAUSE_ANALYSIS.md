# ROOT CAUSE ANALYSIS: PR Conflicts & CI/CD Issues

## Executive Summary

14 PR branches have merge conflicts with main. Investigation reveals **THREE SYSTEMIC ROOT ERRORS**:

1. **CRITICAL CI/CD ERROR**: `pages.yml` has invalid YAML syntax (lines 42-52)
2. **ARCHITECTURE DEPRECATION**: Main branch deleted obsolete files that old PRs still reference
3. **WORKFLOW REFACTORING CONFLICTS**: Major ci.yml rewrite created cascading merge conflicts

---

## ROOT ERROR #1: CRITICAL - pages.yml Invalid YAML Syntax

**File**: `.github/workflows/pages.yml`
**Lines**: 42-52
**Issue**: Unquoted heredoc delimiters causing YAML parse error
**Impact**: Pages deployment workflow will fail to parse/run

### Current Code (BROKEN):
```yaml
cat > dist/_health.html << 'HTML'
...
HTML

# Generate manifest
cat > dist/manifest.json << JSON  # ❌ INVALID - bare word 'JSON'
...
JSON
```

### Problem:
YAML parser sees `JSON` without quotes and no `:` after it, causing:
```
yaml.scanner.ScannerError: while scanning a simple key
  in ".github/workflows/pages.yml", line 44, column 11
could not find expected ':'
```

### Evolution of This Bug:
1. **Commit a4039f2**: Original fix - added proper quoting
2. **Commit 048e01c**: "fix(lint): suppress YAML/ShellCheck warnings" - may have introduced regression
3. **Commit 4dd9678**: "fix(ci): unquote heredoc delimiters in pages.yml to enable shell expansion" - branch tried to fix with `<<'JSON_EOF'` pattern
4. **Main branch**: Diverged with bare `<< JSON` (INVALID)

### Fix:
Use quoted or _EOF suffixed delimiters:
```yaml
cat > dist/manifest.json << 'JSON'
# OR
cat > dist/manifest.json << JSON_EOF
```

---

## ROOT ERROR #2: Architecture Deprecation (MODIFY/DELETE Conflicts)

### The Problem:
Main branch **deleted entire subsystems** that old PR branches still try to modify:

#### Deleted Files (causing 13 MODIFY/DELETE conflicts):
- `boss-api/server.cjs` - old Node.js API server
- `boss-ui/src/App.jsx`, `styles.css`, `vite.config.js` - old React UI
- `run/smoke_api_ui.sh` - old smoke test for API/UI
- `scripts/cutover_launchagents.sh` - old deployment script
- `scripts/health_proxy_launcher.sh` - old proxy infrastructure
- `scripts/repo_root_resolver.sh` - old path resolution
- `.codex/preflight.sh` - old Cursor IDE integration
- `.codex/adapt_style.sh`, `auto_start.sh`, `auto_stop.sh`, etc. (12+ more)
- `crawler/ingest.py` - old web crawler
- `docs/CODEX_MASTER_READINESS.md` - old documentation

#### Why Deleted:
These files were removed as part of **architecture evolution**:
- **Old pattern**: boss-api (Node.js) → boss-ui (React) frontend
- **New pattern**: Native agent-based system (see: agents/, CLS/)
- **Old tooling**: .codex/* (Cursor IDE) → replaced with native integration
- **Old scripts**: Legacy deployment/infrastructure → replaced with modern tools

### Affected Branches (222 commits behind main):
- `chore/auto-update-branch` (Oct 15, 2025)
- `chore/ci-docs-links` (Oct 15, 2025)

These branches contain ~40+ file changes trying to work with the OLD architecture that no longer exists in main.

### Root Cause:
**Branch stale-ness + architecture deprecation**. These branches were created when the old boss-api/boss-ui architecture existed. Main has since evolved away from this entirely.

---

## ROOT ERROR #3: CI.yml Massive Refactoring (9 Content Conflicts)

### The Problem:
Commit `d12d5d7` on Nov 7, 2:18 AM: "feat(ci): make CI quiet & reliable by default (#200)"

This commit **completely rewrote** `.github/workflows/ci.yml`:

#### Changes Made:
- ✅ Refactored validation job (added SKIP_BOSS_API guard, lockfile handling)
- ✅ Made ops-gate and rag-vector-selftest OPTIONAL (continue-on-error)
- ✅ Added label/title gating ([run-smoke] label)
- ✅ Added ci-summary job for always-running status
- ✅ Added fail-fast: false for matrix strategies
- **Result**: +72 lines, new philosophy of "quiet by default"

### Cascading Conflicts:
After this refactor, follow-up commits diverged:

1. **Commit 6f03320** (latest main): "docs(ci): CI automation runbook + repo hygiene (#210)"
   - Modified .gitignore (+6 lines)
   - This is AFTER the ci.yml rewrite

2. **Branches created AFTER d12d5d7** now conflict because:
   - They're based on the OLD ci.yml (before refactor)
   - Main has the NEW ci.yml (after refactor)
   - Merge causes structural conflicts

### Branches with ci.yml Conflicts (9 total):
1. chore/auto-update-branch - 222 commits behind
2. chore/ci-docs-links - 222 commits behind
3. claude/ci-optin-smoke-011C - 2 commits behind ⚠️ **Recent branch, should not conflict**
4. claude/ci-reliability-pack-011C - 2 commits behind ⚠️
5. claude/exploration-and-research-011CUrRfU1hPvBmZXZqjgN9M - 26 commits behind
6. claude/fix-ci-node-lockfile-check-011CUrjUCx7jV39sFNDLkRMo - 22 commits behind
7. claude/fix-dangling-symlink-chmod-011CUrnthGyres339RYKRCTj - 17 commits behind
8. claude/phase15-rag-faiss-prod-011CUrwXGH2CAhL3tptUTayj - 15 commits behind
9. claude/phase15-router-core-akr-011CUrtXLeMoxBZqCMowpFz8 - 13 commits behind

### Root Cause:
**Incomplete rebase strategy**. Branches were created with divergent ci.yml versions and never rebased after the major refactor.

---

## Additional Conflicts

### .gitignore Conflicts (5 branches):
All Phase 16-19 branches have .gitignore conflicts because:
- **Commit ac06da0**: "chore: add explicit patterns for logs/*.out and logs/*.err to .gitignore"
- **Commit 6f03320**: "docs(ci): CI automation runbook + repo hygiene (.gitignore)" - Added 6 more lines
- These branches diverged right at d12d5d7, BEFORE these .gitignore updates

### add/add Conflicts (4 files):
- `g/reports/ci/CI_RELIABILITY_PACK.md` - both main and branches created this file
- `tools/vector_index.py` - vector search implementation
- `g/reports/ci/meta_pr_phase15_AKR.md` - phase reports

---

## Conflict Summary Table

| File | Conflicts | Type | Root Cause |
|------|-----------|------|-----------|
| `.github/workflows/ci.yml` | 9 branches | Content | Major refactor + branch stale-ness |
| `.gitignore` | 5 branches | Content | Incremental updates after branch point |
| `boss-api/server.cjs` | 2 branches | Modify/Delete | Architecture deprecation |
| `.codex/preflight.sh` | 2 branches | Modify/Delete | Architecture deprecation |
| `run/smoke_api_ui.sh` | 2 branches | Modify/Delete | Architecture deprecation |
| `scripts/*.sh` | 2 branches (4 files) | Modify/Delete | Architecture deprecation |
| `docs/DEPLOY.md` | 2 branches | Content | Documentation evolution |
| Reports (CI_RELIABILITY_PACK.md, etc.) | 4 branches | Add/Add | Both sides created same file |

---

## Systemic Issues Identified

### Issue 1: Weak Branch Management
- **Problem**: Old branches (Oct 15) still active despite major architecture changes
- **Root Cause**: No automatic cleanup or notification when architecture changes
- **Impact**: 2 branches are 222 commits behind and unmergeable
- **Fix**: Implement branch hygiene policy (close PRs older than 30 days, auto-notify stale branches)

### Issue 2: CI/CD Workflow Drift
- **Problem**: Main branch has INVALID YAML in pages.yml, blocking deployments
- **Root Cause**: Workflow changes not validated before merge
- **Impact**: GitHub Pages deployment will fail to parse
- **Fix**: Add YAML linting to CI pipeline (yamllint), make it required

### Issue 3: Incomplete Feature Branch Workflows
- **Problem**: Branches created with unstable base (right after major refactors)
- **Root Cause**: No stabilization period after refactors before branch creation
- **Impact**: Newer branches (e.g., claude/ci-optin-smoke, 2 commits behind) have conflicts
- **Fix**: Enforce rebase-after-major-changes policy, communicate refactors to team

### Issue 4: Missing Backward Compatibility Strategy
- **Problem**: Architecture deprecated without deprecation period
- **Root Cause**: No transition plan for active feature branches
- **Impact**: 40+ file changes in old branches are now useless
- **Fix**: Maintain compatibility layer, create migration guide for old branches

---

## Recommendations (Prioritized by Impact)

### IMMEDIATE (Fix Deployment Blocking Issues):
1. **FIX pages.yml YAML syntax**
   - Quote heredoc delimiters: `<< 'JSON'` instead of `<< JSON`
   - This blocks GitHub Pages deployment
   - Estimated effort: 5 minutes
   - Risk: None (syntax fix only)

2. **Add YAML linting to CI pipeline**
   - Tool: `yamllint` already installed
   - Add to ci.yml: linting step that runs on workflow changes
   - Estimated effort: 15 minutes
   - Risk: None (prevents future issues)

### SHORT-TERM (Resolve Merge Conflicts):
3. **Close obsolete branches (chore/auto-update-branch, chore/ci-docs-links)**
   - Root cause: 222 commits behind, based on deprecated architecture
   - Can't be salvaged without complete rewrite
   - Recommendation: Close both PRs with explanation
   - Estimated effort: 2 minutes (per branch)
   - Impact: Reduces conflict count from 14 to 12

4. **Rebase recent branches (Phase 16-19, CI-focus branches)**
   - These are recent (1-26 commits behind) and fixable
   - Need to rebase against latest main (after d12d5d7)
   - Estimated effort: 10-20 minutes per branch
   - Impact: Eliminates remaining conflicts

### MEDIUM-TERM (Prevent Recurrence):
5. **Implement branch lifecycle management**
   - Auto-close branches >30 days old without activity
   - Send notifications when base branch has major refactors
   - Require rebase before merge if behind by >20 commits
   - Estimated effort: 2-4 hours (GitHub Actions workflow)

6. **Create architecture deprecation process**
   - Document deprecation timeline (e.g., "boss-api deprecated as of Nov 7")
   - Notify maintainers of active branches
   - Provide migration guide
   - Estimated effort: 2 hours (documentation + communication)

7. **Enforce workflow validation**
   - Add yamllint as required CI check for .github/workflows/*.yml
   - Add shellcheck for shell scripts in workflows
   - Estimated effort: 1 hour
   - Benefit: Catches syntax errors before merge

### LONG-TERM (Strategic Improvements):
8. **Establish CI/CD governance**
   - Document workflow change approval process
   - Require communication before major refactors
   - Implement staged rollout for workflow changes
   - Estimated effort: 4-8 hours (documentation + process)

9. **Create branch strategy documentation**
   - Document ideal branch lifetime
   - Document required rebase frequency
   - Document handling of stale branches
   - Estimated effort: 2-3 hours

---

## Current Status

### Deployable PRs:
- ✅ Most branches (1-20 commits behind) - just need conflict resolution
- ✅ Phase 16-19 branches - minor refactor conflicts, easily fixable

### Non-Deployable PRs:
- ❌ chore/auto-update-branch (222 commits behind, obsolete architecture)
- ❌ chore/ci-docs-links (222 commits behind, obsolete architecture)
- ❌ pages.yml workflow (INVALID YAML - affects deployment)

### Blocking Issues:
1. pages.yml invalid YAML (critical - deployment blocker)
2. Branch divergence after major ci.yml refactor

---

## Testing Recommendations

After implementing fixes:

1. Test pages.yml syntax:
   ```bash
   python3 -c "import yaml; yaml.safe_load(open('.github/workflows/pages.yml'))"
   ```

2. Test branch merges:
   ```bash
   git checkout main
   git pull origin main
   git checkout <branch>
   git merge origin/main
   # Should have 0 conflicts after rebasing
   ```

3. Run full CI:
   - Verify all workflows parse correctly
   - Run validate job locally (bash tools/ci/validate.sh)
   - Run ops gate test

---

**Analysis Complete**: 3 root errors, 9 recommendations, clear remediation path
