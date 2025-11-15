# AP/IO v3.1 Ledger - Full Pipeline Proposal

**Date:** 2025-11-16  
**Proposed By:** Liam  
**Status:** Ready for Implementation

---

## Executive Summary

Complete implementation pipeline for AP/IO v3.1 Ledger System, including:
- ✅ SPEC + PLAN documents
- ✅ PR Prompt Contract for Andy
- ✅ CLS testcases
- ✅ Schema files (JSON Schema)
- ✅ Writer/Reader stubs
- ✅ Routing integration specification

**Total Deliverables:** 15+ files across 4 phases

---

## Pipeline Overview

### Phase 1: Foundation (Week 1)
- Protocol definition
- Schema creation
- Writer/Reader stubs
- Validator implementation

### Phase 2: Integration (Week 2)
- CLS integration (primary)
- Andy integration
- Hybrid integration
- Liam integration

### Phase 3: Routing (Week 2-3)
- Router implementation
- Agent integration handlers
- Correlation flow
- Error handling

### Phase 4: Testing & Validation (Week 3)
- CLS testcases
- Integration tests
- System tests
- CLS verification

---

## Deliverables Checklist

### Documentation
- [x] SPEC: `g/reports/feature_ap_io_v31_ledger_SPEC.md`
- [x] PLAN: `g/reports/feature_ap_io_v31_ledger_PLAN.md`
- [x] PR Contract: `g/reports/feature_ap_io_v31_ledger_PR_CONTRACT.md`
- [x] Routing Spec: `g/reports/feature_ap_io_v31_ledger_ROUTING_INTEGRATION.md`
- [x] Full Pipeline: `g/reports/feature_ap_io_v31_ledger_FULL_PIPELINE_PROPOSAL.md` (this file)

### Schemas
- [x] `schemas/ap_io_v31.schema.json` - Protocol schema
- [x] `schemas/ap_io_v31_ledger.schema.json` - Ledger entry schema

### Tools (Stubs)
- [x] `tools/ap_io_v31/writer.zsh` - Writer stub
- [x] `tools/ap_io_v31/reader.zsh` - Reader stub
- [x] `tools/ap_io_v31/validator.zsh` - Protocol validator
- [x] `tools/ap_io_v31/correlation_id.zsh` - Correlation ID generator
- [x] `tools/ap_io_v31/router.zsh` - Routing logic

### Tests
- [x] `tests/ap_io_v31/cls_testcases.zsh` - CLS testcases (12 tests)

### Agent Integrations (To Be Implemented)
- [ ] `agents/cls/ap_io_v31_integration.zsh` - CLS integration
- [ ] `agents/andy/ap_io_v31_integration.zsh` - Andy integration
- [ ] `agents/hybrid/ap_io_v31_integration.zsh` - Hybrid integration
- [ ] `agents/liam/ap_io_v31_integration.zsh` - Liam integration
- [ ] `agents/gg/ap_io_v31_integration.zsh` - GG integration (read-only)

### Additional Tests (To Be Created)
- [ ] `tests/ap_io_v31/test_protocol_validation.zsh`
- [ ] `tests/ap_io_v31/test_routing.zsh`
- [ ] `tests/ap_io_v31/test_correlation.zsh`
- [ ] `tests/ap_io_v31/test_backward_compat.zsh`

### Documentation (To Be Created)
- [ ] `docs/AP_IO_V31_PROTOCOL.md` - Protocol documentation
- [ ] `docs/AP_IO_V31_INTEGRATION_GUIDE.md` - Integration guide
- [ ] `docs/AP_IO_V31_ROUTING_GUIDE.md` - Routing guide
- [ ] `docs/AP_IO_V31_MIGRATION.md` - Migration guide

---

## Implementation Roadmap

### Week 1: Foundation

**Days 1-2: Protocol & Schema**
- Review SPEC and PLAN
- Finalize protocol definition
- Validate schemas
- Create protocol documentation

**Days 3-4: Writer/Reader Stubs**
- Implement writer stub (append-only)
- Implement reader stub (v3.1 + v1.0 support)
- Implement validator
- Implement correlation ID generator
- Test stubs

**Day 5: Router**
- Implement routing logic
- Test single/multiple/broadcast modes
- Test priority queuing

### Week 2: Integration

**Days 1-2: CLS Integration**
- Create CLS integration script
- Hook into CLS workflow
- Write events on task start/end
- Read events for correlation
- Update status.json
- Test CLS integration

**Days 3-4: Andy & Hybrid Integration**
- Create Andy integration (Codex CLI wrapper)
- Create Hybrid integration (Luka CLI hooks)
- Test integrations

**Day 5: Liam Integration**
- Create Liam integration
- Hook into orchestration decisions
- Test integration

### Week 3: Testing & Validation

**Days 1-2: Testing**
- Run CLS testcases
- Create additional test suites
- Run integration tests
- Fix issues

**Days 3-4: Documentation**
- Create protocol documentation
- Create integration guide
- Create routing guide
- Create migration guide

**Day 5: CLS Verification**
- CLS reviews implementation
- Fix any issues
- Final validation

---

## Success Metrics

### Functional
- ✅ All schemas created and validated
- ✅ Writer/Reader stubs working
- ✅ Router working (single/multiple/broadcast)
- ✅ All agent integrations working
- ✅ Backward compatibility maintained

### Quality
- ✅ All tests passing
- ✅ CLS verification passed
- ✅ Documentation complete
- ✅ No governance violations

### Performance
- ✅ Minimal overhead (< 10ms per event)
- ✅ Graceful error handling
- ✅ No agent crashes

---

## Risk Mitigation

### Technical Risks
1. **Protocol Complexity**
   - Mitigation: Start with simple events, iterate
   - Fallback: Support v1.0 format

2. **Integration Complexity**
   - Mitigation: Agent-specific stubs, gradual rollout
   - Fallback: Optional integration, graceful degradation

3. **Performance Impact**
   - Mitigation: Async writes, minimal validation
   - Fallback: Disable routing if overhead too high

### Process Risks
1. **Timeline**
   - Mitigation: Phased approach, prioritize CLS
   - Fallback: Extend timeline if needed

2. **Testing Coverage**
   - Mitigation: Comprehensive testcases, CLS verification
   - Fallback: Manual testing, incremental fixes

---

## Dependencies

### External
- jq (JSON processing) - Required
- zsh (shell) - Required
- Existing Agent Ledger v1.0 - For backward compatibility

### Internal
- Agent infrastructure (CLS, Andy, Hybrid, Liam, GG)
- Codex Sandbox Mode (safety)
- Routing system

---

## Next Steps

1. **Boss Review**
   - Review Full Pipeline Proposal
   - Approve implementation plan
   - Assign resources

2. **Andy Implementation**
   - Start with Phase 1 (Foundation)
   - Follow PR Contract
   - Create PRs for each phase

3. **CLS Verification**
   - Review each phase
   - Run testcases
   - Provide feedback

4. **Deployment**
   - Gradual rollout (CLS → Andy → Hybrid → Liam)
   - Monitor performance
   - Collect feedback

---

## Conclusion

Full Pipeline is ready for implementation:
- ✅ All specifications complete
- ✅ All stubs created
- ✅ All testcases defined
- ✅ All integration patterns documented

**Ready to proceed with Andy implementation.**

---

**Proposal Owner:** Liam  
**Implementation:** Andy  
**Verification:** CLS  
**Approval:** Boss
