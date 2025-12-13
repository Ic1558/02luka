# Liam Audit Logger - Specification

**Feature ID:** LIAM-AUDIT-001  
**Version:** 1.0.0 (Restored from liam_251206 archive)  
**Date:** 2025-12-06  
**Status:** Deployed & Production

---

## Problem Statement

Liam (route orchestrator) makes many decisions but doesn't log them. When similar situations arise, there's no way to recall past reasoning.

**Pain Point:**
> "ไม่เสียเวลาคิดซ้ำ" - Don't waste time re-thinking

---

## Core Principle

> **"บันทึกทุกเรื่องที่ใช้สมอง (thinking) ไม่ใช่แค่การทำ (doing)"**

**If thinking > 5 minutes → Log it** ✅  
**If just executing routine → Don't log** ❌

---

## What TO Log ✅

### 1. Route Decisions
```json
{
  "agent": "liam",
  "action": "wo_route_decision",
  "wo_id": "WO-XXX",
  "objective": "Analyze chart...",
  "lane_selected": "trader",
  "lane_rejected": ["dev_oss", "ops"],
  "reasoning": "Complex chart analysis requires specialized trader lane",
  "difficulty": "high"
}
```

### 2. System Analysis
```json
{
  "agent": "liam",
  "action": "system_analysis",
  "topic": "notification_architecture",
  "findings": ["Worker pattern optimal", "LaunchAgent suitable"],
  "output": "g/reports/notification_analysis.md"
}
```

### 3. Retrospectives / Lessons Learned
```json
{
  "agent": "liam",
  "action": "retrospective",
  "wo_id": "WO-XXX",
  "status": "failed",
  "root_cause": "Wrong lane selection",
  "lesson": "GUI tasks require hybrid agent, not free LAC",
  "recommendation": "Update routing criteria"
}
```

### 4. Feature Deployments
```json
{
  "agent": "liam",
  "action": "feature_deployment",
  "feature": "liam_audit_logger",
  "version": "1.0.0",
  "status": "deployed"
}
```

---

## What NOT TO Log ❌

1. Simple file reads (no thinking)
2. Routine operations (frequent, no decisions)
3. Temporary debugging (fix and forget)

---

## Implementation

### Files Created
- `g/core/lib/audit_logger.py` - Main logger
- `g/core/lib/audit_logger_examples.py` - Usage examples
- `g/core/lib/AUDIT_LOGGER_USAGE.md` - Documentation
- `g/core/lib/test_audit_logger.py` - Tests

### Telemetry Output
- `g/telemetry/liam_audit.jsonl`
- `g/telemetry/gmx_audit.jsonl`
- `g/telemetry/clc_audit.jsonl`

### API
```python
from audit_logger import log_liam, log_gmx, log_clc

log_liam('action_name',
         key1='value1',
         key2='value2')
```

---

## Supported Agents

| Agent | Function | Output File |
|-------|----------|-------------|
| Liam | `log_liam()` | `liam_audit.jsonl` |
| GMX | `log_gmx()` | `gmx_audit.jsonl` |
| CLC | `log_clc()` | `clc_audit.jsonl` |

---

## Status

- [x] Core logger implemented ✅
- [x] Example usage documented ✅
- [x] Tests passed (4/4) ✅
- [x] GMX support added ✅
- [x] Telemetry aggregation linked ✅

**Production Ready:** ✅

---

**Restored from:** liam_251206.md chat archive
