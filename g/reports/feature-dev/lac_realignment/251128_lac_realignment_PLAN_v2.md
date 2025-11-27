# LAC Realignment Feature Plan V2
**Feature Slug:** `lac_realignment`  
**Version:** v2.0  
**Date:** 2025-11-28  
**Status:** APPROVED  
**Contract:** `g/ai_contracts/lac_contract_v2.yaml`

---

## Executive Summary

This plan implements the **LAC Realignment** to restore the original concept: **Local-First, Free-First, Self-Governing Autonomous Development Team**.

**Key Changes from V1:**
1. CLC removed from mandatory pipeline → optional specialist tool
2. Agents get direct-write capability via shared policy
3. Budget changed from 300 THB/day → 50 THB emergency only
4. `self_apply` field enables agent self-completion
5. Paid lanes OFF by default, require Boss approval

---

## 1. Phase Overview

| Phase | Focus | Priority | Duration |
|-------|-------|----------|----------|
| P1 | Shared Policy Module | P0 | 1 day |
| P2 | Agent Direct-Write | P0 | 1-2 days |
| P3 | Self-Complete Pipeline | P0 | 2 days |
| P4 | CLC Repositioning | P1 | 1 day |
| P5 | Free-First Budget | P1 | 1 day |

**Total Estimated:** 6-7 days

---

## 2. Phase 1: Shared Policy Module (P1)

### Goal
Create single source of truth for file write permissions used by all agents.

### Tasks

#### P1.1: Create Shared Policy Module
- [ ] **Create:** `shared/__init__.py`
- [ ] **Create:** `shared/policy.py`
  - `FORBIDDEN_PATHS` list
  - `ALLOWED_ROOTS` list
  - `check_write_allowed(path)` function
  - `apply_patch(path, content)` function
- [ ] **Test:** `tests/shared/test_policy.py`

**File: `shared/policy.py`**
```python
"""
Shared Policy Module - Single Source of Truth for Write Permissions
Used by: dev_oss, dev_gmxcli, qa_v4, docs_v4, clc_local
"""

from pathlib import Path
from typing import Tuple
import os

FORBIDDEN_PATHS = [
    ".git/",
    "bridge/",
    "governance/",
    "secrets/",
    ".env",
    "config/secure/"
]

ALLOWED_ROOTS = [
    "g/src/",
    "g/apps/",
    "g/tools/",
    "tests/"
]

def check_write_allowed(file_path: str) -> Tuple[bool, str]:
    """Check if file write is allowed per policy."""
    normalized = str(file_path).replace("\\", "/")
    
    for forbidden in FORBIDDEN_PATHS:
        if forbidden in normalized:
            return False, f"FORBIDDEN_PATH: {forbidden}"
    
    for allowed in ALLOWED_ROOTS:
        if normalized.startswith(allowed):
            return True, "ALLOWED"
    
    return False, "PATH_NOT_IN_ALLOWED_ROOTS"

def apply_patch(file_path: str, content: str, dry_run: bool = False) -> dict:
    """Apply patch after policy check."""
    allowed, reason = check_write_allowed(file_path)
    
    if not allowed:
        return {
            "status": "blocked",
            "reason": reason,
            "file": file_path
        }
    
    if dry_run:
        return {
            "status": "dry_run",
            "would_write": file_path,
            "content_length": len(content)
        }
    
    # Ensure directory exists
    Path(file_path).parent.mkdir(parents=True, exist_ok=True)
    
    # Write file
    with open(file_path, 'w') as f:
        f.write(content)
    
    return {
        "status": "success",
        "file": file_path,
        "bytes_written": len(content)
    }
```

#### P1.2: Create Policy Tests
- [ ] **Test Cases:**
  - Forbidden path → blocked
  - Allowed path → success
  - Path traversal attempt → blocked
  - Dry run mode → no write

**File: `tests/shared/test_policy.py`**
```python
import pytest
from shared.policy import check_write_allowed, apply_patch

class TestCheckWriteAllowed:
    def test_forbidden_git(self):
        allowed, reason = check_write_allowed(".git/config")
        assert not allowed
        assert "FORBIDDEN" in reason
    
    def test_forbidden_secrets(self):
        allowed, reason = check_write_allowed("secrets/api_key.txt")
        assert not allowed
    
    def test_allowed_g_src(self):
        allowed, reason = check_write_allowed("g/src/main.py")
        assert allowed
        assert reason == "ALLOWED"
    
    def test_allowed_tests(self):
        allowed, reason = check_write_allowed("tests/test_foo.py")
        assert allowed
    
    def test_not_in_allowed_roots(self):
        allowed, reason = check_write_allowed("random/path.py")
        assert not allowed
        assert "NOT_IN_ALLOWED" in reason

class TestApplyPatch:
    def test_blocked_write(self, tmp_path):
        result = apply_patch(".git/config", "content")
        assert result["status"] == "blocked"
    
    def test_dry_run(self):
        result = apply_patch("g/src/test.py", "content", dry_run=True)
        assert result["status"] == "dry_run"
```

#### P1.3: Done Criteria
- [ ] `shared/policy.py` exists and importable
- [ ] All tests pass
- [ ] clc_local still works with shared policy

---

## 3. Phase 2: Agent Direct-Write (P2)

### Goal
Enable all Dev/QA/Docs agents to write files directly using shared policy.

### Tasks

#### P2.1: Update Dev OSS Agent
- [ ] **Modify:** `agents/dev_oss/dev_worker.py`
  - Import `from shared.policy import check_write_allowed, apply_patch`
  - Add `self_write()` method
  - Update `execute_task()` to use direct write

**Code Addition:**
```python
# agents/dev_oss/dev_worker.py

from shared.policy import check_write_allowed, apply_patch

class DevOSSWorker:
    def self_write(self, file_path: str, content: str) -> dict:
        """Direct write via shared policy."""
        return apply_patch(file_path, content)
    
    def execute_task(self, task: dict) -> dict:
        # Reason and plan
        plan = self.reason(task)
        patches = self.generate_patches(plan)
        
        results = []
        for patch in patches:
            result = self.self_write(patch["file"], patch["content"])
            results.append(result)
            
            if result["status"] == "blocked":
                return {
                    "status": "failed",
                    "reason": result["reason"],
                    "partial_results": results
                }
        
        return {
            "status": "success",
            "self_applied": True,
            "files_touched": [r["file"] for r in results if r["status"] == "success"]
        }
```

#### P2.2: Update Dev GMXCLI Agent
- [ ] **Modify:** `agents/dev_gmxcli/dev_worker.py`
  - Same pattern as Dev OSS

#### P2.3: Update QA Agent
- [ ] **Modify:** `agents/qa_v4/qa_worker.py`
  - Import shared policy
  - Add capability to write test files

#### P2.4: Update Docs Agent
- [ ] **Modify:** `agents/docs_v4/docs_worker.py`
  - Import shared policy
  - Add capability to write documentation files

#### P2.5: Integration Tests
- [ ] **Create:** `tests/test_agent_direct_write.py`
  - Test: Dev OSS can write to g/src/
  - Test: Dev OSS blocked from .git/
  - Test: QA can write to tests/
  - Test: Docs can write to g/docs/

#### P2.6: Done Criteria
- [ ] All 4 agents import shared.policy
- [ ] All 4 agents can self_write()
- [ ] Integration tests pass
- [ ] No dependency on CLC for simple writes

---

## 4. Phase 3: Self-Complete Pipeline (P3)

### Goal
Enable DEV → QA → DOCS → DIRECT_MERGE without CLC in path.

### Tasks

#### P3.1: Update WO Schema
- [ ] **Modify:** WO JSON schema to include:
  - `self_apply: boolean (default: true)`
  - `complexity: string (default: "simple")`
  - `requires_paid_lane: boolean (default: false)`

**Schema Update:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["wo_id", "objective", "routing_hint", "priority"],
  "properties": {
    "wo_id": {"type": "string"},
    "objective": {"type": "string"},
    "routing_hint": {"type": "string", "enum": ["oss", "gmxcli", "gptdeep"]},
    "priority": {"type": "string", "enum": ["P0", "P1", "P2", "P3"]},
    "self_apply": {"type": "boolean", "default": true},
    "complexity": {"type": "string", "enum": ["simple", "complex"], "default": "simple"},
    "requires_paid_lane": {"type": "boolean", "default": false}
  }
}
```

#### P3.2: Update AI Manager State Machine
- [ ] **Modify:** `agents/ai_manager/ai_manager.py`
  - Add state: `DIRECT_MERGE`
  - Condition: If `self_apply=true` AND `QA_PASSED` → `DIRECT_MERGE`
  - Condition: If `complexity=complex` → route to CLC

**State Machine Logic:**
```python
def transition(self, wo: dict, current_state: str, event: str) -> str:
    if current_state == "DOCS_DONE":
        if wo.get("self_apply", True) and wo.get("complexity", "simple") == "simple":
            return "DIRECT_MERGE"
        else:
            return "ROUTE_TO_CLC"
    
    if current_state == "QA_FAILED":
        wo["qa_fail_count"] = wo.get("qa_fail_count", 0) + 1
        if wo["qa_fail_count"] >= 3:
            return "ESCALATE"
        return "DEV_IN_PROGRESS"  # Return to dev
    
    # ... other transitions
```

#### P3.3: Implement DIRECT_MERGE Action
- [ ] **Create:** `agents/ai_manager/actions/direct_merge.py`
  - Commit changes (if git enabled)
  - Update WO status to COMPLETE
  - Log to autonomous_completions.jsonl

**Code:**
```python
def direct_merge(wo: dict, files_touched: list) -> dict:
    """
    Execute direct merge without CLC involvement.
    Called when: self_apply=true AND QA_PASSED AND complexity=simple
    """
    # Log completion
    completion_record = {
        "wo_id": wo["wo_id"],
        "merge_type": "DIRECT",
        "files": files_touched,
        "timestamp": datetime.utcnow().isoformat(),
        "used_clc": False,
        "used_paid": False
    }
    
    append_jsonl("g/ledger/autonomous_completions.jsonl", completion_record)
    
    # Update WO status
    wo["status"] = "COMPLETE"
    wo["completed_at"] = datetime.utcnow().isoformat()
    
    return {
        "status": "success",
        "merge_type": "DIRECT",
        "wo_id": wo["wo_id"]
    }
```

#### P3.4: QA Fail Handling
- [ ] **Implement:** Return-to-dev logic
  - QA fail → DEV with feedback
  - 3x fail → ESCALATE

#### P3.5: Integration Test
- [ ] **Create:** `tests/test_self_complete_pipeline.py`
  - Test: Simple WO → DEV → QA_PASS → DOCS → DIRECT_MERGE (no CLC)
  - Test: Complex WO → DEV → QA_PASS → DOCS → ROUTE_TO_CLC
  - Test: QA fail → return to DEV
  - Test: 3x QA fail → ESCALATE

#### P3.6: Done Criteria
- [ ] `self_apply` field in WO schema
- [ ] DIRECT_MERGE state implemented
- [ ] Simple WOs complete without CLC
- [ ] QA fail handling works
- [ ] Integration tests pass

---

## 5. Phase 4: CLC Repositioning (P4)

### Goal
Remove CLC from mandatory pipeline, position as optional specialist tool.

### Tasks

#### P4.1: Update CLC Documentation
- [ ] **Modify:** `agents/clc/CLC_V4_SPEC.md`
  - Remove "default executor" language
  - Add "optional specialist tool" positioning
  - Document when to use vs. when NOT to use

#### P4.2: Update Routing Logic
- [ ] **Modify:** `agents/clc/model_router.py`
  - Remove default routing to CLC
  - Add `request_clc` flag check
  - Only route when explicitly requested

**Routing Update:**
```python
def should_route_to_clc(wo: dict) -> bool:
    """
    CLC is optional. Only route when:
    1. complexity == "complex"
    2. request_clc == true
    3. Multi-file patch (10+ files)
    """
    if wo.get("complexity") == "complex":
        return True
    if wo.get("request_clc", False):
        return True
    if len(wo.get("files_to_touch", [])) >= 10:
        return True
    return False
```

#### P4.3: Remove CLC Veto Power
- [ ] **Audit:** Ensure CLC cannot block/approve WOs
- [ ] **Verify:** CLC only executes, never governs

#### P4.4: Done Criteria
- [ ] CLC not in default routing
- [ ] CLC only called when explicitly needed
- [ ] CLC has no veto/approval power
- [ ] Documentation updated

---

## 6. Phase 5: Free-First Budget (P5)

### Goal
Implement strict free-first budgeting with paid lanes OFF by default.

### Tasks

#### P5.1: Update Paid Lane Config
- [ ] **Modify:** `config/paid_lanes.yaml`

```yaml
paid_lanes:
  enabled: false           # DEFAULT: OFF
  require_approval: true   # Boss must approve
  emergency_budget_thb: 50 # Max emergency spend
  
  approval_log: "g/ledger/paid_approvals.jsonl"
  spend_log: "g/ledger/paid_lane_spend.json"
```

#### P5.2: Implement Triple Guard
- [ ] **Create:** `agents/router/paid_lane_guard.py`

```python
def check_paid_lane_allowed(wo_id: str, cost_estimate: float) -> tuple[bool, str]:
    config = load_config("config/paid_lanes.yaml")
    
    # Guard 1: Enabled check
    if not config["paid_lanes"]["enabled"]:
        return False, "PAID_LANE_DISABLED_BY_DEFAULT"
    
    # Guard 2: Approval check
    if not has_boss_approval(wo_id, config["paid_lanes"]["approval_log"]):
        return False, "NO_BOSS_APPROVAL"
    
    # Guard 3: Budget check
    spend = load_daily_spend(config["paid_lanes"]["spend_log"])
    if spend + cost_estimate > config["paid_lanes"]["emergency_budget_thb"]:
        return False, "EMERGENCY_BUDGET_EXCEEDED"
    
    return True, "ALLOWED"
```

#### P5.3: Approval Workflow
- [ ] **Create:** `g/ledger/paid_approvals.jsonl` (empty initially)
- [ ] **Document:** How Boss grants approval

**Approval Format:**
```json
{
  "wo_id": "WO-123",
  "approved_by": "Boss",
  "approved_at": "2025-11-28T10:00:00Z",
  "reason": "Complex algorithm requires GPT-4",
  "budget_limit_thb": 30
}
```

#### P5.4: Tests
- [ ] **Test:** Disabled by default → BLOCKED
- [ ] **Test:** No approval → BLOCKED
- [ ] **Test:** Over budget → BLOCKED
- [ ] **Test:** All checks pass → ALLOWED

#### P5.5: Done Criteria
- [ ] `paid_lanes.enabled = false` by default
- [ ] Triple guard implemented
- [ ] Approval workflow documented
- [ ] All tests pass

---

## 7. Implementation Roadmap

```
Week 1:
├── Day 1: P1 (Shared Policy) ✓
├── Day 2: P2.1-P2.2 (Dev agents direct-write)
├── Day 3: P2.3-P2.5 (QA/Docs + tests)
├── Day 4: P3.1-P3.2 (WO schema + state machine)
└── Day 5: P3.3-P3.6 (Direct merge + tests)

Week 2:
├── Day 1: P4 (CLC repositioning)
├── Day 2: P5 (Free-first budget)
└── Day 3: Final integration testing
```

---

## 8. Success Criteria

### Overall Success When:
- ✅ Simple WOs complete without CLC (DEV → QA → DOCS → DIRECT_MERGE)
- ✅ Agents can write files directly via shared policy
- ✅ CLC is optional, not mandatory
- ✅ Paid lanes OFF by default
- ✅ All tests pass
- ✅ Contract validation passes

### Metrics:
| Metric | Target |
|--------|--------|
| Self-complete rate (simple WOs) | > 90% |
| CLC involvement rate | < 10% |
| Paid lane usage | Emergency only |
| Monthly cost | < $45 (vs. $255 drift) |

---

## 9. Contract Validation

**Contract:** `g/ai_contracts/lac_contract_v2.yaml`

| Rule | Implementation | Status |
|------|----------------|--------|
| CLC not mandatory | P4: Optional tool | ✅ |
| Agents write via policy | P1+P2: shared.policy | ✅ |
| paid_lanes.enabled=false | P5: Default OFF | ✅ |
| self_apply in WO | P3: Schema update | ✅ |
| Budget ≤ 50 THB | P5: emergency_budget | ✅ |

**PLAN V2 Status:** ✅ ALIGNED WITH CONTRACT

---

## 10. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Agents write to wrong paths | Shared policy enforces rules |
| Self-complete breaks something | QA catches issues before merge |
| Budget exceeded | Triple guard blocks all paid calls |
| CLC needed but not called | complexity flag + request_clc option |

---

## 11. Appendix: File List

**New Files:**
- `shared/__init__.py`
- `shared/policy.py`
- `tests/shared/test_policy.py`
- `tests/test_agent_direct_write.py`
- `tests/test_self_complete_pipeline.py`
- `agents/ai_manager/actions/direct_merge.py`
- `agents/router/paid_lane_guard.py`
- `g/ledger/paid_approvals.jsonl`

**Modified Files:**
- `agents/dev_oss/dev_worker.py`
- `agents/dev_gmxcli/dev_worker.py`
- `agents/qa_v4/qa_worker.py`
- `agents/docs_v4/docs_worker.py`
- `agents/ai_manager/ai_manager.py`
- `agents/clc/CLC_V4_SPEC.md`
- `agents/clc/model_router.py`
- `config/paid_lanes.yaml`

---

**Document Status:** ✅ APPROVED  
**Contract Aligned:** ✅ YES  
**Ready for Implementation:** ✅ YES
