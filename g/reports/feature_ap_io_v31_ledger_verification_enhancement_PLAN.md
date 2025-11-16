# Feature PLAN: AP/IO v3.1 Ledger - Verification & Enhancement

**Date:** 2025-11-16  
**Feature:** AP/IO v3.1 Ledger Verification, Ledger Extension Fields, Test Validation, Real Integration

---

## Phase 1: Ledger Extension Fields

### Tasks
1. Update `schemas/ap_io_v31_ledger.schema.json`:
   - Add `ledger_id` field
   - Add `parent_id` field
   - Add `execution_duration_ms` to data object

2. Update `tools/ap_io_v31/writer.zsh`:
   - Generate `ledger_id` automatically
   - Accept `parent_id` parameter
   - Capture `execution_duration_ms` if provided

3. Update `tools/ap_io_v31/reader.zsh`:
   - Parse `ledger_id`, `parent_id`, `execution_duration_ms`
   - Support filtering by parent_id

4. Update `docs/AP_IO_V31_PROTOCOL.md`:
   - Add "Ledger Extension Fields" section
   - Document ledger_id, parent_id, execution_duration_ms
   - Provide examples
   - Link to schema

### Files to Modify
- `schemas/ap_io_v31_ledger.schema.json`
- `tools/ap_io_v31/writer.zsh`
- `tools/ap_io_v31/reader.zsh`
- `docs/AP_IO_V31_PROTOCOL.md`

### Implementation Notes
- ledger_id format: `ledger-YYYYMMDD-HHMMSS-<agent>-<seq>`
- parent_id format: `parent-<type>-<id>` (wo, event, session)
- execution_duration_ms: optional, more precise than duration_sec

---

## Phase 2: Test Validation

### Tasks
1. Run all test suites:
   ```bash
   tests/ap_io_v31/cls_testcases.zsh
   tests/ap_io_v31/test_protocol_validation.zsh
   tests/ap_io_v31/test_routing.zsh
   tests/ap_io_v31/test_correlation.zsh
   tests/ap_io_v31/test_backward_compat.zsh
   ```

2. Document test results:
   - Create `g/reports/ap_io_v31_test_results.md`
   - Record pass/fail for each test
   - Note any issues

3. Fix failing tests:
   - Identify root cause
   - Fix implementation
   - Re-run tests
   - Verify all pass

4. Verify ledger writes:
   - Check ledger files created
   - Verify schema compliance
   - Check file permissions

### Files to Create
- `g/reports/ap_io_v31_test_results.md` - Test results documentation

### Test Commands
```bash
# Run all tests
for test in tests/ap_io_v31/*.zsh; do
  echo "Running $test..."
  "$test" || echo "FAILED: $test"
done

# Verify ledger files
ls -la g/ledger/*/$(date +%Y-%m-%d).jsonl

# Validate schema
tools/ap_io_v31/validator.zsh test_entry.json
```

---

## Phase 3: Real Integration - Hybrid WO Execution

### Tasks
1. Identify WO execution entry points:
   - Find WO execution scripts
   - Identify where WO starts/ends
   - Determine WO ID format

2. Add AP/IO v3.1 hooks:
   - Write `task_start` when WO begins
   - Capture start timestamp
   - Write `task_result` when WO completes
   - Calculate `execution_duration_ms`
   - Set `parent_id` to WO ID

3. Test integration:
   - Run test WO
   - Verify events written to ledger
   - Check correlation_id if multi-agent
   - Verify parent_id links

### Files to Modify
- WO execution scripts (identify and modify)
- `agents/hybrid/ap_io_v31_integration.zsh` (if needed)

### Implementation Notes
- Use `parent_id: "parent-wo-<wo_id>"`
- Capture timestamps precisely for execution_duration_ms
- Link related events via correlation_id

---

## Phase 4: Real Integration - Andy Codex CLI

### Tasks
1. Create Codex CLI wrapper:
   - Wrap Codex CLI execution
   - Capture start/end timestamps
   - Calculate execution_duration_ms

2. Add AP/IO v3.1 hooks:
   - Write `task_start` before Codex execution
   - Write `task_result` after Codex execution
   - Include files_touched from Codex output
   - Set `parent_id` to task ID

3. Test integration:
   - Run test Codex task
   - Verify events written to ledger
   - Check execution_duration_ms accuracy
   - Verify parent_id links

### Files to Create
- `tools/andy_codex_wrapper.zsh` - Codex CLI wrapper with AP/IO v3.1

### Files to Modify
- `agents/andy/ap_io_v31_integration.zsh` (if needed)

---

## Phase 5: Real Integration - Liam Orchestration

### Tasks
1. Add orchestration event logging:
   - Log orchestration decisions (gg_decision blocks)
   - Create correlation_id for multi-agent tasks
   - Write routing events
   - Track agent coordination

2. Test integration:
   - Run test orchestration
   - Verify events written to ledger
   - Check correlation_id propagation
   - Verify routing events

### Files to Modify
- Liam orchestration code (add event logging)
- `agents/liam/ap_io_v31_integration.zsh` (if needed)

---

## Phase 6: Ledger Viewer Tool

### Tasks
1. Create `tools/ap_io_v31/pretty_print.zsh`:
   - Parse JSONL files
   - Pretty print entries
   - Support filtering (agent, event type, date)
   - Support grouping (correlation_id, parent_id)

2. Add timeline visualization:
   - Group by correlation_id
   - Show timeline per agent
   - Display execution duration
   - Show parent-child relationships

3. Add summary statistics:
   - Total events per agent
   - Average execution duration
   - Success/failure counts
   - Correlation chains

### Files to Create
- `tools/ap_io_v31/pretty_print.zsh` - Ledger viewer tool

### Usage Examples
```bash
# Pretty print all entries
tools/ap_io_v31/pretty_print.zsh g/ledger/cls/2025-11-16.jsonl

# Group by correlation
tools/ap_io_v31/pretty_print.zsh g/ledger/cls/2025-11-16.jsonl --group-by correlation

# Filter by agent and event type
tools/ap_io_v31/pretty_print.zsh g/ledger/cls/2025-11-16.jsonl --filter agent=cls --filter event=task_result

# Show timeline
tools/ap_io_v31/pretty_print.zsh g/ledger/cls/2025-11-16.jsonl --timeline
```

---

## Phase 7: End-to-End Verification

### Tasks
1. Test complete flow:
   - Liam creates orchestration event
   - Routes to CLS and Andy
   - Both process and write results
   - Query correlation
   - View with pretty_print

2. Verify data integrity:
   - Check ledger_id uniqueness
   - Verify parent_id links
   - Validate execution_duration_ms
   - Check correlation_id propagation

3. Performance check:
   - Measure overhead
   - Check file sizes
   - Verify append-only behavior

---

## TODO List

### Phase 1: Ledger Extension
- [ ] Update `schemas/ap_io_v31_ledger.schema.json` (add ledger_id, parent_id, execution_duration_ms)
- [ ] Update `tools/ap_io_v31/writer.zsh` (generate ledger_id, accept parent_id, capture execution_duration_ms)
- [ ] Update `tools/ap_io_v31/reader.zsh` (parse new fields, filter by parent_id)
- [ ] Update `docs/AP_IO_V31_PROTOCOL.md` (add Ledger Extension section)

### Phase 2: Test Validation
- [ ] Run `tests/ap_io_v31/cls_testcases.zsh`
- [ ] Run `tests/ap_io_v31/test_protocol_validation.zsh`
- [ ] Run `tests/ap_io_v31/test_routing.zsh`
- [ ] Run `tests/ap_io_v31/test_correlation.zsh`
- [ ] Run `tests/ap_io_v31/test_backward_compat.zsh`
- [ ] Document test results
- [ ] Fix any failing tests
- [ ] Verify all tests pass

### Phase 3: Hybrid Integration
- [ ] Identify WO execution entry points
- [ ] Add AP/IO v3.1 hooks to WO execution
- [ ] Test WO execution logging
- [ ] Verify events written correctly

### Phase 4: Andy Integration
- [ ] Create Codex CLI wrapper
- [ ] Add AP/IO v3.1 hooks
- [ ] Test Codex CLI logging
- [ ] Verify events written correctly

### Phase 5: Liam Integration
- [ ] Add orchestration event logging
- [ ] Test orchestration logging
- [ ] Verify correlation_id propagation

### Phase 6: Ledger Viewer
- [ ] Create `tools/ap_io_v31/pretty_print.zsh`
- [ ] Implement pretty printing
- [ ] Add filtering support
- [ ] Add grouping support
- [ ] Add timeline visualization
- [ ] Add summary statistics

### Phase 7: End-to-End
- [ ] Test complete flow
- [ ] Verify data integrity
- [ ] Performance check
- [ ] Final validation

---

## Test Strategy

### Unit Tests
- Ledger Extension: Test ledger_id generation, parent_id linking, execution_duration_ms calculation
- Writer: Test new fields in output
- Reader: Test parsing new fields

### Integration Tests
- Hybrid WO: Test WO execution logging
- Andy Codex: Test Codex CLI logging
- Liam: Test orchestration logging
- End-to-end: Test complete multi-agent flow

### Validation Tests
- Schema: Verify new fields in schema
- Documentation: Verify docs match schema
- Viewer: Test pretty_print functionality

---

## Implementation Priority

1. **Phase 1** (Ledger Extension) - Foundation, must complete first
2. **Phase 2** (Test Validation) - Verify existing implementation
3. **Phase 3-5** (Real Integration) - Make system useful
4. **Phase 6** (Ledger Viewer) - Enable analysis
5. **Phase 7** (End-to-End) - Final validation

---

## Risk Mitigation

1. **Schema Changes**
   - Maintain backward compatibility
   - New fields are optional
   - Support both old and new formats

2. **Test Failures**
   - Fix incrementally
   - Document issues
   - Re-run after fixes

3. **Integration Complexity**
   - Start with simple cases
   - Test incrementally
   - Verify each integration separately

---

**Plan Owner:** Liam  
**Implementer:** Andy (primary) + CLS (validation)  
**Verifier:** CLS
