# Code Review: Week 3-4 SPEC & PLAN Documents

**Date:** 2025-11-12  
**Reviewer:** Multi-Agent Code Review (Style + Security + History-Aware)  
**Files Reviewed:**
- `g/reports/feature_claude_code_week3_4_docs_monitoring_SPEC.md`
- `g/reports/feature_claude_code_week3_4_docs_monitoring_PLAN.md`

---

## Executive Summary

**Verdict:** ⚠️ **NEEDS FIXES** - Good structure but has path mismatches and integration gaps

**Overall Assessment:**
- ✅ **Strengths:** Clear MVS scope, well-structured phases, practical acceptance criteria
- ⚠️ **Issues:** MLS path mismatch, missing directory creation, metrics file location unclear
- 🔧 **Recommendations:** Align with existing MLS patterns, verify dashboard structure, add directory setup

---

## Agent A: Style Check & Structure Review

### ✅ Strengths

1. **Documentation Structure**
   - Clear section headers
   - Consistent formatting
   - Good use of checkboxes in PLAN
   - Proper status indicators

2. **Scope Definition**
   - Explicit "Out of Scope" section prevents scope creep
   - MVS approach is well-defined
   - Time estimates are realistic

3. **Acceptance Criteria**
   - Measurable and testable
   - Covers all major components
   - Clear success metrics

### ⚠️ Style Issues

1. **Inconsistent Path References**
   - SPEC line 84: `mls/lessons/claude_code/` (new directory)
   - But existing MLS uses: `g/knowledge/mls_lessons.jsonl` and `mls/ledger/YYYY-MM-DD.jsonl`
   - **Recommendation:** Align with existing MLS structure or document new directory creation

2. **Missing Directory Setup**
   - PLAN doesn't explicitly create `mls/lessons/claude_code/` directory
   - Dashboard directory `g/apps/dashboard/` exists but not verified
   - **Recommendation:** Add directory creation steps in Phase 1 or Phase 2

3. **Metrics File Location Ambiguity**
   - SPEC line 76: References `g/reports/claude_code_metrics_YYYYMM.md|json`
   - But grep shows no existing `claude_code_metrics_*.json` files
   - **Recommendation:** Clarify if this is new or existing, and document creation process

---

## Agent B: Security & Integration Review

### ✅ Security Strengths

1. **No Breaking Changes**
   - Explicitly states "No Breaking Changes" constraint
   - Hooks are additive (not replacing existing)
   - Tests use check_runner pattern (safe execution)

2. **Error Handling**
   - MLS capture has "fails silently" risk identified
   - Mitigation plan includes logging
   - Smoke tests use check_runner (prevents early exit)

### ⚠️ Security & Integration Concerns

1. **MLS Capture Integration**
   - **Issue:** SPEC proposes markdown files in `mls/lessons/claude_code/`
   - **Existing Pattern:** System uses `tools/mls_capture.zsh` which writes to `g/knowledge/mls_lessons.jsonl`
   - **Risk:** Two different MLS formats could cause confusion
   - **Recommendation:** Either:
     - Use existing `mls_capture.zsh` tool (call it from hooks)
     - OR document why new format is needed and how to migrate

2. **Hook Modification Risk**
   - **Issue:** PLAN modifies `compare_results.zsh` and `verify_deployment.zsh`
   - **Risk:** Could break existing functionality if not careful
   - **Recommendation:** 
     - Add backup step before modification
     - Test hooks independently after modification
     - Add rollback verification in Phase 2

3. **Dashboard Data Source**
   - **Issue:** Dashboard reads from JSON that may not exist yet
   - **Risk:** Dashboard fails silently if JSON missing
   - **Recommendation:** Add error handling in dashboard HTML (show "No data" message)

---

## Agent C: History-Aware & Pattern Review

### ✅ Pattern Alignment

1. **Test Strategy**
   - ✅ Uses `check_runner.zsh` pattern (consistent with Week 2)
   - ✅ Generates Markdown + JSON reports (matches existing pattern)
   - ✅ Exit code 0 = pass (standard pattern)

2. **Documentation Structure**
   - ✅ Follows existing `docs/claude_code/` pattern
   - ✅ Thai/English bilingual (matches existing docs)
   - ✅ Practical examples (matches `SLASH_COMMANDS_GUIDE.md` style)

3. **Dashboard Design**
   - ✅ Simple HTML with inline CSS (matches `g/apps/dashboard/index.html`)
   - ✅ Vanilla JS (no frameworks, matches existing)
   - ✅ Periodic updates (not real-time, matches health dashboard pattern)

### ⚠️ Pattern Mismatches

1. **MLS Capture Pattern Mismatch**
   - **Existing:** `tools/mls_capture.zsh` writes JSONL to `g/knowledge/mls_lessons.jsonl`
   - **Proposed:** Markdown files to `mls/lessons/claude_code/YYYYMMDD_*.md`
   - **Gap:** Different format, different location, different tool
   - **Recommendation:** 
     - Option A: Use existing `mls_capture.zsh` tool:
       ```zsh
       # In compare_results.zsh hook:
       "$BASE/tools/mls_capture.zsh" solution "Code Review: $FEATURE" "Review completed with $NUM_AGENTS agents" "Backend: $BACKEND"
       ```
     - Option B: Document new format and migration plan

2. **Metrics File Pattern**
   - **Existing:** `g/reports/claude_code_metrics_202511.md` (found in grep)
   - **Proposed:** `g/reports/claude_code_metrics_YYYYMM.json`
   - **Gap:** Format change (MD → JSON), location same
   - **Recommendation:** Clarify if JSON is additional or replacement

3. **Directory Structure**
   - **Existing:** `mls/ledger/` for JSONL files, `g/knowledge/` for lessons
   - **Proposed:** `mls/lessons/claude_code/` for markdown
   - **Gap:** New directory structure not aligned with existing
   - **Recommendation:** Document directory creation in PLAN Phase 2

---

## Risk Summary

### 🔴 High Priority Risks

1. **MLS Path Mismatch**
   - **Impact:** Lessons may not be captured correctly
   - **Likelihood:** High (if not addressed)
   - **Mitigation:** Align with existing MLS tool or document new approach clearly

2. **Missing Directory Creation**
   - **Impact:** MLS capture fails silently
   - **Likelihood:** Medium (if PLAN not followed exactly)
   - **Mitigation:** Add explicit directory creation in PLAN Phase 2

### 🟡 Medium Priority Risks

1. **Dashboard JSON Missing**
   - **Impact:** Dashboard shows no data
   - **Likelihood:** Medium (if metrics_to_json not run)
   - **Mitigation:** Add error handling in dashboard HTML

2. **Hook Modification Breaking Changes**
   - **Impact:** Existing hooks may fail
   - **Likelihood:** Low (if tested properly)
   - **Mitigation:** Add backup and rollback verification

### 🟢 Low Priority Risks

1. **Documentation Too Verbose**
   - **Impact:** Users may skip important sections
   - **Likelihood:** Low (MVS approach helps)
   - **Mitigation:** Keep concise, focus on examples

---

## Diff Hotspots (Areas Requiring Careful Review)

### 1. `tools/subagents/compare_results.zsh` (Line 58 in PLAN)
- **Change:** Add MLS capture hook
- **Risk:** Could break existing report generation
- **Recommendation:** 
  - Add hook at end of function (after report generation)
  - Wrap in `|| true` to prevent failure
  - Test independently

### 2. `tools/claude_hooks/verify_deployment.zsh` (Line 65 in PLAN)
- **Change:** Add MLS capture hook
- **Risk:** Currently a stub (line 4: `# TODO: check health endpoints`)
- **Recommendation:**
  - Complete stub first, then add MLS hook
  - Or add MLS hook as part of stub completion

### 3. `g/apps/dashboard/claude_code.html` (New file)
- **Change:** New dashboard page
- **Risk:** May not integrate with existing dashboard navigation
- **Recommendation:**
  - Check `g/apps/dashboard/index.html` for navigation pattern
  - Add link to new dashboard in main index

### 4. `mls/lessons/claude_code/` (New directory)
- **Change:** New directory structure
- **Risk:** Not aligned with existing MLS patterns
- **Recommendation:**
  - Document why new directory is needed
  - OR use existing `g/knowledge/` or `mls/ledger/` structure

---

## Specific Recommendations

### Must Fix (Before Implementation)

1. **Align MLS Capture with Existing Pattern**
   ```markdown
   **Option A (Recommended):** Use existing mls_capture.zsh
   - Modify hooks to call: `tools/mls_capture.zsh solution "..." "..." "..."`
   - Writes to existing `g/knowledge/mls_lessons.jsonl`
   - No new directory needed
   
   **Option B:** Document new format
   - Explain why markdown files are needed
   - Add migration plan from JSONL to markdown
   - Update MLS documentation
   ```

2. **Add Directory Creation Steps**
   - PLAN Phase 2, Task 2.1: Add `mkdir -p mls/lessons/claude_code`
   - PLAN Phase 3, Task 3.1: Verify `g/apps/dashboard/` exists

3. **Clarify Metrics File Format**
   - SPEC line 76: Document if JSON replaces MD or is additional
   - PLAN Task 3.1: Clarify if `metrics_to_json.zsh` is required or optional

### Should Fix (During Implementation)

1. **Add Error Handling to Dashboard**
   - Show "No data available" if JSON missing
   - Add console.error for debugging

2. **Add Backup Before Hook Modification**
   - PLAN Phase 2: Add backup step before modifying hooks
   - Store backups in `backups/hooks_YYYYMMDD/`

3. **Complete verify_deployment.zsh Stub**
   - PLAN Phase 2, Task 2.2: Complete stub first, then add MLS hook

### Nice to Have (Future)

1. **Add Navigation Link**
   - Update `g/apps/dashboard/index.html` to link to `claude_code.html`

2. **Add MLS Migration Script**
   - If using new format, create script to migrate existing lessons

---

## Final Verdict

**Status:** ⚠️ **APPROVED WITH FIXES REQUIRED**

**Summary:**
- ✅ **Structure:** Excellent - clear phases, realistic timeline, good acceptance criteria
- ⚠️ **Integration:** Needs alignment with existing MLS patterns
- ⚠️ **Completeness:** Missing directory creation and error handling steps

**Required Actions Before Implementation:**
1. ✅ Decide on MLS capture approach (use existing tool OR document new format)
2. ✅ Add directory creation steps to PLAN
3. ✅ Clarify metrics file format (JSON vs MD)
4. ✅ Add error handling to dashboard design

**Recommended Actions During Implementation:**
1. Add backup step before hook modifications
2. Complete verify_deployment.zsh stub
3. Add navigation link to dashboard

**Timeline Impact:** Fixes add ~30 minutes to implementation (minimal impact)

---

## Approval Checklist

- [ ] MLS capture approach decided (existing tool OR new format documented)
- [ ] Directory creation steps added to PLAN
- [ ] Metrics file format clarified
- [ ] Error handling added to dashboard design
- [ ] Backup steps added for hook modifications
- [ ] verify_deployment.zsh stub completion planned

---

**Review Complete:** 2025-11-12T11:51:05Z  
**Next Step:** Address "Must Fix" items, then proceed with implementation
