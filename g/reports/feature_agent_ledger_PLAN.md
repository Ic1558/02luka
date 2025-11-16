# Feature PLAN: Agent Ledger System

**Date:** 2025-11-16  
**Feature:** Multi-Agent Ledger System (Append-Only Event Logging)

---

## Phase 1: Directory Structure & Base Utilities

### Tasks
1. Create directory structure:
   - `g/ledger/cls/`
   - `g/ledger/andy/`
   - `g/ledger/hybrid/`
   - `agents/cls/`
   - `agents/andy/`
   - `agents/hybrid/`
   - `memory/cls/sessions/`
   - `memory/andy/sessions/`
   - `memory/hybrid/sessions/`

2. Create helper utilities:
   - `tools/ledger_write.zsh` - Safe append-only ledger writer
   - `tools/status_update.zsh` - Safe status.json updater
   - `tools/ledger_schema_validate.zsh` - Schema validator

### Files to Create
- `tools/ledger_write.zsh` - Append-only JSONL writer with error handling
- `tools/status_update.zsh` - Safe write (temp → mv) for status.json
- `tools/ledger_schema_validate.zsh` - Validate ledger line schema

### Implementation Notes
- Use `mkdir -p` for directory creation
- Ledger writer: `echo "$json_line" >> "$ledger_file"` with error check
- Status updater: Write to `.tmp`, then `mv .tmp status.json`

---

## Phase 2: CLS Integration (Primary Target)

### Tasks
1. Integrate ledger writes into CLS workflow:
   - On task start: Write `task_start` event
   - On task completion: Write `task_result` event
   - On error: Write `error` event
   - Periodic: Write `heartbeat` event

2. Update status.json:
   - On state change (idle → busy → idle)
   - On task completion
   - On error

3. Create session summary helper:
   - Optional markdown generator
   - Called at session end

### Files to Modify
- CLS agent code (add ledger hooks)
- CLS status updater

### Files to Create
- `tools/cls_ledger_hook.zsh` - CLS-specific ledger integration
- `tools/cls_session_summary.zsh` - Generate session markdown

### Implementation Notes
- Hook into existing CLS execution flow
- Minimal performance impact
- Graceful degradation if ledger unavailable

---

## Phase 3: Andy (Dev Agent) Integration

### Tasks
1. Create Codex CLI wrapper/hook:
   - Detect task start (Codex execution begins)
   - Detect task completion (Codex execution ends)
   - Extract task metadata (files touched, duration, etc.)

2. Integrate ledger writes:
   - Write `task_start` when Codex begins
   - Write `task_result` when Codex completes
   - Update `agents/andy/status.json`

3. Implementation options:
   - Python wrapper around Codex CLI
   - Shell script wrapper
   - Cursor extension hook

### Files to Create
- `tools/andy_ledger_hook.zsh` or `tools/andy_ledger_wrapper.py`
- Integration with Codex CLI execution

### Implementation Notes
- Andy = Codex worker (primary dev agent)
- Hook must capture: task_id, files_touched, duration, status
- Can use existing Codex execution logs as source

---

## Phase 4: Hybrid / Luka CLI Integration

### Tasks
1. Integrate ledger writes into Hybrid execution:
   - On WO received: Write `task_start`
   - On WO completion: Write `task_result` with exit code
   - Update `agents/hybrid/status.json`

2. Sanitize command logging:
   - Remove sensitive data (passwords, tokens)
   - Truncate long outputs
   - Summary only (not full stdout/stderr)

### Files to Modify
- Hybrid/Luka CLI execution scripts
- WO execution handlers

### Files to Create
- `tools/hybrid_ledger_hook.zsh` - Hybrid-specific ledger integration

---

## Phase 5: Validation & Testing

### Tasks
1. Schema validation:
   - Test ledger line JSON schema
   - Test status.json schema
   - Validate ISO-8601 timestamps

2. Safety checks:
   - Verify append-only (no overwrite)
   - Verify safe write pattern (temp → mv)
   - Test directory auto-creation

3. Integration tests:
   - CLS writes ledger entry
   - Andy writes ledger entry
   - Hybrid writes ledger entry
   - Status updates work correctly

### Test Commands
```bash
# Test ledger writer
tools/ledger_write.zsh cls task_start "wo-test" "gg_orchestrator" "Test task"

# Test status updater
tools/status_update.zsh cls idle "2025-11-16T10:00:00+07:00"

# Validate schema
tools/ledger_schema_validate.zsh g/ledger/cls/2025-11-16.jsonl

# Test directory creation
mkdir -p g/ledger/test
# Verify exists
```

### Test Cases
1. ✅ Ledger append-only (try overwrite, should fail gracefully)
2. ✅ Status safe write (temp → mv pattern)
3. ✅ Directory auto-creation
4. ✅ Schema validation
5. ✅ Multiple agents writing simultaneously
6. ✅ Error handling (ledger unavailable)

---

## Phase 6: Documentation

### Tasks
1. Document ledger schema
2. Document status schema
3. Document session summary format
4. Document agent integration patterns
5. Document telemetry → ledger relationship

### Files to Create
- `docs/AGENT_LEDGER_GUIDE.md` - User guide
- `docs/AGENT_LEDGER_SCHEMA.md` - Schema reference

---

## Phase 7: CLS Verification

### Tasks
1. CLS reviews implementation:
   - Schema compliance
   - Path correctness (no governance violations)
   - Safety patterns (append-only, safe write)
   - Integration completeness

2. Fix any issues found

---

## TODO List

### Phase 1: Infrastructure
- [ ] Create `g/ledger/` directory structure
- [ ] Create `agents/` directory structure
- [ ] Create `memory/<agent>/sessions/` directories
- [ ] Implement `tools/ledger_write.zsh`
- [ ] Implement `tools/status_update.zsh`
- [ ] Implement `tools/ledger_schema_validate.zsh`

### Phase 2: CLS Integration
- [ ] Add ledger hooks to CLS execution flow
- [ ] Implement `task_start` event writing
- [ ] Implement `task_result` event writing
- [ ] Implement `error` event writing
- [ ] Implement `heartbeat` event writing
- [ ] Implement status.json updates
- [ ] Create `tools/cls_ledger_hook.zsh`
- [ ] Create `tools/cls_session_summary.zsh` (optional)

### Phase 3: Andy Integration
- [ ] Create Codex CLI wrapper/hook
- [ ] Detect task start/completion
- [ ] Extract task metadata
- [ ] Implement ledger writes for Andy
- [ ] Implement status.json updates for Andy
- [ ] Create `tools/andy_ledger_hook.zsh` or Python wrapper

### Phase 4: Hybrid Integration
- [ ] Add ledger hooks to Hybrid execution
- [ ] Implement WO execution logging
- [ ] Sanitize command outputs
- [ ] Implement status.json updates for Hybrid
- [ ] Create `tools/hybrid_ledger_hook.zsh`

### Phase 5: Testing
- [ ] Test ledger append-only behavior
- [ ] Test status safe write pattern
- [ ] Test directory auto-creation
- [ ] Test schema validation
- [ ] Test multi-agent concurrent writes
- [ ] Test error handling

### Phase 6: Documentation
- [ ] Create `docs/AGENT_LEDGER_GUIDE.md`
- [ ] Create `docs/AGENT_LEDGER_SCHEMA.md`
- [ ] Document integration patterns

### Phase 7: Verification
- [ ] CLS reviews implementation
- [ ] Fix any issues
- [ ] Final validation

---

## Test Strategy

### Unit Tests
- Ledger writer: Test append-only, error handling
- Status updater: Test safe write pattern
- Schema validator: Test JSON schema compliance

### Integration Tests
- CLS writes ledger entry → verify in file
- Andy writes ledger entry → verify in file
- Hybrid writes ledger entry → verify in file
- Status updates → verify JSON valid

### Safety Tests
- Attempt overwrite ledger → should fail gracefully
- Missing directory → should auto-create
- Invalid JSON → should validate and reject
- Concurrent writes → should not corrupt file

### Performance Tests
- Measure overhead of ledger writes
- Measure overhead of status updates
- Verify minimal impact on agent operations

---

## Implementation Priority

1. **Phase 1** (Infrastructure) - Foundation, must complete first
2. **Phase 2** (CLS) - Primary target, highest priority
3. **Phase 3** (Andy) - Important for dev workflow
4. **Phase 4** (Hybrid) - Complete coverage
5. **Phase 5** (Testing) - Validate all phases
6. **Phase 6** (Documentation) - User guidance
7. **Phase 7** (Verification) - Quality gate

---

## Risk Mitigation

1. **Ledger Corruption**
   - Use append-only pattern
   - Validate JSON before write
   - Test concurrent writes

2. **Performance Impact**
   - Async writes where possible
   - Minimal overhead design
   - Graceful degradation

3. **Directory Missing**
   - Auto-create with `mkdir -p`
   - Check before write

4. **Schema Drift**
   - Validation tool
   - CLS review process

---

**Plan Owner:** GG-Orchestrator  
**Implementer:** Andy (primary) + CLC (governance)  
**Verifier:** CLS
