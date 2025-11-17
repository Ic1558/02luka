# Critical PR Code Reviews
**Date:** 2025-11-18  
**Reviewer:** Andy (Codex Layer 4)  
**Method:** `/code-review` pattern

---

## PR #363: feat(lpe): wire Local Patch Engine worker into WO pipeline

### Status: ⚠️ **MERGE CONFLICTS**

**Conflict Details:**
- **File:** `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`
- **Reason:** PR adds 939 lines to protocol doc, but main branch was updated with Section 0 integration (we just pushed)
- **Type:** Add/add conflict (both branches added content)

**Files Changed:**
- `g/config/orchestrator/routing_rules.yaml` (+12 lines, new file)
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md` (+939 lines)
- `tools/watchers/mary_dispatcher.zsh` (+52/-10 lines)

**Code Review:**

**✅ Strengths:**
- Clean separation: routing rules in YAML config
- Proper integration with Mary dispatcher
- Includes smoke test script

**⚠️ Risks:**
- Large protocol doc changes (939 lines) conflict with recent Section 0 addition
- Need to merge protocol changes carefully

**🔧 Resolution Strategy:**
1. Rebase PR branch on latest main
2. Merge protocol doc changes manually (keep Section 0 + PR additions)
3. Verify routing rules don't conflict with existing rules
4. Test Mary dispatcher integration

**Verdict:** ⚠️ **RESOLVE CONFLICTS** - Protocol doc merge needed

---

## PR #298: feat(trading): add trading journal CSV importer and MLS hook

### Status: ❌ **5 CI FAILURES**

**Failing Checks:**
1. `validate / Phase 4/5/6 smoke (local) [REQUIRED]` - FAILURE
2. `sandbox` - FAILURE
3. `Path Guard (Reports)` - FAILURE
4. `ops-gate` - FAILURE
5. `CI Summary` - FAILURE

**Files Changed:** +24,321 / -59 lines

**Path Guard Violations Found:**
- `g/reports/AGENT_LEDGER_INTEGRATION_COMPLETE.md`
- `g/reports/AGENT_LEDGER_SETUP_COMPLETE.md`
- `g/reports/AGENT_LEDGER_SETUP_EXECUTED.md`
- `g/reports/RESOLVE_TRADING_SNAPSHOT_CONFLICTS.md`
- `g/reports/TRADING_CLI_SNAPSHOT_FIX_IMPLEMENTATION.md`
- `g/reports/TRADING_SNAPSHOT_DEPLOYMENT_CHECKLIST.md`
- `g/reports/TRADING_SNAPSHOT_FIX_COMPLETE.md`
- `g/reports/TRADING_SNAPSHOT_INTEGRATION_COMPLETE.md`
- `g/reports/ap_io_v31_implementation_summary.md`
- `g/reports/ap_io_v31_test_results.md`

**Code Review:**

**⚠️ Issues:**
- Very large PR (24K additions) - hard to review
- **10+ files violating Path Guard** (reports in wrong location)
- Multiple CI failures suggest systemic issues
- Sandbox failure suggests unsafe operations

**🔍 Investigation Needed:**
1. ✅ **Path Guard violations identified** - Move reports to `g/reports/system/`
2. Review sandbox failures (unsafe file operations?)
3. Verify smoke tests (integration issues?)
4. Check ops-gate (deployment safety?)

**🔧 Fix Strategy:**
1. **Move all report files to `g/reports/system/`** (Path Guard fix)
2. Review sandbox violations (check for unsafe operations)
3. Fix smoke test failures
4. Fix ops-gate issues
5. Re-run CI after fixes

**Verdict:** ⚠️ **FIX PATH GUARD FIRST** - 10 files need to move to `g/reports/system/`

---

## PR #310: Add WO timeline/history view in dashboard

### Status: ❌ **2 CI FAILURES + VERY LARGE**

**Failing Checks:**
1. `reality_hooks` - FAILURE
2. `Path Guard (Reports)` - FAILURE

**Files Changed:** +199,325 / -199,109 lines (⚠️ **MASSIVE**)

**Code Review:**

**⚠️ Critical Issues:**
- **Extremely large PR** (199K lines) - likely includes generated files or data
- Multiple CI failures
- Path Guard failure suggests report path issues
- Reality hooks failure suggests validation issues

**🔍 Investigation:**
1. **Check if PR includes generated files/data** (should be excluded)
2. Review Path Guard violations
3. Check reality_hooks validation errors
4. Consider splitting into smaller PRs

**🔧 Fix Strategy:**
1. **First:** Identify what's causing 199K line changes (likely node_modules, dist/, or data files)
2. Add to .gitignore if needed
3. Fix Path Guard violations
4. Fix reality_hooks validation
5. Rebase to remove unnecessary files

**Verdict:** ⚠️ **CRITICAL - REVIEW SIZE** - 199K lines is suspicious, likely includes generated files

---

## PR #358: feat(ops): Phase 3 Complete - LaunchAgent Recovery + Context Engineering Spec

### Status: ❌ **PATH GUARD FAILURE + VERY LARGE**

**Failing Checks:**
1. `Path Guard (Reports)` - FAILURE

**Files Changed:** +252,577 / -4 lines (⚠️ **MASSIVE**)

**Code Review:**

**⚠️ Critical Issues:**
- **Extremely large PR** (252K lines) - definitely includes generated files
- Path Guard failure indicates report path violations
- Phase 3 completion suggests this is important work

**🔍 Investigation:**
1. **Check what files are included** (likely hub/index.json or similar generated files)
2. Review Path Guard violations
3. Verify if large files should be in PR or generated in CI

**🔧 Fix Strategy:**
1. **Exclude generated files** from PR (hub/index.json, node_modules, dist/, etc.)
2. Fix Path Guard violations (check report paths)
3. Add generation step to CI if needed
4. Rebase to clean up

**Verdict:** ⚠️ **CRITICAL - EXCLUDE GENERATED FILES** - 252K lines likely includes hub/index.json

---

## PR #355: feat(ops): Phase 2 - LaunchAgent Validator

### Status: ❌ **PATH GUARD FAILURE**

**Failing Checks:**
1. `Path Guard (Reports)` - FAILURE

**Files Changed:** +12,289 / -24 lines

**Path Guard Violations Found:**
- `g/reports/feature_agents_layout_PLAN.md`
- `g/reports/feature_agents_layout_SPEC.md`
- `g/reports/gh_failures/.seen_runs` (should be in subdirectory)
- Multiple `g/reports/mcp_health/*.md` files (should be in subdirectory)

**Code Review:**

**⚠️ Issues:**
- Large PR (12K lines) but more reasonable than #358/#310
- **Path Guard violations identified** - Reports in wrong location
- Part of LaunchAgent recovery work (important)

**🔍 Investigation:**
1. ✅ **Path Guard violations identified:**
   - Feature plans/specs should be in `g/reports/system/` or feature-specific folder
   - MCP health reports should be in `g/reports/system/` or `g/reports/mcp_health/` subdirectory
   - `.seen_runs` file should be in subdirectory

**🔧 Fix Strategy:**
1. Move `feature_agents_layout_PLAN.md` and `feature_agents_layout_SPEC.md` to `g/reports/system/`
2. Move `mcp_health/*.md` files to proper subdirectory or `g/reports/system/`
3. Move `gh_failures/.seen_runs` to subdirectory
4. Re-run CI

**Verdict:** ⚠️ **FIX PATH GUARD** - Move reports to proper subdirectories

---

## PR #312: Reality Hooks CI PR

### Status: ❌ **SANDBOX FAILURE**

**Failing Checks:**
1. `sandbox` - FAILURE

**Files Changed:** +174 / -335 lines (net reduction)

**Code Review:**

**⚠️ Issues:**
- Sandbox failure suggests unsafe operations detected
- Net reduction is good (removing code)
- Reality hooks are important for CI validation

**🔍 Investigation:**
1. Check sandbox violations (unsafe file operations, dangerous commands?)
2. Review removed code (335 deletions) - might have removed safety checks
3. Verify reality hooks still work correctly

**🔧 Fix Strategy:**
1. Review sandbox error logs
2. Fix unsafe operations (use safe alternatives)
3. Ensure safety checks weren't accidentally removed
4. Re-run CI

**Verdict:** ⚠️ **FIX SANDBOX** - Review safety violations

---

## Summary & Actionable Fixes

### ✅ Path Guard Violations (IDENTIFIED - Easy Fixes)

**PR #298:** Move 10 files to `g/reports/system/`
```bash
# Files to move:
g/reports/AGENT_LEDGER_INTEGRATION_COMPLETE.md → g/reports/system/
g/reports/AGENT_LEDGER_SETUP_COMPLETE.md → g/reports/system/
g/reports/AGENT_LEDGER_SETUP_EXECUTED.md → g/reports/system/
g/reports/RESOLVE_TRADING_SNAPSHOT_CONFLICTS.md → g/reports/system/
g/reports/TRADING_CLI_SNAPSHOT_FIX_IMPLEMENTATION.md → g/reports/system/
g/reports/TRADING_SNAPSHOT_DEPLOYMENT_CHECKLIST.md → g/reports/system/
g/reports/TRADING_SNAPSHOT_FIX_COMPLETE.md → g/reports/system/
g/reports/TRADING_SNAPSHOT_INTEGRATION_COMPLETE.md → g/reports/system/
g/reports/ap_io_v31_implementation_summary.md → g/reports/system/
g/reports/ap_io_v31_test_results.md → g/reports/system/
```

**PR #355:** Move feature docs and health reports
```bash
# Files to move:
g/reports/feature_agents_layout_PLAN.md → g/reports/system/
g/reports/feature_agents_layout_SPEC.md → g/reports/system/
g/reports/mcp_health/*.md → g/reports/system/ (or create g/reports/mcp_health/ subdir)
g/reports/gh_failures/.seen_runs → g/reports/system/gh_failures/ (create subdir)
```

### ⚠️ Merge Conflicts (IDENTIFIED)

**PR #363:** Protocol doc conflict
- **Conflict:** `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`
- **Cause:** PR adds 939 lines, main has Section 0 integration
- **Fix:** Merge both changes (keep Section 0 + PR additions)

### 🔍 Investigation Needed

**PR #358 & #310:** Very large PRs (252K & 199K lines)
- **Action:** Check if includes `hub/index.json`, `node_modules/`, or other generated files
- **Fix:** Exclude generated files, add to `.gitignore` if needed

**PR #312:** Sandbox failure
- **Action:** Review sandbox error logs for unsafe operations
- **Fix:** Replace unsafe operations with safe alternatives

**PR #298:** Multiple CI failures
- **Action:** Fix Path Guard first, then investigate other failures
- **Fix:** Address sandbox, smoke tests, ops-gate after Path Guard

### Priority Order:

1. **PR #298** - Fix Path Guard (10 files, easy)
2. **PR #355** - Fix Path Guard (4 files, easy)
3. **PR #363** - Resolve merge conflict (1 file)
4. **PR #358 & #310** - Investigate large file sizes
5. **PR #312** - Fix sandbox violations
6. **PR #298** - Fix remaining CI failures

### Quick Fix Commands:

```bash
# For PR #298 (after checkout):
cd g/reports
mkdir -p system
mv AGENT_LEDGER_*.md system/
mv RESOLVE_TRADING_*.md system/
mv TRADING_*.md system/
mv ap_io_v31_*.md system/

# For PR #355 (after checkout):
mv feature_agents_layout_*.md system/
mkdir -p system/mcp_health
mv mcp_health/*.md system/mcp_health/ 2>/dev/null || true
mkdir -p system/gh_failures
mv gh_failures/.seen_runs system/gh_failures/ 2>/dev/null || true
```

---

**Generated by:** Andy (Codex Layer 4)  
**Review Date:** 2025-11-18
