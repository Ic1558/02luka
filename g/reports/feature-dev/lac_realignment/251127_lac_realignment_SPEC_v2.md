# LAC Realignment Specification v2
**Feature ID:** `lac_realignment`  
**Version:** v2.0 (Finalized)
**Date:** 2025-11-27  
**Status:** Finalized  
**Author:** CLC (Code Lifecycle Controller)

---

## 1. Overview

### 1.2 Problem Statement

**Target Architecture:**
- CLC = **Optional Specialist Tool**, not a gateway
- Agents have **Direct Write** capability (via shared policy)
- **True Self-Completion:** Dev → QA → Docs → **DIRECT_MERGE**
- **Free-First Budget:** Paid lanes OFF by default, emergency-only, require approval

---
## 2. Architecture

### 2.2.1 Component Architecture - Developer Agents
- **Role:** Full developers (Reason + Write)
- **Capability:** `direct_write` via shared `policy.py`

### 2.2.5 Self-Complete Pipeline (P3)

**State Machine:**
```
NEW → DEV → ... → QA_PASSED → DOCS_DONE → **DIRECT_MERGE**
```
- CLC is no longer in the default path. It is an escalation path only.

### 2.2.7 Paid Lane Isolation (P5)

**Configuration:**
```yaml
# config/paid_lanes.yaml
paid_lanes:
  enabled: false           # DEFAULT OFF
  require_approval: true   # Boss must approve
  emergency_budget_thb: 50 # Emergency only
```

---
## 3. Data Flow

### 3.1 Default Local-Only Flow

```
User Request
    ↓
...
    ↓
QA Agent (Local)
    ↓
Docs Agent (Local)
    ↓
**DIRECT_MERGE** (if QA Passed & simple)
    ↓
Complete (No API calls, No CLC)
```
