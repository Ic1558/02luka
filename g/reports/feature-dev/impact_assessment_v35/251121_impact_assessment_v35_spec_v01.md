# Impact Assessment Module V3.5 — SPEC

**Version**: v01  
**Date**: 2025-11-21  
**Owner**: Liam  
**Type**: Core Module (Deploy Protocol)

---

## 1. Objective

Create an **automatic impact assessment module** that determines whether a deployment should be "minimal" or "full" based on objective criteria, eliminating manual guessing.

**Goals**:
- ✅ Auto-classify deploy type (minimal vs full)
- ✅ Assess risk level (low, medium, high)
- ✅ Determine required actions (rollback, SOT update, AI context update)
- ✅ Integrate with feature-dev lane
- ✅ Log all assessments to AP/IO v3.1

---

## 2. Scope

### In Scope:
- ✅ Python module: `g/core/impact_assessment_v35.py`
- ✅ Auto-classification logic (minimal vs full)
- ✅ Risk assessment (low, medium, high)
- ✅ Integration with Liam feature-dev lane
- ✅ Deploy templates (minimal & full)
- ✅ Rollback script generation
- ✅ AP/IO logging

### Out of Scope:
- ❌ Actual file deployment (Hybrid does that)
- ❌ SOT update automation (separate tool)
- ❌ AI context update automation (separate tool)

---

## 3. Requirements

### Functional:

**Classification Rules**:
- **Minimal deploy** when ALL true:
  - ≤ 2 files changed
  - No protocol/schema/executor/bridge changes
  - No governance file changes
  - No agent behavior changes
  - No new subsystem

- **Full deploy** when ANY true:
  - > 2 files changed
  - Protocol/schema changes
  - Executor/bridge changes
  - Agent behavior changes
  - New subsystem added
  - LaunchAgent changes

**Risk Levels**:
- **High**: governance, protocol, executor, bridge, LaunchAgent
- **Medium**: agent behavior, schema, new subsystem
- **Low**: misc changes, docs, small fixes

### Non-Functional:
- Module must be importable by Liam/GMX
- Must return structured `ImpactReport`
- Must integrate with AP/IO v3.1
- Must be deterministic (same input → same output)

---

## 4. Deliverables

### Code:
1. **`g/core/impact_assessment_v35.py`** - Main module
2. **`tests/test_impact_assessment_v35.py`** - Unit tests

### Templates:
3. **`g/templates/deploy/minimal_summary.md`** - Minimal deploy template
4. **`g/templates/deploy/full_summary.md`** - Full deploy template
5. **`g/templates/deploy/rollback.zsh`** - Rollback script template

### Documentation:
6. **Spec** (this file)
7. **Plan** (implementation plan)

---

## 5. Data Structures

### ChangeSummary (Input):
```python
{
  "feature_name": str,
  "description": str,
  "files_touched": List[str],
  "components_affected": List[str],
  "touches_governance": bool,
  "changes_protocol": bool,
  "changes_executor_or_bridge": bool,
  "changes_schema": bool,
  "changes_agent_behavior": bool,
  "adds_new_subsystem": bool,
  "changes_launchagents_or_runtime": bool,
  "is_experimental": bool
}
```

### ImpactReport (Output):
```python
{
  "deploy_type": "minimal" | "full",
  "risk": "low" | "medium" | "high",
  "reason": str,
  "requires_rollback": bool,
  "update_sot": bool,
  "update_ai_context": bool,
  "notify_workers": bool,
  "files_changed": List[str],
  "components_affected": List[str]
}
```

---

## 6. Integration Points

### Feature-dev Lane:
1. Liam completes feature planning
2. Liam calls `assess_deploy_impact(summary)`
3. Liam receives `ImpactReport`
4. Liam uses `deploy_type` to select template
5. Liam logs to AP/IO

### Deploy Lane:
1. Uses `ImpactReport` from feature-dev
2. Creates appropriate deploy structure
3. Generates rollback if needed
4. Updates SOT/AI context if needed

---

## 7. Deploy Output Structure

### Minimal Deploy:
```
g/reports/deployed/<yymmdd_feature_slug>/
├── summary.md
├── meta.yaml
└── diff.json (optional)
```

### Full Deploy:
```
g/reports/deployed/<yymmdd_feature_slug>/
├── summary.md
├── rollback.zsh
├── meta.yaml
└── diff.json (optional)
```

---

## 8. Success Criteria

- [ ] Module created and importable
- [ ] All classification rules implemented
- [ ] Risk assessment logic correct
- [ ] Templates created
- [ ] Integration with feature-dev lane works
- [ ] AP/IO logging functional
- [ ] Unit tests pass
- [ ] Boss approval

---

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Misclassification | Medium | Medium | Comprehensive unit tests |
| Missing edge cases | Low | Medium | Boss override capability |
| Integration issues | Low | Low | Test with real features |

---

## 10. AP/IO Events

- `deploy_impact_assessed` - When assessment completes
- `minimal_deploy_started` - Minimal deploy begins
- `full_deploy_started` - Full deploy begins
- `deploy_completed` - Deploy finishes
- `rollback_available` - Rollback script created

---

**Status**: ✅ SPEC COMPLETE
