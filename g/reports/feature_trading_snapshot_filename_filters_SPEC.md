# Feature Specification: Trading CLI Snapshot Filename with Filters

**Date:** 2025-11-16  
**Feature:** Include filter parameters in trading snapshot filenames  
**Status:** 📋 **SPEC READY FOR REVIEW**  
**Priority:** P1 (Critical - Data Loss Risk)

---

## 1. Clarifying Questions

### Q1: Which filters should be included in filename?

**Question:** Which filter parameters should be incorporated into the snapshot filename?

**Current Filters (from issue description):**
- `--market` (market filter)
- `--account` (account filter)
- `--scenario` (scenario filter)
- `--tag` (tag filter)

**Options:**
- a) Include all filters (market, account, scenario, tag)
- b) Include only non-empty filters
- c) Include only specified filters (user-configurable)

**Default Assumption:** Option b) - Include only non-empty filters (most flexible, avoids empty suffixes)

### Q2: Filename Format and Normalization

**Question:** How should filter values be normalized for use in filenames?

**Constraints:**
- Filenames must be filesystem-safe
- Should be human-readable
- Should be sortable
- Should handle special characters in filter values

**Options:**
- a) Lowercase, replace spaces with underscores, remove special chars
- b) URL-encode filter values
- c) Hash filter values (less readable but safe)

**Default Assumption:** Option a) - Lowercase, underscore replacement, sanitize special chars (most readable)

### Q3: Filename Length Limits

**Question:** How to handle long filenames when multiple filters are used?

**Constraints:**
- Some filesystems have 255-byte filename limits
- Long filenames are hard to read
- Need to preserve uniqueness

**Options:**
- a) Truncate with hash suffix
- b) Use abbreviated filter names (mkt, acc, scn, tag)
- c) No limit (assume modern filesystem)

**Default Assumption:** Option b) - Use abbreviated prefixes (mkt_, acc_, scn_, tag_) to keep names concise

### Q4: Backward Compatibility

**Question:** Should we maintain backward compatibility with existing snapshot files?

**Current Behavior:**
- Files named: `trading_snapshot_<range>.json`
- No filter information in filename

**Options:**
- a) Breaking change - new format only
- b) Support both formats (detect and handle)
- c) Migration script to rename existing files

**Default Assumption:** Option a) - Breaking change (cleaner, but document migration path)

### Q5: Collision Detection

**Question:** What should happen if a file with the same name already exists?

**Options:**
- a) Overwrite silently (current behavior - bad)
- b) Warn and ask for confirmation
- c) Append timestamp to filename
- d) Error and abort

**Default Assumption:** Option c) - Append timestamp if file exists (safest, preserves all snapshots)

---

## 2. Feature Goals

### Primary Goal
Modify trading CLI snapshot command to include filter parameters in output filenames, preventing data loss from overwriting snapshots with different filter configurations.

### Success Criteria
- ✅ Snapshot filenames include relevant filter parameters
- ✅ Different filter combinations produce different filenames
- ✅ No silent overwrites of existing snapshots
- ✅ Filenames are filesystem-safe and human-readable
- ✅ Backward compatibility considered (or migration path documented)

---

## 3. Scope

### In Scope
- Modifying `base_name` construction in snapshot command
- Normalizing filter values for filename use
- Adding collision detection/avoidance
- Updating documentation

### Out of Scope
- Changing snapshot data format
- Modifying filter parsing logic
- Creating snapshot management/indexing system
- Migration of existing snapshot files (separate task)

---

## 4. Technical Requirements

### 4.1 Filename Format

**Proposed Format:**
```
trading_snapshot_<range>_<filters>.json
```

**Where:**
- `<range>` = existing range slug (e.g., `20250101-20250131`)
- `<filters>` = filter suffix (e.g., `mkt_TFEX_acc_BIZ01`)

**Examples:**
- No filters: `trading_snapshot_20250101-20250131.json`
- Market only: `trading_snapshot_20250101-20250131_mkt_TFEX.json`
- Market + Account: `trading_snapshot_20250101-20250131_mkt_TFEX_acc_BIZ01.json`
- All filters: `trading_snapshot_20250101-20250131_mkt_TFEX_acc_BIZ01_scn_test_tag_scalp.json`

### 4.2 Filter Value Normalization

**Rules:**
1. Convert to lowercase
2. Replace spaces with underscores
3. Remove or replace special characters (keep alphanumeric + underscore + hyphen)
4. Truncate if too long (max 20 chars per filter value)
5. Use abbreviated prefixes: `mkt_`, `acc_`, `scn_`, `tag_`

**Examples:**
- `"TFEX"` → `mkt_TFEX`
- `"BIZ-01"` → `acc_BIZ-01` (hyphen OK)
- `"Test Scenario"` → `scn_test_scenario`
- `"scalp strategy"` → `tag_scalp_strategy`

### 4.3 Collision Handling

**Strategy:**
1. Check if target file exists
2. If exists and identical filters → append timestamp: `_20251116_143022`
3. If exists and different filters → should not happen (different filename)
4. Log warning if collision detected

### 4.4 Code Changes Required

**File:** `tools/trading_cli.zsh`

**Location:** Lines 417-420 (approximate)

**Current Code:**
```bash
local normalized=$(printf '%s\n' "$snapshot_json" | jq -S '.')
local slug=$(snapshot_range_slug "$range_from" "$range_to")
local base_name="trading_snapshot_${slug}"
local json_path="$REPORT_DIR/${base_name}.json"
```

**Proposed Code:**
```bash
local normalized=$(printf '%s\n' "$snapshot_json" | jq -S '.')
local slug=$(snapshot_range_slug "$range_from" "$range_to")

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

# Handle collisions
if [[ -f "$json_path" ]]; then
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    json_path="$REPORT_DIR/${base_name}_${timestamp}.json"
    echo "Warning: File exists, appending timestamp: $(basename "$json_path")" >&2
fi
```

**Helper Function:**
```bash
normalize_filter_value() {
    local value="$1"
    # Convert to lowercase, replace spaces with underscores, remove special chars
    echo "$value" | tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9_-]//g' | \
        sed 's/  */_/g' | \
        cut -c1-20
}
```

---

## 5. Discovered Paths (Read-Only Scan)

### 5.1 Trading CLI Implementation
- **Location:** `tools/trading_cli.zsh` (in branch `codex/implement-02luka-trading-cli-v2-spec`)
- **Snapshot function:** Lines ~417-420
- **Report directory:** `$REPORT_DIR` (likely `g/reports/trading/` or similar)

### 5.2 Related Files
- Snapshot range slug function: `snapshot_range_slug()` (location TBD)
- Filter parameter parsing: Lines before snapshot function
- Documentation: `g/manuals/trading_*.md` (if exists)

---

## 6. Risk & Constraints

### 6.1 Data Loss Risk

**Current Risk:**
- ⚠️ **CRITICAL** - Files are silently overwritten
- Different filter combinations produce same filename
- No way to recover overwritten data

**Mitigation:**
- Include filters in filename (prevents collisions)
- Add collision detection as safety net
- Document breaking change

### 6.2 Breaking Changes

**Impact:**
- Scripts/tools expecting old filename format will break
- Existing snapshot files won't match new naming convention

**Mitigation:**
- Document migration path
- Consider backward compatibility mode (optional flag)
- Update all references to snapshot files

### 6.3 Filename Length

**Risk:**
- Long filter values + multiple filters = very long filenames
- Some filesystems have limits

**Mitigation:**
- Truncate filter values (max 20 chars)
- Use abbreviated prefixes
- Monitor filename length

---

## 7. Suggested Implementation

### 7.1 Helper Function

Create `normalize_filter_value()` function:
- Input: raw filter value
- Output: normalized, filesystem-safe string
- Max length: 20 characters

### 7.2 Filename Construction

1. Build base name with range slug
2. Collect non-empty filters
3. Normalize each filter value
4. Combine into filter suffix
5. Append to base name
6. Check for collisions
7. Append timestamp if collision detected

### 7.3 Testing Strategy

**Test Cases:**
1. No filters → original format (backward compatible)
2. Single filter → includes filter in name
3. Multiple filters → includes all filters
4. Special characters in filters → normalized correctly
5. Long filter values → truncated appropriately
6. File collision → timestamp appended
7. Same filters, different times → different files (timestamp)

---

## 8. Work Items for Implementation

### 8.1 Code Changes
- [ ] Add `normalize_filter_value()` helper function
- [ ] Modify `base_name` construction to include filters
- [ ] Add collision detection logic
- [ ] Update markdown file naming (if applicable)

### 8.2 Testing
- [ ] Test with no filters
- [ ] Test with single filter
- [ ] Test with multiple filters
- [ ] Test with special characters
- [ ] Test collision handling
- [ ] Test edge cases (empty values, very long values)

### 8.3 Documentation
- [ ] Update command help text
- [ ] Document new filename format
- [ ] Document breaking changes
- [ ] Add migration guide (if needed)

---

## 9. Assumptions

1. **Filter variables exist** - `$market`, `$account`, `$scenario`, `$tag` are available in scope
2. **REPORT_DIR is set** - Output directory is properly configured
3. **Filesystem is modern** - Supports reasonable filename lengths
4. **Breaking change acceptable** - Or backward compatibility mode can be added

---

## 10. Dependencies

1. **Trading CLI branch** - `codex/implement-02luka-trading-cli-v2-spec`
2. **Filter parsing** - Must be working correctly
3. **Range slug function** - `snapshot_range_slug()` must exist

---

## 11. Success Metrics

- ✅ No silent overwrites of snapshot files
- ✅ Different filter combinations produce different filenames
- ✅ Filenames are readable and include filter information
- ✅ All test cases pass
- ✅ Documentation updated

---

**Spec Status:** 📋 **READY FOR PLAN CREATION**  
**Next Step:** Create PLAN.md with detailed task breakdown

