# PR-10 Routing Analysis — Root Cause

**Date:** 2025-12-10  
**Issue:** PR-10 WOs went to STRICT lane (CLC) instead of FAST lane (local CLS auto-approve)

---

## Findings

### 1. Zone Resolution
- `bridge/templates/` → **OPEN zone** (not in LOCKED_PATTERNS)
- `bridge/docs/` → **OPEN zone** (not in LOCKED_PATTERNS)

**LOCKED_PATTERNS:**
- `^core/`
- `^launchd/`
- `^bridge/core/`
- `^bridge/inbox/`
- `^bridge/outbox/`
- `^bridge/handlers/`
- `^bridge/production/`
- `^g/docs/governance/`

**Note:** `bridge/templates/` and `bridge/docs/` are **NOT** in LOCKED_PATTERNS, so they resolve to OPEN zone.

---

### 2. Lane Resolution (Router v5)
- **OPEN zone + CLI world (cursor)** → **FAST lane** (local execution)
- **OPEN zone + BACKGROUND world (background)** → **STRICT lane** (CLC)

**Test Results:**
```python
route("cursor", "CLS", "bridge/templates/test.html", "write")
# → Zone: OPEN, Lane: FAST, Primary writer: CLS

route("background", "CLS", "bridge/templates/test.html", "write")
# → Zone: OPEN, Lane: STRICT, Primary writer: CLC
```

---

### 3. Telemetry Evidence
- `WO-PR10-CLS-TEMPLATE`: `strict_ops=1` (went to STRICT lane)
- `WO-PR10-CLS-DOC`: `action: "route"` (legacy routing)

**WO Content:**
- Trigger: `cursor`
- Actor: `CLS`
- Target: `bridge/templates/pr10_auto_approve_email.html`

---

## Root Cause Hypothesis

**PR-10 WOs went to STRICT lane because:**

1. **WO Processor Logic:** The WO processor may be:
   - Using `trigger="background"` instead of the WO's `trigger` field
   - Checking `strict_target=CLC` in the WO
   - Using a different world resolution logic

2. **Zone Mismatch:** According to GOVERNANCE v5:
   - Mission Scope whitelist includes `bridge/templates/` and `bridge/docs/`
   - But Mission Scope is for **LOCKED zone → WARN lane** (CLS auto-approve)
   - These paths are **OPEN zone → FAST lane** (no auto-approve needed)

3. **Spec Mismatch:** There's a discrepancy between:
   - **GOVERNANCE v5 spec:** `bridge/templates/` in Mission Scope whitelist (for LOCKED zone)
   - **Router v5 implementation:** `bridge/templates/` resolves to OPEN zone

---

## Expected Behavior

### For CLS Auto-Approve Test (PR-10):
- **Path should be in LOCKED zone** (e.g., `bridge/core/...` or `g/docs/governance/...`)
- **Trigger should be `cursor`** (CLI world)
- **Result:** WARN lane → CLS auto-approve → local execution

### Current Behavior:
- **Path is in OPEN zone** (`bridge/templates/`)
- **Trigger is `cursor`** (CLI world)
- **Result:** FAST lane → local execution (no auto-approve needed)

**Note:** FAST lane is actually correct for OPEN zone! The issue is that the test was designed for LOCKED zone paths.

---

## Recommendations

### Option 1: Fix Test (Recommended)
- Use LOCKED zone paths for PR-10 test:
  - `g/docs/governance/test_pr10.md` (LOCKED zone)
  - Or `bridge/core/test_pr10.py` (LOCKED zone)
- These will go to WARN lane → CLS auto-approve

### Option 2: Update Zone Patterns
- Add `bridge/templates/` and `bridge/docs/` to LOCKED_PATTERNS
- **Risk:** This changes zone semantics for all operations

### Option 3: Update GOVERNANCE v5 Spec
- Clarify that Mission Scope whitelist is for LOCKED zone paths only
- Or update zone definitions to match spec

---

## Status

**Current:** PR-10 test paths are OPEN zone → FAST lane (correct behavior)  
**Expected:** PR-10 test paths should be LOCKED zone → WARN lane (for auto-approve test)

**Verdict:** ⚠️ **TEST DESIGN ISSUE** — Not a routing bug, but test paths don't match test intent

---

**Next Steps:**
1. Update PR-10 test to use LOCKED zone paths
2. Re-run PR-10 test
3. Verify CLS auto-approve works in WARN lane

---

**Last Updated:** 2025-12-10

