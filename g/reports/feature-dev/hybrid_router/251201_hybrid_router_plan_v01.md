# Hybrid Router Implementation Plan

**Date:** 2025-12-01  
**Feature:** Hybrid Router (Local + GG + Alter)  
**Version:** v01  
**Status:** 📋 **PLAN READY FOR REVIEW**  
**Based on:** `251201_hybrid_router_spec_v01.md`  
**File:** `g/reports/feature-dev/hybrid_router/251201_hybrid_router_plan_v01.md`

---

## Executive Summary

This plan implements a **Hybrid Router** that intelligently routes text tasks to:
- **Local engines** (Ollama) for internal/sensitive/high-volume work
- **GG** (ChatGPT Plus) for general reasoning and orchestration
- **Alter** (Polish API) for client-facing polish/translation

**Timeline:** 4-6 days (3 phases)  
**Risk Level:** Low-Medium (extends existing infrastructure)  
**Dependencies:** Alter AI Integration (PR #389) ✅

---

## Phase Breakdown

### Phase H1: Skeleton Router (Days 1-2)

**Goal:** Create core router function with decision logic and basic tests.

#### Task H1.1: Create Router Module

**File:** `agents/ai_manager/hybrid_router.py` (new)

**Implementation:**
```python
"""
Hybrid Router - Routes text tasks to appropriate AI engine.

Decision rules:
- High sensitivity → Local (Ollama)
- Normal internal → GG
- Client-facing/polish → GG/Local draft → Alter polish
"""

from typing import Dict, Any, Optional
from agents.alter.helpers import polish_if_needed
# ... other imports

def hybrid_route_text(text: str, context: Dict[str, Any]) -> Dict[str, Any]:
    """
    Route text to appropriate engine and return result.
    
    Returns:
        {
            "text": str,  # Final processed text
            "engine_used": "local" | "gg" | "alter",
            "alter_status": "used" | "skipped" | "error",
            "fallback": bool
        }
    """
    # Decision logic
    # Engine execution
    # Error handling
    pass
```

**Checklist:**
- [ ] Create file structure
- [ ] Implement decision rules (3 rules from spec)
- [ ] Integrate with existing providers (Local, GG, Alter)
- [ ] Add error handling and fallback
- [ ] Add logging for telemetry

**Estimated Time:** 4-6 hours

#### Task H1.2: Provider Integration

**Files:**
- `agents/ai_manager/hybrid_router.py` (modify)
- `g/config/ai_providers.yaml` (update)

**Implementation:**
- Load provider configs from `ai_providers.yaml`
- Initialize clients for:
  - `local_general` (Ollama)
  - `gg_core` (OpenAI)
  - `alter_polish` (AlterPolishService)
- Add provider health checks

**Checklist:**
- [ ] Add provider config loading
- [ ] Add client initialization
- [ ] Add health check methods
- [ ] Update `ai_providers.yaml` with router configs

**Estimated Time:** 2-3 hours

#### Task H1.3: Unit Tests

**File:** `tests/test_hybrid_router.py` (new)

**Test Cases:**
```python
def test_high_sensitivity_routes_to_local():
    """sensitivity='high' → local engine"""
    pass

def test_client_facing_routes_to_alter():
    """client_facing=True, mode='polish' → alter"""
    pass

def test_normal_internal_routes_to_gg():
    """default case → gg_core"""
    pass

def test_alter_quota_exceeded_fallback():
    """alter quota exceeded → return draft from gg/local"""
    pass

def test_error_handling_fallback():
    """engine error → fallback to gg"""
    pass
```

**Checklist:**
- [ ] Test decision rules (3 main rules)
- [ ] Test error handling
- [ ] Test fallback mechanisms
- [ ] Test quota handling
- [ ] Mock providers for isolation

**Estimated Time:** 3-4 hours

**Phase H1 Total:** 9-13 hours (1.5-2 days)

---

### Phase H2: First Integrations (Days 3-4)

**Goal:** Integrate router into 1-2 real workers and add disable flag.

#### Task H2.1: Docs Worker Integration

**File:** `agents/docs_v4/docs_worker.py` (modify)

**Changes:**
```python
# Before:
from agents.alter.helpers import polish_if_needed
polished = polish_if_needed(content, context)

# After:
from agents.ai_manager.hybrid_router import hybrid_route_text
result = hybrid_route_text(content, context)
polished = result["text"]
```

**Checklist:**
- [ ] Import hybrid_route_text
- [ ] Replace direct Alter calls with router
- [ ] Update context building (add sensitivity, mode)
- [ ] Test with real docs worker tasks
- [ ] Verify no regression

**Estimated Time:** 3-4 hours

#### Task H2.2: LAC Manager Integration (Optional)

**File:** `agents/lac_manager/lac_manager.py` (modify)

**Changes:**
- Similar to docs worker
- Only if LAC manager has text polish needs

**Checklist:**
- [ ] Review LAC manager polish usage
- [ ] Integrate router if applicable
- [ ] Test integration
- [ ] Verify no regression

**Estimated Time:** 2-3 hours (if applicable)

#### Task H2.3: Disable Flag & Config

**Files:**
- `agents/ai_manager/hybrid_router.py` (modify)
- `g/config/ai_providers.yaml` (update)

**Implementation:**
```python
# Check ENV flag
HYBRID_ROUTER_ENABLED = os.getenv("HYBRID_ROUTER_ENABLED", "1") == "1"

if not HYBRID_ROUTER_ENABLED:
    # Fallback to direct GG/Alter calls (backward compatible)
    return direct_call(text, context)
```

**Config:**
```yaml
hybrid_router:
  enabled: true  # Can be overridden by ENV
  fallback_engine: "gg_core"  # Default fallback
```

**Checklist:**
- [ ] Add ENV flag check
- [ ] Add config option
- [ ] Add backward compatibility mode
- [ ] Test disable/enable
- [ ] Document flag usage

**Estimated Time:** 1-2 hours

#### Task H2.4: Integration Tests

**File:** `tests/test_hybrid_router_integration.py` (new)

**Test Cases:**
- Docs worker with router
- Real context scenarios
- End-to-end flow

**Checklist:**
- [ ] Test docs worker integration
- [ ] Test real context scenarios
- [ ] Test disable flag
- [ ] Test backward compatibility

**Estimated Time:** 2-3 hours

**Phase H2 Total:** 8-12 hours (1.5-2 days)

---

### Phase H3: Telemetry & Tuning (Days 5-6, Optional)

**Goal:** Add logging and telemetry for router decisions and performance.

#### Task H3.1: Telemetry Module

**File:** `agents/ai_manager/hybrid_router_telemetry.py` (new)

**Implementation:**
```python
"""
Telemetry for Hybrid Router decisions and performance.
"""

def log_router_decision(context, engine_used, duration, alter_status):
    """Log router decision for analytics."""
    pass

def get_router_stats(hours=24):
    """Get router statistics for last N hours."""
    pass
```

**Checklist:**
- [ ] Create telemetry module
- [ ] Add decision logging
- [ ] Add performance metrics
- [ ] Add stats aggregation
- [ ] Write to `g/data/memory/hybrid_router_logs.jsonl`

**Estimated Time:** 3-4 hours

#### Task H3.2: Analytics Dashboard (Optional)

**File:** `g/tools/hybrid_router_stats.py` (new)

**Implementation:**
- CLI tool to view router stats
- Engine usage breakdown
- Performance metrics
- Alter quota usage

**Checklist:**
- [ ] Create CLI tool
- [ ] Add stats display
- [ ] Add filtering options
- [ ] Test with real logs

**Estimated Time:** 2-3 hours

**Phase H3 Total:** 5-7 hours (1 day, optional)

---

## Test Strategy

### Unit Tests
- **Coverage:** Decision rules, error handling, fallback
- **Location:** `tests/test_hybrid_router.py`
- **Mock:** All providers (Local, GG, Alter)

### Integration Tests
- **Coverage:** Real worker integration, end-to-end flow
- **Location:** `tests/test_hybrid_router_integration.py`
- **Real:** Docs worker, LAC manager (if applicable)

### Manual Testing
- **Scenarios:**
  1. High sensitivity task → Local
  2. Normal internal task → GG
  3. Client-facing task → GG draft → Alter polish
  4. Alter quota exceeded → Fallback to draft
  5. Engine error → Fallback to GG

---

## File Structure

```
agents/
  ai_manager/
    hybrid_router.py              # NEW - Core router
    hybrid_router_telemetry.py     # NEW (Phase H3) - Telemetry
    
  docs_v4/
    docs_worker.py                 # MODIFY - Use router
    
  lac_manager/
    lac_manager.py                 # MODIFY (optional) - Use router

g/
  config/
    ai_providers.yaml              # MODIFY - Add router configs
  
  data/
    memory/
      hybrid_router_logs.jsonl    # NEW (Phase H3) - Telemetry logs

g/tools/
  hybrid_router_stats.py           # NEW (Phase H3) - Stats CLI

tests/
  test_hybrid_router.py            # NEW - Unit tests
  test_hybrid_router_integration.py # NEW - Integration tests
```

---

## Dependencies

### Required (Already Exists)
- ✅ `AlterPolishService` (from PR #389)
- ✅ `ai_providers.yaml` config
- ✅ Local Ollama client
- ✅ GG client (OpenAI)
- ✅ MLS / ledger system

### New (To Be Created)
- `agents/ai_manager/hybrid_router.py`
- `tests/test_hybrid_router.py`
- Config updates

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Router logic bug | Medium | High | Comprehensive tests, fallback to GG |
| Provider integration issues | Low | Medium | Health checks, error handling |
| Performance degradation | Low | Medium | Telemetry, monitoring |
| Backward compatibility | Low | High | Disable flag, fallback mode |

---

## Success Criteria

### Phase H1
- [ ] Router function implemented
- [ ] All unit tests pass
- [ ] Decision rules work correctly

### Phase H2
- [ ] Docs worker uses router
- [ ] No regression in existing flows
- [ ] Disable flag works
- [ ] Integration tests pass

### Phase H3 (Optional)
- [ ] Telemetry logs router decisions
- [ ] Stats CLI works
- [ ] Analytics available

### Overall
- [ ] Workers use router in 1-2 real points
- [ ] No regression
- [ ] Alter used only for client-facing/polish
- [ ] Clear path forward for future enhancements

---

## Timeline Summary

| Phase | Tasks | Time | Days |
|-------|-------|------|------|
| H1 | Skeleton Router | 9-13 hours | 1.5-2 |
| H2 | First Integrations | 8-12 hours | 1.5-2 |
| H3 | Telemetry (Optional) | 5-7 hours | 1 |
| **Total** | | **22-32 hours** | **4-6 days** |

---

## Next Steps

1. **Review this plan** with CLS / Mary / AI Manager
2. **Start Phase H1** (skeleton implementation)
3. **Test with 1-2 real use cases** before full rollout
4. **Measure results** (time saved, quality, cost, privacy)

---

**Plan Version:** 1.0  
**Last Updated:** 2025-12-01  
**Status:** 📋 **PLAN READY FOR REVIEW**
