# Feature Plan: Claude Code Week 3-4 - Documentation & Monitoring (MVS)

**Feature ID:** `claude_code_week3_4_docs_monitoring`  
**Date:** 2025-11-12  
**Status:** 📋 **PLAN**

---

## Overview

**Time Estimate:** 1-2 working days (8-12 hours)  
**Approach:** MVS (Minimum Viable Set) - practical and deliverable  
**Strategy:** Build on existing infrastructure, minimal new code

---

## Task Breakdown

### Phase 1: Documentation (Morning / First Half Day)

**Time:** 3-4 hours

#### Task 1.1: Create `docs/claude_code/ONBOARDING.md`
- [ ] Write quick start section (5-minute setup)
- [ ] Add first run instructions
- [ ] Include example commands with expected outputs
- [ ] Add sample SPEC/PLAN template
- [ ] Test: Follow instructions and complete first run
- **Deliverable:** Complete onboarding guide

#### Task 1.2: Create `docs/claude_code/BEST_PRACTICES.md`
- [ ] Document do/don't patterns
- [ ] Extract real patterns from codebase
- [ ] Add command usage guidelines
- [ ] Document common workflows
- [ ] Reference existing examples
- **Deliverable:** Best practices guide

#### Task 1.3: Create `docs/claude_code/TROUBLESHOOTING.md`
- [ ] Document common symptoms
- [ ] Map symptoms to causes
- [ ] Provide solution commands
- [ ] Add hook debugging steps
- [ ] Include error message interpretation
- **Deliverable:** Troubleshooting guide

**Phase 1 Deliverables:**
- 3 documentation files complete
- User can follow onboarding successfully

---

### Phase 2: MLS Capture Integration (Morning / First Half Day)

**Time:** 1-2 hours

#### Task 2.0: Verify directories and tools exist
- [ ] Verify `g/knowledge/` directory exists (create if needed: `mkdir -p "$BASE/g/knowledge"`)
- [ ] Verify `tools/mls_capture.zsh` exists and is executable
- [ ] Test `mls_capture.zsh` with sample entry
- [ ] Verify entry appears in `g/knowledge/mls_lessons.jsonl`
- **Deliverable:** MLS infrastructure verified

#### Task 2.1: Create MLS capture hook for code reviews
- [ ] Backup `tools/subagents/compare_results.zsh` to `backups/hooks_$(date +%Y%m%d)/`
- [ ] Modify `tools/subagents/compare_results.zsh`
- [ ] Add hook at end of function (after report generation)
- [ ] Call: `"$BASE/tools/mls_capture.zsh" solution "Code Review: <feature>" "<summary>" "<context>"`
- [ ] Wrap in `|| true` to prevent hook failure
- [ ] Test: Run code review and verify MLS entry in `g/knowledge/mls_lessons.jsonl`
- **Deliverable:** Auto-capture from code reviews

#### Task 2.2: Create MLS capture hook for deployments
- [ ] Backup `tools/claude_hooks/verify_deployment.zsh` to `backups/hooks_$(date +%Y%m%d)/`
- [ ] Complete `verify_deployment.zsh` stub (if still TODO)
- [ ] Modify `tools/claude_hooks/verify_deployment.zsh`
- [ ] Add hook at end of function (after verification)
- [ ] Call: `"$BASE/tools/mls_capture.zsh" improvement "Deployment: <feature>" "<summary>" "<context>"`
- [ ] Wrap in `|| true` to prevent hook failure
- [ ] Test: Run deployment and verify MLS entry in `g/knowledge/mls_lessons.jsonl`
- **Deliverable:** Auto-capture from deployments

**Phase 2 Deliverables:**
- MLS entries created automatically
- Format is JSONL (existing MLS system)
- Hooks backed up before modification
- All hooks tested and verified

---

### Phase 3: Metrics Dashboard (Afternoon / Second Half Day)

**Time:** 3-4 hours

#### Task 3.0: Verify and create directories
- [ ] Verify `g/apps/dashboard/` exists (create if needed: `mkdir -p "$BASE/g/apps/dashboard"`)
- [ ] Verify `g/reports/` exists (create if needed: `mkdir -p "$BASE/g/reports"`)
- **Deliverable:** Required directories exist

#### Task 3.1: Create metrics JSON generator (if needed)
- [ ] Create `tools/claude_tools/metrics_to_json.zsh`
- [ ] Read from logs and metrics files
- [ ] Generate `g/reports/claude_code_metrics_YYYYMM.json` (additional to existing MD file)
- [ ] Include: hook success rates, subagent usage, deployment outcomes
- [ ] Validate JSON structure with `jq`
- [ ] Test: Generate JSON and verify structure
- **Note:** JSON is additional format, does not replace existing MD file
- **Deliverable:** JSON metrics file generator

#### Task 3.2: Create dashboard HTML
- [ ] Create `g/apps/dashboard/claude_code.html`
- [ ] Design 3-card layout (hook success, subagent usage, deployments)
- [ ] Add vanilla JavaScript to read JSON
- [ ] Add error handling:
  - Check if JSON file exists
  - Validate JSON structure
  - Display "No data available" if missing/invalid
  - Fallback to MD file if JSON unavailable
- [ ] Display latest/week data
- [ ] Add navigation link in `g/apps/dashboard/index.html` (if applicable)
- [ ] Test: Open HTML and verify cards display (with and without data)
- **Deliverable:** Working dashboard page with error handling

**Phase 3 Deliverables:**
- Dashboard displays 3 cards correctly
- Reads from JSON/metrics files
- Updates periodically

---

### Phase 4: Smoke Tests (Afternoon / Second Half Day)

**Time:** 2-3 hours

#### Task 4.1: Create E2E smoke test for commands
- [ ] Create `tests/claude_code/e2e_smoke_commands.zsh`
- [ ] Use `check_runner.zsh` pattern
- [ ] Test all 5 commands: `/feature-dev`, `/deploy`, `/code-review`, `/commit`, `/health-check`
- [ ] Each test = one `cr_run_check`
- [ ] Generate reports (Markdown + JSON)
- [ ] Test: Run script and verify exit 0
- **Deliverable:** E2E smoke test passing

#### Task 4.2: Create orchestrator smoke test
- [ ] Create `tests/claude_code/orchestrator_review_smoke.zsh`
- [ ] Use `check_runner.zsh` pattern
- [ ] Test "review strategy" (single case)
- [ ] Verify subagent execution
- [ ] Verify result synthesis
- [ ] Generate reports (Markdown + JSON)
- [ ] Test: Run script and verify exit 0
- **Deliverable:** Orchestrator smoke test passing

**Phase 4 Deliverables:**
- Both smoke tests pass (exit 0)
- Reports generated correctly
- Tests use check_runner pattern

---

### Phase 5: Final Documentation & Delivery (End of Day)

**Time:** 1 hour

#### Task 5.1: Create delivery report
- [ ] Create `g/reports/system/claude_code_week3_MVS_DELIVERED_YYYYMMDD.md`
- [ ] Document all deliverables
- [ ] Include acceptance criteria verification
- [ ] List files created/modified
- **Deliverable:** Delivery report

#### Task 5.2: Update weekly recap (if applicable)
- [ ] Add metrics block to weekly recap
- [ ] Reference new dashboard
- [ ] Include documentation links
- **Deliverable:** Updated weekly recap

**Phase 5 Deliverables:**
- Delivery report complete
- Weekly recap updated

---

## Test Strategy

### Unit Tests
- Documentation files exist and are readable
- Dashboard HTML is valid
- MLS files are created with correct format
- Test scripts are executable

### Integration Tests
- E2E smoke test for all commands
- Orchestrator smoke test
- MLS capture triggers correctly
- Dashboard reads JSON correctly

### System Tests
- User can follow onboarding successfully
- Dashboard displays accurate data
- MLS files created automatically
- All smoke tests pass

---

## Risk Mitigation

**Risk:** Documentation too verbose  
**Mitigation:** Keep concise, focus on practical examples

**Risk:** Dashboard JSON format mismatch  
**Mitigation:** Validate JSON structure, add error handling

**Risk:** MLS capture fails silently  
**Mitigation:** 
- Use existing `mls_capture.zsh` tool (proven reliability)
- Wrap in `|| true` to prevent hook failure
- Verify entry in `g/knowledge/mls_lessons.jsonl` in tests
- Add logging to capture success/failure

**Risk:** Smoke tests fail due to environment  
**Mitigation:** Use check_runner pattern, handle errors gracefully

---

## Rollback Plan

**If Issues:**
1. Remove new documentation files
2. Remove dashboard HTML
3. Remove MLS capture hooks
4. Remove smoke test files
5. Document issues in delivery report

**Rollback Script:** `tools/rollback_claude_code_week3_4_YYYYMMDD.zsh` (create if needed)

---

## Dependencies

- Week 1 foundation complete ✅
- Week 2 workflows complete ✅
- `tools/lib/check_runner.zsh` exists ✅
- `tools/subagents/compare_results.zsh` exists ✅
- `tools/claude_hooks/verify_deployment.zsh` exists ✅
- `tools/claude_tools/metrics_collector.zsh` exists (optional)
- `tools/mls_capture.zsh` exists ✅ (required for MLS capture)
- `g/knowledge/` directory exists (will create if needed)
- `g/apps/dashboard/` directory exists (will create if needed)

---

## Success Criteria

1. ✅ All 3 documentation files created and tested
2. ✅ Dashboard displays 3 cards correctly (with error handling)
3. ✅ MLS entries created automatically after reviews/deployments (in `g/knowledge/mls_lessons.jsonl`)
4. ✅ E2E smoke test passes (exit 0)
5. ✅ Orchestrator smoke test passes (exit 0)
6. ✅ Delivery report created
7. ✅ User can onboard in < 5 minutes
8. ✅ No regression in system health
9. ✅ All directories created (g/knowledge, g/apps/dashboard, g/reports)
10. ✅ Hooks backed up before modification

---

## Timeline Summary

**Morning (4-5 hours):**
- Documentation (3 files)
- MLS capture hooks

**Afternoon (4-5 hours):**
- Metrics dashboard (JSON + HTML)
- Smoke tests (2 files)

**End of Day (1 hour):**
- Delivery report
- Final verification

**Total:** 8-12 hours (1-2 working days)

---

**Status:** 📋 **READY FOR IMPLEMENTATION** (v1.1 - Fixed per code review)
