# V4 Unified Task Layer - IMPLEMENTATION PLAN

**Version**: v0.1
**Date**: 2025-11-21
**Owner**: GMX
**Status**: DESIGN

---

## 1. Objective

To execute the migration of the 02luka system to the V4 Unified Task Layer. This plan outlines the concrete steps required to refactor agent personas and establish the new GMX-centric planning flow.

---

## 2. Implementation Phases

This project will be executed in distinct, sequential phases to ensure stability and minimize disruption.

### **Phase 2.1: Schema and Persona Formalization**

The foundation of the new system.

1.  **Finalize `TASK_SPEC_v4` Schema:**
    -   **Action:** Create a formal JSON Schema definition file.
    -   **File:** `g/core/task_spec_v4_schema.json`
    -   **Details:** This file will contain the machine-readable schema, enabling automated validation of all future task specs.

2.  **Update GMX Persona (The Planner):**
    -   **Action:** Update the GMX planner's core persona to make it the sole generator of `TASK_SPEC_v4`.
    -   **File:** `agents/gmx/PERSONA_PROMPT_v4.md`
    -   **Details:** The new persona will instruct GMX to always output tasks in the new v4 format and to refuse any requests to perform actions directly.

3.  **Update GG Persona (The Router):**
    -   **Action:** Rework the GG agent's persona to function purely as a router and evaluator.
    -   **File:** `agents/gg/PERSONA_PROMPT_v4.md`
    -   **Details:** The new persona will instruct GG to forward all planning requests to GMX and to focus on evaluating the outcomes of completed tasks against their acceptance criteria.

### **Phase 2.2: Agent Migration Blueprints**

For each agent, we will create a detailed migration plan. This phase does not involve writing the implementation code, only the plans.

1.  **Plan Liam Migration:**
    -   **Action:** Create a task plan for refactoring Liam.
    -   **File:** `g/reports/feature-dev/v4_agent_migrations/liam_v4_migration_plan.md`
    -   **Details:** The plan will specify changes to make Liam's executor consume `TASK_SPEC_v4` and enforce the "Proof of Use" memory protocol within the new task structure.

2.  **Plan CLC Migration:**
    -   **Action:** Create a task plan for refactoring the CLC agent.
    -   **File:** `g/reports/feature-dev/v4_agent_migrations/clc_v4_migration_plan.md`
    -   **Details:** The plan will outline how to adapt CLC to operate as a domain-limited executor that receives its instructions exclusively via a `TASK_SPEC_v4` from the Bridge.

3.  **Plan Paula Migration:**
    -   **Action:** Create a task plan for migrating Paula's trading and data tasks.
    -   **File:** `g/reports/feature-dev/v4_agent_migrations/paula_v4_migration_plan.md`
    -   **Details:** This plan will map Paula's existing ad-hoc tasks to the new structured `TASK_SPEC_v4` format, specifying `lane: 'data-ops'` or `lane: 'trading'`.

### **Phase 2.3: System Integration & Testing**

1.  **Update Bridge Dispatcher:**
    -   **Action:** Modify `dispatch_to_bridge.py` to handle the new `lane` field in `TASK_SPEC_v4`.
    -   **Details:** The router will need a mapping from `lane` to the correct inbox (e.g., `feature-dev` -> `LIAM`, `code-review` -> `MARY`). This ensures tasks are sent to the right agent group.

2.  **Implement Dual-Mode Router:**
    -   **Action:** Create a top-level routing function that can decide whether to use the V3.5 or V4 task pipeline.
    -   **Details:** Initially, this router can be controlled by a feature flag in a configuration file.

3.  **End-to-End Testing Plan:**
    -   **Action:** Define a comprehensive test plan for the dual-mode system.
    -   **Details:** The plan must include scenarios for routing to V4, falling back to V3.5, and ensuring no breaking changes are introduced.

---

## 3. AP/IO Event Registration

Upon the start of this implementation, the following event should be logged to the AP/IO ledger to mark the official commencement of V4 migration.

-   **Event:** `v4_task_layer_migration_started`
-   **Data:**
    ```json
    {
      "version": "4.0",
      "phase": 1,
      "description": "Migration to a GMX-centric, unified task layer has begun.",
      "strategy": "dual-mode"
    }
    ```
