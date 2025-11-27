# LAC Realignment Specification
**Feature ID:** `lac_realignment`  
**Version:** v1.0  
**Date:** 2025-11-27  
**Status:** Draft  
**Author:** CLC (Code Lifecycle Controller)

---

## 1. Overview

### 1.2 Problem Statement

**Target Architecture:**
- CLC = Universal Local Executor (model-agnostic)
- `clc_local` is default executor
- Autonomous Team self-completes (Dev → QA → Docs → Merge)
- Paid lanes are explicit, logged, budget-guarded

---
## 2. Architecture

### 2.2.5 Self-Complete Pipeline (P3)

**State Machine:**
```
NEW → DEV → ... → QA_PASSED → DOCS_DONE → **CLC Local Executor** → MERGE
```

### 2.2.7 Paid Lane Isolation (P5)

**Configuration:**
```yaml
# config/paid_lanes.yaml
paid_lanes:
  enabled: false
  daily_budget_thb: 300
  warn_at_ratio: 0.8
```

---
## 3. Data Flow

### 3.1 Default Local-Only Flow

```
User Request
    ↓
...
    ↓
**CLC Local Executor** (Default)
    ↓
Auto-Merge (if enabled)
    ↓
Complete (No API calls)
```