# Governance: LAC Allowed Write Paths - Implementation Plan

**Date:** 2025-12-06  
**Type:** Policy Specification  
**Status:** ✅ **IMPLEMENTED** - 2025-12-06  
**Owner:** Governance / Policy Team  
**Evidence:** `g/reports/code_review_governance_lac_v1_20251206.md`

---

## 🎯 **OBJECTIVE**

Define safe write zones for LAC to enable file creation in test suite and production workflows, while maintaining system security boundaries.

**Goal:** Change test suite results from `SKIP` (governance blocked) → `PASS` (file created), without compromising system security.

---

## 📊 **CURRENT STATE**

**Problem:**
- LAC sets `source: "LAC"` in Work Orders
- Governance Router doesn't recognize "LAC" → normalizes to "UNKNOWN"
- "UNKNOWN" writer → `writer_not_allowed` → file writes denied

**Evidence:**
```json
{
  "zone": "open_zone",
  "allowed": false,
  "writer": "UNKNOWN",
  "normalized_writer": "UNKNOWN",
  "reason": "writer_not_allowed"
}
```

**Impact:**
- Test suite: 3 tests SKIP (file creation blocked)
- Production: LAC cannot create reports, tools, or output files

---

## ✅ **REQUIRED CHANGES**

### **Change 1: Add LAC to CANON_WRITERS**

**File:** `shared/governance_router_v41.py`  
**Line:** ~14-22

**Current:**
```python
CANON_WRITERS: Dict[str, str] = {
    "gg": "GG",
    "gc": "GC",
    "liam": "LIAM",
    "cls": "CLS",
    "codex": "CODEX",
    "gmx": "GMX",
    "clc": "CLC",
}
```

**Change:**
```python
CANON_WRITERS: Dict[str, str] = {
    "gg": "GG",
    "gc": "GC",
    "liam": "LIAM",
    "cls": "CLS",
    "codex": "CODEX",
    "gmx": "GMX",
    "clc": "CLC",
    "lac": "LAC",  # ← ADD THIS
}
```

**Why:** Enables `normalize_writer("LAC")` → `"LAC"` (not "UNKNOWN")

---

### **Change 2: Add LAC to open_zone.allowed_writers**

**File:** `g/governance/zone_definitions_v41.yaml`  
**Line:** ~35-41

**Current:**
```yaml
open_zone:
  allowed_writers:
    - "GG"
    - "GC"
    - "LIAM"
    - "CLS"
    - "CODEX"
    - "GMX"
```

**Change:**
```yaml
open_zone:
  allowed_writers:
    - "GG"
    - "GC"
    - "LIAM"
    - "CLS"
    - "CODEX"
    - "GMX"
    - "LAC"  # ← ADD THIS
```

**Why:** Enables `check_writer_permission("LAC", "open_zone")` → `True`

---

## 🗺️ **LAC ALLOWED WRITE ZONES**

Based on `zone_definitions_v41.yaml`, LAC can write to **open_zone patterns**:

### ✅ **Allowed Paths:**

1. **Agent Code:**
   - `agents/lac_manager/**` - LAC Manager code
   - `agents/dev_oss/**` - Dev OSS worker (if LAC routes to it)

2. **Configuration:**
   - `g/config/lac_*.yaml` - LAC-specific configs
   - `g/config/lac_lanes.yaml` - Lane definitions

3. **Tools:**
   - `g/tools/lac_*.py` - LAC tools
   - `tools/test_lac_*.zsh` - LAC test scripts

4. **Reports:**
   - `g/reports/feature-dev/lac_*` - Feature dev reports
   - `g/reports/experimental/lac_*` - Experimental reports
   - `g/reports/dev/lac_*` - Dev reports
   - `g/reports/lac_*.md` - LAC reports (if in dev/experimental)

5. **Shared Utilities:**
   - `shared/lac_*.py` - LAC shared utilities

6. **Tests:**
   - `tests/lac_*.py` - LAC test files

7. **Documentation:**
   - `g/docs/lac_*.md` - LAC documentation
   - `g/manuals/lac_*.md` - LAC manuals

8. **Scratch Space (Proposed):**
   - `g/scratch/lac/**` - LAC temporary files (if pattern added)

---

### ❌ **Forbidden Paths (locked_zone):**

1. **Core Agent Code:**
   - `CLC/**` - CLC code (CLC-only)
   - `CLS/**` - CLS code (CLS-only)

2. **System Files:**
   - `g/reports/system/**` - System reports
   - `g/ai_contracts/**` - AI contracts
   - `g/catalog/**` - Catalog

3. **Core Infrastructure:**
   - `launchd/**` - LaunchAgents
   - `bridge/core/**` - Bridge core
   - `bridge/production/**` - Production bridge

4. **Protected Docs:**
   - `g/docs/AI_OP_001_v4.md`
   - `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md`
   - `g/docs/02LUKA_PHILOSOPHY_v1.3.md`

---

## 🧪 **TEST SUITE IMPACT**

**Current Test Results:**
```
Passed: 5
Failed: 0
Skipped: 3 (governance blocked)
```

**Expected After Fix:**
```
Passed: 8 (all tests)
Failed: 0
Skipped: 0
```

**Tests That Will Change:**
1. **Test 1: dev_oss** - File creation test
   - Current: SKIP (output file not created)
   - Expected: PASS (file created)

2. **Test 2: QA Report** - Report file creation
   - Current: SKIP (report file not created)
   - Expected: PASS (report file created)

3. **Test 3: Routing** - May improve timing
   - Current: PASS/SKIP (timing dependent)
   - Expected: PASS (consistent)

---

## 🔒 **SECURITY CONSIDERATIONS**

### **Why This Is Safe:**

1. **Zone-Based Protection:**
   - LAC only gets `open_zone` access
   - `locked_zone` remains CLC-only
   - Unknown paths default to `locked_zone`

2. **Pattern Matching:**
   - Governance checks file paths against patterns
   - LAC cannot write to locked patterns even if allowed_writers includes "LAC"

3. **Separation of Concerns:**
   - LAC writes to its own namespace (`lac_*`, `LAC/**`)
   - No overlap with CLC/CLS protected zones

4. **Test Coverage:**
   - Test suite verifies routing and processing
   - Can add governance-specific tests if needed

---

## 📋 **IMPLEMENTATION CHECKLIST**

- [ ] **Step 1:** Add `"lac": "LAC"` to `CANON_WRITERS` in `shared/governance_router_v41.py`
- [ ] **Step 2:** Add `"LAC"` to `open_zone.allowed_writers` in `g/governance/zone_definitions_v41.yaml`
- [ ] **Step 3:** Verify normalization:
  ```bash
  python3 -c "
  from shared.governance_router_v41 import normalize_writer
  assert normalize_writer('LAC') == 'LAC'
  assert normalize_writer('lac') == 'LAC'
  print('✅ Normalization OK')
  "
  ```
- [ ] **Step 4:** Run test suite:
  ```bash
  cd ~/02luka
  ./tools/test_lac_qa_suite.zsh
  ```
- [ ] **Step 5:** Verify telemetry shows `writer: "LAC"` and `allowed: true`
- [ ] **Step 6:** Check created files exist:
  ```bash
  # Test 1 output
  ls -la g/scratch/lac/test_output.txt  # or wherever test creates file
  # Test 2 report
  ls -la g/reports/lac_qa_test_report_qa_20251206.md
  ```
- [ ] **Step 7:** Verify no locked_zone writes attempted
- [ ] **Step 8:** Document in system log: "LAC writer role enabled in governance policy"

---

## 🔄 **ROLLBACK PLAN**

If issues arise:

1. **Revert Changes:**
   - Remove "LAC" from `CANON_WRITERS`
   - Remove "LAC" from `allowed_writers`

2. **Verify:**
   - Test suite should return to previous state (SKIP for file creation)
   - No new security issues

3. **Investigate:**
   - Check telemetry for unexpected writes
   - Review zone pattern matching

---

## 📊 **SUCCESS CRITERIA**

✅ **Implementation Successful If:**
- Test suite: 8 PASS, 0 FAIL, 0 SKIP
- Telemetry: `writer: "LAC"`, `allowed: true` for LAC WOs
- Files created in expected locations
- No writes to locked_zone patterns
- No regression in existing governance checks

---

## 🔗 **RELATED DOCUMENTS**

- **Clarification:** `g/reports/governance_lac_writer_clarification_20251206.md`
- **Incident Report:** `g/reports/lac_incident_resolution_v1_20251206.md`
- **Test Suite:** `tools/test_lac_qa_suite.zsh`
- **Governance Router:** `shared/governance_router_v41.py`
- **Zone Definitions:** `g/governance/zone_definitions_v41.yaml`

---

## 📝 **NOTES**

- This is a **policy change**, not a code bug fix
- LAC infrastructure is already working (verified by test suite)
- Changes are minimal (2 additions to existing configs)
- Security boundaries remain intact (zone-based protection)

---

**Status:** 📋 **PLAN** - Ready for implementation  
**Next:** Assign to Governance/Policy team for review and implementation
