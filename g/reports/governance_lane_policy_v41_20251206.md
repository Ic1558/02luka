# Governance Lane Policy v4.1 – LAC & QA Lanes

**Date:** 2025-12-06  
**Version:** Governance v4.1  
**Scope:** LAC-related lanes (qa, dev_lac_manager, dev_oss)  
**Status:** Active Policy

---

## Executive Summary

This document clarifies which lanes are governed by `governance_router_v41.py` and which lanes are internal-only to LAC Manager. It prevents confusion when LAC uses lanes that are **not** whitelisted in governance.

**Key Rule:** Only `dev_oss`, `dev_gmxcli`, and `dev_codex` lanes can write files through governance in `open_zone`. All other lanes (including `qa` and `dev_lac_manager`) are internal-only and should not be used as `routing_hint` for file-writing Work Orders.

---

## 1. Lane Classification

| Lane | Type | Can Write (via Governance)? | Notes |
|------|------|---------------------------|-------|
| `dev_oss` | OSS dev lane | ✅ YES | Whitelisted in `OPEN_ZONE_LANES` |
| `dev_gmxcli` | Tool dev lane | ✅ YES | Whitelisted in `OPEN_ZONE_LANES` |
| `dev_codex` | Tool dev lane | ✅ YES | Whitelisted in `OPEN_ZONE_LANES` |
| `qa` | Internal LAC lane | ⛔ NO | LAC-internal only, not in governance whitelist |
| `dev_lac_manager` | Internal LAC lane | ⛔ NO | LAC-internal only, not in governance whitelist |

**"Can Write?" Explanation:**
- **YES** = Lane is whitelisted in `governance_router_v41.py` and can write files in `open_zone` through governance gate
- **NO** = Lane is NOT whitelisted in governance; if used as `routing_hint`, governance will return `lane_not_allowed`

**Important:** "NO" does not mean the lane cannot do anything. It means:
- The lane **cannot pass governance gate** for file writes
- The lane can still be used **internally by LAC Manager** for routing/decision-making
- The lane should **not** be used as `routing_hint` in Work Orders that modify files

---

## 2. Governance Behavior (v4.1)

### Current Implementation

**File:** `shared/governance_router_v41.py`

**Whitelist:**
```python
OPEN_ZONE_LANES = {"dev_oss", "dev_gmxcli", "dev_codex"}
```

**Gate Logic:**
```python
if zone == "open_zone":
    return lane_norm in OPEN_ZONE_LANES
```

### What This Means

- **If** Work Order has `routing_hint: "qa"` or `routing_hint: "dev_lac_manager"`
- **And** Work Order targets files in `open_zone`
- **Then** Governance will return:
  ```json
  {
    "result": "deny",
    "reason": "lane_not_allowed",
    "zone": "open_zone",
    "lane": "qa"
  }
  ```

**Consequence:** Work Order will be blocked, sent to `bridge/failed/LIAM/`, and cannot write files.

---

## 3. Usage Rules for Work Orders

### Rule 1: For WOs that Modify Files (Write Operations)

**Use ONLY whitelisted lanes:**
```yaml
routing_hint: "dev_oss"      # ✅ OK
routing_hint: "dev_gmxcli"   # ✅ OK
routing_hint: "dev_codex"    # ✅ OK
routing_hint: "qa"           # ❌ BLOCKED
routing_hint: "dev_lac_manager"  # ❌ BLOCKED
```

**Recommendation:** For LAC development work that writes files, use `routing_hint: "dev_oss"`.

### Rule 2: For QA / Diagnostic WOs (Read-Only)

**Options:**
- **Option A:** Omit `routing_hint` entirely
  - Governance will ignore lane-based checks
  - Work Order processed based on zone + path only

- **Option B:** Use `routing_hint: "qa"` if Work Order is read-only
  - Safe if no file writes are requested
  - LAC can use for internal routing
  - Governance won't block (if no write operations)

### Rule 3: LAC Internal Routing

**LAC Manager can use any lane in `lac_lanes.yaml` for internal routing:**
```yaml
# lac_lanes.yaml
lanes:
  dev_oss:
    agents: [dev_oss]
  qa:
    agents: [qa_v4]
  dev_lac_manager:
    agents: [manager]
```

**But:** When LAC creates Work Orders that write files, it should use `routing_hint: "dev_oss"` (or omit routing_hint) to pass governance.

---

## 4. Why "Internal Lane" Makes Sense

### Analogy: Highway vs. Local Roads

- **Governance lanes** (`dev_oss`, `dev_gmxcli`, `dev_codex`) = **Highway lanes**
  - Fast lanes for getting work done (file writes approved)
  - Checked by governance gate
  - Must follow strict rules

- **Internal lanes** (`qa`, `dev_lac_manager`) = **Local roads**
  - Used by LAC Manager internally for routing decisions
  - Not meant to pass through governance gate
  - Can be used for read-only operations, diagnostics, planning

### Real-World Example

**Scenario:** LAC receives a QA test request

**Internal Flow (LAC Manager):**
1. LAC reads intent: "run QA tests on governance module"
2. LAC routes to lane: `qa` (internal routing)
3. LAC creates Work Order: **omits `routing_hint`** or uses `routing_hint: "dev_oss"` if write needed
4. Work Order passes governance (because routing_hint is whitelisted)
5. QA agent executes tests

**Key:** LAC uses `qa` lane internally, but **doesn't expose it** to governance for file writes.

---

## 5. Current State vs. Desired State

### Current State (v4.1) ✅

| Lane | Governance | LAC Internal | File Writes |
|------|-----------|--------------|-------------|
| `dev_oss` | ✅ Whitelisted | ✅ Can use | ✅ Allowed |
| `dev_gmxcli` | ✅ Whitelisted | ✅ Can use | ✅ Allowed |
| `dev_codex` | ✅ Whitelisted | ✅ Can use | ✅ Allowed |
| `qa` | ❌ Not whitelisted | ✅ Can use | ⛔ Blocked (via governance) |
| `dev_lac_manager` | ❌ Not whitelisted | ✅ Can use | ⛔ Blocked (via governance) |

**This is correct behavior** because:
- QA lanes should not write production files without review
- LAC Manager lanes are for internal coordination, not direct file operations

### Future State (If Needed)

If we want `qa`/`dev_lac_manager` to write files:
1. Add to `OPEN_ZONE_LANES` in `governance_router_v41.py`
2. Add comprehensive tests
3. Update AI_OP_001 documentation
4. Bump governance version to v4.2

**Decision:** Not needed for v4.1. Current behavior is correct.

---

## 6. Migration Guide

### If You See "lane_not_allowed" Errors

**Error Message:**
```json
{
  "result": "deny",
  "reason": "lane_not_allowed",
  "zone": "open_zone",
  "lane": "qa"
}
```

**Solution:**
```yaml
# Before (WRONG):
wo_id: "WO-TEST-001"
routing_hint: "qa"
zone: "open_zone"
paths:
  - "agents/qa_v4/test.py"  # Write operation

# After (CORRECT):
wo_id: "WO-TEST-001"
routing_hint: "dev_oss"  # ✅ Use whitelisted lane
zone: "open_zone"
paths:
  - "agents/qa_v4/test.py"
```

Or:
```yaml
# Alternative (if read-only):
wo_id: "WO-TEST-001"
# routing_hint: (omitted)  # ✅ No lane check needed
zone: "open_zone"
operations:
  - type: "read"  # Read-only, no writes
```

---

## 7. Testing & Validation

### Test Cases

**Test 1: dev_oss lane in open_zone (should pass)**
```python
result = governance_router_v41.check_wo_allowed(
    zone="open_zone",
    routing_hint="dev_oss",
    paths=["agents/dev_oss/test.py"]
)
assert result["result"] == "allow"
```

**Test 2: qa lane in open_zone (should deny)**
```python
result = governance_router_v41.check_wo_allowed(
    zone="open_zone",
    routing_hint="qa",
    paths=["agents/qa_v4/test.py"]
)
assert result["result"] == "deny"
assert result["reason"] == "lane_not_allowed"
```

**Test 3: No routing_hint (should check paths only)**
```python
result = governance_router_v41.check_wo_allowed(
    zone="open_zone",
    routing_hint=None,  # No lane specified
    paths=["agents/qa_v4/test.py"]
)
# Result depends on path rules, not lane
```

---

## 8. FAQ

### Q: Why can't `qa` lane write files?

**A:** By design. QA should:
- Test existing code (read-only)
- Report issues (no direct fixes)
- Run in isolated environment

If QA needs to write test fixtures or update test code, use `routing_hint: "dev_oss"` for the Work Order.

### Q: What if LAC needs to write files for dev_lac_manager lane?

**A:** Use `routing_hint: "dev_oss"` in the Work Order. LAC can still track internally that the work is for "dev_lac_manager" purpose, but uses a whitelisted lane for governance gate.

### Q: Can I add qa/dev_lac_manager to OPEN_ZONE_LANES?

**A:** Yes, but requires:
1. Governance version bump (v4.1 → v4.2)
2. Test coverage for new lanes
3. Documentation update (AI_OP_001)
4. Boss approval

Not recommended for v4.1.

### Q: Does this mean qa/dev_lac_manager lanes are useless?

**A:** No! They are useful for:
- LAC internal routing decisions
- Intent mapping
- Agent selection
- Read-only operations
- Planning/diagnostic work

They just can't **write files through governance gate**.

---

## 9. Related Files

- **Governance Router:** `shared/governance_router_v41.py`
- **LAC Lanes Config:** `g/config/lac_lanes.yaml`
- **Governance Lock:** `g/reports/governance_v41_lock_20251206.md`
- **AI_OP_001:** `g/docs/AI_OP_001_v4.md`

---

## 10. Summary

**"Internal lane" makes sense because:**

1. **Separation of Concerns**
   - Governance controls **what can be written**
   - LAC controls **how work is routed internally**

2. **Security & Safety**
   - QA should not modify production code directly
   - LAC Manager is for coordination, not direct file operations

3. **Clear Boundaries**
   - Dev lanes (`dev_oss`, etc.) = approved for writes
   - Internal lanes (`qa`, `dev_lac_manager`) = routing/planning only

4. **Flexibility**
   - LAC can use any lane internally
   - But must use whitelisted lanes for governance-controlled writes

**Conclusion:** Current design is correct. `qa` and `dev_lac_manager` as "Internal lane / ⛔ No write (via governance)" accurately reflects the intended architecture.

---

**Policy Status:** ✅ Active  
**Next Review:** When governance v4.2 spec is needed
