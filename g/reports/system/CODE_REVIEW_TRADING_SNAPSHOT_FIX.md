# Code Review: Trading Snapshot Filename Fix

**Date:** 2025-11-16  
**Reviewer:** GG-Orchestrator  
**Files Reviewed:**
- `tools/trading_snapshot.zsh`
- `tools/fix_ci_path_guard.zsh`
- `g/reports/system/` (file moves)

---

## Style Check

### ✅ Shell Script Standards

**`tools/trading_snapshot.zsh`:**
- ✅ Uses `#!/usr/bin/env zsh` shebang
- ✅ Has `set -euo pipefail` for safety
- ✅ Uses `local` for all variables
- ✅ Proper function documentation
- ✅ Consistent indentation (4 spaces)

**`tools/fix_ci_path_guard.zsh`:**
- ✅ Uses `#!/usr/bin/env zsh` shebang
- ✅ Has `set -euo pipefail` for safety
- ✅ Uses `local` for variables
- ✅ Good error handling
- ✅ Clear output messages

### ⚠️ Minor Style Issues

1. **Line 53 in trading_snapshot.zsh**: Missing timestamp variable declaration (FIXED)
2. **Line 34**: Uses `2>/dev/null || echo` fallback - acceptable but could be more explicit

---

## History-Aware Review

### Context
- **Issue:** P1 bug - snapshot files overwritten when different filter combinations used
- **Solution:** Include filter parameters in filenames
- **SPEC/PLAN:** `feature_trading_snapshot_filename_filters_SPEC.md` and `PLAN.md` exist
- **Implementation:** Standalone function created (`trading_snapshot.zsh`)

### Related Changes
- CI Path Guard fix: Moved report files to `g/reports/system/`
- Trading import: Already has filter support (`tools/trading_import.zsh`)
- This fix complements existing trading infrastructure

---

## Obvious-Bug Scan

### ✅ Fixed Issues

1. **Missing timestamp variable** (line 53) - FIXED
   - Was: `json_path="$REPORT_DIR/${base_name}_${timestamp}.json"` (undefined variable)
   - Now: `local timestamp=$(date '+%Y%m%d_%H%M%S')` added

### ⚠️ Potential Issues

1. **Line 34: `snapshot_range_slug` function dependency**
   - Uses `2>/dev/null || echo` fallback
   - **Risk:** Low - has fallback to `${range_from}_${range_to}`
   - **Mitigation:** Acceptable, function may not exist in all contexts

2. **Line 31: `jq -S` dependency**
   - Requires `jq` to be installed
   - **Risk:** Medium - script will fail if `jq` not available
   - **Mitigation:** Should check for `jq` or handle gracefully

3. **Line 59: File overwrite risk**
   - Uses `>` instead of `>>` for JSON write
   - **Risk:** Low - collision detection prevents overwrites
   - **Note:** Intentional - creates new file each time

4. **Line 82: Markdown generation**
   - Always generates markdown even if not needed
   - **Risk:** Low - but could be optional
   - **Note:** Acceptable for now, can be made optional later

---

## Risk Summary

| Risk | Severity | Impact | Mitigation |
|------|----------|--------|------------|
| Missing `jq` dependency | Medium | Script fails | Should add check or graceful degradation |
| `snapshot_range_slug` missing | Low | Uses fallback | Has fallback, acceptable |
| Timestamp variable bug | High | Fixed | ✅ Fixed |
| File overwrite | Low | Collision detection prevents | ✅ Protected |

---

## Diff Hotspots

### Primary Changes

**`tools/trading_snapshot.zsh` (NEW FILE):**
- Lines 9-17: `normalize_filter_value()` helper function
- Lines 36-46: Filter suffix construction logic
- Lines 51-56: Collision detection
- Lines 61-66: Markdown collision handling

**`tools/fix_ci_path_guard.zsh` (NEW FILE):**
- Lines 16-22: File discovery logic
- Lines 30-37: File moving loop
- Lines 43-49: Verification logic

**`g/reports/system/` (FILE MOVES):**
- Multiple `.md` files moved from `g/reports/` root
- Fixes CI Path Guard check

---

## Code Quality Assessment

### Strengths

1. **Clear separation of concerns**
   - Helper function for normalization
   - Main function for snapshot logic
   - Collision detection separate

2. **Good error handling**
   - Collision detection prevents overwrites
   - Fallback for missing `snapshot_range_slug`
   - Warning messages on collisions

3. **Backward compatibility**
   - No filters = original format
   - Existing behavior preserved

4. **Filesystem safety**
   - Filter normalization prevents invalid filenames
   - Truncation prevents overly long names

### Areas for Improvement

1. **Dependency checking**
   - Should check for `jq` before use
   - Should verify `REPORT_DIR` is writable

2. **Error handling**
   - Could add more explicit error messages
   - Could handle `jq` failures gracefully

3. **Testing**
   - Needs integration tests
   - Should test edge cases (very long filter values, special chars)

---

## Testing Recommendations

### Unit Tests Needed

1. **`normalize_filter_value()` function:**
   - Test with special characters
   - Test with spaces
   - Test with very long strings
   - Test with empty string

2. **Filter suffix construction:**
   - Test with no filters
   - Test with single filter
   - Test with all filters
   - Test with empty filter values

3. **Collision detection:**
   - Test when file exists
   - Test when file doesn't exist
   - Test timestamp format

### Integration Tests Needed

1. End-to-end snapshot creation
2. Multiple snapshots with different filters
3. Collision handling
4. Backward compatibility (no filters)

---

## Security Considerations

### ✅ Safe Practices

- No command injection risks (uses parameter expansion)
- No file system traversal (normalizes paths)
- No sensitive data exposure (only writes provided JSON)

### ⚠️ Considerations

- Filter values are user-controlled input
- Normalization prevents most issues
- Truncation prevents path length attacks

---

## Performance Considerations

### ✅ Efficient

- Single-pass filter processing
- Minimal file I/O
- No unnecessary operations

### ⚠️ Potential Optimizations

- Could cache `snapshot_range_slug` result
- Could batch file operations
- Markdown generation could be optional

---

## Final Verdict

### ✅ **APPROVED with Minor Recommendations**

**Reasons:**
1. ✅ **Fixes critical P1 bug** - Prevents data loss from overwrites
2. ✅ **Well-structured code** - Clear functions, good separation
3. ✅ **Backward compatible** - Doesn't break existing behavior
4. ✅ **Safe implementation** - Collision detection, normalization
5. ⚠️ **Minor improvements needed** - Dependency checks, error handling

**Recommendations:**
1. Add `jq` dependency check
2. Add integration tests
3. Consider making markdown generation optional
4. Add more explicit error messages

**Overall:** The implementation is solid and addresses the critical bug. The code is clean, well-documented, and follows shell script best practices. Minor improvements can be made in follow-up PRs.

---

**Review Status:** ✅ **APPROVED**

**Next Steps:**
1. ✅ Commit changes
2. ⏳ Push to trigger CI
3. ⏳ Verify CI passes
4. ⏳ Run integration tests

---

**Maintained by:** GG-Orchestrator  
**Last Updated:** 2025-11-16
