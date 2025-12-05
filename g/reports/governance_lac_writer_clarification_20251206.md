# Governance Layer: LAC Writer Role Blocking - Clarification

**Date:** 2025-12-06  
**Type:** Policy/Configuration Issue  
**Status:** 🔍 **CLARIFIED** - Ready for rewrite

---

## 🎯 **PROBLEM SUMMARY**

**Governance Layer blocks LAC from writing files because:**
- LAC sets `source: "LAC"` in Work Orders
- Governance Router doesn't recognize "LAC" as a valid writer
- "LAC" → normalized to "UNKNOWN" → denied

---

## 🔍 **ROOT CAUSE ANALYSIS**

### **1. How Governance Router Works:**

**File:** `shared/governance_router_v41.py`

**Process:**
1. Reads `writer` or `source` from WO
2. Normalizes via `normalize_writer()` using `CANON_WRITERS` map
3. Checks if normalized writer is in `allowed_writers` for the zone
4. If writer is "UNKNOWN" → **DENY**

**Current CANON_WRITERS:**
```python
CANON_WRITERS = {
    "gg": "GG",
    "gc": "GC",
    "liam": "LIAM",
    "cls": "CLS",
    "codex": "CODEX",
    "gmx": "GMX",
    "clc": "CLC",
}
# ❌ "LAC" is MISSING
```

**Current open_zone.allowed_writers:**
```yaml
# g/governance/zone_definitions_v41.yaml
open_zone:
  allowed_writers:
    - "GG"
    - "GC"
    - "LIAM"
    - "CLS"
    - "CODEX"
    - "GMX"
# ❌ "LAC" is MISSING
```

---

### **2. What Happens When LAC Processes a WO:**

**LAC Manager Code:**
```python
# agents/lac_manager/lac_manager.py:90
source: "{task.get('source', 'LAC')}"
```

**Flow:**
1. LAC sets `source: "LAC"` in requirement
2. AI Manager passes WO to Governance Router
3. Governance Router calls `normalize_writer("LAC")`
4. `normalize_writer()` looks up "LAC" in `CANON_WRITERS`
5. **Not found** → returns `"UNKNOWN"`
6. `check_writer_permission("UNKNOWN", "open_zone")` → returns `False`
7. Result: `GOVERNANCE_DENY: writer_not_allowed`

**Evidence from Telemetry:**
```json
{
  "zone": "open_zone",
  "allowed": false,
  "writer": "UNKNOWN",
  "normalized_writer": "UNKNOWN",
  "lane": "dev_oss",
  "reason": "writer_not_allowed",
  "details": "Writer UNKNOWN not allowed for open_zone"
}
```

---

## 💡 **SOLUTION: Two-Part Fix**

### **Part 1: Add LAC to CANON_WRITERS**

**File:** `shared/governance_router_v41.py`

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

**Why:** So `normalize_writer("LAC")` → `"LAC"` (not "UNKNOWN")

---

### **Part 2: Add LAC to open_zone.allowed_writers**

**File:** `g/governance/zone_definitions_v41.yaml`

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

**Why:** So `check_writer_permission("LAC", "open_zone")` → `True`

---

## 📋 **WHAT PATHS CAN LAC WRITE TO?**

**Based on `zone_definitions_v41.yaml`:**

### ✅ **Allowed (open_zone patterns):**
- `agents/**` - Agent code
- `g/config/**` - Config files
- `shared/**` - Shared utilities
- `tests/**` - Test files
- `g/tools/**` - Tools
- `g/reports/feature-dev/**` - Feature dev reports
- `g/reports/experimental/**` - Experimental reports
- `g/reports/dev/**` - Dev reports
- `g/manuals/**` - Manuals
- `g/docs/**` - Documentation

### ❌ **Forbidden (locked_zone patterns):**
- `CLC/**` - CLC code
- `CLS/**` - CLS code
- `g/docs/AI_OP_001_v4.md` - Specific docs
- `g/reports/system/**` - System reports
- `g/ai_contracts/**` - AI contracts
- `g/catalog/**` - Catalog
- `launchd/**` - LaunchAgents
- `bridge/core/**` - Bridge core
- `bridge/production/**` - Production bridge

---

## 🔧 **IMPLEMENTATION CHECKLIST**

- [ ] **Step 1:** Add `"lac": "LAC"` to `CANON_WRITERS` in `shared/governance_router_v41.py`
- [ ] **Step 2:** Add `"LAC"` to `open_zone.allowed_writers` in `g/governance/zone_definitions_v41.yaml`
- [ ] **Step 3:** Test with sample WO:
  ```bash
  # Create test WO
  cat > bridge/inbox/ENTRY/WO-TEST-LAC-GOVERNANCE.yaml <<'YAML'
  id: WO-TEST-LAC-GOVERNANCE
  strict_target: LAC
  task:
    intent: "test governance fix"
    files: ["g/reports/test_lac_write.md"]
  YAML
  
  # Wait for processing
  # Check telemetry: should see writer="LAC" (not "UNKNOWN")
  # Check file: should be created
  ```
- [ ] **Step 4:** Verify telemetry shows `writer: "LAC"` and `allowed: true`
- [ ] **Step 5:** Run LAC QA test suite again - file creation tests should PASS

---

## 📊 **EXPECTED OUTCOME**

**Before Fix:**
```json
{
  "writer": "UNKNOWN",
  "normalized_writer": "UNKNOWN",
  "allowed": false,
  "reason": "writer_not_allowed"
}
```

**After Fix:**
```json
{
  "writer": "LAC",
  "normalized_writer": "LAC",
  "allowed": true,
  "reason": "allowed"
}
```

---

## 🔗 **RELATED FILES**

- **Governance Router:** `shared/governance_router_v41.py` (line 14-22, 82-84)
- **Zone Definitions:** `g/governance/zone_definitions_v41.yaml` (line 35-41)
- **LAC Manager:** `agents/lac_manager/lac_manager.py` (line 90)
- **Telemetry:** `g/telemetry/lac_events.jsonl` (shows "UNKNOWN" writer)

---

## ✅ **VERIFICATION COMMANDS**

```bash
# 1. Check current CANON_WRITERS
grep -A 10 "CANON_WRITERS" shared/governance_router_v41.py

# 2. Check current allowed_writers
grep -A 10 "allowed_writers:" g/governance/zone_definitions_v41.yaml

# 3. Test normalization
python3 -c "
from shared.governance_router_v41 import normalize_writer
print('LAC ->', normalize_writer('LAC'))
print('lac ->', normalize_writer('lac'))
"

# 4. Check telemetry for LAC writer
tail -20 g/telemetry/lac_events.jsonl | jq '.writer, .normalized_writer, .allowed'
```

---

**Status:** ✅ **CLARIFIED** - Ready for implementation
