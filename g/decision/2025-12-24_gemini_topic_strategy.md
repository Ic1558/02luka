# Strategic Decision: Gemini Topic
**Status:** DECIDED
**Timestamp:** Wed Dec 24 16:14:40 +07 2025

---

## 1. Objective
*   Establish the operational framework and integration strategy for the Gemini (`gmx`) agent within the `02luka` system.
*   Ensure strict alignment with `02luka Workflow Protocol v1` and `PR_AUTOPILOT_RULES` to maintain system integrity and safety.

## 2. Context
*   **Environment:** `02luka` is a strictly governed codebase with established protocols (Decision Gates, Two Worlds model, PR flow).
*   **Identity:** Gemini is identified as `gmx`.
*   **Current Status:** Migration/Setup artifacts exist (`gmx_migration_temp.patch`, `gmx_todo.txt`).
*   **Requirement:** `gmx` must function effectively without violating safety guards (e.g., direct pushes to main, undocumented strategic changes).

## 3. Options
*   **Option A: Full Native Integration (Standard)**
    *   `gmx` fully adopts existing protocols: Phase 0 Discovery, Decision Boxes for strategy, and PR-based code changes.
    *   `gmx` acts as a compliant operator similar to `CLS`.
*   **Option B: Isolated Sandbox**
    *   `gmx` operates only within a specific scope (e.g., `gmx/` directory) or read-only mode.
    *   All changes require human manual intervention to propagate to core.
*   **Option C: Parallel Workflow (Exempt)**
    *   `gmx` bypasses standard protocols for speed, operating outside existing governance.

## 4. Trade-offs

| Dimension | Option A (Full Native) | Option B (Sandbox) | Option C (Parallel) |
| :--- | :--- | :--- | :--- |
| **System Integrity** | **High** (Guarded) | **Very High** (Isolated) | **Low** (Risk of drift) |
| **Velocity** | **Medium** (Process overhead) | **Low** (Manual bottlenecks) | **High** (Unchecked) |
| **Compliance** | **100%** | **N/A** (Limited scope) | **0%** (Violation) |
| **Collaboration** | **Seamless** (Standard artifacts) | **Friction** (Siloed) | **Confusing** (Dual standards) |

## 5. Assumptions
*   `gmx` possesses the necessary tool capabilities to execute the full workflow (Git, filesystem, analysis).
*   The user ("Boss") intends for `gmx` to perform active software engineering tasks, not just passive queries.
*   The `02luka` governance documentation is the single source of truth (SOT).

## 6. Recommendation (Non-binding)
*   **Adopt Option A: Full Native Integration.**
*   **Rationale:** To act as an effective engineer, `gmx` must be a first-class citizen within the system's governance. Bypassing rules creates technical debt and risk; sandboxing limits utility.
*   **Immediate Next Steps:**
    1.  Acknowledge `WORKFLOW_PROTOCOL v1` as the fundamental working method.
    2.  Treat `gmx_todo.txt` items as individual tasks following the Discovery → Plan → Verify loop.


---
## LAC Mirror Pass

### 1. Pressure Test
1.  **The "Context vs. Compliance" Cost:** Option A requires heavy token usage to strictly follow "Discovery → Plan → Verify". Does `gmx` have sufficient context window persistence to maintain the strict `02luka` state machine across long multi-turn engineering tasks without "forgetting" the protocol mid-stream?
2.  **The "Guard" Mechanics:** The draft assumes `gmx` *can* follow protocol, but how does it physically interact with `.cls_guard`? Does `gmx` have a specific directive to check existence/content of this file before *every* write operation, or is this relying on probabilistic LLM obedience?
3.  **Conflict Handling:** If `gmx` (Option A) and a human (or `CLS`) are working simultaneously, how does `gmx` handle a `git push` rejection? Does it know how to rebase safely according to `CONFLICT_RESOLUTION_GUIDE.md`, or will it resort to force pushes/destructive merges?

### 2. Risks (Pre-mortem)
1.  **Risk: Protocol Mimicry (Cargo Culting).** `gmx` generates the *artifacts* of compliance (e.g., a "Phase 0" document) that are logically empty or hallucinated, tricking the user into thinking due diligence was done when it wasn't.
2.  **Risk: The "Clean" State Corruption.** `gmx` attempts a "Full Native" fix but fails during the verification phase (step 4), leaving untracked files, temp branches, or half-modified config files that pollute the directory for the next agent/user.
3.  **Risk: Alert Fatigue.** If `gmx` is too rigid (Option A), it may flag *every* minor adjustment as a "Strategic Change" requiring a `DECISION_BOX`, causing the user to bypass `gmx` entirely (shifting to Option C de facto).

### 3. Required Evidence
1.  **Validation Artifact:** A PR created by `gmx` where the body explicitly links to a specific `DECISION_BOX` ID and includes a copy-paste of the local `Dry-Run` success logs.
2.  **Negative Test:** A log showing `gmx` attempting a task, detecting a `.cls_guard` or `lock` file, and explicitly outputting "System Locked: Aborting" rather than proceeding.
3.  **Recovery Proof:** A session transcript where `gmx` makes a mistake (fails a test), successfully runs `git reset` / `git clean` to restore state, and *then* informs the user, demonstrating self-healing capability.

### 4. Quick Table: Failure Modes

| Feature | Option A (Native) Failure Mode | Option B (Sandbox) Failure Mode |
| :--- | :--- | :--- |
| **Workflow** | **Bloat:** Agent spends 80% of tokens on process, 20% on code. | **Irrelevance:** Code works in sandbox but breaks immediately in `prod`. |
| **Safety** | **False Confidence:** User trusts "Verified" status of a hallucinated test. | **Integration Hell:** Merge conflicts are massive due to delayed integration. |
| **Governance** | **Drift:** Agent subtly rewrites rules to fit its training bias. | **Ignorance:** Agent never learns the actual system constraints. |

---
## 7. Decision (Human)
- Chosen Option: Option B
- Reason: Low risk, high value. 

## 8. Confidence & Next Check
- Confidence: 
- Revisit Trigger: 
