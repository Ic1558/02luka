# Feature Plan: save.sh Full Cycle Test (CLS + CLC Lanes)

**Date:** 2025-11-15  
**Feature:** Full save cycle testing in CLS and CLC environments  
**Status:** 📋 **PLAN READY FOR EXECUTION**

---

## Executive Summary

Test save.sh in both CLS (Cursor IDE) and CLC (Claude Code) environments to ensure:
1. Auto-commit integration works (or verify existing mechanism)
2. Verification command executes correctly
3. MLS logging creates entries for each save

**Estimated Time:** 2-3 hours  
**Priority:** High (ensures save.sh works in production)

---

## Task Breakdown

### Phase 1: Manual Commit Verification

**Task 1.1: Verify save.sh Does NOT Auto-Commit**
- **Status:** 🔄 Pending
- **Action:** 
  - Confirm save.sh has no git commit/push commands
  - Verify save.sh ends at "workspace updated, ready to commit"
  - Document Layer 5 as "manual commit / review step"
- **Deliverable:** Confirmation that save.sh does not auto-commit
- **Time:** 15 min

**Task 1.2: Test Manual Commit After save.sh**
- **Status:** 🔄 Pending
- **Action:**
  - Run save.sh
  - Check `git status` for uncommitted files (session, context, memory)
  - Verify files are in clean state ready for commit
  - Test manual commit: `git add` + `git commit`
  - Verify commit succeeds cleanly
- **Deliverable:** Manual commit test report
- **Time:** 30 min

**Task 1.3: Verify Higher-Level Auto-Commit (if exists)**
- **Status:** 🔄 Pending
- **Action:** If auto-commit exists in higher-level tooling:
  - Find auto-commit script/LaunchAgent/pre-commit hooks
  - Verify it picks up save.sh output files
  - Document integration (but don't modify save.sh)
- **Deliverable:** Higher-level auto-commit documentation
- **Time:** 30 min

---

### Phase 2: MLS Logging Integration (Opt-in Hook)

**Task 2.1: Add Opt-in MLS Logging Hook to save.sh**
- **Status:** 🔄 Pending
- **Action:**
  - Add opt-in hook: `if [ "${LUKA_MLS_AUTO_RECORD:-0}" = "1" ]; then ... fi`
  - Use `mls_auto_record.zsh` with save details:
    - Type: "save_sh_full_cycle"
    - Title: "Session saved: TIMESTAMP"
    - Summary: Include session summary, actions, status, verification status
    - Tags: "save,session,auto-captured"
    - Context payload: Include session file path, verification status
  - Default: Flag unset/0, so normal runs do not spam MLS
  - Handle MLS logging failures gracefully (non-blocking)
- **Deliverable:** Updated save.sh with opt-in MLS logging hook
- **Time:** 30 min

**Task 2.2: Test MLS Logging (Opt-in)**
- **Status:** 🔄 Pending
- **Action:**
  - Run save.sh with `LUKA_MLS_AUTO_RECORD=1`
  - Verify MLS entry created in ledger
  - Verify entry contains correct data (timestamp, summary, actions, status, verification status)
  - Verify entry links to session file
  - Run save.sh without flag (default)
  - Verify no MLS entry created (default behavior)
  - Verify no crash or slowdown in main save path
- **Deliverable:** MLS logging test report
- **Time:** 20 min

---

### Phase 3: CLS Lane Testing

**Task 3.1: Identify CLS Environment**
- **Status:** 🔄 Pending
- **Action:**
  - Determine CLS working directory (local clone, e.g. `~/LocalProjects/02luka_local_g/...`)
  - Check CLS environment variables (LUKA_SOT, etc.)
  - Verify CLS has access to save.sh
  - Check available verification tools in CLS:
    - `gh` workflows, Codex review, `cls-ci.yml`
    - Editor-side checks (ESLint/TS, etc.)
  - Document "IDE lane" risk pattern (small edits, untracked files, WIP branches)
- **Deliverable:** CLS environment documentation
- **Time:** 20 min

**Task 3.2: Run Full Save Cycle in CLS**
- **Status:** 🔄 Pending
- **Action:**
  - Execute save.sh in CLS environment with `LUKA_MLS_AUTO_RECORD=1`
  - Monitor all 4 layers (session, context, memory, verification)
  - Check `git status` for manual commit readiness
  - Verify MLS entry created (opt-in hook enabled)
  - Capture logs and output
  - Document any CLS-specific differences (paths, env vars, missing tools) as MLS entries
- **Deliverable:** CLS test execution report
- **Time:** 30 min

**Task 3.3: Verify CLS Results**
- **Status:** 🔄 Pending
- **Action:**
  - Check session file created correctly
  - Verify context files updated (if they exist)
  - Verify memory file appended
  - Verify verification ran and passed
  - Check `git status` shows files ready for manual commit
  - Test manual commit succeeds cleanly
  - Verify MLS entry in ledger (opt-in hook)
  - Document any CLS-specific issues or differences
- **Deliverable:** CLS verification report
- **Time:** 20 min

---

### Phase 4: CLC Lane Testing

**Task 4.1: Identify CLC Environment**
- **Status:** 🔄 Pending
- **Action:**
  - Determine CLC working directory (primary SOT, e.g. `~/02luka/g/...`)
  - Check CLC environment variables (LUKA_SOT, etc.)
  - Verify CLC has access to save.sh
  - Check available verification tools in CLC:
    - Local scripts (`tools/*`), make targets
    - System-level CI (`cls-ci.yml`, other workflows)
  - Check CLC-specific configurations (`state/clc_export_mode.env`)
  - Document "Governance lane" risk pattern (must obey SOT, telemetry, MLS, LaunchAgent patterns)
- **Deliverable:** CLC environment documentation
- **Time:** 20 min

**Task 4.2: Run Full Save Cycle in CLC**
- **Status:** 🔄 Pending
- **Action:**
  - Execute save.sh in CLC environment with `LUKA_MLS_AUTO_RECORD=1`
  - Monitor all 4 layers (session, context, memory, verification)
  - Check `git status` for manual commit readiness
  - Verify MLS entry created (opt-in hook enabled)
  - Capture logs and output
  - Document any CLC-specific differences (paths, env vars, missing tools) as MLS entries
- **Deliverable:** CLC test execution report
- **Time:** 30 min

**Task 4.3: Verify CLC Results**
- **Status:** 🔄 Pending
- **Action:**
  - Check session file created correctly
  - Verify context files updated (if they exist)
  - Verify memory file appended
  - Verify verification ran and passed
  - Check `git status` shows files ready for manual commit
  - Test manual commit succeeds cleanly
  - Verify MLS entry in ledger (opt-in hook)
  - Document any CLC-specific issues or differences
- **Deliverable:** CLC verification report
- **Time:** 20 min

---

### Phase 5: Integration Verification & Documentation

**Task 5.1: Compare CLS vs CLC Results**
- **Status:** 🔄 Pending
- **Action:**
  - Compare test results from both lanes
  - Document any differences
  - Identify lane-specific issues
  - Create comparison report
- **Deliverable:** CLS vs CLC comparison report
- **Time:** 30 min

**Task 5.2: Create Test Documentation**
- **Status:** 🔄 Pending
- **Action:**
  - Document test procedures
  - Create test checklist
  - Document expected results
  - Create troubleshooting guide
- **Deliverable:** Test documentation
- **Time:** 30 min

**Task 5.3: Final Verification**
- **Status:** 🔄 Pending
- **Action:**
  - Run one final test in each lane
  - Verify all components work
  - Create final test report
- **Deliverable:** Final test report
- **Time:** 20 min

---

## Test Strategy

### Test Environment Setup

**CLS Lane:**
- Environment: Cursor IDE (CLS)
- Working Directory: `~/02luka` (or CLS-specific)
- Verification Tools: Test availability of ci_check.zsh, auto_verify_template.sh
- Git: Verify git access and auto-commit behavior
- MLS: Verify MLS ledger accessible

**CLC Lane:**
- Environment: Claude Code (CLC) / Claude Subagents
- Working Directory: Check CLC-specific paths
- Verification Tools: Test availability of ci_check.zsh, auto_verify_template.sh
- Git: Verify git access and auto-commit behavior
- MLS: Verify MLS ledger accessible
- Config: Check `state/clc_export_mode.env` for CLC-specific settings

### Test Cases

**TC1: CLS Full Save Cycle**
```
1. Run: tools/save.sh --summary "CLS test" --actions "Testing" --status "Test"
2. Verify: All 4 layers complete
3. Verify: Verification runs (PASS)
4. Verify: Auto-commit (if enabled)
5. Verify: MLS entry created
6. Verify: Session file exists
7. Verify: Context files updated
```

**TC2: CLC Full Save Cycle**
```
1. Run: tools/save.sh --summary "CLC test" --actions "Testing" --status "Test"
2. Verify: All 4 layers complete
3. Verify: Verification runs (PASS)
4. Verify: Auto-commit (if enabled)
5. Verify: MLS entry created
6. Verify: Session file exists
7. Verify: Context files updated
```

**TC3: Verification Failure**
```
1. Simulate verification failure (temporarily break ci_check.zsh)
2. Run: tools/save.sh --summary "Test" --actions "Test" --status "Test"
3. Verify: save.sh fails with error
4. Verify: --skip-verify bypasses failure
5. Restore verification tool
```

**TC4: Manual Commit Verification**
```
1. Run save.sh
2. Check: git status shows uncommitted files (session, context, memory)
3. Verify: Files are in clean state ready for commit
4. Test: git add + git commit
5. Verify: Commit succeeds cleanly
6. Verify: Commit message format (manual)
```

**TC5: MLS Logging Verification (Opt-in)**
```
1. Run save.sh with LUKA_MLS_AUTO_RECORD=1
2. Check: MLS ledger for new entry
3. Verify: Entry type (save_sh_full_cycle), title, summary correct
4. Verify: Entry includes verification status, session file path
5. Verify: Entry timestamp matches save timestamp
6. Run save.sh without flag (default)
7. Verify: No MLS entry created (default behavior)
8. Verify: No crash or slowdown
```

### Test Data

**Test Session Data:**
- Summary: "Full cycle test - [LANE] - [TIMESTAMP]"
- Actions: "Testing save.sh in [LANE] environment"
- Status: "Test run - verification and MLS logging"

**Expected Results:**
- Session file: `g/reports/sessions/session_YYYYMMDD_HHMMSS.md`
- 02luka.md: Last Session marker added
- Context files: Updated (if exist)
- Memory file: Session appended
- Verification: PASS (1-5s duration)
- MLS entry: Created in ledger (only if `LUKA_MLS_AUTO_RECORD=1`)
- Git status: Files ready for manual commit (no auto-commit)

---

## Implementation Details

### Manual Commit Verification

**Requirement:** save.sh must NOT add its own git commit or git push.

**Layer 5: Manual Commit/Review Step**
- save.sh ends at "workspace updated, ready to commit"
- Test verifies: `git status` shows expected files, manual commit succeeds
- No automatic git operations in save.sh

**Verification Steps:**
1. Run save.sh
2. Check `git status` for uncommitted files (session, context, memory)
3. Verify files are in clean state ready for commit
4. Test manual commit: `git add` + `git commit`
5. Verify commit succeeds cleanly

**Higher-Level Auto-Commit (if exists):**
- Check for auto-commit script/LaunchAgent/pre-commit hooks
- Verify it picks up save.sh output files
- Document integration (but don't modify save.sh)

### MLS Logging Integration (Opt-in Hook)

**Implementation:**
```zsh
# MLS Logging (opt-in hook, after Layer 4)
if [[ "${LUKA_MLS_AUTO_RECORD:-0}" == "1" ]]; then
    if [[ -f "$BASE_DIR/tools/mls_auto_record.zsh" ]]; then
        CONTEXT_PAYLOAD="Summary: $SESSION_SUMMARY | Actions: $SESSION_ACTIONS | Status: $SESSION_STATUS | Verification: $VERIFY_STATUS | Session: $SESSION_FILE"
        "$BASE_DIR/tools/mls_auto_record.zsh" \
            "save_sh_full_cycle" \
            "Session saved: $TIMESTAMP" \
            "$CONTEXT_PAYLOAD" \
            "save,session,auto-captured" \
            "" 2>/dev/null || {
            echo "⚠️  MLS logging failed (non-blocking)" >&2
        }
    fi
fi
```

**Default Behavior:**
- `LUKA_MLS_AUTO_RECORD` unset/0 → No MLS call (normal runs)
- `LUKA_MLS_AUTO_RECORD=1` → MLS entry created (test runs)

---

## Risk Mitigation

### Risk 1: Auto-Commit Conflicts
**Mitigation:**
- Use atomic commits (one commit per save)
- Check git status before committing
- Handle merge conflicts gracefully
- Make auto-commit optional (env var)

### Risk 2: Verification Command Differences
**Mitigation:**
- Use fallback chain (ci_check.zsh → auto_verify_template.sh → file check)
- Test both commands in both lanes
- Document which command is used in each lane

### Risk 3: MLS Logging Failures
**Mitigation:**
- Make MLS logging non-blocking
- Log errors but don't fail save
- Verify MLS entry creation in tests

### Risk 4: Path Differences
**Mitigation:**
- Use LUKA_SOT environment variable
- Test path resolution in both lanes
- Document path differences

### Risk 5: Environment Variable Differences
**Mitigation:**
- Check LUKA_SOT in both lanes
- Document required environment variables
- Provide setup instructions

---

## Success Criteria

- ✅ save.sh runs successfully in CLS lane (100% pass rate)
- ✅ save.sh runs successfully in CLC lane (100% pass rate)
- ✅ Manual commit works cleanly after save.sh (git status + commit)
- ✅ Verification executes in both lanes (100% execution rate)
- ✅ MLS entries created when opt-in flag enabled (100% logging rate when enabled)
- ✅ Default behavior: No MLS spam (flag unset/0)
- ✅ Zero errors or warnings in test runs
- ✅ All 4 layers complete in both lanes
- ✅ Any CLS/CLC differences documented as MLS entries
- ✅ Documentation complete

---

## Deliverables

1. **Updated save.sh** (if auto-commit/MLS logging added)
2. **CLS test report** - Full cycle test results
3. **CLC test report** - Full cycle test results
4. **Comparison report** - CLS vs CLC differences
5. **Test documentation** - Procedures and checklist
6. **Final test report** - Summary of all tests

---

## Timeline

**Phase 1: Manual Commit Verification** - 1.25 hours
- Task 1.1: 15 min
- Task 1.2: 30 min
- Task 1.3: 30 min
- Buffer: 10 min

**Phase 2: MLS Logging Integration (Opt-in Hook)** - 50 min
- Task 2.1: 30 min
- Task 2.2: 20 min

**Phase 3: CLS Lane Testing** - 1.5 hours
- Task 3.1: 20 min
- Task 3.2: 30 min
- Task 3.3: 20 min
- Buffer: 20 min

**Phase 4: CLC Lane Testing** - 1.5 hours
- Task 4.1: 20 min
- Task 4.2: 30 min
- Task 4.3: 20 min
- Buffer: 20 min

**Phase 5: Integration & Documentation** - 1.5 hours
- Task 5.1: 30 min
- Task 5.2: 30 min
- Task 5.3: 20 min
- Buffer: 10 min

**Total Estimated Time:** 6.25 hours

---

## Next Steps

1. **Review SPEC.md** - Confirm assumptions and clarify questions
2. **Start Phase 1** - Auto-commit integration analysis
3. **Execute phases sequentially** - Complete each phase before moving to next
4. **Document as you go** - Create reports for each phase
5. **Final verification** - Run complete test cycle in both lanes

---

**Plan Status:** 📋 **READY FOR EXECUTION**  
**Priority:** High  
**Dependencies:** save.sh script (✅ complete), verification tools, MLS logging tools
