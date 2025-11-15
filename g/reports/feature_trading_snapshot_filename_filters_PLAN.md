# Feature Plan: Trading CLI Snapshot Filename with Filters

**Date:** 2025-11-16  
**Feature:** Include filter parameters in trading snapshot filenames  
**Status:** 📋 **PLAN READY FOR EXECUTION**  
**Priority:** P1 (Critical - Data Loss Risk)

---

## Executive Summary

Fix critical data loss bug in trading CLI snapshot command by including filter parameters (market, account, scenario, tag) in output filenames. This prevents silent overwrites when running snapshots with different filter combinations.

**Estimated Time:** 2-3 hours  
**Risk Level:** Medium (breaking change, but fixes critical bug)  
**Dependencies:** Branch `codex/implement-02luka-trading-cli-v2-spec`

---

## Task Breakdown

### Phase 1: Discovery & Analysis (30 min)

**Task 1.1: Examine Current Implementation**
- [ ] Checkout target branch: `codex/implement-02luka-trading-cli-v2-spec`
- [ ] Read `tools/trading_cli.zsh` snapshot function
- [ ] Identify filter parameter variables (`$market`, `$account`, `$scenario`, `$tag`)
- [ ] Locate `snapshot_range_slug()` function
- [ ] Understand current filename construction logic
- **Deliverable:** Understanding of current implementation
- **Time:** 15 min

**Task 1.2: Identify All Affected Code**
- [ ] Find all references to snapshot filenames
- [ ] Check for scripts/tools that read snapshot files
- [ ] Identify markdown file generation (if separate)
- [ ] Document current filename format usage
- **Deliverable:** Impact analysis document
- **Time:** 15 min

---

### Phase 2: Implementation (90 min)

**Task 2.1: Create Helper Function**
- [ ] Add `normalize_filter_value()` function
- [ ] Implement normalization rules:
  - Lowercase conversion
  - Space to underscore replacement
  - Special character removal
  - Length truncation (max 20 chars)
- [ ] Add unit tests or manual verification
- **Deliverable:** Helper function with tests
- **Time:** 20 min

**Task 2.2: Modify Filename Construction**
- [ ] Update lines 417-420 in `tools/trading_cli.zsh`
- [ ] Build filter suffix from non-empty filters
- [ ] Combine with range slug
- [ ] Update `base_name` variable
- **Deliverable:** Updated filename construction
- **Time:** 30 min

**Task 2.3: Add Collision Detection**
- [ ] Check if target file exists
- [ ] If exists, append timestamp to filename
- [ ] Add warning message to stderr
- [ ] Handle both JSON and Markdown files (if applicable)
- **Deliverable:** Collision detection logic
- **Time:** 20 min

**Task 2.4: Update Markdown File Naming (if applicable)**
- [ ] Check if markdown files use same naming
- [ ] Apply same filter suffix logic
- [ ] Ensure consistency between JSON and MD files
- **Deliverable:** Consistent naming across file types
- **Time:** 20 min

---

### Phase 3: Testing (45 min)

**Task 3.1: Create Test Cases**
- [ ] Test with no filters (backward compatibility)
- [ ] Test with single filter (market)
- [ ] Test with single filter (account)
- [ ] Test with multiple filters
- [ ] Test with special characters in filter values
- [ ] Test with long filter values (truncation)
- [ ] Test collision handling (file exists)
- **Deliverable:** Test case document
- **Time:** 15 min

**Task 3.2: Manual Testing**
- [ ] Run snapshot with no filters → verify filename
- [ ] Run snapshot with `--market TFEX` → verify `_mkt_TFEX` in name
- [ ] Run snapshot with `--account BIZ-01` → verify `_acc_BIZ-01` in name
- [ ] Run snapshot with multiple filters → verify all in name
- [ ] Run same command twice → verify timestamp appended on second run
- [ ] Verify files are not overwritten
- **Deliverable:** Test results
- **Time:** 30 min

---

### Phase 4: Documentation & Cleanup (30 min)

**Task 4.1: Update Command Help**
- [ ] Update `--help` text for snapshot command
- [ ] Document new filename format
- [ ] Add examples showing filter impact on filenames
- **Deliverable:** Updated help text
- **Time:** 10 min

**Task 4.2: Create Migration Guide**
- [ ] Document breaking changes
- [ ] Provide examples of old vs new filenames
- [ ] Suggest migration path for existing snapshots (if needed)
- [ ] Update any scripts that reference snapshot files
- **Deliverable:** Migration documentation
- **Time:** 20 min

---

## Test Strategy

### Test Approach

**Manual Testing:**
- Run actual snapshot commands with various filter combinations
- Verify filenames match expected format
- Verify no overwrites occur
- Verify collision handling works

**Edge Cases:**
- Empty filter values
- Very long filter values
- Special characters (spaces, symbols)
- Multiple filters with same values
- Filesystem limits

### Test Cases

**TC1: No Filters (Backward Compatibility)**
```
Command: trading_cli.zsh snapshot --day 2025-01-01
Expected: trading_snapshot_20250101.json
```

**TC2: Single Filter - Market**
```
Command: trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
Expected: trading_snapshot_20250101_mkt_TFEX.json
```

**TC3: Single Filter - Account**
```
Command: trading_cli.zsh snapshot --day 2025-01-01 --account "BIZ-01"
Expected: trading_snapshot_20250101_acc_BIZ-01.json
```

**TC4: Multiple Filters**
```
Command: trading_cli.zsh snapshot --day 2025-01-01 --market TFEX --account BIZ01
Expected: trading_snapshot_20250101_mkt_TFEX_acc_BIZ01.json
```

**TC5: Special Characters**
```
Command: trading_cli.zsh snapshot --day 2025-01-01 --account "Test Account"
Expected: trading_snapshot_20250101_acc_test_account.json
```

**TC6: Collision Handling**
```
Command 1: trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
Command 2: trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
Expected: Second file has timestamp suffix
```

**TC7: Long Filter Values**
```
Command: trading_cli.zsh snapshot --day 2025-01-01 --account "Very Long Account Name That Exceeds Limit"
Expected: trading_snapshot_20250101_acc_very_long_account_n.json (truncated)
```

---

## Implementation Details

### Filename Format

**Pattern:**
```
trading_snapshot_<range>_<filters>.json
trading_snapshot_<range>_<filters>_<timestamp>.json (if collision)
```

**Filter Suffix Construction:**
1. Collect non-empty filters: `market`, `account`, `scenario`, `tag`
2. Normalize each: lowercase, replace spaces, remove special chars, truncate
3. Add prefix: `mkt_`, `acc_`, `scn_`, `tag_`
4. Join with underscores: `mkt_TFEX_acc_BIZ01`

**Examples:**
- No filters: `trading_snapshot_20250101.json`
- Market: `trading_snapshot_20250101_mkt_TFEX.json`
- Market + Account: `trading_snapshot_20250101_mkt_TFEX_acc_BIZ01.json`
- All filters: `trading_snapshot_20250101_mkt_TFEX_acc_BIZ01_scn_test_tag_scalp.json`
- Collision: `trading_snapshot_20250101_mkt_TFEX_20251116_143022.json`

### Code Structure

**Helper Function:**
```bash
normalize_filter_value() {
    local value="$1"
    echo "$value" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9_-]//g' | \
        sed 's/  */_/g' | \
        cut -c1-20
}
```

**Main Logic:**
```bash
# Build filter suffix
local filter_parts=()
[[ -n "$market" ]] && filter_parts+=("mkt_$(normalize_filter_value "$market")")
[[ -n "$account" ]] && filter_parts+=("acc_$(normalize_filter_value "$account")")
[[ -n "$scenario" ]] && filter_parts+=("scn_$(normalize_filter_value "$scenario")")
[[ -n "$tag" ]] && filter_parts+=("tag_$(normalize_filter_value "$tag")")

local filter_suffix=""
if [[ ${#filter_parts[@]} -gt 0 ]]; then
    filter_suffix="_$(IFS='_'; echo "${filter_parts[*]}")"
fi

local base_name="trading_snapshot_${slug}${filter_suffix}"
local json_path="$REPORT_DIR/${base_name}.json"

# Collision detection
if [[ -f "$json_path" ]]; then
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    json_path="$REPORT_DIR/${base_name}_${timestamp}.json"
    echo "Warning: File exists, appending timestamp: $(basename "$json_path")" >&2
fi
```

---

## Risk Mitigation

### Risk 1: Breaking Changes
**Mitigation:**
- Document breaking change clearly
- Provide migration examples
- Consider optional flag for old format (if needed)

### Risk 2: Filename Length
**Mitigation:**
- Truncate filter values (max 20 chars)
- Use abbreviated prefixes
- Monitor in testing

### Risk 3: Special Characters
**Mitigation:**
- Aggressive normalization (remove non-alphanumeric)
- Test with various special characters
- Handle edge cases gracefully

### Risk 4: Collision Logic
**Mitigation:**
- Always append timestamp on collision
- Log warning message
- Preserve all snapshots

---

## Success Criteria

- ✅ Snapshot filenames include filter parameters
- ✅ Different filter combinations produce different filenames
- ✅ No silent overwrites occur
- ✅ Collision detection works correctly
- ✅ Filenames are filesystem-safe and readable
- ✅ All test cases pass
- ✅ Documentation updated

---

## Deliverables

1. **Updated Code** - `tools/trading_cli.zsh` with filter-aware filenames
2. **Helper Function** - `normalize_filter_value()` implementation
3. **Test Results** - Manual testing verification
4. **Documentation** - Updated help text and migration guide
5. **SPEC** - This specification document

---

## Timeline

**Phase 1: Discovery & Analysis** - 30 min
- Task 1.1: 15 min
- Task 1.2: 15 min

**Phase 2: Implementation** - 90 min
- Task 2.1: 20 min
- Task 2.2: 30 min
- Task 2.3: 20 min
- Task 2.4: 20 min

**Phase 3: Testing** - 45 min
- Task 3.1: 15 min
- Task 3.2: 30 min

**Phase 4: Documentation** - 30 min
- Task 4.1: 10 min
- Task 4.2: 20 min

**Total Estimated Time:** 3.25 hours

---

## Dependencies

1. **Branch Access** - `codex/implement-02luka-trading-cli-v2-spec`
2. **Filter Variables** - Must be available in snapshot function scope
3. **Range Slug Function** - `snapshot_range_slug()` must exist

---

## Next Steps

1. **Review SPEC** - Confirm approach and assumptions
2. **Checkout Branch** - Access target branch
3. **Examine Code** - Understand current implementation
4. **Implement Changes** - Follow task breakdown
5. **Test Thoroughly** - Verify all test cases
6. **Update Documentation** - Help text and migration guide

---

**Plan Status:** 📋 **READY FOR EXECUTION**  
**Priority:** P1 (Critical - Data Loss Risk)  
**Dependencies:** Branch access and code examination

---

## TODO List (For Implementation Tracking)

### Phase 1: Discovery & Analysis
- [ ] **Task 1.1**: Checkout branch `codex/implement-02luka-trading-cli-v2-spec`
- [ ] **Task 1.1**: Read `tools/trading_cli.zsh` snapshot function (lines ~417-420)
- [ ] **Task 1.1**: Identify filter variables (`$market`, `$account`, `$scenario`, `$tag`)
- [ ] **Task 1.1**: Locate `snapshot_range_slug()` function
- [ ] **Task 1.2**: Find all references to snapshot filenames
- [ ] **Task 1.2**: Check for scripts/tools reading snapshot files
- [ ] **Task 1.2**: Identify markdown file generation logic

### Phase 2: Implementation
- [ ] **Task 2.1**: Add `normalize_filter_value()` helper function
- [ ] **Task 2.1**: Implement lowercase conversion
- [ ] **Task 2.1**: Implement space-to-underscore replacement
- [ ] **Task 2.1**: Implement special character removal
- [ ] **Task 2.1**: Implement length truncation (max 20 chars)
- [ ] **Task 2.2**: Update lines 417-420 with filter suffix logic
- [ ] **Task 2.2**: Build filter_parts array from non-empty filters
- [ ] **Task 2.2**: Combine filter suffix with range slug
- [ ] **Task 2.3**: Add file existence check before write
- [ ] **Task 2.3**: Append timestamp on collision
- [ ] **Task 2.3**: Add warning message to stderr
- [ ] **Task 2.4**: Check markdown file naming (if exists)
- [ ] **Task 2.4**: Apply same filter logic to markdown files

### Phase 3: Testing
- [ ] **Task 3.1**: Document TC1 - No filters (backward compatibility)
- [ ] **Task 3.1**: Document TC2 - Single filter (market)
- [ ] **Task 3.1**: Document TC3 - Single filter (account)
- [ ] **Task 3.1**: Document TC4 - Multiple filters
- [ ] **Task 3.1**: Document TC5 - Special characters
- [ ] **Task 3.1**: Document TC6 - Collision handling
- [ ] **Task 3.1**: Document TC7 - Long filter values
- [ ] **Task 3.2**: Execute TC1 - Verify original format
- [ ] **Task 3.2**: Execute TC2 - Verify `_mkt_TFEX` in filename
- [ ] **Task 3.2**: Execute TC3 - Verify `_acc_BIZ-01` in filename
- [ ] **Task 3.2**: Execute TC4 - Verify all filters in filename
- [ ] **Task 3.2**: Execute TC5 - Verify normalization works
- [ ] **Task 3.2**: Execute TC6 - Verify timestamp appended on collision
- [ ] **Task 3.2**: Execute TC7 - Verify truncation works

### Phase 4: Documentation
- [ ] **Task 4.1**: Update `--help` text for snapshot command
- [ ] **Task 4.1**: Add filename format examples
- [ ] **Task 4.1**: Document filter impact on filenames
- [ ] **Task 4.2**: Document breaking changes
- [ ] **Task 4.2**: Create old vs new filename examples
- [ ] **Task 4.2**: Suggest migration path for existing snapshots
