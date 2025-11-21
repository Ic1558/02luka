# V3.5 Writer Policy — PLAN

**Version**: V3.5  
**Date**: 2025-11-21  
**Owner**: Liam  
**Executor**: Liam (design) → Hybrid (file creation)

---

## 1. Overview

This plan outlines the steps to create the formal V3.5 Writer Policy as a YAML file with enforcement mechanism.

**Effort**: Low  
**Risk**: Low  
**Duration**: 20 minutes

---

## 2. Implementation Steps

### Step 1: Create Writer Policy YAML (Improved)

**File**: `docs/WRITER_POLICY_V35.yaml`

**Improvements from Boss's version**:

1. **Add wo_specs zone** (missing in original):
```yaml
zones:
  wo_specs:
    description: "GMX-generated task specifications"
    paths:
      - "g/wo_specs/**"
    write_allowed: true
```

2. **Add enforcement section**:
```yaml
enforcement:
  method: "overseer_pre_check"
  implementation:
    - "All WOs validated against zone rules"
    - "Hybrid checks target path vs allowed zones"
    - "AP/IO logs all write attempts"
  validation_script: "tools/validate_writer_policy.zsh"
```

3. **Add examples section**:
```yaml
examples:
  allowed:
    - agent: "Hybrid"
      action: "write"
      path: "g/reports/my_report.md"
      result: "✅ ALLOWED (reports zone)"
  blocked:
    - agent: "Liam"
      action: "write"
      path: "tools/my_tool.py"
      result: "❌ BLOCKED (Liam cannot write)"
```

4. **Add version history**:
```yaml
version_history:
  "3.5":
    date: "2025-11-21"
    changes:
      - "Deprecated CLC/CLS as writers"
      - "Centralized writes through Hybrid"
      - "Added soft/hard safeguard distinction"
```

---

### Step 2: Create Complete Writer Policy File

**Action**: Write improved YAML to `docs/WRITER_POLICY_V35.yaml`

**Tool**: `write_to_file`

---

### Step 3: Create Validation Script (Optional)

**File**: `tools/validate_writer_policy.zsh`

**Purpose**: Validate WO against writer policy before execution

**Pseudocode**:
```bash
#!/usr/bin/env zsh
# Read WO JSON
# Extract target path
# Check against policy zones
# Return allowed/blocked
```

---

### Step 4: Log to AP/IO

**Event**: `writer_policy_defined`

**Data**:
```json
{
  "version": "3.5",
  "zones": 7,
  "writers": 5,
  "enforcement": "overseer_pre_check",
  "file": "docs/WRITER_POLICY_V35.yaml"
}
```

---

### Step 5: Update Documentation

**Files to update**:
1. `README.md` - Link to writer policy
2. `docs/AP_IO_V31_PROTOCOL.md` - Reference writer policy
3. `agents/liam/README.md` - Mention writer policy

---

## 3. File Structure

```
docs/
└── WRITER_POLICY_V35.yaml  (main policy)

tools/
└── validate_writer_policy.zsh  (optional validator)

g/reports/
├── 250121_Writer_Policy_V35_SPEC.md
└── 250121_Writer_Policy_V35_PLAN.md
```

---

## 4. Execution Order

1. ✅ Create SPEC.md
2. ✅ Create PLAN.md
3. ⬜ Create improved Writer Policy YAML
4. ⬜ (Optional) Create validation script
5. ⬜ Log to AP/IO
6. ⬜ Update documentation links

---

## 5. Testing

### Test 1: YAML Validation
```bash
yamllint docs/WRITER_POLICY_V35.yaml
```
**Expected**: No errors

### Test 2: Policy Query
```bash
yq '.zones.governance.write_allowed' docs/WRITER_POLICY_V35.yaml
```
**Expected**: `false`

### Test 3: Writer Check
```bash
yq '.writers.Hybrid.allowed_zones[]' docs/WRITER_POLICY_V35.yaml
```
**Expected**: List of allowed zones

---

## 6. Rollback Plan

**If policy causes issues**:
1. Revert `docs/WRITER_POLICY_V35.yaml`
2. Remove validation script if created
3. Restore previous behavior

**Risk**: None (policy is documentation, not enforcement code)

---

## 7. Post-Implementation

1. Boss reviews policy
2. Team familiarizes with zones and rules
3. Validation script integrated into WO processing (optional)
4. Policy becomes V3.5 governance reference

---

**Status**: ✅ PLAN COMPLETE - READY FOR EXECUTION
