# WO-QA-003 Implementation Runbook

**Feature:** QA 3-Mode System with Auto-Selection  
**WO:** WO-QA-003  
**Date:** 2025-12-03  
**Status:** Ready for Implementation

---

## Pre-Implementation Checklist

- [x] Specification complete (`g/specs/lac_v4_qa_mode_strategy.md`)
- [x] Feature plan complete (`g/reports/feature-dev/feature_qa_3mode_PLAN.md`)
- [x] WO spec created (`g/wo_specs/WO-QA-003_qa_3mode_system.yaml`)
- [x] Requirement document created (`g/requirements/lac/2025-12-03_QA_3MODE_requirement.md`)
- [x] Current QA worker functional (`agents/qa_v4/qa_worker.py`)
- [x] QA handoff module exists (`agents/dev_common/qa_handoff.py`)

---

## Phase 1: Structure Setup (2 hours)

### Step 1.1: Create Directory Structure

**Command:**
```bash
cd /Users/icmini/LocalProjects/02luka_local_g
mkdir -p agents/qa_v4/workers
```

**Expected Result:**
- Directory `agents/qa_v4/workers/` created

---

### Step 1.2: Move Current QA Worker to Basic

**Action:** Rename and move current `qa_worker.py` to `workers/basic.py`

**Files:**
- Source: `agents/qa_v4/qa_worker.py`
- Target: `agents/qa_v4/workers/basic.py`

**Changes Required:**
1. Copy `qa_worker.py` → `workers/basic.py`
2. Rename class: `QAWorkerV4` → `QAWorkerBasic`
3. Update docstring to indicate "Basic Mode"
4. Keep all current functionality intact

**Verification:**
```bash
python3 -m py_compile agents/qa_v4/workers/basic.py
```

**Expected Result:**
- No syntax errors
- Class name: `QAWorkerBasic`

---

### Step 1.3: Create Workers __init__.py

**File:** `agents/qa_v4/workers/__init__.py`

**Content:**
```python
"""
QA Worker implementations for 3-mode system.

Modes:
- Basic: Fast, lightweight QA
- Enhanced: Warnings, batch support, configurable
- Full: Comprehensive QA with all features
"""

from agents.qa_v4.workers.basic import QAWorkerBasic

__all__ = ["QAWorkerBasic"]
```

**Verification:**
```bash
python3 -c "from agents.qa_v4.workers import QAWorkerBasic; print('OK')"
```

**Expected Result:**
- Import successful
- No errors

---

### Step 1.4: Update Main __init__.py

**File:** `agents/qa_v4/__init__.py`

**Action:** Add backward compatibility export

**Add:**
```python
# Backward compatibility
from agents.qa_v4.workers.basic import QAWorkerBasic as QAWorkerV4
```

**Verification:**
```bash
python3 -c "from agents.qa_v4 import QAWorkerV4; print('OK')"
```

**Expected Result:**
- Existing imports still work
- No breaking changes

---

## Phase 2: Enhanced Mode Implementation (4 hours)

### Step 2.1: Create Enhanced Worker

**File:** `agents/qa_v4/workers/enhanced.py`

**Base Template:**
```python
"""
QA Worker Enhanced Mode.

Features:
- All Basic features
- Warnings tracking (separate from issues)
- Enhanced security (8 patterns)
- Batch file processing
- Configurable flags
- R&D feedback (light version)
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

sys.path.insert(0, os.getcwd())

from agents.qa_v4.actions import QaActions
from agents.qa_v4.checklist_engine import evaluate_checklist
from agents.qa_v4.rnd_integration import send_to_rnd


class QAWorkerEnhanced:
    """
    Enhanced QA Worker with warnings and batch support.
    """
    
    def __init__(
        self,
        enable_lint: bool = True,
        enable_tests: bool = True,
        enable_security: bool = True,
        enable_rnd_feedback: bool = True,
    ):
        self.telemetry_file = Path("g/telemetry/qa_lane_execution.jsonl")
        self.telemetry_file.parent.mkdir(parents=True, exist_ok=True)
        self.actions = QaActions()
        self.enable_lint = enable_lint
        self.enable_tests = enable_tests
        self.enable_security = enable_security
        self.enable_rnd_feedback = enable_rnd_feedback

    def process_task(self, task_data: Dict[str, Any]) -> Dict[str, Any]:
        # Implementation details in next steps
        pass
```

**Verification:**
```bash
python3 -m py_compile agents/qa_v4/workers/enhanced.py
```

---

### Step 2.2: Implement Enhanced Features

**Key Features to Add:**

1. **Warnings Tracking:**
   ```python
   warnings = []
   issues = []
   
   # Separate warnings from critical issues
   if lint_result.get("warnings"):
       warnings.extend(lint_result["warnings"])
   if lint_result.get("errors"):
       issues.extend(lint_result["errors"])
   ```

2. **Batch File Processing:**
   ```python
   files_touched = task_data.get("files_touched", [])
   if isinstance(files_touched, str):
       files_touched = [files_touched]
   
   # Process all files
   for file_path in files_touched:
       # Process each file
   ```

3. **Enhanced Security (8 patterns):**
   - Use existing `QaActions` with 8 patterns
   - Already implemented in merged version

4. **R&D Feedback (Light):**
   ```python
   if self.enable_rnd_feedback and issues:
       send_to_rnd({
           "task_id": task_id,
           "issues": issues,
           "mode": "enhanced",
       })
   ```

**Verification:**
- Unit test: Enhanced mode processes warnings correctly
- Unit test: Batch files processed

---

### Step 2.3: Update Workers __init__.py

**File:** `agents/qa_v4/workers/__init__.py`

**Add:**
```python
from agents.qa_v4.workers.enhanced import QAWorkerEnhanced

__all__ = ["QAWorkerBasic", "QAWorkerEnhanced"]
```

---

## Phase 3: Full Mode Implementation (3 hours)

### Step 3.1: Create Full Worker

**File:** `agents/qa_v4/workers/full.py`

**Features to Port from Merged Version:**

1. **3-Level Status:**
   ```python
   status = "pass"  # pass | warning | fail
   if issues:
       status = "fail"
   elif warnings:
       status = "warning"
   ```

2. **ArchitectSpec-Driven Checklist:**
   ```python
   architect_spec = task_data.get("architect_spec", {})
   if architect_spec:
       checklist = evaluate_checklist(architect_spec, files_touched)
   ```

3. **3-Level Lint Fallback:**
   ```python
   # ruff → flake8 → py_compile
   lint_result = self.actions.run_lint(file_path)
   if not lint_result["success"]:
       lint_result = self.actions.run_flake8(file_path)
   if not lint_result["success"]:
       lint_result = self.actions.run_py_compile(file_path)
   ```

4. **R&D Feedback (Full):**
   ```python
   send_to_rnd({
       "task_id": task_id,
       "issues": issues,
       "warnings": warnings,
       "checklist": checklist_result,
       "mode": "full",
       "categorization": categorize_issues(issues),
   })
   ```

**Verification:**
- Unit test: 3-level status works
- Unit test: ArchitectSpec checklist evaluated

---

### Step 3.2: Update Workers __init__.py

**File:** `agents/qa_v4/workers/__init__.py`

**Add:**
```python
from agents.qa_v4.workers.full import QAWorkerFull

__all__ = ["QAWorkerBasic", "QAWorkerEnhanced", "QAWorkerFull"]
```

---

## Phase 4: Mode Selector Implementation (3 hours)

### Step 4.1: Create Mode Selector

**File:** `agents/qa_v4/mode_selector.py`

**Implementation:**

```python
"""
QA Mode Selection Logic.

Determines appropriate QA mode based on:
- Hard overrides (WO/Requirement/Env)
- Risk & complexity
- History
- Environment
"""

import os
from typing import Dict, Any, Optional


def calculate_qa_mode_score(
    wo_spec: Optional[Dict[str, Any]] = None,
    requirement: Optional[Dict[str, Any]] = None,
    dev_result: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
    env: Optional[Dict[str, Any]] = None,
) -> int:
    """
    Calculate score for QA mode selection.
    
    Returns: Score (0-10)
    """
    score = 0
    wo_spec = wo_spec or {}
    requirement = requirement or {}
    dev_result = dev_result or {}
    history = history or {}
    env = env or {}
    
    # Risk factors
    risk = wo_spec.get("risk", {}) or requirement.get("risk", {})
    risk_level = risk.get("level", "low")
    if risk_level == "high":
        score += 2
    elif risk_level == "medium":
        score += 1
    
    domain = risk.get("domain", "generic")
    if domain in {"security", "auth", "payment"}:
        score += 2
    elif domain == "api":
        score += 1
    
    # Complexity
    files = dev_result.get("files_touched", [])
    if isinstance(files, str):
        files = [files]
    if len(files) > 5:
        score += 1
    
    loc = dev_result.get("lines_of_code", 0)
    if loc > 800:
        score += 1
    
    # History
    recent_failures = history.get("recent_qa_failures_for_module", 0)
    if recent_failures >= 2:
        score += 1
    
    fragile_file = history.get("is_fragile_file", False)
    if fragile_file:
        score += 1
    
    return score


def select_qa_mode(
    wo_spec: Optional[Dict[str, Any]] = None,
    requirement: Optional[Dict[str, Any]] = None,
    dev_result: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
    env: Optional[Dict[str, Any]] = None,
) -> str:
    """
    Select appropriate QA mode.
    
    Returns: "basic" | "enhanced" | "full"
    """
    wo_spec = wo_spec or {}
    requirement = requirement or {}
    env = env or {}
    
    # 1. Hard override (highest priority)
    explicit_mode = (
        wo_spec.get("qa", {}).get("mode") or
        requirement.get("qa", {}).get("mode") or
        os.getenv("QA_MODE")
    )
    if explicit_mode in {"basic", "enhanced", "full"}:
        return explicit_mode
    
    # 2. Env-based defaults
    lac_env = env.get("LAC_ENV") or os.getenv("LAC_ENV", "dev")
    default_mode = "enhanced" if lac_env == "prod" else "basic"
    
    # 3. QA_STRICT upgrade
    if os.getenv("QA_STRICT") == "1":
        if default_mode == "basic":
            default_mode = "enhanced"
        elif default_mode == "enhanced":
            default_mode = "full"
    
    # 4. Score-based upgrade
    score = calculate_qa_mode_score(wo_spec, requirement, dev_result, history, env)
    
    if score >= 4:
        return "full"
    elif score >= 2:
        return "enhanced"
    else:
        return default_mode


def get_mode_selection_reason(
    mode: str,
    wo_spec: Optional[Dict[str, Any]] = None,
    requirement: Optional[Dict[str, Any]] = None,
    dev_result: Optional[Dict[str, Any]] = None,
    history: Optional[Dict[str, Any]] = None,
    env: Optional[Dict[str, Any]] = None,
) -> str:
    """
    Generate human-readable reason for mode selection.
    """
    reasons = []
    
    # Check override
    explicit = (
        (wo_spec or {}).get("qa", {}).get("mode") or
        (requirement or {}).get("qa", {}).get("mode") or
        os.getenv("QA_MODE")
    )
    if explicit:
        reasons.append(f"override={explicit}")
        return ", ".join(reasons)
    
    # Check score factors
    wo_spec = wo_spec or {}
    requirement = requirement or {}
    risk = wo_spec.get("risk", {}) or requirement.get("risk", {})
    
    if risk.get("level") == "high":
        reasons.append("risk.level=high")
    if risk.get("domain") in {"security", "auth", "payment"}:
        reasons.append(f"domain={risk.get('domain')}")
    
    files = (dev_result or {}).get("files_touched", [])
    if isinstance(files, str):
        files = [files]
    if len(files) > 5:
        reasons.append(f"files_count={len(files)}")
    
    if not reasons:
        lac_env = (env or {}).get("LAC_ENV") or os.getenv("LAC_ENV", "dev")
        reasons.append(f"env_default={lac_env}")
    
    return ", ".join(reasons) if reasons else "default"
```

**Verification:**
```bash
python3 -m py_compile agents/qa_v4/mode_selector.py
python3 -c "from agents.qa_v4.mode_selector import select_qa_mode; print(select_qa_mode())"
```

**Expected Result:**
- Returns "basic" (default)

---

## Phase 5: Factory Implementation (1 hour)

### Step 5.1: Create Factory

**File:** `agents/qa_v4/factory.py`

**Implementation:**

```python
"""
QA Worker Factory.

Creates appropriate QA worker based on mode.
"""

from typing import Dict, Any, Optional

from agents.qa_v4.workers.basic import QAWorkerBasic
from agents.qa_v4.workers.enhanced import QAWorkerEnhanced
from agents.qa_v4.workers.full import QAWorkerFull


class QAWorkerFactory:
    """
    Factory for creating QA workers.
    """
    
    @staticmethod
    def create(mode: str = "basic", **kwargs) -> Any:
        """
        Create QA worker for specified mode.
        
        Args:
            mode: "basic" | "enhanced" | "full"
            **kwargs: Additional arguments for worker initialization
        
        Returns:
            QA worker instance
        
        Raises:
            ValueError: If mode is invalid
        """
        if mode == "basic":
            return QAWorkerBasic(**kwargs)
        elif mode == "enhanced":
            return QAWorkerEnhanced(**kwargs)
        elif mode == "full":
            return QAWorkerFull(**kwargs)
        else:
            raise ValueError(f"Invalid QA mode: {mode}. Must be 'basic', 'enhanced', or 'full'")
```

**Verification:**
```bash
python3 -c "from agents.qa_v4.factory import QAWorkerFactory; w = QAWorkerFactory.create('basic'); print(type(w).__name__)"
```

**Expected Result:**
- `QAWorkerBasic`

---

## Phase 6: Integration (2 hours)

### Step 6.1: Update QA Handoff

**File:** `agents/dev_common/qa_handoff.py`

**Changes:**

1. **Import factory and selector:**
   ```python
   from agents.qa_v4.factory import QAWorkerFactory
   from agents.qa_v4.mode_selector import select_qa_mode, get_mode_selection_reason
   ```

2. **Update `handoff_to_qa()` function:**
   ```python
   def handoff_to_qa(
       qa_task: Dict[str, Any],
       wo_spec: Optional[Dict[str, Any]] = None,
       requirement: Optional[Dict[str, Any]] = None,
       history: Optional[Dict[str, Any]] = None,
   ) -> Dict[str, Any]:
       """
       Execute QA worker on prepared QA task with mode selection.
       
       Args:
           qa_task: Task prepared by prepare_qa_task()
           wo_spec: Work order spec (for mode override)
           requirement: Requirement doc (for mode override)
           history: History data (for auto-selection)
       
       Returns:
           QA execution result
       """
       if QAWorkerFactory is None:
           return {
               "status": "skipped",
               "reason": "QAWorkerFactory not available",
               "task_id": qa_task.get("task_id", "unknown"),
           }
       
       # Select mode
       env = {"LAC_ENV": os.getenv("LAC_ENV", "dev")}
       dev_result = qa_task.get("dev_result", {})
       
       mode = select_qa_mode(
           wo_spec=wo_spec,
           requirement=requirement,
           dev_result=dev_result,
           history=history,
           env=env,
       )
       
       mode_reason = get_mode_selection_reason(
           mode, wo_spec, requirement, dev_result, history, env
       )
       
       try:
           worker = QAWorkerFactory.create(mode=mode)
           result = worker.process_task(qa_task)
           
           # Add mode metadata
           result["qa_mode"] = mode
           result["qa_mode_reason"] = mode_reason
           
           return result
       except Exception as e:
           return {
               "status": "error",
               "reason": f"QA execution failed: {e}",
               "task_id": qa_task.get("task_id", "unknown"),
               "qa_mode": mode,
           }
   ```

3. **Update `run_qa_handoff()` to pass context:**
   ```python
   def run_qa_handoff(
       dev_result: Dict[str, Any],
       spec: Optional[Dict[str, Any]] = None,
       history: Optional[Dict[str, Any]] = None,
   ) -> Dict[str, Any]:
       """
       Full QA handoff workflow with mode selection.
       
       Args:
           dev_result: Result from dev worker
           spec: ArchitectSpec (optional, for QA checklist and mode override)
           history: History data (optional, for auto-selection)
       
       Returns:
           Merged result with QA status
       """
       if not should_handoff_to_qa(dev_result):
           result = dict(dev_result)
           result["qa_ran"] = False
           result["qa_status"] = "skipped"
           result["final_status"] = dev_result.get("status", "unknown")
           return result
       
       qa_task = prepare_qa_task(dev_result, spec)
       qa_result = handoff_to_qa(qa_task, wo_spec=spec, requirement=spec, history=history)
       return merge_qa_results(dev_result, qa_result)
   ```

**Verification:**
- E2E test: Dev → Mode Selection → QA → Results

---

### Step 6.2: Add Telemetry Logging

**File:** `agents/qa_v4/mode_selector.py` (add function)

**Add:**
```python
def log_mode_decision(
    task_id: str,
    mode: str,
    reason: str,
    score: int,
    override: bool,
    inputs: Dict[str, Any],
) -> None:
    """
    Log mode decision to telemetry.
    """
    from pathlib import Path
    from datetime import datetime, timezone
    import json
    
    telemetry_file = Path("g/telemetry/qa_mode_decisions.jsonl")
    telemetry_file.parent.mkdir(parents=True, exist_ok=True)
    
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "task_id": task_id,
        "mode_selected": mode,
        "mode_reason": reason,
        "mode_score": score,
        "override": override,
        "inputs": inputs,
    }
    
    with open(telemetry_file, "a") as f:
        f.write(json.dumps(entry) + "\n")
```

**Call in `handoff_to_qa()`:**
```python
log_mode_decision(
    task_id=qa_task.get("task_id", "unknown"),
    mode=mode,
    reason=mode_reason,
    score=calculate_qa_mode_score(wo_spec, requirement, dev_result, history, env),
    override=bool(explicit_mode),
    inputs={
        "risk_level": (wo_spec or {}).get("risk", {}).get("level", "low"),
        "domain": (wo_spec or {}).get("risk", {}).get("domain", "generic"),
        "files_count": len(dev_result.get("files_touched", [])),
        "recent_failures": (history or {}).get("recent_qa_failures_for_module", 0),
    },
)
```

**Verification:**
- Check `g/telemetry/qa_mode_decisions.jsonl` exists
- Verify entries are logged

---

## Phase 7: Guardrails & Safety (2 hours)

### Step 7.1: Implement Budget Limits

**File:** `agents/qa_v4/guardrails.py` (new)

**Implementation:**

```python
"""
QA Mode Guardrails.

Prevents mode abuse and ensures performance.
"""

import json
from pathlib import Path
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional


class QAModeGuardrails:
    """
    Guardrails for QA mode selection.
    """
    
    def __init__(self):
        self.budget_file = Path("g/data/qa_mode_budget.json")
        self.budget_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Daily limits
        self.limits = {
            "full": 10,
            "enhanced": 50,
            "basic": -1,  # Unlimited
        }
    
    def check_budget(self, mode: str) -> tuple[bool, Optional[str]]:
        """
        Check if mode is within budget.
        
        Returns:
            (allowed, reason)
        """
        if mode == "basic":
            return True, None
        
        # Load budget
        budget = self._load_budget()
        today = datetime.now(timezone.utc).date().isoformat()
        
        if today not in budget:
            budget[today] = {"full": 0, "enhanced": 0}
        
        count = budget[today].get(mode, 0)
        limit = self.limits.get(mode, 0)
        
        if limit > 0 and count >= limit:
            return False, f"{mode} mode budget exceeded ({count}/{limit})"
        
        return True, None
    
    def record_usage(self, mode: str) -> None:
        """
        Record mode usage.
        """
        if mode == "basic":
            return
        
        budget = self._load_budget()
        today = datetime.now(timezone.utc).date().isoformat()
        
        if today not in budget:
            budget[today] = {"full": 0, "enhanced": 0}
        
        budget[today][mode] = budget[today].get(mode, 0) + 1
        
        # Clean old entries (keep last 7 days)
        cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).date().isoformat()
        budget = {k: v for k, v in budget.items() if k >= cutoff}
        
        with open(self.budget_file, "w") as f:
            json.dump(budget, f, indent=2)
    
    def _load_budget(self) -> Dict[str, Any]:
        """
        Load budget from file.
        """
        if not self.budget_file.exists():
            return {}
        
        try:
            with open(self.budget_file, "r") as f:
                return json.load(f)
        except Exception:
            return {}
```

**Integration in `mode_selector.py`:**
```python
from agents.qa_v4.guardrails import QAModeGuardrails

guardrails = QAModeGuardrails()

# In select_qa_mode(), after determining mode:
allowed, reason = guardrails.check_budget(mode)
if not allowed:
    # Degrade mode
    if mode == "full":
        mode = "enhanced"
    elif mode == "enhanced":
        mode = "basic"
    
    # Record degradation
    log_mode_decision(..., override=False, degraded=True, degradation_reason=reason)
```

---

### Step 7.2: Implement Cooldown Logic

**Add to `guardrails.py`:**

```python
def check_cooldown(self, task_id: str, module: str) -> tuple[bool, Optional[str]]:
    """
    Check if module is in cooldown period.
    
    Returns:
        (should_upgrade, reason)
    """
    # Load recent failures
    # If module failed QA in last N tasks → suggest enhanced/full
    # Implementation: Check qa_lane_execution.jsonl for recent failures
    pass
```

---

## Phase 8: Testing (3 hours)

### Step 8.1: Unit Tests

**File:** `agents/qa_v4/tests/test_mode_selector.py` (new)

**Tests:**
1. Test hard override (WO spec)
2. Test risk-based selection
3. Test complexity-based selection
4. Test history-based escalation
5. Test guardrail budget limits

---

### Step 8.2: Integration Tests

**File:** `agents/dev_common/tests/test_qa_3mode_integration.py` (new)

**Tests:**
1. E2E: Basic mode selection
2. E2E: Enhanced mode (risk trigger)
3. E2E: Full mode (override)
4. E2E: Auto-degrade (guardrail)

---

### Step 8.3: Manual Verification

**Commands:**
```bash
# Test basic mode
python3 -c "
from agents.qa_v4.factory import QAWorkerFactory
worker = QAWorkerFactory.create('basic')
print('Basic mode OK')
"

# Test enhanced mode
python3 -c "
from agents.qa_v4.factory import QAWorkerFactory
worker = QAWorkerFactory.create('enhanced')
print('Enhanced mode OK')
"

# Test full mode
python3 -c "
from agents.qa_v4.factory import QAWorkerFactory
worker = QAWorkerFactory.create('full')
print('Full mode OK')
"

# Test mode selector
python3 -c "
from agents.qa_v4.mode_selector import select_qa_mode
mode = select_qa_mode()
print(f'Default mode: {mode}')
"
```

---

## Phase 9: Documentation (1 hour)

### Step 9.1: Update QA Documentation

**File:** `g/docs/qa_mode_guide.md` (new)

**Content:**
- Mode descriptions
- Configuration examples
- Auto-selection logic
- Override methods

---

## Verification Checklist

- [ ] All 3 modes functional
- [ ] Mode selector works correctly
- [ ] Factory creates correct workers
- [ ] Integration with qa_handoff works
- [ ] Telemetry logs mode decisions
- [ ] Guardrails prevent abuse
- [ ] Backward compatible (existing code works)
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Documentation complete

---

## Rollback Plan

If issues occur:

1. **Quick Rollback:** Revert `qa_handoff.py` to use `QAWorkerV4` directly
2. **Partial Rollback:** Keep structure, disable auto-selection (force basic)
3. **Full Rollback:** Revert all changes, restore original `qa_worker.py`

---

## Success Criteria

✅ All phases complete  
✅ All tests pass  
✅ Telemetry working  
✅ Backward compatible  
✅ Documentation updated

---

**Ready to proceed?** → Start with Phase 1: Structure Setup
