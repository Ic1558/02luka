# LAC Realignment Specification V2
**Feature ID:** `lac_realignment`  
**Version:** v2.0  
**Date:** 2025-11-28  
**Status:** APPROVED  
**Contract:** `g/ai_contracts/lac_contract_v2.yaml`

---

## 1. Overview

### 1.1 Purpose

This specification defines the **LAC (Local-First, Autonomous, Cost-Effective) Realignment** feature, transforming the 02luka system to a **truly self-governing, local-first, free-first** architecture as per the original concept.

### 1.2 Core Principle

> **"ทำคนเดียวแต่ดูเหมือนมีทีมงาน 30 คน"**  
> Local-First, Free-First, Self-Governing.  
> CLC is a role/tool, NOT a gateway.  
> Agents self-complete by default.

### 1.3 Problem Statement (Drift from Concept)

| Aspect | Original Concept | Drifted Implementation |
|--------|------------------|------------------------|
| CLC Role | Tool for complex patches | Gateway/bottleneck |
| Pipeline | DEV → QA → DOCS → MERGE | DEV → QA → DOCS → **CLC** → MERGE |
| Agent Capability | Full developers (reason + write) | Reasoning only |
| Budget | $70 total for major project | $255/month default |
| Paid Lanes | Emergency only, Boss approval | Budget-based auto-spend |

### 1.4 Target State (Concept Alignment)

- ✅ Agents self-complete: DEV → QA → DOCS → **DIRECT_MERGE**
- ✅ Agents write files directly via shared `policy.py`
- ✅ CLC = optional specialist tool (not in critical path)
- ✅ Paid lanes = OFF by default, emergency only, require approval
- ✅ R&D = Full autonomous department

### 1.5 Scope

**In Scope:**
- P1: Agent Direct-Write Capability
- P2: Self-Complete Pipeline (CLC-free default path)
- P3: Free-First Budget Model
- P4: CLC Repositioning (tool, not gateway)
- P5: Shared Policy Module

**Out of Scope:**
- Removing CLC entirely (kept as specialist tool)
- Changing governance rules (Writer Policy v3.5 still applies)
- External integrations

---

## 2. Architecture

### 2.1 System Context (Corrected)

```
┌─────────────────────────────────────────────────────────────┐
│           AUTONOMOUS DEV TEAM (Self-Governing)               │
│                                                              │
│   ┌──────────┐    ┌───────────┐    ┌─────────────────┐      │
│   │AI Manager│───▶│ Architect │───▶│ Dev (OSS/GMX)   │      │
│   │  (free)  │    │   (free)  │    │    (free)       │      │
│   └──────────┘    └───────────┘    └────────┬────────┘      │
│                                              │               │
│                                              ▼               │
│                                    ┌─────────────────┐      │
│                                    │  WRITE FILES    │      │
│                                    │ (via policy.py) │      │
│                                    └────────┬────────┘      │
│                                              │               │
│                                              ▼               │
│                                    ┌─────────────────┐      │
│                                    │    QA Agent     │      │
│                                    │    (free)       │      │
│                                    └────────┬────────┘      │
│                                              │               │
│                          ┌───────────────────┼───────────┐  │
│                          │                   │           │  │
│                          ▼                   ▼           │  │
│                   ┌──────────┐        ┌──────────┐       │  │
│                   │ QA PASS  │        │ QA FAIL  │       │  │
│                   └────┬─────┘        └────┬─────┘       │  │
│                        │                   │             │  │
│                        ▼                   ▼             │  │
│                 ┌────────────┐      ┌────────────┐       │  │
│                 │ Docs Agent │      │ Return to  │       │  │
│                 │   (free)   │      │    DEV     │       │  │
│                 └─────┬──────┘      └────────────┘       │  │
│                       │                                  │  │
│                       ▼                                  │  │
│               ┌───────────────┐                          │  │
│               │ DIRECT MERGE  │◀── DEFAULT PATH          │  │
│               │ (self_apply)  │                          │  │
│               └───────────────┘                          │  │
└──────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    UTILITY LAYER (Optional)                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌───────────────┐                                         │
│   │  CLC Local    │◀── Called ONLY for:                     │
│   │  (optional)   │    • Complex multi-file patches         │
│   └───────────────┘    • Conflict resolution                │
│                        • Agent requests assistance          │
│                                                              │
│   NOT in critical path. NO veto power.                      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              EMERGENCY ONLY (OFF by default)                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌───────────────┐                                         │
│   │  Paid Lane    │◀── Requirements:                        │
│   │ (Claude/GPT)  │    • paid_lanes.enabled = true          │
│   └───────────────┘    • Boss approval granted              │
│                        • Emergency budget (50 THB max)      │
│                                                              │
│   DEFAULT: OFF. Never auto-spend.                           │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Architecture

#### 2.2.1 Shared Policy Module (NEW - P5)

**Location:** `shared/policy.py`

**Purpose:** Single source of truth for file write permissions. Used by ALL agents and CLC.

```python
# shared/policy.py

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

def check_write_allowed(file_path: str) -> tuple[bool, str]:
    """
    Check if file write is allowed.
    Used by: dev_oss, dev_gmxcli, qa_v4, docs_v4, clc_local
    
    Returns:
        (allowed: bool, reason: str)
    """
    for forbidden in FORBIDDEN_PATHS:
        if forbidden in file_path:
            return False, f"FORBIDDEN_PATH: {forbidden}"
    
    for allowed in ALLOWED_ROOTS:
        if file_path.startswith(allowed):
            return True, "ALLOWED"
    
    return False, "PATH_NOT_IN_ALLOWED_ROOTS"

def apply_patch(file_path: str, content: str) -> dict:
    """
    Apply patch after policy check.
    """
    allowed, reason = check_write_allowed(file_path)
    if not allowed:
        return {"status": "blocked", "reason": reason}
    
    # Write file
    with open(file_path, 'w') as f:
        f.write(content)
    
    return {"status": "success", "file": file_path}
```

#### 2.2.2 Agent Direct-Write Capability (P1)

**All Dev/QA/Docs agents import shared policy:**

```python
# agents/dev_oss/dev_worker.py

from shared.policy import check_write_allowed, apply_patch

class DevOSSWorker:
    def execute_task(self, task):
        # Reason and plan
        plan = self.reason(task)
        
        # Generate patch
        patch = self.generate_patch(plan)
        
        # Direct write (via shared policy)
        for file_op in patch.operations:
            result = apply_patch(file_op.path, file_op.content)
            if result["status"] == "blocked":
                self.log_blocked(result)
                return {"status": "failed", "reason": result["reason"]}
        
        return {"status": "success", "self_applied": True}
```

#### 2.2.3 Self-Complete Pipeline (P2)

**State Machine (Corrected):**

```
NEW
  │
  ▼
DEV_IN_PROGRESS
  │
  ▼
DEV_DONE ──────────────────────────────────────┐
  │                                             │
  ▼                                             │
QA_IN_PROGRESS                                  │
  │                                             │
  ├─── QA_PASSED ────▶ DOCS_IN_PROGRESS        │
  │                         │                   │
  │                         ▼                   │
  │                    DOCS_DONE                │
  │                         │                   │
  │                         ▼                   │
  │    ┌────────────────────┴───────────────┐  │
  │    │                                    │  │
  │    ▼                                    ▼  │
  │  [self_apply=true]              [self_apply=false]
  │  [complexity=simple]            [complexity=complex]
  │    │                                    │  │
  │    ▼                                    ▼  │
  │  DIRECT_MERGE                    ROUTE_TO_CLC
  │    │                                    │  │
  │    ▼                                    ▼  │
  │  COMPLETE                         CLC_APPLIED
  │                                         │  │
  │                                         ▼  │
  │                                      COMPLETE
  │                                             │
  └─── QA_FAILED ────▶ Return to DEV ──────────┘
           │
           ▼
      [3x fail] ────▶ ESCALATE (manual review or CLC)
```

**Key Rules:**
1. `self_apply=true` + `QA_PASSED` → **DIRECT_MERGE** (no CLC)
2. `self_apply=false` OR `complexity=complex` → route to CLC
3. `QA_FAILED` → return to DEV with feedback
4. `QA_FAILED` 3x → escalate for review

#### 2.2.4 Free-First Budget Model (P3)

**Configuration:**

```yaml
# config/paid_lanes.yaml

paid_lanes:
  enabled: false           # DEFAULT: OFF
  require_approval: true   # Boss must approve ANY paid call
  emergency_budget_thb: 50 # Max emergency spend per day
  
  approval_log: "g/ledger/paid_approvals.jsonl"
  spend_log: "g/ledger/paid_lane_spend.json"
  
  guards:
    - name: "enabled_check"
      rule: "paid_lanes.enabled must be true"
      action: "BLOCK if false"
    
    - name: "approval_check"
      rule: "Must have Boss approval in approval_log"
      action: "BLOCK if no approval"
    
    - name: "budget_check"
      rule: "total_spend + estimate <= emergency_budget_thb"
      action: "BLOCK if exceeded"
```

**Guard Logic:**

```python
def check_paid_lane_allowed(cost_estimate: float, wo_id: str) -> tuple[bool, str]:
    config = load_config("config/paid_lanes.yaml")
    
    # Guard 1: Enabled check
    if not config["paid_lanes"]["enabled"]:
        return False, "PAID_LANE_DISABLED"
    
    # Guard 2: Approval check
    if not has_boss_approval(wo_id):
        return False, "NO_BOSS_APPROVAL"
    
    # Guard 3: Budget check
    ledger = load_daily_budget()
    if ledger["total_spend"] + cost_estimate > config["paid_lanes"]["emergency_budget_thb"]:
        return False, "EMERGENCY_BUDGET_EXCEEDED"
    
    return True, "ALLOWED"
```

#### 2.2.5 CLC Repositioning (P4)

**CLC Role (Corrected):**

| Aspect | Old (Drifted) | New (Aligned) |
|--------|---------------|---------------|
| Position | Mandatory in pipeline | Optional utility |
| Power | Could veto/approve | NO veto power |
| Usage | All file writes | Complex patches only |
| Default | Always called | Never called unless needed |

**When to Use CLC:**
- Multi-file complex patches (10+ files)
- Conflict resolution between patches
- Agent explicitly requests assistance (`request_clc: true`)
- Security-sensitive modifications

**When NOT to Use CLC:**
- Simple single-file changes
- Standard refactors
- Documentation updates
- Test file additions
- Any task where `self_apply=true` and `QA_PASSED`

---

## 3. Interface Contracts

### 3.1 Work Order Schema (Updated)

```json
{
  "wo_id": "string (required)",
  "objective": "string (required)",
  "routing_hint": "string (required) - oss|gmxcli|gptdeep",
  "priority": "string (required) - P0|P1|P2|P3",
  
  "self_apply": "boolean (default: true)",
  "complexity": "string (default: simple) - simple|complex",
  "requires_paid_lane": "boolean (default: false)",
  
  "tasks": [
    {
      "task_id": "string",
      "description": "string",
      "operations": [
        {
          "op": "write_file|apply_patch",
          "file": "path/to/file",
          "content": "string"
        }
      ]
    }
  ]
}
```

### 3.2 Agent Execution Result

```json
{
  "wo_id": "string",
  "status": "success|failed|escalated",
  "self_applied": "boolean",
  "files_touched": ["path1", "path2"],
  "used_clc": "boolean",
  "used_paid_lane": "boolean",
  "errors": []
}
```

### 3.3 Shared Policy Interface

```python
# All agents must implement:

from shared.policy import check_write_allowed, apply_patch

class AgentWorker:
    def can_write(self, path: str) -> bool:
        allowed, _ = check_write_allowed(path)
        return allowed
    
    def write_file(self, path: str, content: str) -> dict:
        return apply_patch(path, content)
```

---

## 4. Data Flow

### 4.1 Default Flow (Self-Complete, No CLC)

```
1. WO arrives at AI Manager
2. AI Manager routes to Dev (OSS/GMX)
3. Dev reasons → plans → writes files (via policy.py)
4. Dev marks DEV_DONE
5. Auto-trigger QA
6. QA tests → PASS
7. Auto-trigger Docs
8. Docs generates docs (via policy.py)
9. DIRECT_MERGE (self_apply=true)
10. COMPLETE

CLC: Not called
Paid Lane: Not called
```

### 4.2 Complex Patch Flow (CLC Involved)

```
1. WO arrives at AI Manager
2. AI Manager routes to Dev
3. Dev reasons → realizes complex (multi-file, conflicts)
4. Dev sets complexity=complex or request_clc=true
5. Dev marks DEV_DONE
6. QA tests → PASS
7. Route to CLC Local (for complex patch)
8. CLC applies patch
9. Docs generates docs
10. MERGE
11. COMPLETE

Paid Lane: Not called
```

### 4.3 Emergency Paid Lane Flow

```
1. WO arrives with requires_paid_lane=true
2. Check: paid_lanes.enabled? → NO → BLOCKED
   (Boss must enable first)
3. If enabled: Check approval_log for this WO
   → NO approval → BLOCKED
4. If approved: Check budget
   → Over budget → BLOCKED
5. If all pass: Route to Paid Lane
6. Execute → Log spend
7. Continue normal flow

Requirements:
- Boss enables paid_lanes
- Boss approves specific WO
- Within emergency budget (50 THB)
```

---

## 5. Non-Functional Requirements

### 5.1 Performance

| Operation | Target |
|-----------|--------|
| Agent direct-write | < 50ms per file |
| Policy check | < 5ms |
| QA test suite | < 30s |
| Self-complete (simple WO) | < 2 min |

### 5.2 Cost

| Lane | Cost Target |
|------|-------------|
| OSS/GMX/Local | $0 |
| Paid (emergency) | < $1.50/day (50 THB) |
| Monthly total | < $45 (vs. $255 in drift) |

### 5.3 Reliability

- Policy enforcement: 100%
- Self-complete success rate: > 90% (simple tasks)
- QA catch rate: > 95%

---

## 6. Acceptance Criteria

### 6.1 P1: Agent Direct-Write
- ✅ All Dev/QA/Docs agents import `shared.policy`
- ✅ Agents can write to allowed paths directly
- ✅ Forbidden paths are blocked
- ✅ No CLC required for simple writes

### 6.2 P2: Self-Complete Pipeline
- ✅ DEV → QA → DOCS → DIRECT_MERGE works without CLC
- ✅ `self_apply=true` triggers direct merge
- ✅ `complexity=complex` routes to CLC
- ✅ QA fail returns to DEV

### 6.3 P3: Free-First Budget
- ✅ `paid_lanes.enabled = false` by default
- ✅ Paid calls blocked without approval
- ✅ Emergency budget = 50 THB max
- ✅ All spend logged

### 6.4 P4: CLC Repositioning
- ✅ CLC NOT in default pipeline
- ✅ CLC has no veto power
- ✅ CLC only called for complex patches
- ✅ Agents work without CLC dependency

### 6.5 P5: Shared Policy
- ✅ `shared/policy.py` exists
- ✅ All agents use same policy
- ✅ Policy matches CLC rules
- ✅ Unit tests pass

---

## 7. Validation Against Contract

**Contract Reference:** `g/ai_contracts/lac_contract_v2.yaml`

| Contract Rule | This SPEC | Status |
|---------------|-----------|--------|
| CLC not in mandatory pipeline | ✅ CLC is optional | ✅ PASS |
| Agents can write via policy | ✅ shared.policy | ✅ PASS |
| paid_lanes.enabled = false default | ✅ Config shows false | ✅ PASS |
| self_apply field in WO | ✅ Schema includes it | ✅ PASS |
| Budget ≤ 50 THB emergency | ✅ 50 THB max | ✅ PASS |

**SPEC V2 Status:** ✅ ALIGNED WITH CONTRACT

---

## 8. References

- **Contract:** `g/ai_contracts/lac_contract_v2.yaml`
- **Original Concept:** `lac_concept_history.txt`
- **Plan:** `g/reports/feature-dev/lac_realignment/251128_lac_realignment_PLAN_v2.md`

---

**Document Status:** ✅ APPROVED  
**Contract Aligned:** ✅ YES  
**Ready for Implementation:** ✅ YES
