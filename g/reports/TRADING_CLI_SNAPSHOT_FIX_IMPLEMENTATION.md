# Trading CLI Snapshot Filename Fix - Implementation Guide

**Date:** 2025-11-16  
**Branch:** `codex/implement-02luka-trading-cli-v2-spec`  
**File:** `tools/trading_cli.zsh`  
**Lines:** 417-420 (approximate)

---

## Problem

The snapshot subcommand writes to `trading_snapshot_<range>.{json,md}` regardless of filter parameters (market, account, scenario, tag), causing silent data loss when different filter combinations overwrite each other.

---

## Solution

Include filter parameters in the snapshot filename and add collision detection.

---

## Implementation Steps

### Step 1: Add Helper Function

Add this function **before** the snapshot function (around line 400):

```bash
normalize_filter_value() {
    local value="$1"
    # Convert to lowercase, replace spaces with underscores, remove special chars, truncate
    echo "$value" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9_-]//g' | \
        sed 's/  */_/g' | \
        cut -c1-20
}
```

### Step 2: Modify Filename Construction

**Find this code (around lines 417-420):**

```bash
local normalized=$(printf '%s\n' "$snapshot_json" | jq -S '.')
local slug=$(snapshot_range_slug "$range_from" "$range_to")
local base_name="trading_snapshot_${slug}"
local json_path="$REPORT_DIR/${base_name}.json"
```

**Replace with:**

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

### Step 3: Update Markdown File Naming (if applicable)

If there's a markdown file generated with the same base name, apply the same logic:

**Find:**
```bash
local md_path="$REPORT_DIR/${base_name}.md"
```

**Replace with:**
```bash
local md_path="$REPORT_DIR/${base_name}.md"

# Handle collisions for markdown file too
if [[ -f "$md_path" ]]; then
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    md_path="$REPORT_DIR/${base_name}_${timestamp}.md"
fi
```

---

## Expected Behavior

### Before Fix
```bash
# Both commands create the same file (second overwrites first)
trading_cli.zsh snapshot --day 2025-01-01 --account A
# Creates: trading_snapshot_20250101.json

trading_cli.zsh snapshot --day 2025-01-01 --account B
# Overwrites: trading_snapshot_20250101.json ❌
```

### After Fix
```bash
# Different filter combinations create different files
trading_cli.zsh snapshot --day 2025-01-01 --account A
# Creates: trading_snapshot_20250101_acc_a.json ✅

trading_cli.zsh snapshot --day 2025-01-01 --account B
# Creates: trading_snapshot_20250101_acc_b.json ✅

# No overwrite! ✅
```

### Collision Handling
```bash
# Same command run twice
trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
# Creates: trading_snapshot_20250101_mkt_TFEX.json

trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
# Creates: trading_snapshot_20250101_mkt_TFEX_20251116_143022.json
# Warning: File exists, appending timestamp ✅
```

---

## Filename Examples

| Filters | Filename |
|---------|----------|
| None | `trading_snapshot_20250101.json` |
| `--market TFEX` | `trading_snapshot_20250101_mkt_TFEX.json` |
| `--account BIZ-01` | `trading_snapshot_20250101_acc_BIZ-01.json` |
| `--market TFEX --account BIZ01` | `trading_snapshot_20250101_mkt_TFEX_acc_BIZ01.json` |
| `--account "Test Account"` | `trading_snapshot_20250101_acc_test_account.json` |
| All filters | `trading_snapshot_20250101_mkt_TFEX_acc_BIZ01_scn_test_tag_scalp.json` |

---

## Testing

After implementation, test with:

```bash
# Test 1: No filters (backward compatibility)
trading_cli.zsh snapshot --day 2025-01-01
# Expected: trading_snapshot_20250101.json

# Test 2: Single filter
trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
# Expected: trading_snapshot_20250101_mkt_TFEX.json

# Test 3: Multiple filters
trading_cli.zsh snapshot --day 2025-01-01 --market TFEX --account BIZ01
# Expected: trading_snapshot_20250101_mkt_TFEX_acc_BIZ01.json

# Test 4: Special characters
trading_cli.zsh snapshot --day 2025-01-01 --account "Test Account"
# Expected: trading_snapshot_20250101_acc_test_account.json

# Test 5: Collision handling
trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
trading_cli.zsh snapshot --day 2025-01-01 --market TFEX
# Expected: Second file has timestamp suffix
```

---

## Verification Checklist

- [ ] Helper function `normalize_filter_value()` added
- [ ] Filename construction modified to include filters
- [ ] Collision detection added
- [ ] Markdown file naming updated (if applicable)
- [ ] Tested with no filters (backward compatibility)
- [ ] Tested with single filter
- [ ] Tested with multiple filters
- [ ] Tested with special characters
- [ ] Tested collision handling
- [ ] Verified no overwrites occur

---

## Related Documentation

- **SPEC:** `g/reports/feature_trading_snapshot_filename_filters_SPEC.md`
- **PLAN:** `g/reports/feature_trading_snapshot_filename_filters_PLAN.md`

---

**Implementation Status:** 📋 **READY FOR IMPLEMENTATION**  
**Priority:** P1 (Critical - Data Loss Risk)
