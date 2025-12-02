# QA Mode Configuration Guide

**Status:** Production | **Version:** 1.0 | **Date:** 2025-12-03  
**WO:** WO-QA-003 | **System:** LAC v4 QA Lane

---

## Overview

This guide provides detailed configuration options for the QA 3-Mode System, including Work Order specifications, environment variables, and programmatic configuration.

---

## Work Order Specification Format

### Basic Format

```yaml
wo_id: WO-EXAMPLE-001
title: Example Work Order
qa:
  mode: enhanced  # basic | enhanced | full (optional override)
risk:
  level: high     # low | medium | high
  domain: security  # generic | api | security | auth | payment
```

### Full Example

```yaml
wo_id: WO-SECURITY-001
title: Critical Security Fix
description: Fix authentication bypass vulnerability

qa:
  mode: full  # Override to full mode

risk:
  level: high
  domain: security
  details: |
    This change affects authentication logic.
    Requires comprehensive QA.

actions:
  - type: modify
    target: agents/auth.py
    description: Fix authentication bypass
```

---

## Requirement Document Format

### Basic Format

```yaml
qa:
  mode: full  # Optional override
```

### Full Example

```yaml
requirement_id: REQ-SECURITY-001
title: Security Enhancement

qa:
  mode: full
  checklist:
    - security_review
    - penetration_testing

risk:
  level: high
  domain: security
```

---

## Environment Variables

### Mode Selection

| Variable | Values | Description | Default |
|----------|--------|-------------|---------|
| `QA_MODE` | `basic`, `enhanced`, `full` | Hard override for QA mode | None |
| `QA_STRICT` | `0`, `1` | Upgrade mode by 1 level | `0` |
| `LAC_ENV` | `dev`, `prod`, `exp` | Environment (affects default mode) | `dev` |

**Examples:**
```bash
# Force full mode
export QA_MODE=full

# Upgrade by 1 level (basic → enhanced, enhanced → full)
export QA_STRICT=1

# Set environment (prod defaults to enhanced)
export LAC_ENV=prod
```

### Budget Limits

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `QA_MODE_BUDGET_FULL` | Integer | Daily limit for full mode | `10` |
| `QA_MODE_BUDGET_ENHANCED` | Integer | Daily limit for enhanced mode | `50` |

**Examples:**
```bash
# Increase full mode budget to 20/day
export QA_MODE_BUDGET_FULL=20

# Increase enhanced mode budget to 100/day
export QA_MODE_BUDGET_ENHANCED=100
```

### Performance Thresholds

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `QA_MODE_LATENCY_THRESHOLD_FULL` | Float | Latency threshold for full mode (seconds) | `30.0` |
| `QA_MODE_LATENCY_THRESHOLD_ENHANCED` | Float | Latency threshold for enhanced mode (seconds) | `15.0` |
| `QA_MODE_LATENCY_THRESHOLD_BASIC` | Float | Latency threshold for basic mode (seconds) | `5.0` |

**Examples:**
```bash
# Increase full mode threshold to 60s
export QA_MODE_LATENCY_THRESHOLD_FULL=60.0

# Increase enhanced mode threshold to 30s
export QA_MODE_LATENCY_THRESHOLD_ENHANCED=30.0
```

### Cooldown

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `QA_MODE_COOLDOWN_MINUTES` | Integer | Cooldown period after failures (minutes) | `30` |

**Example:**
```bash
# Set cooldown to 60 minutes
export QA_MODE_COOLDOWN_MINUTES=60
```

---

## Programmatic Configuration

### Using Factory

```python
from agents.qa_v4.factory import QAWorkerFactory

# Direct mode creation
worker = QAWorkerFactory.create("enhanced")

# Intelligent mode selection
result = QAWorkerFactory.create_for_task({
    "task_id": "WO-TEST",
    "risk": {"level": "high", "domain": "security"},
    "qa": {"mode": "full"},  # Override
    "files_touched": ["test.py"],
    "history": {"recent_qa_failures_for_module": 2},
    "env": {"LAC_ENV": "prod"},
})
```

### Using Mode Selector

```python
from agents.qa_v4.mode_selector import select_qa_mode

mode = select_qa_mode(
    wo_spec={"qa": {"mode": "full"}},
    requirement={"qa": {"mode": "enhanced"}},
    dev_result={"files_touched": ["test.py"]},
    history={"recent_qa_failures_for_module": 2},
    env={"LAC_ENV": "prod"},
)
```

### Using QA Handoff

```python
from agents.dev_common.qa_handoff import run_qa_handoff

dev_result = {
    "status": "success",
    "task_id": "WO-TEST",
    "files_touched": ["test.py"],
    "risk": {"level": "high", "domain": "security"},
}

spec = {
    "qa": {"mode": "full"},  # Override
    "risk": {"level": "high", "domain": "security"},
}

history = {
    "recent_qa_failures_for_module": 2,
    "is_fragile_file": True,
}

result = run_qa_handoff(dev_result, spec=spec, history=history)
```

---

## Configuration Files

### Budget File

**Location:** `g/data/qa_mode_budget.json`

**Format:**
```json
{
  "2025-12-03": {
    "full": 5,
    "enhanced": 12
  },
  "2025-12-02": {
    "full": 10,
    "enhanced": 25
  }
}
```

**Management:**
- Automatically created on first use
- Automatically cleaned (keeps last 7 days)
- Manually editable if needed

### Telemetry File

**Location:** `g/telemetry/qa_mode_decisions.jsonl`

**Format:**
```json
{"timestamp": "2025-12-03T10:30:00.000Z", "task_id": "WO-001-qa", "mode_selected": "full", ...}
{"timestamp": "2025-12-03T10:31:00.000Z", "task_id": "WO-002-qa", "mode_selected": "enhanced", ...}
```

**Usage:**
- Append-only log file
- One entry per mode decision
- Used for analysis and debugging

---

## Configuration Examples

### Example 1: Development Environment

```bash
# .env or shell profile
export LAC_ENV=dev
export QA_MODE_BUDGET_FULL=5      # Lower budget for dev
export QA_MODE_BUDGET_ENHANCED=20
```

**Result:** Default mode is Basic, lower budgets prevent abuse.

### Example 2: Production Environment

```bash
# .env or shell profile
export LAC_ENV=prod
export QA_STRICT=1                # Upgrade by 1 level
export QA_MODE_BUDGET_FULL=20     # Higher budget for prod
export QA_MODE_BUDGET_ENHANCED=100
```

**Result:** Default mode is Enhanced, QA_STRICT upgrades to Full when needed.

### Example 3: Security-Critical Project

```yaml
# WO Spec
wo_id: WO-SECURITY-001
qa:
  mode: full  # Always use full mode
risk:
  level: high
  domain: security
```

**Result:** Always uses Full mode regardless of other factors.

### Example 4: High-Volume Project

```bash
# Increase budgets for high-volume project
export QA_MODE_BUDGET_FULL=50
export QA_MODE_BUDGET_ENHANCED=200
export QA_MODE_LATENCY_THRESHOLD_FULL=60.0
```

**Result:** Higher budgets and thresholds for high-volume usage.

---

## Configuration Priority

Configuration is applied in the following priority order (highest to lowest):

1. **Hard Override** (Highest)
   - `QA_MODE` environment variable
   - `qa.mode` in WO spec
   - `qa.mode` in requirement

2. **Environment-Based Defaults**
   - `LAC_ENV=prod` → Enhanced
   - `LAC_ENV=dev` → Basic

3. **QA_STRICT Upgrade**
   - `QA_STRICT=1` → Upgrade by 1 level

4. **Score-Based Selection**
   - Risk + Complexity + History → Score → Mode

5. **Guardrails** (Applied after selection)
   - Budget limits → Degrade if exceeded
   - Performance → Warn if exceeded

---

## Advanced Configuration

### Custom Guardrails

```python
from agents.qa_v4.guardrails import QAModeGuardrails

# Create custom guardrails instance
guardrails = QAModeGuardrails(
    budget_file=Path("custom/budget.json")
)

# Custom limits
guardrails.limits = {
    "full": 20,
    "enhanced": 100,
    "basic": -1,
}

# Custom thresholds
guardrails.performance_thresholds = {
    "full": 60.0,
    "enhanced": 30.0,
    "basic": 10.0,
}
```

### Custom Mode Selector

```python
from agents.qa_v4.mode_selector import calculate_qa_mode_score, select_qa_mode

# Calculate custom score
score = calculate_qa_mode_score(
    wo_spec={"risk": {"level": "high"}},
    dev_result={"files_touched": ["test.py"]},
    history={"recent_qa_failures_for_module": 2},
)

# Custom selection logic
if score >= 5:  # Custom threshold
    mode = "full"
elif score >= 3:
    mode = "enhanced"
else:
    mode = "basic"
```

---

## Troubleshooting Configuration

### Issue: Mode Not Respecting Override

**Check:**
1. Override format: `qa.mode: full` (not `qa_mode: full`)
2. Environment variable: `QA_MODE=full` (not `QA_MODE="full"`)
3. Priority: Hard override should work regardless of other factors

**Solution:**
```python
# Debug mode selection
from agents.qa_v4.mode_selector import select_qa_mode, get_mode_selection_reason

mode = select_qa_mode(wo_spec={"qa": {"mode": "full"}})
reason = get_mode_selection_reason(mode=mode, wo_spec={"qa": {"mode": "full"}})
print(f"Mode: {mode}, Reason: {reason}")
```

### Issue: Budget Not Resetting

**Check:**
1. Budget file: `g/data/qa_mode_budget.json`
2. Date format: Should be ISO format (`YYYY-MM-DD`)
3. Cleanup: Old entries (>7 days) should be removed

**Solution:**
```python
# Manually reset budget
from agents.qa_v4.guardrails import get_guardrails
import json
from pathlib import Path
from datetime import datetime, timezone

budget_file = Path("g/data/qa_mode_budget.json")
budget = {}
today = datetime.now(timezone.utc).date().isoformat()
budget[today] = {"full": 0, "enhanced": 0}
with open(budget_file, "w") as f:
    json.dump(budget, f, indent=2)
```

### Issue: Performance Thresholds Not Working

**Check:**
1. Environment variable format: `QA_MODE_LATENCY_THRESHOLD_FULL=30.0` (float)
2. Execution time tracking: `result["qa_execution_time_seconds"]`
3. Warnings: Check `result.get("warnings", [])`

**Solution:**
```python
# Check performance
from agents.qa_v4.guardrails import get_guardrails

guardrails = get_guardrails()
perf_ok, reason = guardrails.check_performance("full", 35.0)
print(f"Acceptable: {perf_ok}, Reason: {reason}")
```

---

## Best Practices

1. **Use Environment Variables for Global Settings**
   - Budget limits, thresholds, cooldown
   - Set in `.env` or shell profile

2. **Use WO Spec for Task-Specific Overrides**
   - Mode overrides for specific tasks
   - Risk profiles for specific changes

3. **Monitor Telemetry Regularly**
   - Review mode decisions
   - Adjust budgets based on usage
   - Identify patterns

4. **Start Conservative, Adjust as Needed**
   - Start with default budgets
   - Increase based on actual usage
   - Monitor performance warnings

5. **Document Custom Configurations**
   - Document why overrides are used
   - Document budget adjustments
   - Document threshold changes

---

## Related Documentation

- [QA Mode Guide](./qa_mode_guide.md) - User guide and overview
- [QA Mode Strategy Spec](../specs/lac_v4_qa_mode_strategy.md) - Architecture specification

---

**Last Updated:** 2025-12-03  
**Maintained By:** GG (Claude Desktop)
