# Phase 1 Mismatch Fixes - Summary

**Date:** 2025-12-07  
**Status:** ✅ FIXED

---

## 🔧 **Issues Fixed**

### 1. **PAULA Target Mismatch** ✅

**Problem:**
- `routing_hint_mapping.trading` → `PAULA`
- `directories.targets.PAULA` exists
- But `supported_targets` did NOT include `PAULA`

**Impact:**
- WO with `routing_hint: trading` would map to `PAULA`
- But `route_wo()` checks `if mapped_target in self.supported_targets`
- Result: `PAULA` rejected → `target = None` → moved to error/

**Fix:**
- Added `PAULA` to `supported_targets` in:
  - ✅ `251207_mary_router_phase1_config_draft.yaml`
  - ✅ `251207_mary_router_phase1_multi_target_SPEC.md`
  - ✅ `251207_mary_router_phase1_checklist.md`

---

### 2. **Default Config Mismatch** ✅

**Problem:**
- `_default_config()` in code still Phase 0 (CLC-only)
- YAML draft has Phase 1 (CLC, GMX, LOCAL, KIM, PAULA)
- Mismatch between code defaults and config draft

**Impact:**
- If config file missing → uses `_default_config()` → only CLC supported
- If config file exists → uses YAML → 5 targets supported
- Inconsistent behavior

**Fix:**
- Updated SPEC to show `_default_config()` should include all Phase 1 targets
- Checklist Step 5 now specifies full target list

**Note:** Actual code update needed in implementation (Step 5 of checklist)

---

### 3. **Telemetry Format Verification** ✅

**Status:** Already correct

**Verification:**
- `log_telemetry()` uses `json.dumps(event) + "\n"` → JSONL format ✅
- Checklist `jq` command updated to handle JSONL properly:
  ```bash
  tail -10 g/telemetry/gateway_v3_router.log | jq -r '.target_inbox // .target // empty'
  ```

---

## ✅ **Files Updated**

1. `251207_mary_router_phase1_config_draft.yaml`
   - Added `PAULA` to `supported_targets`

2. `251207_mary_router_phase1_multi_target_SPEC.md`
   - Added `PAULA` to all config examples
   - Updated `_default_config()` example to include all 5 targets

3. `251207_mary_router_phase1_checklist.md`
   - Updated Step 5 default config example
   - Fixed telemetry check command (JSONL-safe)

---

## 🎯 **Consistency Check**

**All configs now aligned:**

| Component | Targets |
|-----------|---------|
| `supported_targets` | CLC, GMX, LOCAL, KIM, PAULA ✅ |
| `routing_hint_mapping` | dev_oss→GMX, dev_oss_lane→CLC, local_fix→LOCAL, trading→PAULA ✅ |
| `directories.targets` | CLC, GMX, LOCAL, KIM, PAULA ✅ |
| `_default_config()` (spec) | CLC, GMX, LOCAL, KIM, PAULA ✅ |

**All targets in `routing_hint_mapping` and `directories.targets` are now in `supported_targets`** ✅

---

## 📝 **Next Steps**

1. ✅ Config draft ready (all mismatches fixed)
2. ⏳ Implementation: Follow checklist Step 5 to update `_default_config()` in code
3. ⏳ Testing: Verify PAULA routing works with `routing_hint: trading`

---

**Status:** Ready for implementation - no config mismatches remaining
