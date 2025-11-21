# V4 Task Layer v02 - CLC Local Validation Spec

**Date**: 2025-11-22  
**Agent**: Liam (Antigravity)  
**Status**: VALIDATED

---

## Overview

This specification details the interface, routing, safety, and validation of `clc_local` within the V4 Task Layer. `clc_local` serves as a generic, model-agnostic patch executor.

## Interface

**Entrypoint**: `agents/clc_local/clc_local.py`
**Executor**: `agents/clc_local/executor.py`

**Task Spec Format**:
```json
{
  "task_id": "string",
  "intent": "refactor|fix-bug|add-feature|generate-file",
  "operations": [
    {
      "op": "write_file|apply_patch",
      "file": "path/to/file",
      "content": "string",
      "patch": "string"
    }
  ]
}
```

## Routing Logic

**GMX -> Liam -> CLC Local**

1.  **GMX**: Generates a high-level plan/task.
2.  **Liam**:
    - Receives task via `mary_router.py`.
    - Validates intent (`refactor`, `fix-bug`, etc.).
    - Calls `route_to_clc_local` (new function).
    - Logs `route_to_clc_local` event to AP/IO ledger.
    - Generates a `task_spec` for `clc_local`.
3.  **CLC Local**:
    - Receives `task_spec`.
    - Validates operations against policy.
    - Executes operations (write/patch).
    - Returns result status.

## Safety Model

**Policy**: `agents/clc_local/policy.py`
- **Function**: `check_file_allowed(file_path)`
- **Rules**: Blocks writes to forbidden paths (e.g., `.git/`, `bridge/`, `governance/`).
- **Enforcement**: Checked before every operation in `executor.py`.

## Validation Results

**Test Suite**:
- `tests/clc_local/test_executor.py`: ✅ PASSED
- `tests/clc_local/test_policy.py`: ✅ PASSED
- `tests/test_impact_assessment_v35.py`: ✅ PASSED

**Self-Check**:
- `agents/clc_local/self_check.py`: ✅ PASSED (Imports, Policy, Executor Dry-Run)

**E2E Demo**:
- `agents/clc_local/demo_e2e.py`: ✅ PASSED (Sandbox file generation verified)

## Limitations

1.  **Model Selection**: Currently relies on environment variables or external config. No dynamic model switching per task yet.
2.  **Operations**: Supports `write_file` and `apply_patch`. `replace_snippet` etc. are TODO.
3.  **Safety**: Policy is hardcoded in `policy.py`. Future versions should load from config.

## Usage

**When to use**:
- Local file modifications (refactor, fix, feature).
- When a lightweight, local executor is preferred.

**When NOT to use**:
- Tasks requiring shell access (use Hybrid Shell).
- Tasks requiring complex reasoning *during* execution (CLC is an executor, not a planner).
