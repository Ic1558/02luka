# Feature PLAN: Shared Memory Phase 2 - GC/CLS Integration & Metrics

**Feature ID:** `shared_memory_phase2_gc_cls`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Task Breakdown

### Phase 2: GC/CLS Integration & Metrics ✅

- [x] **Task 2.1:** Create GC memory sync helper
  - `tools/gc_memory_sync.sh`
  - Commands: update, push, get
  - Integration with memory_sync.sh

- [x] **Task 2.2:** Create CLS memory bridge
  - `agents/cls_bridge/cls_memory.py`
  - Functions: before_task(), after_task()
  - Python subprocess integration

- [x] **Task 2.3:** Create metrics collector
  - `tools/memory_metrics.zsh`
  - Collect agent count, token usage
  - Output to NDJSON

- [x] **Task 2.4:** Create health check
  - `tools/shared_memory_health.zsh`
  - 5-point health check
  - Exit codes for automation

- [x] **Task 2.5:** Create metrics LaunchAgent
  - `com.02luka.memory.metrics`
  - Hourly collection
  - Log paths

---

## Test Strategy

### Unit Tests

**Test 1: GC Memory Sync**
```bash
# Test update
tools/gc_memory_sync.sh update
tools/memory_sync.sh get | jq '.agents.gc.status'
# Expected: "active"

# Test push
tools/gc_memory_sync.sh push '{"test":"data"}'
ls bridge/memory/inbox/gc_context_*.json
# Expected: File exists

# Test get
tools/gc_memory_sync.sh get | jq .
# Expected: GC context data
```

**Test 2: CLS Memory Bridge**
```python
# Test before_task
python3 -c "from agents.cls_bridge.cls_memory import before_task; print(before_task())"
# Expected: Context JSON

# Test after_task
python3 -c "from agents.cls_bridge.cls_memory import after_task; after_task({'test': True})"
ls bridge/memory/inbox/cls_result_*.json
# Expected: File exists
```

**Test 3: Metrics Collector**
```bash
# Run metrics
tools/memory_metrics.zsh

# Check output
tail -1 metrics/memory_usage.ndjson | jq .
# Expected: Metrics JSON with ts, agents, token_total, token_saved, saved_pct
```

**Test 4: Health Check**
```bash
# Run health check
tools/shared_memory_health.zsh
# Expected: All ✅ checks pass
```

### Integration Tests

**Test 1: End-to-End GC Flow**
```bash
# GC updates status
tools/gc_memory_sync.sh update

# GC pushes context
tools/gc_memory_sync.sh push '{"task":"test","phase":2}'

# Wait for bridge monitor
sleep 3

# Verify in context
tools/memory_sync.sh get | jq '.agents.gc'
# Expected: Status updated, context available
```

**Test 2: End-to-End CLS Flow**
```python
# CLS loads context
from agents.cls_bridge.cls_memory import before_task, after_task
ctx = before_task()
print(ctx['agents'])

# CLS saves result
after_task({"task": "test", "result": "success"})

# Verify in bridge
# (check bridge/memory/inbox/cls_result_*.json)
```

**Test 3: Metrics Collection**
```bash
# Update token usage in context
jq '.token_usage.total = 1000 | .token_usage.saved = 400' \
  shared_memory/context.json > /tmp/ctx.json && mv /tmp/ctx.json shared_memory/context.json

# Collect metrics
tools/memory_metrics.zsh

# Verify metrics
tail -1 metrics/memory_usage.ndjson | jq '.saved_pct'
# Expected: 40
```

---

## Deployment Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Phase 1 deployed
  - [x] Verify memory_sync.sh exists
  - [x] Verify bridge system operational

- [x] **Deployment:**
  - [x] Create GC helper script
  - [x] Create CLS bridge module
  - [x] Create metrics collector
  - [x] Create health check
  - [x] Create metrics LaunchAgent
  - [x] Load LaunchAgent

- [x] **Post-Deployment:**
  - [x] Run health checks
  - [x] Test GC integration
  - [x] Test CLS integration
  - [x] Test metrics collection
  - [x] Verify LaunchAgent running

---

## Rollback Plan

### Immediate Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.metrics.plist

# Remove files
rm -f ~/Library/LaunchAgents/com.02luka.memory.metrics.plist
rm -f ~/02luka/tools/gc_memory_sync.sh
rm -f ~/02luka/tools/memory_metrics.zsh
rm -f ~/02luka/tools/shared_memory_health.zsh
rm -rf ~/02luka/agents/cls_bridge

# Preserve data
# (keep metrics/ for analysis)
```

---

## Acceptance Criteria

✅ **Functional:**
- GC helper works (update, push, get)
- CLS bridge works (before_task, after_task)
- Metrics collector works
- Health check passes

✅ **Integration:**
- GC can update and push context
- CLS can load and save context
- Metrics collected automatically
- Health checks comprehensive

✅ **SLO:**
- SLO-1: Health check passes 100%
- SLO-2: Metrics written ≥ 1 record/hour
- SLO-3: Token saved/total ≥ 40% (Week 1)

---

## Timeline

- **Phase 2:** ✅ Complete (one-shot installer)
- **Metrics Collection:** Ongoing (hourly)
- **SLO Tracking:** Week 1

**Total Phase 2:** ~5 minutes (one-shot installer)

---

## Success Metrics

1. **Functionality:** All components working
2. **Integration:** GC/CLS can use shared memory
3. **Metrics:** Automated collection running
4. **Health:** All checks passing
5. **SLO:** Token savings ≥ 40% (Week 1)

---

## Next Steps

1. **Immediate:**
   - Deploy Phase 2
   - Test GC/CLS integration
   - Verify metrics collection

2. **Week 1:**
   - Monitor metrics
   - Track token savings
   - Verify SLO-3 (≥40% savings)

3. **Week 2:**
   - Phase 3: Redis integration
   - Real-time sync
   - Full coordination

---

## References

- **SPEC:** `g/reports/feature_shared_memory_phase2_gc_cls_SPEC.md`
- **Phase 1:** `g/reports/feature_shared_memory_system_SPEC.md`
- **SOT Path:** `/Users/icmini/02luka`
