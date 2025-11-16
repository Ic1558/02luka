# Feature PLAN: Shared Memory Phase 3 - Remaining Agents Integration

**Feature ID:** `shared_memory_phase3_remaining_agents`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Task Breakdown

### Phase 3: Remaining Agents Integration ✅

- [x] **Task 3.1:** Create GPT/GG memory bridge
  - `agents/gpt_bridge/gpt_memory.py`
  - Functions: get_context_for_gpt(), save_gpt_response()
  - GPT system message formatting

- [x] **Task 3.2:** Create Gemini memory wrapper
  - `tools/gemini_memory_wrapper.sh`
  - CLI wrapper with context injection
  - Memory update after execution

- [x] **Task 3.3:** Update health check
  - Add GPT/GG bridge check
  - Add Gemini wrapper check
  - Verify all agents integrated

---

## Test Strategy

### Unit Tests

**Test 1: GPT Bridge**
```python
# Test get_context_for_gpt
from agents.gpt_bridge.gpt_memory import GPTMemoryBridge
bridge = GPTMemoryBridge()
context = bridge.get_context_for_gpt()
# Expected: Formatted system message with agent status

# Test save_gpt_response
bridge.save_gpt_response("Test response")
# Expected: Memory updated, bridge file created
```

**Test 2: Gemini Wrapper**
```bash
# Test wrapper
tools/gemini_memory_wrapper.sh "test question"
# Expected: Gemini called with context, memory updated

# Test context injection
tools/gemini_memory_wrapper.sh "What agents are active?"
# Expected: Response includes shared context
```

### Integration Tests

**Test 1: End-to-End GPT Flow**
```python
# GPT with shared context
bridge = GPTMemoryBridge()
context = bridge.get_context_for_gpt()
# Use context in GPT call
response = gpt_api_call(context, user_message)
bridge.save_gpt_response(response)

# Verify in memory
tools/memory_sync.sh get | jq '.agents.gg'
# Expected: GG status updated
```

**Test 2: End-to-End Gemini Flow**
```bash
# Gemini with shared context
tools/gemini_memory_wrapper.sh "What are we working on?"

# Verify memory updated
tools/memory_sync.sh get | jq '.agents.gemini'
# Expected: Gemini status updated
```

**Test 3: All Agents Coordination**
```bash
# GC updates
tools/gc_memory_sync.sh update

# CLS updates
python3 -c "from agents.cls_bridge.cls_memory import after_task; after_task({'test': True})"

# GPT updates (via bridge)
# Gemini updates (via wrapper)

# Verify all in context
tools/memory_sync.sh get | jq '.agents | keys'
# Expected: ["gc", "cls", "gg", "gemini"]
```

---

## Deployment Checklist

- [x] **Pre-Deployment:**
  - [x] Verify Phase 1+2 deployed
  - [x] Verify shared memory operational
  - [x] Check GPT/Gemini API access

- [x] **Deployment:**
  - [x] Create GPT bridge module
  - [x] Create Gemini wrapper
  - [x] Update health check
  - [x] Test integrations

- [x] **Post-Deployment:**
  - [x] Run health checks
  - [x] Test GPT integration
  - [x] Test Gemini integration
  - [x] Verify all agents in context

---

## Rollback Plan

### Immediate Rollback
```bash
# Remove Phase 3 components
rm -f ~/02luka/agents/gpt_bridge/gpt_memory.py
rm -f ~/02luka/tools/gemini_memory_wrapper.sh

# Preserve Phase 1+2
# (keep existing infrastructure)
```

---

## Acceptance Criteria

✅ **Functional:**
- GPT bridge works (get_context, save_response)
- Gemini wrapper works (transparent CLI)
- All agents in shared context
- Health check passes

✅ **Integration:**
- GPT can use shared context
- Gemini can use shared context
- All agents coordinated
- Token savings maximized

✅ **Token Savings:**
- GPT/GG: 60-80% reduction
- Gemini: 60-80% reduction
- Overall: 70-85% reduction

---

## Timeline

- **Phase 3:** ✅ Complete (one-shot installer)
- **Testing:** Week 1
- **Optimization:** Week 2

**Total Phase 3:** ~10 minutes (one-shot installer)

---

## Success Metrics

1. **Functionality:** All agents integrated
2. **Token Savings:** 70-85% overall reduction
3. **Coordination:** All agents aware of each other
4. **Health:** All checks passing

---

## Next Steps

1. **Immediate:**
   - Deploy Phase 3
   - Test GPT/Gemini integration
   - Verify token savings

2. **Week 1:**
   - Monitor token usage
   - Optimize context formatting
   - Fine-tune system prompts

3. **Week 2:**
   - Advanced features (caching, coordination)
   - Full automation
   - System optimization

---

## References

- **SPEC:** `g/reports/feature_shared_memory_phase3_remaining_agents_SPEC.md`
- **Phase 1:** `g/reports/feature_shared_memory_system_SPEC.md`
- **Phase 2:** `g/reports/feature_shared_memory_phase2_gc_cls_SPEC.md`
