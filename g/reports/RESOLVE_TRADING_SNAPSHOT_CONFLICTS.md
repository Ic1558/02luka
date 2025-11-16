# Resolve Trading Snapshot Conflicts

**Branch:** `codex/fix-trading-cli-snapshot-naming-issue`  
**File:** `tools/trading_snapshot.zsh`  
**Date:** 2025-11-16

---

## Conflict Resolution Guide

When resolving conflicts in `tools/trading_snapshot.zsh`, follow these steps:

---

## Step 1: Identify Conflict Markers

Look for conflict markers in the file:

```
<<<<<<< HEAD
[Current branch code]
=======
[Incoming branch code]
>>>>>>> branch-name
```

---

## Step 2: Understand the Changes

### Our Changes (HEAD - the fix we're implementing):
- Add `normalize_filter_value()` helper function
- Modify filename construction to include filter parameters
- Add collision detection

### Incoming Changes (the other branch):
- May have other modifications to the snapshot function
- May have different formatting or structure

---

## Step 3: Resolution Strategy

### Option A: Keep Our Changes (Recommended)

If the incoming changes don't conflict with our filter fix:

1. **Keep the helper function:**
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

2. **Keep the modified filename construction:**
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

### Option B: Merge Both Changes

If the incoming branch has important changes we need to keep:

1. Keep the incoming changes that don't conflict
2. Add our filter fix on top
3. Ensure both sets of changes work together

---

## Step 4: Remove Conflict Markers

After resolving, remove all conflict markers:
- Remove `<<<<<<< HEAD`
- Remove `=======`
- Remove `>>>>>>> branch-name`

---

## Step 5: Verify Resolution

1. **Check syntax:**
```bash
zsh -n tools/trading_snapshot.zsh
```

2. **Test the function:**
```bash
# Test with no filters
# Test with single filter
# Test with multiple filters
# Test collision handling
```

---

## Common Conflict Scenarios

### Scenario 1: Function Signature Changed

**If incoming branch changed function parameters:**
- Keep the new signature
- Apply our filter logic to the new signature

### Scenario 2: Variable Names Changed

**If incoming branch renamed variables:**
- Use the new variable names
- Apply our filter logic with new names

### Scenario 3: Code Structure Changed

**If incoming branch refactored the code:**
- Keep the new structure
- Integrate our filter logic into the new structure

---

## Resolution Checklist

- [ ] Identified all conflict markers
- [ ] Understood both sets of changes
- [ ] Chose resolution strategy
- [ ] Merged changes correctly
- [ ] Removed all conflict markers
- [ ] Verified syntax is correct
- [ ] Tested the function
- [ ] Committed the resolution

---

## After Resolution

1. **Stage the resolved file:**
```bash
git add tools/trading_snapshot.zsh
```

2. **Commit the resolution:**
```bash
git commit -m "Resolve conflicts in trading_snapshot.zsh - include filter parameters in filename"
```

3. **Continue merge/rebase:**
```bash
# If merging:
git merge --continue

# If rebasing:
git rebase --continue
```

---

## Need Help?

If conflicts are complex:
1. Review both versions carefully
2. Test each version separately
3. Merge incrementally
4. Test after each merge step

---

**Related Documentation:**
- Implementation Guide: `g/reports/TRADING_CLI_SNAPSHOT_FIX_IMPLEMENTATION.md`
- SPEC: `g/reports/feature_trading_snapshot_filename_filters_SPEC.md`
- PLAN: `g/reports/feature_trading_snapshot_filename_filters_PLAN.md`
