# Feature PLAN: Restore AP/IO v3.1 Protocol Files

**Feature:** Restore missing AP/IO v3.1 protocol implementation files  
**Date:** 2025-11-17  
**Status:** Draft  
**Estimated Time:** 8-12 hours (Priority 1: Critical)

---

## Implementation Roadmap

### Phase 1: Investigation & Git History Search (1-2 hours)
**Goal:** Find files in git history, identify last known good commit

### Phase 2: File Restoration (3-4 hours)
**Goal:** Restore files from git or recreate from SPEC/PLAN

### Phase 3: Verification & Testing (2-3 hours)
**Goal:** Verify all files work, run tests, fix issues

### Phase 4: Integration Check (1-2 hours)
**Goal:** Verify integration with existing system

### Phase 5: Documentation & Cleanup (1 hour)
**Goal:** Update documentation, verify completeness

---

## Phase 1: Investigation & Git History Search (1-2 hours)

### Task 1.1: Search Git History (30 min)

**Description:** Search git history for AP/IO v3.1 files

**Commands:**
```bash
# Search for AP/IO v3.1 files in git history
git log --all --full-history -- "*ap_io_v31*" "*AP_IO_V31*"
git log --all --full-history -- "tools/ap_io_v31/*"
git log --all --full-history -- "schemas/ap_io_v31*"
git log --all --full-history -- "tests/ap_io_v31/*"
git log --all --full-history -- "docs/AP_IO_V31*"
```

**Deliverables:**
- List of commits containing AP/IO v3.1 files
- Last known good commit hash
- List of files found in history

**Acceptance Criteria:**
- ✅ Identified commits with AP/IO v3.1 files
- ✅ Identified last known good commit
- ✅ List of files in history

---

### Task 1.2: Check SPEC/PLAN Documents (30 min)

**Description:** Verify SPEC/PLAN documents exist and are complete

**Files to Check:**
- `g/reports/feature_ap_io_v31_ledger_SPEC.md`
- `g/reports/feature_ap_io_v31_ledger_PLAN.md`
- `g/reports/feature_ap_io_v31_ledger_verification_enhancement_SPEC.md`
- `g/reports/feature_ap_io_v31_ledger_verification_enhancement_PLAN.md`
- `docs/AP_IO_V31_PROTOCOL.md` (if exists)

**Deliverables:**
- List of available SPEC/PLAN documents
- Assessment of completeness
- Identification of missing information

**Acceptance Criteria:**
- ✅ All SPEC/PLAN documents located
- ✅ Completeness assessed
- ✅ Missing information identified

---

### Task 1.3: Create Restoration Plan (30 min)

**Description:** Create detailed plan for restoration based on findings

**Deliverables:**
- Restoration strategy (git restore vs recreate)
- File-by-file restoration plan
- Priority order for restoration

**Acceptance Criteria:**
- ✅ Clear restoration strategy
- ✅ All 23 files accounted for
- ✅ Priority order defined

---

## Phase 2: File Restoration (3-4 hours)

### Task 2.1: Restore Core Protocol Tools (90 min)

**Description:** Restore 6 core protocol tools

**Files:**
1. `tools/ap_io_v31/writer.zsh`
2. `tools/ap_io_v31/reader.zsh`
3. `tools/ap_io_v31/validator.zsh`
4. `tools/ap_io_v31/correlation_id.zsh`
5. `tools/ap_io_v31/router.zsh`
6. `tools/ap_io_v31/pretty_print.zsh`

**Process:**
```bash
# For each file, try git restore first
git show <commit>:tools/ap_io_v31/writer.zsh > tools/ap_io_v31/writer.zsh

# If not in git, recreate from SPEC/PLAN
# Use SPEC/PLAN as source of truth
```

**Verification:**
- Syntax validation: `zsh -n tools/ap_io_v31/*.zsh`
- Make executable: `chmod +x tools/ap_io_v31/*.zsh`
- Test basic functionality

**Acceptance Criteria:**
- ✅ All 6 files restored/recreated
- ✅ All pass syntax validation
- ✅ All are executable
- ✅ Basic functionality works

---

### Task 2.2: Restore Schemas (30 min)

**Description:** Restore 2 schema files

**Files:**
1. `schemas/ap_io_v31.schema.json`
2. `schemas/ap_io_v31_ledger.schema.json`

**Process:**
```bash
# Restore from git or recreate from SPEC
git show <commit>:schemas/ap_io_v31.schema.json > schemas/ap_io_v31.schema.json
```

**Verification:**
- JSON validation: `jq . schemas/ap_io_v31*.json`
- Schema completeness check

**Acceptance Criteria:**
- ✅ Both schemas restored/recreated
- ✅ Valid JSON
- ✅ All required fields present

---

### Task 2.3: Restore Documentation (45 min)

**Description:** Restore 4 documentation files

**Files:**
1. `docs/AP_IO_V31_PROTOCOL.md`
2. `docs/AP_IO_V31_INTEGRATION_GUIDE.md`
3. `docs/AP_IO_V31_ROUTING_GUIDE.md`
4. `docs/AP_IO_V31_MIGRATION.md`

**Process:**
- Restore from git or recreate from SPEC/PLAN
- Ensure completeness
- Verify accuracy

**Acceptance Criteria:**
- ✅ All 4 docs restored/recreated
- ✅ Complete and accurate
- ✅ Formatting correct

---

### Task 2.4: Restore Agent Integrations (60 min)

**Description:** Restore 5 agent integration files

**Files:**
1. `agents/cls/ap_io_v31_integration.zsh`
2. `agents/andy/ap_io_v31_integration.zsh`
3. `agents/hybrid/ap_io_v31_integration.zsh`
4. `agents/liam/ap_io_v31_integration.zsh`
5. `agents/gg/ap_io_v31_integration.zsh`

**Process:**
- Restore from git or recreate from integration guide
- Verify agent-specific logic
- Test integration points

**Acceptance Criteria:**
- ✅ All 5 integration files restored/recreated
- ✅ Agent-specific logic correct
- ✅ Integration points verified

---

### Task 2.5: Restore Tests (45 min)

**Description:** Restore 6 test files

**Files:**
1. `tests/ap_io_v31/cls_testcases.zsh`
2. `tests/ap_io_v31/test_protocol_validation.zsh`
3. `tests/ap_io_v31/test_routing.zsh`
4. `tests/ap_io_v31/test_correlation.zsh`
5. `tests/ap_io_v31/test_backward_compat.zsh`
6. `tools/run_ap_io_v31_tests.zsh`

**Process:**
- Restore from git or recreate from test requirements
- Ensure test isolation
- Verify test coverage

**Acceptance Criteria:**
- ✅ All 6 test files restored/recreated
- ✅ Test isolation implemented
- ✅ Test coverage complete

---

## Phase 3: Verification & Testing (2-3 hours)

### Task 3.1: Syntax Validation (15 min)

**Description:** Validate all scripts

**Commands:**
```bash
# Validate all zsh scripts
for f in tools/ap_io_v31/*.zsh tests/ap_io_v31/*.zsh agents/*/ap_io_v31_integration.zsh; do
  zsh -n "$f" || echo "ERROR: $f"
done

# Validate JSON schemas
jq . schemas/ap_io_v31*.json
```

**Acceptance Criteria:**
- ✅ All scripts pass syntax validation
- ✅ All schemas are valid JSON

---

### Task 3.2: Run Test Suite (60 min)

**Description:** Run all AP/IO v3.1 tests

**Commands:**
```bash
# Run test suite
tools/run_ap_io_v31_tests.zsh

# Run individual tests
tests/ap_io_v31/cls_testcases.zsh
tests/ap_io_v31/test_protocol_validation.zsh
# ... etc
```

**Acceptance Criteria:**
- ✅ All tests pass
- ✅ Test isolation works (no production data pollution)
- ✅ Test coverage adequate

---

### Task 3.3: Fix Issues (60-90 min)

**Description:** Fix any issues found during testing

**Common Issues:**
- Path calculation errors
- Missing dependencies
- Test isolation problems
- Backward compatibility issues

**Acceptance Criteria:**
- ✅ All issues fixed
- ✅ All tests pass
- ✅ No regressions

---

## Phase 4: Integration Check (1-2 hours)

### Task 4.1: Verify Agent Integration (45 min)

**Description:** Verify integration with existing agents

**Checks:**
- Integration scripts work
- Ledger entries written correctly
- Correlation IDs work
- Parent IDs work

**Acceptance Criteria:**
- ✅ All agent integrations work
- ✅ Ledger entries correct
- ✅ No conflicts with existing code

---

### Task 4.2: Verify Backward Compatibility (30 min)

**Description:** Verify v1.0 ledger format still works

**Tests:**
- Read v1.0 ledger entries
- Write v1.0 compatible entries
- Mixed format support

**Acceptance Criteria:**
- ✅ v1.0 entries still readable
- ✅ v1.0 format still writable
- ✅ Mixed formats supported

---

## Phase 5: Documentation & Cleanup (1 hour)

### Task 5.1: Update Documentation (30 min)

**Description:** Update documentation with restoration status

**Files:**
- Update restoration report
- Update any missing documentation
- Verify all docs are complete

**Acceptance Criteria:**
- ✅ Documentation updated
- ✅ All docs complete
- ✅ Restoration documented

---

### Task 5.2: Final Verification (30 min)

**Description:** Final check of all restored files

**Checks:**
- All 23 files exist
- All files in correct locations
- All files functional
- All tests pass
- Integration works

**Acceptance Criteria:**
- ✅ All files verified
- ✅ System functional
- ✅ Ready for merge

---

## Test Strategy

### Unit Tests
- Test each tool individually
- Mock dependencies
- Test error cases

### Integration Tests
- Test tool interactions
- Test agent integrations
- Test end-to-end flows

### Backward Compatibility Tests
- Test v1.0 format support
- Test mixed format support
- Test migration scenarios

### Test Isolation
- Use `LEDGER_BASE_DIR` for test isolation
- Use `mktemp -d` for temporary directories
- Clean up after tests

---

## Rollback Plan

### If Restoration Fails
1. Document what was restored
2. Document what failed
3. Create follow-up work order
4. Proceed with partial restoration

### If Tests Fail
1. Fix critical issues
2. Document non-critical issues
3. Create follow-up tasks
4. Proceed with known issues

---

## Success Metrics

### Restoration
- ✅ All 23 files restored/recreated
- ✅ All files pass syntax validation
- ✅ All files functional

### Testing
- ✅ All tests pass
- ✅ Test isolation works
- ✅ Backward compatibility maintained

### Integration
- ✅ Agent integrations work
- ✅ No conflicts with existing code
- ✅ System functional

---

## Estimated Effort

- **Phase 1:** 1-2 hours
- **Phase 2:** 3-4 hours
- **Phase 3:** 2-3 hours
- **Phase 4:** 1-2 hours
- **Phase 5:** 1 hour
- **Total:** 8-12 hours

---

## Dependencies

### Required
- Git history access
- SPEC/PLAN documents
- Existing 02LUKA infrastructure

### Tools
- `git` - For history search
- `jq` - For JSON processing
- `zsh` - For scripts

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Files not in git | High | Recreate from SPEC/PLAN |
| Incomplete SPEC | Medium | Use existing docs as reference |
| Breaking changes | High | Test backward compatibility |
| Time overrun | Medium | Prioritize critical files first |

---

**Status:** Ready for implementation  
**Next Step:** Begin Phase 1 - Investigation & Git History Search
