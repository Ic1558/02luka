# Impact Assessment Module V3.5 — PLAN

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Executor**: Hybrid (file creation) → Liam (integration)

---

## 1. Overview

This plan implements the automatic impact assessment module for V3.5 deploy protocol.

**Effort**: Medium  
**Risk**: Low  
**Duration**: 1-2 hours

---

## 2. Implementation Steps

### Step 1: Create Core Module

**File**: `g/core/impact_assessment_v35.py`

**Content**: Boss-provided code (complete implementation)

**Actions**:
1. Create `g/core/` directory if needed
2. Write module with all functions:
   - `assess_deploy_impact()`
   - `impact_report_to_apio_payload()`
   - Type definitions (`ChangeSummary`, `ImpactReport`)

**Tool**: `write_to_file`

---

### Step 2: Create Deploy Templates

**Files**:
1. `g/templates/deploy/minimal_summary.md`
2. `g/templates/deploy/full_summary.md`
3. `g/templates/deploy/rollback.zsh`

**Content**: Boss-provided templates

**Tool**: `write_to_file` (3 files)

---

### Step 3: Create Unit Tests

**File**: `tests/test_impact_assessment_v35.py`

**Test Cases**:
1. Minimal deploy (2 files, no flags)
2. Full deploy (3+ files)
3. Full deploy (protocol change)
4. Full deploy (executor change)
5. Risk level assessment
6. AP/IO payload generation

**Tool**: `write_to_file`

---

### Step 4: Integrate with Liam Feature-dev

**File**: `agents/liam/core.py` (or new integration module)

**Add**:
```python
from g.core.impact_assessment_v35 import assess_deploy_impact

def liam_feature_dev_decide_deploy(...):
    # Boss-provided integration code
```

**Tool**: Code edit (if file exists) or `write_to_file` (new module)

---

### Step 5: Update Liam Persona

**File**: `agents/liam/PERSONA_PROMPT.md`

**Add section**:
```markdown
## Deploy Impact Assessment (V3.5)

When feature-dev completes, I automatically:
1. Call `assess_deploy_impact()` with feature summary
2. Receive `ImpactReport` (minimal vs full)
3. Use appropriate deploy template
4. Log to AP/IO
```

**Tool**: Code edit

---

### Step 6: Create Deploy Directory Structure

**Directories**:
```bash
mkdir -p g/reports/deployed
mkdir -p g/templates/deploy
mkdir -p g/core
```

**Tool**: `run_command`

---

### Step 7: Test Module

**Commands**:
```bash
# Test import
python -c "from g.core.impact_assessment_v35 import assess_deploy_impact; print('✅ Import OK')"

# Run unit tests
pytest tests/test_impact_assessment_v35.py -v
```

**Tool**: `run_command`

---

### Step 8: Log to AP/IO

**Event**: `impact_assessment_module_deployed`

**Data**:
```json
{
  "version": "v3.5",
  "module": "g/core/impact_assessment_v35.py",
  "features": [
    "auto_classification",
    "risk_assessment",
    "template_selection"
  ]
}
```

**Tool**: Python script with `write_ledger_entry`

---

## 3. File Structure

```
g/
├── core/
│   └── impact_assessment_v35.py          # Main module
├── templates/
│   └── deploy/
│       ├── minimal_summary.md            # Minimal template
│       ├── full_summary.md               # Full template
│       └── rollback.zsh                  # Rollback template
└── reports/
    ├── feature-dev/
    │   └── impact_assessment_v35/
    │       ├── 251121_impact_assessment_v35_spec_v01.md
    │       └── 251121_impact_assessment_v35_plan_v01.md
    └── deployed/                         # Future deploys go here

agents/liam/
└── core.py (or integration module)      # Liam integration

tests/
└── test_impact_assessment_v35.py         # Unit tests
```

---

## 4. Execution Order

1. ✅ Create SPEC.md
2. ✅ Create PLAN.md
3. ⬜ Create directories
4. ⬜ Create core module
5. ⬜ Create templates
6. ⬜ Create unit tests
7. ⬜ Integrate with Liam
8. ⬜ Update Liam persona
9. ⬜ Test module
10. ⬜ Log to AP/IO

---

## 5. Testing

### Test 1: Minimal Deploy Classification
```python
summary = {
    "feature_name": "fix_typo",
    "files_touched": ["README.md"],
    "touches_governance": False,
    # ... all flags False
}
report = assess_deploy_impact(summary)
assert report["deploy_type"] == "minimal"
assert report["risk"] == "low"
```

### Test 2: Full Deploy Classification
```python
summary = {
    "feature_name": "add_executor",
    "files_touched": ["executor.py", "bridge.py", "schema.json"],
    "changes_executor_or_bridge": True,
    "changes_schema": True,
}
report = assess_deploy_impact(summary)
assert report["deploy_type"] == "full"
assert report["risk"] == "high"
assert report["requires_rollback"] == True
```

### Test 3: Integration Test
```python
# Simulate Liam feature-dev → deploy
from agents.liam.core import liam_feature_dev_decide_deploy

report = liam_feature_dev_decide_deploy(
    feature_name="test_feature",
    description="Test",
    files=["file1.py"],
    components=["component1"],
    flags={}
)
assert "deploy_type" in report
```

---

## 6. Rollback Plan

**If module causes issues**:
1. Remove `g/core/impact_assessment_v35.py`
2. Revert Liam integration
3. Restore manual deploy type selection

**Risk**: Very low (module is pure logic, no side effects)

---

## 7. Post-Implementation

### Documentation:
- Update `docs/DEPLOY_PROTOCOL_V35.md` (if exists)
- Link from `README.md`

### Next Features:
- SOT auto-update tool (uses `update_sot` flag)
- AI context auto-update tool (uses `update_ai_context` flag)
- Worker notification system (uses `notify_workers` flag)

---

**Status**: ✅ PLAN COMPLETE - READY FOR EXECUTION
