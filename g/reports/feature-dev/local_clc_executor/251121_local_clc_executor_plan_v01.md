# Local CLC Executor — PLAN v0.1
**Date:** 2025-11-21  
**Owner:** GMX + Liam  
**Status:** Implementation plan (ready)

---

## 1. Phases

### Phase 1 — Skeleton + CLI Demo

1.  **Create directories**:
    -   `agents/clc_local/`
1.  **Create files**:
    -   `agents/clc_local/clc_local.py`
    -   `agents/clc_local/README.md`
3.  **Implement CLI entrypoint**:
    ```bash
    python agents/clc_local/main.py --spec-file /path/to/task_spec.json
    ```
4.  **Support operations**:
    -   `write_file`
    -   `apply_patch`
5.  **Log AP/IO**:
    -   `clc_local_started`
    -   `clc_local_task_executed`

### Phase 2 — Writer Policy Enforcement

1.  **Import Writer Policy V3.5 helper**:
    -   Reuse / extend existing validation code
2.  **Before applying any op**:
    -   Validate file path
3.  **On violation**:
    -   Skip op
    -   Log `clc_local_policy_blocked`
    -   Set status: "failed"

### Phase 3 — Bridge Integration (V3.5 → V4 safe)

1.  **Add mode**:
    -   Read `TASK_SPEC_v4` from bridge inbox (file-bridge or Redis)
2.  **Map**:
    -   `lane` → correct executor (for now: only local CLC)
3.  **Return EXEC_RESULT** through:
    -   stdout (for bridge)
    -   optional outbox file

### Phase 4 — Tests + Validation

1.  **Add tests**:
    -   `tests/test_clc_local_executor.py`
2.  **Test cases**:
    -   Allowed file write in `g/reports/feature-dev/**`
    -   Blocked write to `02luka.md`
    -   Partial failure (some ops succeed, some blocked)
3.  **Confirm**:
    -   AP/IO logging works
    -   `EXEC_RESULT` structure matches spec

---

## 2. Dependencies

-   Python 3 environment (already present)
-   Writer Policy V3.5
-   AP/IO v3.1 writer

---

## 3. Risks

-   Misconfigured writer policy → accidental governance writes
-   Incomplete tests → silent failures
-   Bridge integration complexity (Phase 3)

**Mitigation**:
-   Start with CLI demo mode
-   Lock governance paths behind hard deny list
-   Require tests before bridge hookup

---

## 4. Done Definition

-   Local CLC can run via CLI with a `TASK_SPEC` file
-   Writer Policy enforced (hard deny list proven)
-   At least one real feature (small change in `g/**`) successfully executed via local CLC
-   GMX + Liam updated to route all write tasks through local CLC

---

**Status**: Ready for implementation.
