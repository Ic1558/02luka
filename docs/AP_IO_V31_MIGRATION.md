# AP/IO v3.1 Migration Guide

**Date:** 2025-11-16  
**From:** Agent Ledger v1.0  
**To:** AP/IO v3.1

---

## Overview

This guide explains how to migrate from Agent Ledger v1.0 to AP/IO v3.1.

---

## Backward Compatibility

AP/IO v3.1 **fully supports** Agent Ledger v1.0 format:
- Reader automatically converts v1.0 to v3.1 structure
- No breaking changes required
- Gradual migration possible

---

## Migration Strategy

### Phase 1: Dual Mode (Current)
- Existing v1.0 entries continue to work
- New entries use v3.1 format
- Reader supports both formats

### Phase 2: Gradual Migration
- Update agent integrations to use v3.1 writer
- Keep v1.0 reader support
- Test compatibility

### Phase 3: Full Migration
- All agents use v3.1 format
- v1.0 support maintained for historical data
- Optional: Convert historical v1.0 entries to v3.1

---

## Format Comparison

### v1.0 Format
```json
{
  "ts": "2025-11-16T10:00:00+07:00",
  "agent": "cls",
  "event": "task_start",
  "task_id": "wo-test",
  "source": "gg_orchestrator",
  "summary": "Starting task"
}
```

### v3.1 Format
```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "ts": "2025-11-16T10:00:00+07:00",
  "agent": "cls",
  "event": {
    "type": "task_start",
    "task_id": "wo-test",
    "source": "gg_orchestrator",
    "summary": "Starting task"
  },
  "routing": {
    "targets": ["cls"],
    "broadcast": false,
    "priority": "normal"
  }
}
```

---

## Migration Steps

### Step 1: Update Writer
Replace v1.0 writer with v3.1 writer:
```bash
# Old (v1.0)
echo '{"ts":"...","agent":"cls","event":"task_start"}' >> ledger.jsonl

# New (v3.1)
tools/ap_io_v31/writer.zsh cls task_start "wo-test" "gg_orchestrator" "Starting task"
```

### Step 2: Update Reader
Use v3.1 reader (supports both formats):
```bash
tools/ap_io_v31/reader.zsh g/ledger/cls/2025-11-16.jsonl
```

### Step 3: Update Agent Integrations
Use v3.1 integration scripts:
```bash
agents/cls/ap_io_v31_integration.zsh normal < event.json
```

### Step 4: Test Compatibility
Run backward compatibility tests:
```bash
tests/ap_io_v31/test_backward_compat.zsh
```

---

## Benefits of v3.1

1. **Protocol Standardization** - Consistent format across agents
2. **Routing Support** - Cross-agent event communication
3. **Correlation** - Link related events across agents
4. **Enhanced Metadata** - More detailed event information
5. **Versioning** - Protocol version tracking

---

## Rollback Plan

If issues occur:
1. Revert to v1.0 writer
2. v3.1 reader still supports v1.0 format
3. No data loss
4. Gradual re-migration possible

---

## Timeline

- **Week 1:** Foundation (Protocol, Schemas, Stubs)
- **Week 2:** Integration (CLS, Andy, Hybrid, Liam)
- **Week 3:** Testing & Validation
- **Ongoing:** Monitor and optimize

---

## Support

For questions or issues:
- Review SPEC: `g/reports/feature_ap_io_v31_ledger_SPEC.md`
- Review PLAN: `g/reports/feature_ap_io_v31_ledger_PLAN.md`
- Check integration guide: `docs/AP_IO_V31_INTEGRATION_GUIDE.md`

---

**Guide Owner:** Liam  
**Last Updated:** 2025-11-16
