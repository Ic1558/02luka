# V4 Unified Task Layer - SPECIFICATION

**Version**: v0.1
**Date**: 2025-11-21
**Owner**: GMX
**Status**: IN DESIGN

---

## 1. Objective

To refactor the 02luka system's core tasking mechanism by migrating all agent tasks to a single, unified `TASK_SPEC_v4` format. The primary goal is to establish **GMX as the sole and central task planner**, eliminating inconsistent, ad-hoc task generation across different agents and creating a single source of truth for all system actions.

---

## 2. Core Architectural Principles

-   **GMX-Centric Planning:** GMX is the only component in the system authorized to generate new task specifications. All natural language requests from the "Boss" are routed to GMX for planning.
-   **GG as a Router/Evaluator:** The GG agent's role is simplified. It no longer generates plans. It routes user requests to GMX and evaluates the final outcomes of tasks executed by other agents.
-   **Unified Executor Consumption:** All executor agents (Liam, CLC, Paula, etc.) will be refactored to consume the single, standardized `TASK_SPEC_v4` format.
-   **System-Wide Consistency:** All tasks, regardless of their nature (feature development, code review, deployment, data analysis), will be represented by the same data structure, enabling consistent logging, validation, and governance.

---

## 3. `TASK_SPEC_v4` Schema

This JSON schema will be the universal format for all tasks within the 02luka V4 system.

```json
{
  "task_id": "string, required, unique (e.g., WO-20251121-CLC-abcdef)",
  "version": "4.0",
  "lane": "string, required (e.g., 'feature-dev', 'code-review', 'deploy', 'data-ops')",
  "intent": "string, required (e.g., 'add-feature', 'fix-bug', 'run-command')",
  "owner": "string, required (The agent or user initiating the task, e.g., 'GMX', 'Boss')",
  "priority": "string, optional (e.g., 'normal', 'high', 'low')",
  "target_files": [
    "string (list of relative file paths relevant to the task)"
  ],
  "acceptance_criteria": [
    "string (A list of measurable conditions for task completion)"
  ],
  "context": {
    "description": "string, required (Detailed natural language description of the task for the executor agent)",
    "source_prompt": "string, optional (The original prompt from the Boss)",
    "dependencies": "array, optional (List of other task_ids that must be complete first)"
  },
  "metadata": {
    "created_at": "string (ISO 8601 timestamp)",
    "gmx_model": "string (The model version used by GMX to generate this spec)"
  }
}
```

---

## 4. Migration Strategy: Dual-Mode Operation

To ensure system stability, the migration will be conducted in a **dual-mode** with **zero breaking changes**.

-   **V3.5 Lanes Remain Active:** The existing V3.5 tasking pathways will remain operational during the migration.
-   **V4 as an Overlay:** The V4 task layer will be built as a parallel system. A top-level router will decide whether to route a task through the legacy V3.5 pipeline or the new V4 pipeline.
-   **Gradual Cutover:** Individual agents will be migrated one by one to use the new `TASK_SPEC_v4`. The system will run in dual-mode until all agents and lanes are fully migrated and validated.

---

## 5. Scope for Phase-1

This initial phase is focused exclusively on designing and formalizing the **Task Layer**.

-   **IN SCOPE:**
    -   Defining the final `TASK_SPEC_v4` schema.
    -   Updating agent personas (GMX, GG) to reflect their new roles.
    -   Creating a detailed migration plan for all agents.
-   **OUT OF SCOPE:**
    -   The actual code implementation for refactoring the executor agents (Liam, CLC, etc.). This will be handled in a subsequent phase based on the plan created in Phase-1.
    -   Changes to the Overseer, gm_policy, or AP/IO ledger formats.
