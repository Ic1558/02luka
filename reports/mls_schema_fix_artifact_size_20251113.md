# MLS Schema Fix - artifact_size Field Removal

**Date:** 2025-11-13  
**Status:** ✅ FIXED  
**Issue:** Schema violation - `artifact_size` field in `source` object

---

## Problem

The MLS ledger entries contained an invalid field `artifact_size` in the `source` object, violating the schema constraint.

**Schema Constraint:**
- File: `mls/schema/mls_event.schema.json`
- Line 23: `"additionalProperties": false`
- Allowed fields in `source`: `producer`, `context`, `repo`, `run_id`, `workflow`, `sha`, `artifact`, `artifact_path`
- **NOT allowed:** `artifact_size`

**Impact:**
- Schema validation failures
- Potential issues with MLS processing tools
- Inconsistent data structure

---

## Root Cause

1. **CI Workflows** were adding `artifact_size` to `source` object
   - `.github/workflows/cls-ci.yml` (line 300)
   - `.github/workflows/bridge-selfcheck.yml` (line 373)

2. **Normalization Steps** were trying to backfill `artifact_size`
   - Both workflows had normalization steps that added the field

3. **Existing Entries** already contained the invalid field
   - `mls/ledger/2025-11-13.jsonl`
   - `mls/ledger/2025-11-12.jsonl`

---

## Fixes Applied

### 1. Fixed Ledger Entries ✅

**Files Fixed:**
- `mls/ledger/2025-11-13.jsonl` - Removed `artifact_size` from `source`
- `mls/ledger/2025-11-12.jsonl` - Removed `artifact_size` from all entries

**Method:**
```bash
jq -c 'del(.source.artifact_size)'
```

### 2. Fixed CI Workflows ✅

**Files Updated:**
- `.github/workflows/cls-ci.yml`
- `.github/workflows/bridge-selfcheck.yml`

**Changes:**
- Removed `artifact_size` from `source` object in MLS entry creation
- Removed `--argjson artifact_size` parameter
- Removed `artifact_size: $artifact_size` from source object

### 3. Replaced Normalization Steps ✅

**Old Behavior:**
- Normalization step tried to add `artifact_size` if missing
- Created duplicate entries with normalized data

**New Behavior:**
- Clean step removes `artifact_size` if present
- Ensures schema compliance
- No duplicate entries

**New Step:**
```bash
# Clean MLS entries (remove invalid artifact_size field)
# Removes artifact_size from source if present (schema violation)
```

---

## Verification

### Schema Compliance ✅

```bash
# Check if artifact_size exists
cat mls/ledger/2025-11-13.jsonl | jq '.source | has("artifact_size")'
# Result: false ✅

# Validate all files
./tools/mls_ledger_protect.zsh verify-all
# Result: ✅ All ledger files are valid
```

### Files Fixed ✅

- ✅ `mls/ledger/2025-11-13.jsonl` - Schema compliant
- ✅ `mls/ledger/2025-11-12.jsonl` - Schema compliant
- ✅ CI workflows - No longer add `artifact_size`
- ✅ Normalization steps - Now clean instead of add

---

## Prevention

### CI Workflows
- ✅ Removed `artifact_size` from entry creation
- ✅ Added cleaning step to remove if present
- ✅ Schema validation will catch future violations

### Protection Scripts
- ✅ `mls_ledger_protect.zsh` validates JSONL format
- ✅ `mls_ledger_monitor.zsh` monitors for corruption
- ✅ Git pre-commit hook protects against dangerous changes

---

## Notes

**Why `artifact_size` was removed:**
- Not in schema definition
- Schema has `additionalProperties: false`
- Violates strict schema validation

**If artifact size is needed:**
- Could be added to `summary` field as text
- Could be added to top-level (requires schema update)
- Currently not needed for MLS functionality

---

**Status:** ✅ COMPLETE - All schema violations fixed, prevention in place
