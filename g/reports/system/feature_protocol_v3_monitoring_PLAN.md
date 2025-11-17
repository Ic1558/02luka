# Feature Plan: Protocol v3.2 Monitoring & Verification

**Feature:** Automated monitoring and verification of Protocol v3.2 compliance in bridge self-check workflow

**Date:** 2025-11-18  
**Status:** PLAN  
**Author:** Auto (via /feature-dev)

---

## 1. Problem Statement

After implementing Protocol v3.2 alignment in the bridge self-check workflow, we need automated verification that:

1. **Escalation prompts** correctly route through Mary/GC per Protocol v3.2
2. **MLS events** include the `context-protocol-v3.2` tag
3. **Routing matrix** is followed when issues occur (CLC for locked zones, Gemini for non-locked)

Currently, verification is manual and requires:
- Checking workflow run logs
- Downloading artifacts
- Inspecting MLS ledger files
- Manually confirming routing behavior

**Goal:** Automate verification and provide clear pass/fail reports.

---

## 2. Requirements

### 2.1 Functional Requirements

**FR1: Workflow Run Analysis**
- Parse workflow run logs for escalation prompts
- Verify prompts contain Protocol v3.2 routing instructions
- Check for correct Mary/GC routing (not direct CLC/Gemini)

**FR2: MLS Event Verification**
- Query MLS ledger for events from bridge self-check runs
- Verify `context-protocol-v3.2` tag is present
- Check event metadata matches workflow run

**FR3: Escalation Prompt Validation**
- Download escalation prompt artifacts when available
- Validate prompt format matches Protocol v3.2 template
- Verify routing instructions (locked → CLC, non-locked → Gemini)

**FR4: Reporting**
- Generate pass/fail report per workflow run
- Aggregate compliance metrics over time
- Alert on Protocol v3.2 violations

### 2.2 Non-Functional Requirements

**NFR1: Performance**
- Verification should complete within 30 seconds
- Should not block workflow execution

**NFR2: Reliability**
- Handle missing artifacts gracefully
- Work with both successful and failed workflow runs

**NFR3: Maintainability**
- Use existing tools (`gh`, `jq`, `zsh`)
- Follow 02luka patterns (reports in `g/reports/system/`)

---

## 3. Technical Approach

### 3.1 Architecture

```
┌─────────────────────────────────────────┐
│  Bridge Self-Check Workflow            │
│  (Generates escalation prompts + MLS)  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Protocol v3.2 Verification Script     │
│  (Runs post-workflow, analyzes artifacts)│
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Verification Report                    │
│  (g/reports/system/protocol_v3_verify_*)│
└─────────────────────────────────────────┘
```

### 3.2 Components

**Component 1: Workflow Run Analyzer**
- Input: Workflow run ID
- Process:
  1. Fetch run logs via `gh run view`
  2. Extract escalation prompt content
  3. Validate Protocol v3.2 routing format
- Output: Pass/fail with details

**Component 2: MLS Event Verifier**
- Input: Workflow run ID, run timestamp
- Process:
  1. Query MLS ledger for matching events
  2. Check for `context-protocol-v3.2` tag
  3. Verify event metadata
- Output: Pass/fail with event details

**Component 3: Artifact Validator**
- Input: Workflow run ID
- Process:
  1. Download escalation prompt artifact (if exists)
  2. Parse prompt content
  3. Validate against Protocol v3.2 template
- Output: Pass/fail with validation details

**Component 4: Report Generator**
- Input: All verification results
- Process:
  1. Aggregate pass/fail status
  2. Generate markdown report
  3. Save to `g/reports/system/`
- Output: Verification report file

---

## 4. Implementation Plan

### 4.1 Task Breakdown

**Task 1: Create Verification Script**
- File: `g/tools/verify_protocol_v3_compliance.zsh`
- Function: Main verification orchestrator
- Dependencies: `gh`, `jq`, `zsh`
- Estimated effort: 2-3 hours

**Task 2: Implement Workflow Run Analyzer**
- Function: Parse logs and extract escalation prompts
- Validation: Check for Mary/GC routing, Protocol v3.2 references
- Estimated effort: 1-2 hours

**Task 3: Implement MLS Event Verifier**
- Function: Query MLS ledger and verify tags
- Validation: Check for `context-protocol-v3.2` tag
- Estimated effort: 1-2 hours

**Task 4: Implement Artifact Validator**
- Function: Download and validate escalation prompts
- Validation: Template matching, routing instruction check
- Estimated effort: 1-2 hours

**Task 5: Create Report Generator**
- Function: Generate markdown verification reports
- Output: `g/reports/system/protocol_v3_verify_<RUN_ID>.md`
- Estimated effort: 1 hour

**Task 6: Integration Testing**
- Test with successful workflow runs
- Test with failed workflow runs
- Test with missing artifacts
- Estimated effort: 1-2 hours

**Total Estimated Effort:** 7-12 hours

### 4.2 File Structure

```
g/tools/
  └── verify_protocol_v3_compliance.zsh    # Main script

g/reports/system/
  └── protocol_v3_verify_<RUN_ID>.md       # Generated reports
```

---

## 5. Test Strategy

### 5.1 Unit Tests

**Test 1: Escalation Prompt Parsing**
- Input: Sample workflow log with escalation prompt
- Expected: Correctly extracts prompt content
- Validation: Prompt contains "Mary/GC" and Protocol v3.2 references

**Test 2: MLS Tag Verification**
- Input: MLS ledger entry with `context-protocol-v3.2` tag
- Expected: Verification passes
- Validation: Tag is correctly identified

**Test 3: Artifact Download**
- Input: Workflow run with escalation prompt artifact
- Expected: Artifact downloaded and parsed
- Validation: Content matches expected format

### 5.2 Integration Tests

**Test 1: Successful Workflow Run**
- Trigger: Bridge self-check workflow (healthy state)
- Expected: Verification passes (no escalation prompt, MLS tag present)
- Validation: Report shows all checks passing

**Test 2: Failed Workflow Run (Critical Issues)**
- Trigger: Bridge self-check workflow with critical issues
- Expected: Verification passes (escalation prompt follows Protocol v3.2)
- Validation: Report confirms Mary/GC routing

**Test 3: Missing Artifacts**
- Trigger: Workflow run without escalation prompt artifact
- Expected: Verification handles gracefully
- Validation: Report indicates missing artifact (not a failure)

### 5.3 Manual Testing

**Test 1: Run verification on existing workflow runs**
- Use run #19444054508 (already executed)
- Verify script produces correct report
- Check report accuracy

**Test 2: Run verification on PR #365 workflow runs**
- Use runs from PR #365
- Verify Protocol v3.2 compliance
- Confirm all checks pass

---

## 6. Success Criteria

### 6.1 Functional Success

✅ **Verification script runs successfully**
- No errors on valid workflow runs
- Handles edge cases gracefully

✅ **Reports are accurate**
- Correctly identifies Protocol v3.2 compliance
- Provides actionable feedback on failures

✅ **Integration works**
- Can be run manually via CLI
- Can be integrated into CI/CD (future)

### 6.2 Non-Functional Success

✅ **Performance**
- Completes within 30 seconds
- Doesn't block workflow execution

✅ **Reliability**
- Handles missing data gracefully
- Provides clear error messages

---

## 7. Open Questions

**Q1: Should verification run automatically?**
- Option A: Manual CLI tool (recommended for MVP)
- Option B: GitHub Action that runs post-workflow
- **Decision:** Start with Option A, consider Option B later

**Q2: How to handle historical workflow runs?**
- Option A: Only verify new runs
- Option B: Batch verify past N runs
- **Decision:** Start with Option A, add batch mode if needed

**Q3: Where to store verification results?**
- Option A: `g/reports/system/` (recommended)
- Option B: MLS ledger entries
- **Decision:** Option A for reports, Option B for metrics (future)

---

## 8. Dependencies

**External:**
- `gh` CLI (GitHub CLI)
- `jq` (JSON processor)
- `zsh` (shell)

**Internal:**
- Bridge self-check workflow (`.github/workflows/bridge-selfcheck.yml`)
- MLS ledger structure
- Protocol v3.2 documentation (`g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`)

---

## 9. Risks & Mitigations

**Risk 1: MLS ledger format changes**
- **Impact:** High - verification would break
- **Mitigation:** Use schema validation, version checks

**Risk 2: Workflow log format changes**
- **Impact:** Medium - prompt extraction would fail
- **Mitigation:** Use flexible parsing, fallback to artifact download

**Risk 3: Missing artifacts in some runs**
- **Impact:** Low - expected behavior for healthy runs
- **Mitigation:** Handle gracefully, not a failure condition

---

## 10. Future Enhancements

**Enhancement 1: Automated CI Integration**
- Add verification step to bridge self-check workflow
- Fail workflow if Protocol v3.2 compliance fails

**Enhancement 2: Compliance Dashboard**
- Aggregate verification results over time
- Track compliance trends

**Enhancement 3: Alerting**
- Notify on Protocol v3.2 violations
- Integrate with existing alerting system

---

## 11. Implementation Checklist

- [ ] Create verification script skeleton
- [ ] Implement workflow run analyzer
- [ ] Implement MLS event verifier
- [ ] Implement artifact validator
- [ ] Create report generator
- [ ] Add unit tests
- [ ] Test with existing workflow runs
- [ ] Document usage
- [ ] Create example reports

---

## 12. References

- Protocol v3.2: `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`
- Bridge self-check workflow: `.github/workflows/bridge-selfcheck.yml`
- Integration test: `g/reports/integration_test_bridge_selfcheck.md`
- PR #365: Bridge self-check Protocol v3.2 alignment

---

**Next Steps:**
1. Review and approve this plan
2. Create TODO list from task breakdown
3. Begin implementation with Task 1
