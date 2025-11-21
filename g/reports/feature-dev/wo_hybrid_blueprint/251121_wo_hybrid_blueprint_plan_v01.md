# WO HYBRID Blueprint Creation — PLAN

**Version**: V3.5  
**Date**: 2025-11-21  
**Owner**: Liam  
**Executor**: Boss (manual script run) → Hybrid (WO execution)

---

## 1. Overview

This plan outlines the steps to create a safe WO script that generates the V3.5 Blueprint via HYBRID executor.

**Effort**: Low  
**Risk**: Low  
**Duration**: 15 minutes

---

## 2. Implementation Steps

### Step 1: Create WO Script with Fixes

**File**: `~/wo_create_v35_blueprint.zsh`

**Improvements from Boss's version**:

1. **Fix path calculation**:
```bash
# Use git to find repo root (more reliable)
BASE="$(git -C "$HOME/02luka" rev-parse --show-toplevel 2>/dev/null || echo "$HOME/02luka")"
```

2. **Add WO existence check**:
```bash
if [[ -f "$WO_PATH" ]]; then
  echo "❌ ERROR: WO already exists at $WO_PATH"
  echo "Remove it first or use a different WO_ID"
  exit 1
fi
```

3. **Add success message**:
```bash
echo "✅ Created HYBRID WO at: $WO_PATH"
echo "📋 Next: Hybrid will process this WO and create the Blueprint"
```

4. **Add dry-run mode**:
```bash
DRY_RUN="${1:-}"
if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "Would create: $WO_PATH"
  cat "$WO_PATH" | jq '.' 2>/dev/null || cat "$WO_PATH"
  exit 0
fi
```

---

### Step 2: Create Improved WO Script

**Action**: Write complete script to `~/wo_create_v35_blueprint.zsh`

**Tool**: `write_to_file`

---

### Step 3: Make Script Executable

**Command**:
```bash
chmod +x ~/wo_create_v35_blueprint.zsh
```

---

### Step 4: Test (Dry-Run)

**Command**:
```bash
~/wo_create_v35_blueprint.zsh --dry-run
```

**Expected**: Shows WO JSON without creating file

---

### Step 5: Execute Script

**Command**:
```bash
~/wo_create_v35_blueprint.zsh
```

**Expected**: Creates `bridge/inbox/HYBRID/WO-250121-CREATE-V35-BLUEPRINT.json`

---

### Step 6: Verify WO File

**Command**:
```bash
cat ~/02luka/bridge/inbox/HYBRID/WO-250121-CREATE-V35-BLUEPRINT.json | jq '.'
```

**Check**:
- [ ] Valid JSON
- [ ] Correct `wo_id`
- [ ] Target path is `g/reports/250121_02luka_V3.5_Blueprint.md`
- [ ] AP/IO events configured
- [ ] Safety profile correct

---

### Step 7: Process WO (Hybrid)

**Action**: Hybrid executor processes the WO and creates the Blueprint file

**Expected Output**: `g/reports/250121_02luka_V3.5_Blueprint.md`

---

### Step 8: Log to AP/IO

**Event**: `wo_script_executed`

**Data**:
```json
{
  "wo_id": "WO-250121-CREATE-V35-BLUEPRINT",
  "target_agent": "HYBRID",
  "target_file": "g/reports/250121_02luka_V3.5_Blueprint.md",
  "script_path": "~/wo_create_v35_blueprint.zsh"
}
```

---

## 3. File Structure

```
~/wo_create_v35_blueprint.zsh           (WO creation script)
↓
bridge/inbox/HYBRID/
└── WO-250121-CREATE-V35-BLUEPRINT.json (WO file)
    ↓ (processed by Hybrid)
g/reports/
└── 250121_02luka_V3.5_Blueprint.md     (final blueprint)
```

---

## 4. Execution Order

1. ✅ Create SPEC.md
2. ✅ Create PLAN.md
3. ⬜ Create improved WO script
4. ⬜ Make script executable
5. ⬜ Test with dry-run
6. ⬜ Execute script
7. ⬜ Verify WO file
8. ⬜ Hybrid processes WO
9. ⬜ Verify Blueprint file created
10. ⬜ Log to AP/IO

---

## 5. Rollback Plan

**If WO creation fails**:
1. Delete `~/wo_create_v35_blueprint.zsh`
2. Delete WO file if partially created

**If Blueprint creation fails**:
1. Delete WO file from `bridge/inbox/HYBRID/`
2. Check Hybrid logs for errors
3. Fix WO JSON and retry

---

## 6. Testing

### Test 1: Dry-Run Mode
```bash
~/wo_create_v35_blueprint.zsh --dry-run
```
**Expected**: Shows WO JSON, no file created

### Test 2: WO Creation
```bash
~/wo_create_v35_blueprint.zsh
```
**Expected**: WO file created in `bridge/inbox/HYBRID/`

### Test 3: JSON Validation
```bash
jq '.' < bridge/inbox/HYBRID/WO-250121-CREATE-V35-BLUEPRINT.json
```
**Expected**: Valid JSON, no errors

---

## 7. Post-Implementation

1. Boss reviews generated Blueprint file
2. Boss edits/expands content as needed
3. Blueprint becomes V3.5 SOT reference
4. Link from main README or docs

---

**Status**: ✅ PLAN COMPLETE - READY FOR EXECUTION
