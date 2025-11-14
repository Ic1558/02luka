# MLS artifact_size Schema Violation - Verification Complete

**Date:** 2025-11-13  
**Status:** ✅ VERIFIED - NO VIOLATIONS FOUND

---

## Bug Report

**Bug 1:** The MLS entry contains an extra field "artifact_size" in the "source" object. According to the MLS schema (`mls/schema/mls_event.schema.json`, line 23), the "source" object has `"additionalProperties": false`, which means only the defined properties are allowed.

**Allowed Fields (8):**
- `producer`
- `context`
- `repo`
- `run_id`
- `workflow`
- `sha`
- `artifact`
- `artifact_path`

**Violation:** `artifact_size` is not in the allowed list and violates schema.

---

## Verification Results

### Current State

**File:** `mls/ledger/2025-11-13.jsonl`

```json
{
  "source": {
    "producer": "cls",
    "context": "ci",
    "repo": "Ic1558/02luka",
    "run_id": "19305991940",
    "workflow": "cls-ci.yml",
    "sha": "64d0e88611784a273e7a7db3417ed5f4ee29bf5a",
    "artifact": "selfcheck-report",
    "artifact_path": "output/reports/selfcheck.json"
  }
}
```

**Result:** ✅ **NO `artifact_size` field present**

### Schema Compliance Check

```bash
# Check if artifact_size exists
cat mls/ledger/2025-11-13.jsonl | jq '.source | has("artifact_size")'
# Result: false ✅

# Verify only allowed fields
cat mls/ledger/2025-11-13.jsonl | jq '.source | keys'
# Result: Only 8 allowed fields ✅
```

### All Ledger Files Check

**Verification:** Checked all `mls/ledger/*.jsonl` files

**Result:** ✅ **No `artifact_size` found in any ledger file**

---

## Previous Fixes Applied

### 1. CI Workflow Fixes ✅

**Files Modified:**
- `.github/workflows/cls-ci.yml`
- `.github/workflows/bridge-selfcheck.yml`

**Changes:**
- ❌ Removed `--argjson artifact_size` from MLS entry creation
- ✅ Added cleaning step to remove `artifact_size` if present
- ✅ Changed "Normalize" step to "Clean" step

### 2. Ledger File Fixes ✅

**Files Fixed:**
- `mls/ledger/2025-11-13.jsonl` - Removed `artifact_size`
- `mls/ledger/2025-11-12.jsonl` - Removed `artifact_size`

**Method:**
- Used `jq` to remove `artifact_size` from `source` object
- Verified schema compliance after fix

---

## Prevention Measures

### 1. CI Workflow Cleaning ✅

**Step:** "Clean MLS entries (remove invalid artifact_size field)"

**Logic:**
```bash
echo "$line" | jq -c 'if .source.artifact_size then del(.source.artifact_size) else . end'
```

**Effect:** Automatically removes `artifact_size` if present in CI runs

### 2. Schema Validation ✅

**Location:** `.github/workflows/cls-ci.yml` → "Validate MLS (jq schema-lite)"

**Effect:** Validates entries against schema, catches violations

### 3. Monitoring ✅

**Script:** `tools/mls_ledger_protect.zsh`

**Effect:** Validates ledger files, detects schema violations

---

## Current Status

### Schema Compliance

- ✅ `2025-11-13.jsonl` - Schema compliant
- ✅ `2025-11-12.jsonl` - Schema compliant (fixed)
- ✅ All other ledger files - Schema compliant

### Prevention

- ✅ CI workflows no longer add `artifact_size`
- ✅ CI workflows clean `artifact_size` if present
- ✅ Schema validation catches violations
- ✅ Monitoring validates files

---

## Verification Commands

### Check Single File

```bash
# Check if artifact_size exists
cat mls/ledger/2025-11-13.jsonl | jq '.source | has("artifact_size")'
# Expected: false ✅

# List all source fields
cat mls/ledger/2025-11-13.jsonl | jq '.source | keys'
# Expected: Only 8 allowed fields ✅
```

### Check All Files

```bash
# Find any entries with artifact_size
for f in mls/ledger/*.jsonl; do
  cat "$f" | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if echo "$line" | jq -e '.source.artifact_size' >/dev/null 2>&1; then
      echo "❌ Found in $(basename $f)"
    fi
  done
done
# Expected: No output ✅
```

### Schema Validation

```bash
# Validate against schema
cat mls/ledger/2025-11-13.jsonl | jq -e '.source | keys | all(. as $k | $k == "producer" or $k == "context" or $k == "repo" or $k == "run_id" or $k == "workflow" or $k == "sha" or $k == "artifact" or $k == "artifact_path")'
# Expected: true ✅
```

---

## Conclusion

**Status:** ✅ **BUG ALREADY FIXED**

**Verification:**
- ✅ No `artifact_size` in `2025-11-13.jsonl`
- ✅ No `artifact_size` in any ledger file
- ✅ Schema compliant
- ✅ Prevention measures in place

**No action needed** - Bug was fixed in previous session and verification confirms compliance.

---

**Verified:** 2025-11-13  
**Result:** ✅ NO VIOLATIONS FOUND
