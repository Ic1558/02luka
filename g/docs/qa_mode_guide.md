# QA Mode Guide - 3-Mode System

**Status:** Production | **Version:** 1.0 | **Date:** 2025-12-03  
**WO:** WO-QA-003 | **System:** LAC v4 QA Lane

---

## Executive Summary

The QA 3-Mode System provides intelligent, context-aware quality assurance with three levels of rigor: **Basic**, **Enhanced**, and **Full**. The system automatically selects the appropriate mode based on risk, complexity, and history, while allowing manual overrides when needed.

**Key Benefits:**
- ⚡ **Performance:** Fast QA for routine tasks, comprehensive QA when needed
- 🛡️ **Risk Management:** Auto-escalate QA rigor for high-risk domains
- 🔧 **Flexibility:** Manual override available, but smart defaults
- 📊 **Telemetry:** All mode decisions logged for analysis

---

## Mode Overview

### 🟢 Basic Mode (Default)

**Purpose:** Fast, lightweight QA for routine tasks

**Features:**
- ✅ File existence check
- ✅ Minimal linting (ruff → flake8 fallback)
- ✅ Test execution (if test files present)
- ✅ Basic security patterns (6 patterns)
- ✅ Simple checklist evaluation
- ❌ No warnings tracking
- ❌ No R&D feedback
- ❌ No 3-level status

**Use Cases:**
- Dev loop (interactive development)
- Low-risk features
- Small file changes (<3 files)
- Non-critical domains

**Performance:** <500ms typical

**When Selected:**
- Default for dev environment
- Low risk, low complexity tasks
- No recent failures

---

### 🟡 Enhanced Mode

**Purpose:** Balanced QA with warnings and enhanced security

**Features:**
- ✅ All Basic features
- ✅ Warnings tracking (separate from issues)
- ✅ Enhanced security (8 patterns)
- ✅ Batch file support
- ✅ Light R&D feedback (on failures only)
- ❌ No 3-level status
- ❌ No ArchitectSpec-driven checklist

**Use Cases:**
- Medium-risk features
- Production environment (default)
- Modules with recent failures
- Multiple files changed (5+ files)

**Performance:** 1-3s typical

**When Selected:**
- Default for prod environment
- Medium risk or complexity
- Recent QA failures (2+)
- QA_STRICT=1 upgrade

---

### 🔴 Full Mode

**Purpose:** Comprehensive QA with all features

**Features:**
- ✅ All Enhanced features
- ✅ 3-level status (pass/warning/fail)
- ✅ ArchitectSpec-driven checklist
- ✅ Full R&D feedback (with categorization)
- ✅ 3-level lint fallback (ruff → flake8 → py_compile)
- ✅ Comprehensive security patterns (8-12 patterns)

**Use Cases:**
- High-risk domains (security, auth, payment)
- Critical production changes
- Explicit override via WO spec
- Nightly/batch jobs with time budget

**Performance:** 3-10s typical

**When Selected:**
- Explicit override (WO/Requirement/Env)
- High risk + security domain
- Score >= 4 (risk + complexity + history)
- QA_STRICT=1 in prod

---

## Auto-Selection Logic

The system automatically selects the appropriate QA mode based on multiple factors:

### Decision Priority (Highest to Lowest)

1. **Hard Override** (Highest Priority)
   - WO spec: `qa.mode: full`
   - Requirement: `qa.mode: enhanced`
   - Environment: `QA_MODE=full`

2. **Environment-Based Defaults**
   - `LAC_ENV=prod` → Enhanced (default)
   - `LAC_ENV=dev` → Basic (default)

3. **QA_STRICT Upgrade**
   - `QA_STRICT=1` → Upgrade by 1 level
   - Basic → Enhanced
   - Enhanced → Full

4. **Score-Based Upgrade**
   - Score >= 4 → Full
   - Score >= 2 → Enhanced
   - Score < 2 → Default (Basic/Enhanced)

5. **Guardrails** (Applied after selection)
   - Budget limits → Degrade if exceeded
   - Performance → Warn if exceeded

### Scoring Factors

The system calculates a score (0-10) based on:

| Factor | Points | Description |
|--------|--------|-------------|
| Risk Level: High | +2 | High-risk changes |
| Risk Level: Medium | +1 | Medium-risk changes |
| Domain: Security/Auth/Payment | +2 | Critical domains |
| Domain: API | +1 | API changes |
| Complexity: Files >5 | +1 | Many files changed |
| Complexity: LOC >800 | +1 | Large changes |
| History: Recent Failures >=2 | +1 | Module has issues |
| History: Fragile File | +1 | Known problematic file |

**Score Mapping:**
- Score >= 4 → Full mode
- Score >= 2 → Enhanced mode
- Score < 2 → Default mode (Basic/Enhanced)

---

## Manual Override Methods

### 1. Work Order Spec

```yaml
wo_id: WO-EXAMPLE-001
title: Critical Security Fix
qa:
  mode: full  # basic | enhanced | full
risk:
  level: high
  domain: security
```

### 2. Requirement Document

```yaml
qa:
  mode: enhanced
```

### 3. Environment Variable

```bash
export QA_MODE=full
```

### 4. QA_STRICT Mode

```bash
export QA_STRICT=1  # Upgrades by 1 level
```

---

## Guardrails & Safety

### Budget Limits

Daily limits prevent mode abuse:

- **Full Mode:** 10/day (default, configurable via `QA_MODE_BUDGET_FULL`)
- **Enhanced Mode:** 50/day (default, configurable via `QA_MODE_BUDGET_ENHANCED`)
- **Basic Mode:** Unlimited

**Behavior:**
- If budget exceeded, mode automatically degrades
- Full → Enhanced → Basic
- Budget tracked in `g/data/qa_mode_budget.json`

### Performance Monitoring

Latency thresholds (configurable):

- **Full Mode:** 30s (default, `QA_MODE_LATENCY_THRESHOLD_FULL`)
- **Enhanced Mode:** 15s (default, `QA_MODE_LATENCY_THRESHOLD_ENHANCED`)
- **Basic Mode:** 5s (default, `QA_MODE_LATENCY_THRESHOLD_BASIC`)

**Behavior:**
- Warnings logged if threshold exceeded
- Does not fail QA (informational only)

### Cooldown Logic

Modules with recent failures (2+) are automatically suggested for enhanced/full mode.

---

## Telemetry

All mode decisions are logged to `g/telemetry/qa_mode_decisions.jsonl`:

```json
{
  "timestamp": "2025-12-03T10:30:00.000Z",
  "task_id": "WO-EXAMPLE-001-qa",
  "mode_selected": "full",
  "mode_reason": "override=full",
  "mode_score": 0,
  "override": true,
  "degraded": false,
  "inputs": {
    "risk_level": "high",
    "domain": "security",
    "files_count": 3,
    "recent_failures": 0
  }
}
```

**Fields:**
- `mode_selected`: Selected mode (basic/enhanced/full)
- `mode_reason`: Human-readable reason
- `mode_score`: Calculated score (0-10)
- `override`: Whether mode was overridden
- `degraded`: Whether mode was degraded by guardrails
- `inputs`: Input parameters for debugging

---

## Usage Examples

### Example 1: Default Behavior

```python
from agents.dev_common.qa_handoff import run_qa_handoff

dev_result = {
    "status": "success",
    "task_id": "WO-SIMPLE-001",
    "files_touched": ["agents/utils.py"],
    "lane": "oss",
}

result = run_qa_handoff(dev_result)
# Mode: basic (default for dev)
```

### Example 2: Risk-Based Selection

```python
dev_result = {
    "status": "success",
    "task_id": "WO-SECURITY-001",
    "files_touched": ["agents/auth.py"],
    "lane": "oss",
    "risk": {"level": "high", "domain": "security"},
}

result = run_qa_handoff(dev_result)
# Mode: full (high risk + security domain)
```

### Example 3: Manual Override

```python
dev_result = {
    "status": "success",
    "task_id": "WO-CRITICAL-001",
    "files_touched": ["agents/payment.py"],
    "lane": "oss",
}

spec = {"qa": {"mode": "full"}}
result = run_qa_handoff(dev_result, spec=spec)
# Mode: full (explicit override)
```

### Example 4: Factory Direct Usage

```python
from agents.qa_v4.factory import QAWorkerFactory

# Direct mode creation
worker = QAWorkerFactory.create("enhanced")

# Intelligent mode selection
result = QAWorkerFactory.create_for_task({
    "task_id": "WO-TEST",
    "risk": {"level": "high", "domain": "security"},
    "files_touched": ["test.py"],
})
worker = result["worker"]
mode = result["mode"]  # "full"
reason = result["reason"]  # "risk.level=high, domain=security"
```

---

## Migration Guide

### For Existing Code

The system is **backward compatible**. Existing code continues to work:

```python
from agents.qa_v4 import QAWorkerV4

worker = QAWorkerV4()  # Still works (points to Basic)
```

### For New Code

Use the factory for intelligent mode selection:

```python
from agents.qa_v4.factory import create_worker_for_task

result = create_worker_for_task(task_data)
worker = result["worker"]
```

---

## Troubleshooting

### Mode Not Upgrading

**Issue:** Expected Enhanced/Full but got Basic

**Solutions:**
1. Check risk level in WO spec: `risk.level: high`
2. Check domain: `risk.domain: security`
3. Check score factors (files count, LOC, history)
4. Use explicit override: `qa.mode: enhanced`

### Budget Exceeded

**Issue:** Mode degraded due to budget

**Solutions:**
1. Check budget status: `g/data/qa_mode_budget.json`
2. Increase budget via env: `QA_MODE_BUDGET_FULL=20`
3. Wait for next day (budget resets daily)

### Performance Warnings

**Issue:** Performance warnings in results

**Solutions:**
1. Check execution time: `result["qa_execution_time_seconds"]`
2. Increase threshold: `QA_MODE_LATENCY_THRESHOLD_FULL=60.0`
3. Optimize QA checks or use lower mode

---

## Best Practices

1. **Let Auto-Selection Work:** Trust the system for most cases
2. **Override When Critical:** Use explicit override for critical changes
3. **Monitor Telemetry:** Review mode decisions regularly
4. **Adjust Budgets:** Tune budget limits based on usage patterns
5. **Use Appropriate Mode:** Don't force Full mode for simple changes

---

## Related Documentation

- [QA Mode Configuration](./qa_mode_configuration.md) - Detailed configuration guide
- [QA Mode Strategy Spec](../specs/lac_v4_qa_mode_strategy.md) - Architecture specification
- [LAC v4 Developer Lane](../docs/AI_OP_001_v4.md) - Dev lane integration

---

**Last Updated:** 2025-12-03  
**Maintained By:** GG (Claude Desktop)
