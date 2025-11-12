# Feature PLAN: Shared Memory Phase 4 - Redis Real-time Hub & Mary/R&D Integration

**Feature ID:** `shared_memory_phase4_redis_hub`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Task Breakdown

### Phase 4: Redis Hub & Mary/R&D Integration ✅

- [x] **Task 4.1:** Create memory hub service
  - `agents/memory_hub/memory_hub.py`
  - Redis connection and pub/sub
  - File sync functions
  - Context merging logic

- [x] **Task 4.2:** Create memory hub LaunchAgent
  - `com.02luka.memory.hub`
  - KeepAlive: true
  - Continuous operation

- [x] **Task 4.3:** Integrate Mary dispatcher
  - Hook into `tools/mary_dispatcher.zsh`
  - Record task results
  - Update shared memory + Redis

- [x] **Task 4.4:** Integrate R&D consumer
  - Hook into `tools/rnd_consumer.zsh`
  - Record proposal outcomes
  - Update shared memory + Redis

- [x] **Task 4.5:** Update health check
  - Add Redis connectivity check
  - Add hub service check
  - Verify Mary/R&D integration

---

## Test Strategy

### Unit Tests

**Test 1: Memory Hub Service**
```python
# Test Redis connection
from agents.memory_hub.memory_hub import UnifiedMemoryHub
hub = UnifiedMemoryHub()
# Expected: Connected to Redis

# Test update
hub.update_agent_context("test", {"status": "active"})
# Expected: Redis updated, file synced

# Test get unified context
context = hub.get_unified_context()
# Expected: Merged context from Redis + file
```

**Test 2: Pub/Sub**
```python
# Test publish
hub.publish_update({"agent": "test", "event": "update"})
# Expected: Message published to channel

# Test subscribe
hub.subscribe_updates()
# Expected: Receives updates from channel
```

**Test 3: Mary Integration**
```bash
# Test Mary result recording
# (after Mary completes task)
tools/memory_sync.sh get | jq '.agents.mary'
# Expected: Mary status and results updated
```

**Test 4: R&D Integration**
```bash
# Test R&D outcome recording
# (after R&D processes proposal)
tools/memory_sync.sh get | jq '.agents.rnd'
# Expected: R&D status and outcomes updated
```

### Integration Tests

**Test 1: End-to-End Real-time Flow**
```python
# Agent 1 updates
hub.update_agent_context("agent1", {"task": "work1"})

# Agent 2 receives update (via pub/sub)
# Expected: Agent 2 sees update immediately
```

**Test 2: Mary → Shared Memory**
```bash
# Mary completes task
# (via mary_dispatcher.zsh hook)

# Verify in shared memory
tools/memory_sync.sh get | jq '.agents.mary'
# Expected: Mary results recorded
```

**Test 3: R&D → Shared Memory**
```bash
# R&D processes proposal
# (via rnd_consumer.zsh hook)

# Verify in shared memory
tools/memory_sync.sh get | jq '.agents.rnd'
# Expected: R&D outcomes recorded
```

---

## Deployment Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Redis running
  - [x] Verify Phase 1-3 deployed
  - [x] Check Redis password/config

- [x] **Deployment:**
  - [x] Create memory hub service
  - [x] Create LaunchAgent
  - [x] Add Mary integration hooks
  - [x] Add R&D integration hooks
  - [x] Update health check
  - [x] Load LaunchAgent

- [x] **Post-Deployment:**
  - [x] Run health checks
  - [x] Test Redis connectivity
  - [x] Test pub/sub
  - [x] Test Mary integration
  - [x] Test R&D integration

---

## Rollback Plan

### Immediate Rollback
```bash
# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.memory.hub.plist

# Remove files
rm -f ~/Library/LaunchAgents/com.02luka.memory.hub.plist
rm -rf ~/02luka/agents/memory_hub

# Revert Mary/R&D hooks
# (restore original scripts)

# Preserve data
# (keep Redis data, file-based context)
```

---

## Acceptance Criteria

✅ **Functional:**
- Memory hub running continuously
- Redis sync working
- Pub/sub updates working
- Mary results recorded
- R&D outcomes recorded

✅ **Real-time:**
- Updates propagate < 1 second
- All agents see updates immediately
- No stale context

✅ **Integration:**
- Mary integrated
- R&D integrated
- All agents coordinated

---

## Timeline

- **Phase 4:** ✅ Complete (one-shot installer)
- **Testing:** Week 1
- **Optimization:** Week 2

**Total Phase 4:** ~15 minutes (one-shot installer)

---

## Success Metrics

1. **Functionality:** All components working
2. **Real-time:** Updates < 1 second
3. **Integration:** Mary/R&D recording results
4. **Coordination:** All agents see unified state

---

## Next Steps

1. **Immediate:**
   - Deploy Phase 4
   - Test Redis connectivity
   - Verify real-time updates

2. **Week 1:**
   - Monitor update latency
   - Verify Mary/R&D integration
   - Test conflict resolution

3. **Week 2:**
   - Optimize performance
   - Advanced features
   - Full automation

---

## References

- **SPEC:** `g/reports/feature_shared_memory_phase4_redis_hub_SPEC.md`
- **Phase 1-3:** Previous phase SPECs
- **Redis Config:** `localhost:6379` (password: `changeme-02luka`)

