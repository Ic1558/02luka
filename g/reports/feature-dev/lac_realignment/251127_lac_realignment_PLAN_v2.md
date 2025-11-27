# LAC Realignment Feature Plan v2
**Feature Slug:** `lac_realignment`  
**Date:** 2025-11-27  
**Status:** Finalized  
**Priority:** P0 (Critical Architecture Alignment)

---

## 1. Specification (SPEC)

### 1.1 Problem Statement

**Current State (Drift):**
- ❌ CLC = Claude API executor (locked to paid model)
- ❌ All file writes must go through CLC API
- ❌ Autonomous Team cannot self-complete
- ❌ Routing defaults to API lanes
- ❌ No OSS/GMX CLI reasoning lanes
- ❌ Budget/state tied to external services

**Target State (Concept Alignment):**
- ✅ CLC = **Optional Specialist Tool**, not a gateway
- ✅ Agents have **Direct Write** capability (via shared policy)
- ✅ **True Self-Completion:** Dev → QA → Docs → **DIRECT_MERGE**
- ✅ **Free-First Budget:** Paid lanes OFF by default, emergency-only, require approval
- ✅ Local-first default routing
- ✅ OSS/GMX CLI reasoning lanes available
- ✅ Local state/memory per lane

---
## 2. Task Breakdown

### Phase 1: CLC Local-First (P1)
...
### Phase 3: Self-Complete Pipeline (P3)
- [ ] State Machine: `NEW → DEV → QA → DOCS → DIRECT_MERGE`
- [ ] Add `self_apply: true|false` flag to WO spec to control pipeline.
- [ ] Implement agent direct-write capability using a shared `policy.py` module.
...
### Phase 5: Paid Lane Isolation (P5)
- [ ] **Task:** Add paid lane config
  - **File:** `config/paid_lanes.yaml` (new)
  - **Content:**
    ```yaml
    paid_lanes:
      enabled: false           # DEFAULT OFF
      require_approval: true   # Boss must approve
      emergency_budget_thb: 50 # Emergency only
    ```
...
---
## 3. Current vs Target State Comparison

### 3.1 Executor Routing

| Aspect | Current | Target |
|--------|---------|--------|
| Default Executor | CLC API (Claude) | Agent Direct Write / `clc_local` for complex |
...

### 3.2 Reasoning Lanes

| Aspect | Current | Target |
|--------|---------|--------|
| OSS Reasoner | ❌ "Reasoning" only | ✅ **Full Developer** (Reason + Write) |
| GMX CLI Worker | ❌ "Reasoning" only | ✅ **Full Developer** (Reason + Write) |
...

### 3.3 Pipeline Automation

| Aspect | Current | Target |
|--------|---------|--------|
| Dev → QA | Manual | Auto-trigger |
| QA → Docs | Manual | Auto-trigger (if QA pass) |
| Docs → Merge | Manual approval | **DIRECT_MERGE** (if QA pass & simple) |
...
