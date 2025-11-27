# LAC Realignment Feature Plan
**Feature Slug:** `lac_realignment`  
**Date:** 2025-11-27  
**Status:** Planning  
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
- ✅ CLC = Universal Local Executor (model-agnostic)
- ✅ Local-first default routing
- ✅ OSS/GMX CLI reasoning lanes available
- ✅ Autonomous Team self-completes (Dev → QA → Docs → Merge)
- ✅ Paid lanes are explicit, logged, budget-guarded
- ✅ Local state/memory per lane

---
## 2. Task Breakdown

### Phase 1: CLC Local-First (P1)
...
### Phase 3: Self-Complete Pipeline (P3)
- [ ] State Machine: `NEW → DEV_IN_PROGRESS → DEV_DONE → QA_IN_PROGRESS → QA_PASSED → DOCS_DONE → CLC_LOCAL → MERGED`
...
### Phase 5: Paid Lane Isolation (P5)
- [ ] **Task:** Add paid lane config
  - **File:** `config/paid_lanes.yaml` (new)
  - **Content:**
    ```yaml
    paid_lanes:
      enabled: false
      daily_budget_thb: 300
      warn_at_ratio: 0.8
    ```
...
---
## 3. Current vs Target State Comparison

### 3.1 Executor Routing

| Aspect | Current | Target |
|--------|---------|--------|
| Default Executor | CLC API (Claude) | `clc_local` (local Python) |
...

### 3.2 Reasoning Lanes

| Aspect | Current | Target |
|--------|---------|--------|
| OSS Reasoner | ❌ Not exists | ✅ `agents/oss_reasoner/worker.py` |
| GMX CLI Worker | ❌ Not exists | ✅ `agents/gmx_cli/worker.py` |
...

### 3.3 Pipeline Automation

| Aspect | Current | Target |
|--------|---------|--------|
| Dev → QA | Manual | Auto-trigger |
| QA → Docs | Manual | Auto-trigger (if QA pass) |
| Docs → Merge | Manual approval | Auto-merge via **CLC_LOCAL** |
...