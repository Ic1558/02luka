# Feature PLAN: AP/IO v3.1 Ledger System

**Date:** 2025-11-16  
**Feature:** Application Protocol / Input-Output v3.1 Ledger

---

## Phase 1: Protocol Definition & Schema

### Tasks
1. Define AP/IO v3.1 protocol specification
2. Create protocol schema (JSON Schema)
3. Create ledger entry schema
4. Define versioning rules
5. Document backward compatibility

### Files to Create
- `schemas/ap_io_v31.schema.json` - Protocol schema
- `schemas/ap_io_v31_ledger.schema.json` - Ledger entry schema
- `docs/AP_IO_V31_PROTOCOL.md` - Protocol documentation

### Implementation Notes
- Use JSON Schema for validation
- Support version negotiation
- Maintain backward compatibility with v1.0

---

## Phase 2: Writer/Reader Stubs

### Tasks
1. Create writer stub (`tools/ap_io_v31/writer.zsh`)
2. Create reader stub (`tools/ap_io_v31/reader.zsh`)
3. Create validator (`tools/ap_io_v31/validator.zsh`)
4. Implement protocol validation
5. Implement correlation ID generation

### Files to Create
- `tools/ap_io_v31/writer.zsh` - Writer stub
- `tools/ap_io_v31/reader.zsh` - Reader stub
- `tools/ap_io_v31/validator.zsh` - Protocol validator
- `tools/ap_io_v31/correlation_id.zsh` - Correlation ID generator

### Implementation Notes
- Writer: Append-only, protocol-aware
- Reader: Parse v3.1 and v1.0 formats
- Validator: Check protocol compliance
- Correlation ID: Unique per event chain

---

## Phase 3: Routing Integration

### Tasks
1. Create routing logic (`tools/ap_io_v31/router.zsh`)
2. Implement target selection
3. Implement priority queuing
4. Implement broadcast mode
5. Create agent-specific integration stubs

### Files to Create
- `tools/ap_io_v31/router.zsh` - Routing logic
- `agents/cls/ap_io_v31_integration.zsh` - CLS integration
- `agents/andy/ap_io_v31_integration.zsh` - Andy integration
- `agents/hybrid/ap_io_v31_integration.zsh` - Hybrid integration
- `agents/liam/ap_io_v31_integration.zsh` - Liam integration

### Implementation Notes
- Routing: Support single/multiple/broadcast targets
- Priority: Critical → High → Normal → Low
- Integration: Agent-specific hooks

---

## Phase 4: CLS Integration (Primary)

### Tasks
1. Integrate AP/IO v3.1 into CLS workflow
2. Write events on task start/end
3. Read events for correlation
4. Update status.json with protocol info
5. Test CLS event flow

### Files to Modify
- CLS agent code (add AP/IO v3.1 hooks)
- `agents/cls/status.json` (add protocol field)

### Files to Create
- `agents/cls/ap_io_v31_integration.zsh` - CLS integration

### Implementation Notes
- Hook into existing CLS execution
- Minimal performance impact
- Graceful degradation

---

## Phase 5: Andy Integration

### Tasks
1. Create Codex CLI wrapper for AP/IO v3.1
2. Hook into Codex execution
3. Write events for dev tasks
4. Read events for status
5. Test Andy event flow

### Files to Create
- `agents/andy/ap_io_v31_integration.zsh` - Andy integration
- `tools/andy_ap_io_wrapper.zsh` - Codex CLI wrapper

### Implementation Notes
- Wrap Codex CLI execution
- Capture task metadata
- Write AP/IO v3.1 events

---

## Phase 6: Hybrid Integration

### Tasks
1. Integrate AP/IO v3.1 into Hybrid/Luka CLI
2. Write events for WO execution
3. Read events for status updates
4. Test Hybrid event flow

### Files to Create
- `agents/hybrid/ap_io_v31_integration.zsh` - Hybrid integration

### Implementation Notes
- Hook into Luka CLI execution
- Log WO execution events
- Sanitize command outputs

---

## Phase 7: Liam Integration

### Tasks
1. Integrate AP/IO v3.1 into Liam orchestrator
2. Write events for orchestration decisions
3. Read events for multi-agent coordination
4. Test Liam event flow

### Files to Create
- `agents/liam/ap_io_v31_integration.zsh` - Liam integration

### Implementation Notes
- Integrate with Liam decision blocks
- Write orchestration events
- Read for coordination

---

## Phase 8: Testing & Validation

### Tasks
1. Create CLS testcases
2. Create integration tests
3. Test protocol validation
4. Test routing
5. Test backward compatibility
6. Test cross-agent correlation

### Files to Create
- `tests/ap_io_v31/test_protocol_validation.zsh`
- `tests/ap_io_v31/test_routing.zsh`
- `tests/ap_io_v31/test_correlation.zsh`
- `tests/ap_io_v31/test_backward_compat.zsh`
- `tests/ap_io_v31/cls_testcases.zsh` - CLS-specific tests

### Test Cases
- [ ] Protocol validation (valid/invalid messages)
- [ ] Writer stub (append-only, protocol-aware)
- [ ] Reader stub (parse v3.1 and v1.0)
- [ ] Routing (single/multiple/broadcast)
- [ ] Priority queuing
- [ ] Correlation ID generation
- [ ] Cross-agent event correlation
- [ ] Backward compatibility (v1.0 support)
- [ ] CLS integration
- [ ] Andy integration
- [ ] Hybrid integration
- [ ] Liam integration

---

## Phase 9: Documentation

### Tasks
1. Document AP/IO v3.1 protocol
2. Document integration patterns
3. Document routing rules
4. Document migration guide
5. Create usage examples

### Files to Create
- `docs/AP_IO_V31_PROTOCOL.md` - Protocol documentation
- `docs/AP_IO_V31_INTEGRATION_GUIDE.md` - Integration guide
- `docs/AP_IO_V31_ROUTING_GUIDE.md` - Routing guide
- `docs/AP_IO_V31_MIGRATION.md` - Migration guide

---

## Phase 10: CLS Verification

### Tasks
1. CLS reviews implementation
2. CLS validates protocol compliance
3. CLS checks routing logic
4. CLS verifies testcases
5. Fix any issues

---

## TODO List

### Phase 1: Protocol & Schema
- [ ] Create `schemas/ap_io_v31.schema.json`
- [ ] Create `schemas/ap_io_v31_ledger.schema.json`
- [ ] Create `docs/AP_IO_V31_PROTOCOL.md`
- [ ] Define versioning rules
- [ ] Document backward compatibility

### Phase 2: Writer/Reader Stubs
- [ ] Create `tools/ap_io_v31/writer.zsh`
- [ ] Create `tools/ap_io_v31/reader.zsh`
- [ ] Create `tools/ap_io_v31/validator.zsh`
- [ ] Create `tools/ap_io_v31/correlation_id.zsh`
- [ ] Implement protocol validation
- [ ] Implement correlation ID generation

### Phase 3: Routing
- [ ] Create `tools/ap_io_v31/router.zsh`
- [ ] Implement target selection
- [ ] Implement priority queuing
- [ ] Implement broadcast mode
- [ ] Create agent integration stubs

### Phase 4: CLS Integration
- [ ] Create `agents/cls/ap_io_v31_integration.zsh`
- [ ] Integrate into CLS workflow
- [ ] Write events on task start/end
- [ ] Read events for correlation
- [ ] Update status.json

### Phase 5: Andy Integration
- [ ] Create `agents/andy/ap_io_v31_integration.zsh`
- [ ] Create `tools/andy_ap_io_wrapper.zsh`
- [ ] Hook into Codex CLI
- [ ] Write events for dev tasks

### Phase 6: Hybrid Integration
- [ ] Create `agents/hybrid/ap_io_v31_integration.zsh`
- [ ] Hook into Luka CLI
- [ ] Write events for WO execution

### Phase 7: Liam Integration
- [ ] Create `agents/liam/ap_io_v31_integration.zsh`
- [ ] Integrate with Liam decision blocks
- [ ] Write orchestration events

### Phase 8: Testing
- [ ] Create `tests/ap_io_v31/test_protocol_validation.zsh`
- [ ] Create `tests/ap_io_v31/test_routing.zsh`
- [ ] Create `tests/ap_io_v31/test_correlation.zsh`
- [ ] Create `tests/ap_io_v31/test_backward_compat.zsh`
- [ ] Create `tests/ap_io_v31/cls_testcases.zsh`
- [ ] Run all tests
- [ ] Fix issues

### Phase 9: Documentation
- [ ] Create `docs/AP_IO_V31_INTEGRATION_GUIDE.md`
- [ ] Create `docs/AP_IO_V31_ROUTING_GUIDE.md`
- [ ] Create `docs/AP_IO_V31_MIGRATION.md`
- [ ] Create usage examples

### Phase 10: Verification
- [ ] CLS reviews
- [ ] Fix issues
- [ ] Final validation

---

## Test Strategy

### Unit Tests
- Protocol validation: Test valid/invalid messages
- Writer stub: Test append-only, protocol-aware writes
- Reader stub: Test parsing v3.1 and v1.0
- Validator: Test schema compliance
- Correlation ID: Test uniqueness and format

### Integration Tests
- CLS integration: Test event flow
- Andy integration: Test Codex CLI wrapper
- Hybrid integration: Test Luka CLI hooks
- Liam integration: Test orchestration events
- Routing: Test single/multiple/broadcast

### System Tests
- Cross-agent correlation: Test event correlation
- Backward compatibility: Test v1.0 support
- Performance: Test overhead
- Reliability: Test error handling

---

## Implementation Priority

1. **Phase 1** (Protocol) - Foundation
2. **Phase 2** (Stubs) - Core functionality
3. **Phase 3** (Routing) - Integration layer
4. **Phase 4** (CLS) - Primary target
5. **Phase 5** (Andy) - Dev workflow
6. **Phase 6** (Hybrid) - CLI execution
7. **Phase 7** (Liam) - Orchestration
8. **Phase 8** (Testing) - Validation
9. **Phase 9** (Documentation) - User guidance
10. **Phase 10** (Verification) - Quality gate

---

**Plan Owner:** Liam  
**Implementer:** Andy (primary) + CLS (validation)  
**Verifier:** CLS
