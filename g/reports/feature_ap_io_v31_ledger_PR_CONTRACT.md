# PR Prompt Contract: AP/IO v3.1 Ledger System

**For:** Andy (Dev Agent)  
**Feature:** Application Protocol / Input-Output v3.1 Ledger  
**Priority:** High

---

# PR Title

feat: AP/IO v3.1 Ledger System - Protocol-Aware Event Logging

---

## Background

- **Problem:** Current Agent Ledger System (v1.0) lacks standardized protocol layer, unified I/O, and cross-agent event correlation
- **Desired Behavior:** Implement AP/IO v3.1 protocol with enhanced ledger schema, writer/reader stubs, routing integration, and full agent support

---

## Scope

### Allowed Files
- `schemas/ap_io_v31*.json` - Protocol schemas
- `tools/ap_io_v31/*.zsh` - Writer/reader/router stubs
- `agents/*/ap_io_v31_integration.zsh` - Agent integrations
- `tests/ap_io_v31/*.zsh` - Test cases
- `docs/AP_IO_V31_*.md` - Documentation

### Forbidden Files
- `/CLC/**`
- `/core/governance/**`
- `02luka.md` (Master Protocol)
- `memory_center/**`
- Existing `g/telemetry/*.jsonl` (keep as-is)

---

## Required Changes

### Phase 1: Protocol & Schema
- [ ] Create `schemas/ap_io_v31.schema.json` - Protocol schema
- [ ] Create `schemas/ap_io_v31_ledger.schema.json` - Ledger entry schema
- [ ] Create `docs/AP_IO_V31_PROTOCOL.md` - Protocol documentation
- [ ] Define versioning rules (v3.1, backward compat with v1.0)

### Phase 2: Writer/Reader Stubs
- [ ] Create `tools/ap_io_v31/writer.zsh` - Append-only writer with protocol support
- [ ] Create `tools/ap_io_v31/reader.zsh` - Reader supporting v3.1 and v1.0
- [ ] Create `tools/ap_io_v31/validator.zsh` - Protocol validation
- [ ] Create `tools/ap_io_v31/correlation_id.zsh` - Correlation ID generator

### Phase 3: Routing Integration
- [ ] Create `tools/ap_io_v31/router.zsh` - Routing logic (single/multiple/broadcast)
- [ ] Implement priority queuing (critical/high/normal/low)
- [ ] Create agent integration stubs:
  - `agents/cls/ap_io_v31_integration.zsh`
  - `agents/andy/ap_io_v31_integration.zsh`
  - `agents/hybrid/ap_io_v31_integration.zsh`
  - `agents/liam/ap_io_v31_integration.zsh`

### Phase 4: CLS Integration
- [ ] Integrate AP/IO v3.1 into CLS workflow
- [ ] Write events on task start/end
- [ ] Read events for correlation
- [ ] Update `agents/cls/status.json` with protocol field

### Phase 5: Andy Integration
- [ ] Create `tools/andy_ap_io_wrapper.zsh` - Codex CLI wrapper
- [ ] Hook into Codex execution
- [ ] Write events for dev tasks
- [ ] Read events for status

### Phase 6: Hybrid Integration
- [ ] Integrate into Hybrid/Luka CLI
- [ ] Write events for WO execution
- [ ] Read events for status updates

### Phase 7: Liam Integration
- [ ] Integrate with Liam decision blocks
- [ ] Write orchestration events
- [ ] Read for multi-agent coordination

### Phase 8: Testing
- [ ] Create `tests/ap_io_v31/test_protocol_validation.zsh`
- [ ] Create `tests/ap_io_v31/test_routing.zsh`
- [ ] Create `tests/ap_io_v31/test_correlation.zsh`
- [ ] Create `tests/ap_io_v31/test_backward_compat.zsh`
- [ ] Create `tests/ap_io_v31/cls_testcases.zsh` - CLS-specific tests

### Phase 9: Documentation
- [ ] Create `docs/AP_IO_V31_INTEGRATION_GUIDE.md`
- [ ] Create `docs/AP_IO_V31_ROUTING_GUIDE.md`
- [ ] Create `docs/AP_IO_V31_MIGRATION.md`

---

## Implementation Details

### Protocol Format
```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "cls",
  "timestamp": "2025-11-16T02:12:34+07:00",
  "correlation_id": "corr-20251116-001",
  "session_id": "2025-11-16_cls_001",
  "event": {
    "type": "task_result",
    "task_id": "wo-251116-agents-layout",
    "source": "gg_orchestrator",
    "summary": "Completed /agents layout SPEC + PLAN"
  },
  "data": {
    "status": "success",
    "duration_sec": 132,
    "files_touched": ["path1", "path2"],
    "metadata": {
      "complexity": "medium",
      "risk_level": "guarded",
      "impact_zone": "normal_code"
    }
  },
  "routing": {
    "targets": ["cls", "andy"],
    "broadcast": false,
    "priority": "normal",
    "delivered_to": []
  }
}
```

### Writer Stub Requirements
- Append-only (`>>`) to ledger files
- Protocol validation before write
- Correlation ID generation
- Error handling (graceful degradation)

### Reader Stub Requirements
- Parse AP/IO v3.1 format
- Support backward compatibility (v1.0)
- Extract event data
- Handle malformed entries gracefully

### Routing Requirements
- Support single agent: `targets: ["cls"]`
- Support multiple agents: `targets: ["cls", "andy"]`
- Support broadcast: `broadcast: true`
- Priority levels: critical → high → normal → low

---

## Tests

### Unit Tests
- [ ] Protocol validation (valid/invalid messages)
- [ ] Writer stub (append-only, protocol-aware)
- [ ] Reader stub (parse v3.1 and v1.0)
- [ ] Correlation ID generation (uniqueness, format)
- [ ] Validator (schema compliance)

### Integration Tests
- [ ] CLS integration (event flow)
- [ ] Andy integration (Codex CLI wrapper)
- [ ] Hybrid integration (Luka CLI hooks)
- [ ] Liam integration (orchestration events)
- [ ] Routing (single/multiple/broadcast)

### System Tests
- [ ] Cross-agent event correlation
- [ ] Backward compatibility (v1.0 support)
- [ ] Performance (overhead measurement)
- [ ] Reliability (error handling)

### Test Commands
```bash
# Protocol validation
tools/ap_io_v31/validator.zsh test_message.json

# Writer test
tools/ap_io_v31/writer.zsh cls task_start "wo-test" "gg_orchestrator"

# Reader test
tools/ap_io_v31/reader.zsh g/ledger/cls/2025-11-16.jsonl

# Routing test
tools/ap_io_v31/router.zsh test_event.json

# CLS testcases
tests/ap_io_v31/cls_testcases.zsh

# Full test suite
tests/ap_io_v31/test_protocol_validation.zsh
tests/ap_io_v31/test_routing.zsh
tests/ap_io_v31/test_correlation.zsh
tests/ap_io_v31/test_backward_compat.zsh
```

---

## Safety & Governance

- **Never touch:** /CLC, /core/governance/**, memory center, bridges, launchd
- **Follow:** Codex Sandbox Mode
- **Maintain:** Backward compatibility with Agent Ledger v1.0
- **Validate:** All protocol messages before write
- **Error handling:** Graceful degradation if ledger unavailable

---

## Acceptance Criteria

- [ ] All schemas created and validated
- [ ] Writer/Reader stubs working
- [ ] Routing integration complete
- [ ] All agent integrations working
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Backward compatibility maintained
- [ ] CLS verification passed

---

## References

- SPEC: `g/reports/feature_ap_io_v31_ledger_SPEC.md`
- PLAN: `g/reports/feature_ap_io_v31_ledger_PLAN.md`
- Agent Ledger v1.0: `g/reports/feature_agent_ledger_SPEC.md`

---

**Contract Owner:** Liam  
**Executor:** Andy  
**Reviewer:** CLS
