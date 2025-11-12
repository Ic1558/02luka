# Feature SPEC: Fix gg_nlp_bridge AWK Syntax Error

**Feature ID:** `fix_gg_nlp_bridge_awk_error`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Objective

Fix the AWK syntax error in `gg_nlp_bridge` script that's causing log errors. The error indicates a malformed regex pattern in an `awk match()` function.

---

## Problem Statement

**Error from Log:**
```
awk: syntax error at source line 6
 context is
      if (match($0, >>>  /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, <<< 
awk: illegal statement at source line 6
```

**Issues Identified:**
1. Malformed regex pattern with `>>>` and `<<<` markers (should not be there)
2. Incomplete regex pattern (missing closing delimiter)
3. AWK `match()` function syntax error
4. Pattern appears to be parsing key-value pairs (likely JSON/YAML parsing)

**Impact:**
- `gg_nlp_bridge` script failing
- NLP bridge functionality broken
- Error logs being generated

---

## Root Cause Analysis

**Likely Causes:**
1. **Regex Pattern Issue:** The pattern `/^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/` is malformed
   - May be missing proper escaping
   - May have incorrect delimiter placement
   - The `>>>` and `<<<` suggest debug markers left in code

2. **AWK Syntax:** AWK `match()` function requires:
   ```awk
   if (match($0, /pattern/, arr)) { ... }
   ```
   Not: `if (match($0, >>> /pattern/, <<< arr))`

3. **Script Location:** Need to find the actual script causing this error

---

## Solution Approach

### Step 1: Locate the Script
- Search for scripts using `gg_nlp_bridge` or `nlp_bridge`
- Check LaunchAgents for related services
- Check Python scripts in `agents/` directory
- Check shell scripts in `tools/` directory

### Step 2: Fix AWK Syntax
- Remove `>>>` and `<<<` markers
- Fix regex pattern syntax
- Ensure proper AWK `match()` function usage
- Test with sample input

### Step 3: Validate Fix
- Run script with test input
- Verify no AWK errors
- Check log files for errors
- Test NLP bridge functionality

---

## Technical Details

### AWK `match()` Function Correct Syntax

**Incorrect (from error):**
```awk
if (match($0, >>>  /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, <<< arr))
```

**Correct:**
```awk
if (match($0, /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, arr))
```

**Or with proper escaping:**
```awk
if (match($0, /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, arr)) {
    key = arr[1]
    value = arr[2]
    # process key-value pair
}
```

### Pattern Purpose
The pattern appears to parse:
- Quoted or unquoted keys: `"key"` or `key`
- Colon separator: `:`
- Values: alphanumeric, dots, underscores, hyphens

**Example matches:**
- `"key": value`
- `key: value123`
- `"my-key": test_value`

---

## Success Criteria

### Functional
- ✅ Script runs without AWK syntax errors
- ✅ NLP bridge functionality works
- ✅ No errors in log files
- ✅ Key-value parsing works correctly

### Quality
- ✅ Code is clean (no debug markers)
- ✅ Proper error handling
- ✅ Logs are informative

---

## Dependencies

- AWK (standard macOS/Unix)
- Script that uses `gg_nlp_bridge`
- LaunchAgent (if applicable)

---

## Risk Assessment

### Low Risk
- Fixing syntax error (doesn't change logic)
- Simple regex pattern correction
- Easy to test and verify

### Mitigation
- Test with sample input before deploying
- Keep backup of original script
- Verify LaunchAgent still works after fix

---

## References

- **Error Log:** `logs/gg_nlp_bridge.20251112_052244.log`
- **AWK Documentation:** Standard AWK `match()` function

