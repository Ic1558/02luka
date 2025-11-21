# Feature-Dev Structure Deployment — PLAN

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Executor**: Liam (verification) → Boss (approval)

---

## 1. Overview

This plan outlines the deployment of the new feature-dev structure and naming convention.

**Effort**: Minimal (already completed)  
**Risk**: Very low (documentation only)  
**Duration**: 5 minutes (verification)

---

## 2. Deployment Steps

### Step 1: Verify Directory Structure ✅

**Command**:
```bash
tree g/reports/feature-dev -L 2
```

**Expected**:
```
g/reports/feature-dev/
├── README.md
├── deployment/
│   ├── 251121_feature_dev_structure_spec_v01.md
│   └── 251121_feature_dev_structure_plan_v01.md
├── v35_blueprint/
│   ├── 251121_v35_blueprint_spec_v01.md
│   └── 251121_v35_blueprint_plan_v01.md
├── wo_hybrid_blueprint/
│   ├── 251121_wo_hybrid_blueprint_spec_v01.md
│   └── 251121_wo_hybrid_blueprint_plan_v01.md
└── writer_policy_v35/
    ├── 251121_writer_policy_v35_spec_v01.md
    └── 251121_writer_policy_v35_plan_v01.md
```

**Status**: ✅ COMPLETE

---

### Step 2: Verify Naming Convention ✅

**Command**:
```bash
find g/reports/feature-dev -name "*_spec_*.md" -o -name "*_plan_*.md" | sort
```

**Expected**: All files follow `yymmdd_topic_spec/plan_vXX.md` format

**Status**: ✅ COMPLETE

---

### Step 3: Verify No Old Files ✅

**Command**:
```bash
ls g/reports/*.md 2>/dev/null | grep -v "feature-dev" || echo "✅ Clean"
```

**Expected**: No SPEC/PLAN files in root `g/reports/`

**Status**: ✅ COMPLETE

---

### Step 4: Update Liam Persona (If Needed)

**File**: `agents/liam/PERSONA_PROMPT.md`

**Check**: Does persona mention feature-dev structure?

**Action**: Add note about automatic file creation in feature-dev lane

**Status**: ⬜ PENDING

---

### Step 5: Log to AP/IO

**Event**: `feature_dev_structure_deployed`

**Data**:
```json
{
  "version": "v01",
  "date": "2025-11-21",
  "features_migrated": 3,
  "naming_convention": "yymmdd_topic_spec/plan_vXX.md",
  "directory": "g/reports/feature-dev/"
}
```

**Status**: ⬜ PENDING

---

## 3. Post-Deployment Verification

### Test 1: Create New Feature (Dry-Run)

**Scenario**: Boss requests a new feature

**Expected Behavior**:
1. Liam creates `g/reports/feature-dev/<feature_name>/`
2. Liam creates `yymmdd_topic_spec_v01.md`
3. Liam creates `yymmdd_topic_plan_v01.md`

**Status**: ⬜ TO BE TESTED

---

### Test 2: Update Existing Feature

**Scenario**: Boss requests changes to existing spec

**Expected Behavior**:
1. Liam creates `yymmdd_topic_spec_v02.md` (same date prefix)
2. Liam creates `yymmdd_topic_plan_v02.md` (if needed)
3. Old v01 files remain for history

**Status**: ⬜ TO BE TESTED

---

## 4. Rollback Plan

**Trigger**: If new structure causes confusion or issues

**Steps**:
1. Move files back to `g/reports/` root
2. Rename to old format (without date prefix)
3. Delete `feature-dev/` directory
4. Revert Liam persona changes

**Estimated Time**: 5 minutes

**Risk**: Very low (no code changes, only file organization)

---

## 5. Communication Plan

### Internal (Agents):
- ✅ Liam: Updated to use new structure automatically
- ⬜ GMX: No changes needed (doesn't create these files)
- ⬜ Hybrid: No changes needed (executes WOs only)

### External (Boss):
- ⬜ Notify Boss of new structure
- ⬜ Share README.md for reference
- ⬜ Confirm approval before marking as deployed

---

## 6. Success Metrics

- [x] All files migrated successfully
- [x] Naming convention applied consistently
- [x] README.md created and accurate
- [ ] Liam uses new convention automatically
- [ ] Boss approves new structure

---

## 7. Next Steps

1. ⬜ Boss reviews and approves deployment
2. ⬜ Log deployment to AP/IO
3. ⬜ Update Liam persona (if needed)
4. ⬜ Test with new feature request
5. ⬜ Mark deployment as complete

---

**Status**: ✅ DEPLOYMENT PLAN COMPLETE - AWAITING APPROVAL
