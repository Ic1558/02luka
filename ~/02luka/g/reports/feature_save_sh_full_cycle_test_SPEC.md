# Feature Specification: save.sh Full Cycle Test (CLS + CLC Lanes)

**Date:** 2025-11-15  
**Feature:** Full save cycle testing in CLS and CLC environments  
**Status:** 📋 **SPEC READY FOR REVIEW**

---

## 1. Clarifying Questions

### Q1: CLS vs CLC Lane Differences
**Decision:** ✅ **Canonical comparison defined**

**CLS Lane (Cursor / CLS Agent):**
- Editor/Driver: Cursor IDE, CLS agent
- Typical working dir: Local clone used by Cursor (e.g. `~/LocalProjects/02luka_local_g/...`), not necessarily main SOT
- Environment:
  - Often runs under Cursor sandbox / integrated terminal
  - Heavier use of Codex / GitHub-style tools (gh, CI hints, Codex review)
- Verification tools:
  - `gh` workflows, Codex review comments, `cls-ci.yml`
  - Editor-side checks (ESLint/TS, etc. if present)
- Risk pattern: "IDE lane" – lots of small edits, high risk of untracked files and WIP branches

**CLC Lane (Claude Code / CLC Agent):**
- Editor/Driver: Claude Code, CLC agent
- Typical working dir: Primary 02luka SOT (e.g. `~/02luka/g/...`), aligned with system governance
- Environment:
  - Shell driven via MCP / Hybrid Agent
  - Closer to production file layout and LaunchAgents
- Verification tools:
  - Local scripts (`tools/*`, make targets)
  - System-level CI (`cls-ci.yml`, other workflows) triggered from this source of truth
- Risk pattern: "Governance lane" – changes must obey SOT, telemetry, MLS, and LaunchAgent patterns

**For full-cycle test:**
- Same save.sh behavior must succeed in both lanes
- Any differences (paths, env vars, missing tools) get logged as MLS entries

### Q2: Auto-Commit Integration
**Decision:** ✅ **c) Manual commit only (no new auto-commit in save.sh)**

**Details:**
- save.sh must NOT add its own git commit or git push
- The full-cycle test will verify:
  - Files are saved correctly
  - `git status` / manual commit works cleanly after running save.sh
  - Any auto-commit logic stays in higher-level tooling (pre-commit hooks, CI, separate helpers), not in save.sh
- Layer 5 = "manual commit / review step"
- save.sh ends at "workspace updated, ready to commit," not "commit created"

### Q3: MLS Logging Integration
**Decision:** ✅ **Opt-in hook via environment variable**

**Details:**
- Do NOT call MLS logging unconditionally
- Integrate MLS as a controlled, opt-in hook
- Implementation:
  ```zsh
  if [ "${LUKA_MLS_AUTO_RECORD:-0}" = "1" ]; then
    g/tools/mls_auto_record.zsh "save_sh_full_cycle" "$CONTEXT_PAYLOAD"
  fi
  ```
- Default: `LUKA_MLS_AUTO_RECORD` unset/0, so normal runs do not spam MLS
- For full-cycle tests: Turn flag on explicitly to verify integration
- Confirm: MLS entry created successfully, no crash or slowdown

### Q4: Verification Command Priority
**Question:** Which verification command should be used in each lane?

**Options:**
- a) Same verification for both (ci_check.zsh)
- b) CLS uses one command, CLC uses another
- c) Lane-specific verification commands
- d) Fallback chain: try multiple commands

**Default assumption:** Use existing priority (ci_check.zsh → auto_verify_template.sh → file check)

---

## 2. Feature Goals

### Primary Goal
Ensure save.sh works correctly in both CLS and CLC environments with:
1. **Auto-commit integration** -** Session files and context updates are committed to git
2. **Verification command execution** - Verification runs and reports correctly
3. **MLS logging** - Save events are logged to MLS ledger

### Success Criteria
- ✅ save.sh runs successfully in CLS lane
- ✅ save.sh runs successfully in CLC lane
- ✅ Auto-commit works (if integrated) or verified separately
- ✅ Verification command executes and reports correctly
- ✅ MLS entry created for each save
- ✅ All 4 layers (session, context, memory, verification) complete
- ✅ No errors or warnings in either lane

---

## 3. Scope

### In Scope
- Testing save.sh in CLS environment
- Testing save.sh in CLC environment
- Verifying auto-commit behavior
- Verifying verification command execution
- Verifying MLS logging
- Documenting differences between lanes (if any)

### Out of Scope
- Modifying save.sh implementation (already done)
- Creating new verification commands
- Modifying MLS logging mechanism
- Git workflow changes (unless auto-commit integration needed)

---

## 4. Technical Requirements

### 4.1 Auto-Commit Integration

**Requirement:** save.sh must NOT add its own git commit or git push.

**Verification Requirements:**
- Files are saved correctly (all 4 layers)
- `git status` shows clean state ready for manual commit
- Manual commit works cleanly after running save.sh
- Any auto-commit logic stays in higher-level tooling (pre-commit hooks, CI, separate helpers)

**Layer 5 (Manual Commit/Review Step):**
- save.sh ends at "workspace updated, ready to commit"
- Test verifies: `git status` shows expected files, manual commit succeeds
- No automatic git operations in save.sh

### 4.2 Verification Command Execution

**Requirement:** Verification must:
- Run in both CLS and CLC lanes
- Report correct status (PASS/FAIL)
- Emit summary for dashboard scraping
- Fail save if verification fails (unless --skip-verify)

**Current Implementation:**
- ✅ Already implemented in Layer 4
- ✅ Uses priority: ci_check.zsh → auto_verify_template.sh → file check
- ⚠️ Needs testing in both lanes

### 4.3 MLS Logging Integration

**Requirement:** MLS logging is integrated via an optional hook in save.sh, enabled by environment flag.

**Implementation:**
- Add opt-in hook: `if [ "${LUKA_MLS_AUTO_RECORD:-0}" = "1" ]; then ... fi`
- Default: `LUKA_MLS_AUTO_RECORD` unset/0, so normal runs do not spam MLS
- For tests: Enable flag explicitly to verify integration
- MLS entry includes: timestamp, summary, actions, status, verification status, session file link

**Verification:**
- MLS entry created successfully when flag enabled
- No crash or slowdown in main save path
- Default behavior remains "no MLS call" unless explicitly enabled

---

## 5. Test Strategy

### 5.1 Test Environments

**CLS Lane (Cursor / CLS Agent):**
- Environment: Cursor IDE, CLS agent
- Working directory: Local clone (e.g. `~/LocalProjects/02luka_local_g/...`)
- Verification: `gh` workflows, Codex review, `cls-ci.yml`, editor-side checks
- Git: Test manual commit after save.sh
- Risk pattern: "IDE lane" – small edits, untracked files, WIP branches
- MLS logging: Enable `LUKA_MLS_AUTO_RECORD=1` for test

**CLC Lane (Claude Code / CLC Agent):**
- Environment: Claude Code, CLC agent, MCP / Hybrid Agent
- Working directory: Primary SOT (e.g. `~/02luka/g/...`)
- Verification: Local scripts (`tools/*`), make targets, system-level CI
- Git: Test manual commit after save.sh
- Risk pattern: "Governance lane" – must obey SOT, telemetry, MLS, LaunchAgent patterns
- MLS logging: Enable `LUKA_MLS_AUTO_RECORD=1` for test
- Config: Check `state/clc_export_mode.env` for CLC-specific settings

### 5.2 Test Cases

**Test Case 1: CLS Lane - Full Save Cycle**
1. Run save.sh in CLS environment with `LUKA_MLS_AUTO_RECORD=1`
2. Verify all 4 layers complete
3. Verify verification runs and passes
4. Check `git status` for manual commit readiness
5. Verify MLS entry created (opt-in hook)
6. Check session file created
7. Check context files updated

**Test Case 2: CLC Lane - Full Save Cycle**
1. Run save.sh in CLC environment with `LUKA_MLS_AUTO_RECORD=1`
2. Verify all 4 layers complete
3. Verify verification runs and passes
4. Check `git status` for manual commit readiness
5. Verify MLS entry created (opt-in hook)
6. Check session file created
7. Check context files updated

**Test Case 3: Verification Failure Handling**
1. Simulate verification failure
2. Verify save.sh fails correctly
3. Verify --skip-verify bypass works
4. Verify MLS entry reflects failure

**Test Case 4: Manual Commit Verification**
1. Run save.sh
2. Check `git status` for uncommitted files (session, context, memory files)
3. Verify files are in clean state ready for commit
4. Test manual commit: `git add` + `git commit`
5. Verify commit succeeds cleanly

**Test Case 5: MLS Logging Verification (Opt-in)**
1. Run save.sh with `LUKA_MLS_AUTO_RECORD=1`
2. Check MLS ledger for new entry
3. Verify entry contains correct data (timestamp, summary, actions, status, verification status)
4. Verify entry links to session file
5. Run save.sh without flag (default)
6. Verify no MLS entry created (default behavior)

---

## 6. Implementation Plan

### Phase 1: Manual Commit Verification
- Confirm save.sh does NOT auto-commit
- Verify save.sh ends at "workspace updated, ready to commit"
- Test manual commit after save.sh
- Document Layer 5 as "manual commit / review step"

### Phase 2: MLS Logging Integration (Opt-in Hook)
- Add opt-in hook to save.sh: `if [ "${LUKA_MLS_AUTO_RECORD:-0}" = "1" ]; then ... fi`
- Use `mls_auto_record.zsh` with save details
- Include verification status in MLS entry
- Test MLS entry creation (with flag enabled)
- Verify default behavior (no MLS call when flag unset)

### Phase 3: CLS Lane Testing
- Run full save cycle in CLS environment
- Verify all components work
- Document any CLS-specific issues
- Fix issues if found

### Phase 4: CLC Lane Testing
- Run full save cycle in CLC environment
- Verify all components work
- Document any CLC-specific issues
- Fix issues if found

### Phase 5: Integration Verification
- Run save cycle in both lanes
- Compare results
- Document differences (if any)
- Create final test report

---

## 7. Assumptions

1. **CLS and CLC lanes exist** and have different execution contexts (defined in Q1)
2. **Auto-commit is manual only** - save.sh does NOT auto-commit
3. **MLS logging is opt-in** via `LUKA_MLS_AUTO_RECORD` environment variable
4. **Verification commands are available** in both lanes (or fallback works)
5. **Git repository is accessible** in both lanes
6. **Environment variables are set** correctly in both lanes (LUKA_SOT, etc.)

---

## 8. Risks

1. **Manual commit conflicts** - Merge conflicts when committing save.sh output
2. **Verification command differences** - Different tools available in each lane
3. **MLS logging failures** - MLS entry creation fails silently (non-blocking)
4. **Path differences** - CLS vs CLC use different paths (documented as MLS entries)
5. **Environment variable differences** - Different LUKA_SOT or other vars (documented)

---

## 9. Dependencies

1. **save.sh script** - Already implemented ✅
2. **Verification tools** - ci_check.zsh or auto_verify_template.sh
3. **MLS logging** - mls_auto_record.zsh
4. **Git access** - Git repository accessible in both lanes
5. **Environment setup** - LUKA_SOT and other vars configured

---

## 10. Success Metrics

- ✅ save.sh runs successfully in CLS lane (100% pass rate)
- ✅ save.sh runs successfully in CLC lane (100% pass rate)
- ✅ Manual commit works cleanly after save.sh (git status + commit)
- ✅ Verification executes in both lanes (100% execution rate)
- ✅ MLS entries created when opt-in flag enabled (100% logging rate when enabled)
- ✅ Default behavior: No MLS spam (flag unset/0)
- ✅ Zero errors or warnings in test runs
- ✅ Any CLS/CLC differences documented as MLS entries

---

**Spec Status:** 📋 **READY FOR PLAN CREATION**  
**Next Step:** Create PLAN.md with detailed task breakdown
