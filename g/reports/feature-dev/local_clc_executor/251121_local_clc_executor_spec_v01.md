# Local CLC Executor — SPEC v0.1
**Date:** 2025-11-21  
**Owner:** GG + GMX + Liam  
**Status:** Draft → Ready for implementation

---

## 1. Objective

Create a **local file executor agent** (“local CLC”) that:

- Receives **structured tasks** (TASK_SPEC_v4 / V3.5 WO)
- Applies **safe, idempotent file changes** on the local filesystem
- Respects **Writer Policy V3.5**
- Reports back **result, summary, and diff info**
- Does **no planning** — execution only

This replaces the old CLC (Claude Code) as the write-capable worker.

---

## 2. Scope

### In-scope

- Implement a Python entrypoint:
  - `agents/clc_local/clc_local.py`
- Implement task loop:
  - Read from bridge inbox / CLI for:
    - `TASK_SPEC_v4`
    - V3.5 compatible WOs (for migration)
- Support operations:
  - `write_file` (create/overwrite)
  - `apply_patch` (Safe Idempotent Patch)
  - `replace_snippet`
  - `create_dir`
  - `delete_file` (only in allowed zones)
- Integrate with:
  - AP/IO v3.1 (`write_ledger_entry`)
  - Writer Policy V3.5 (“normal_code”, “reports”, “tests”, “feature-dev”)

### Out-of-scope (v0.1)

- No architecture design
- No prompt engineering
- No direct network calls
- No governance file writes:
  - `02luka.md`, `AI:OP-001`, `CLAUDE.md`, writer policy files

---

## 3. I/O Contract

### 3.1 Input: TASK_SPEC_v4 (preferred)

```json
{
  "task_id": "TS-YYYYMMDD-XXXX",
  "version": "v4",
  "lane": "feature-dev",
  "intent": "apply-patch",
  "target_files": ["g/tools/example.py"],
  "operations": [
    {
      "op": "apply_patch",
      "file": "g/tools/example.py",
      "patch": "..."
    }
  ],
  "metadata": {
    "requested_by": "GMX",
    "approved_by": "Liam",
    "risk_level": "low"
  }
}
```

### 3.2 Output: EXEC_RESULT

```json
{
  "task_id": "TS-YYYYMMDD-XXXX",
  "status": "success | failed | partial",
  "summary": "One-line human summary",
  "details": {
    "files_touched": ["g/tools/example.py"],
    "ops_applied": 3,
    "errors": []
  }
}
```

---

## 4. Safety + Writer Policy Integration
- Before each operation, local CLC MUST:
  - Check target_files against Writer Policy V3.5
  - Reject any file in forbidden zones:
    - Governance: `02luka.md`, `AI:OP-001`, `CLAUDE.md`, writer policy specs
    - `/CLC`, `/CLS` protocols
- On violation:
  - Do not touch filesystem
  - Return status: "failed"
  - Log AP/IO event: `clc_local_policy_blocked`

---

## 5. Implementation Notes (v0.1)
- Language: Python 3
- Location:
  - `agents/clc_local/main.py`
- Run mode:
  - Start as a simple loop:
    - CLI demo mode first (read TASK_SPEC from file path)
    - Later: bridge inbox (Redis / file-bridge)

---

## 6. AP/IO Events
- `clc_local_started`
- `clc_local_task_executed`
- `clc_local_policy_blocked`
- `clc_local_error`

---

## 7. Success Criteria
- Can execute a `TASK_SPEC_v4` that writes to `g/reports/feature-dev/**`
- Correctly blocks attempts to touch governance files
- Logs AP/IO events for every task
- GMX + Liam can rely on local CLC for all write operations

---

**Status**: Ready for plan + implementation.
