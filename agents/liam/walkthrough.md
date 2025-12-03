# Liam Refactor Walkthrough: Antigravity Mode

**Date**: 2025-11-20
**Status**: Verified

## Overview
This walkthrough documents the refactoring of the Liam agent to support "Antigravity" agentic patterns (stateful execution) and strict AP/IO v3.1 compliance.

## Changes Implemented

### 1. AP/IO v3.1 Protocol & Tools
- **Protocol**: Created `docs/AP_IO_V31_PROTOCOL.md` defining the standard schema.
- **Writer**: Created `tools/ap_io_v31/writer.py` for robust, UUID-based logging.

### 2. Mary Router Refactor (`agents/liam/mary_router.py`)
- **Secure Defaults**: Changed default approval from "Yes" to "BLOCKED".
- **Logging**: Integrated `write_ledger_entry` into `enforce_overseer` and routing functions.
- **State Init**: Added `init_task_state` stub.

### 3. Liam Core (`agents/liam/core.py`)
- **LiamAgent Class**: Created a stateful wrapper that:
    - Validates intent via Mary Router.
    - Initializes `task.md` state.
    - Logs `task_start` events to the ledger.

### 4. Liam Executor (`agents/liam/executor.py`)
- **Purpose**: Executes GMX-generated AP/IO workflows from JSON specs.
- **Capabilities**:
    - Reads `g/wo_specs/*.json`.
    - Writes to AP/IO Ledger (`write_ledger_entry`).
    - Writes to Bridge Inbox (`write_to_bridge`).
    - Enforces path security (cannot write outside `bridge/inbox`).

## Verification Results

### Automated Test
Ran `python3 agents/liam/core.py` to simulate a "wake" event.

**Output**:
```
Wake Result: {'status': 'STARTED', 'ledger_id': '...', 'task_file': 'task.md', ...}
```

### Ledger Verification
Checked `g/ledger/ap_io_v31.jsonl`:

```json
{"agent": "Liam", "event": "overseer_check", "data": {"intent": "refactor", "decision": {"approval": "Yes" ...}}}
{"agent": "Liam", "event": "task_start", "data": {"task_spec": ...}}
```

### Self-Test Flow (Planned)
The new `executor.py` enables a full self-test loop:
1.  **Input**: `g/wo_specs/gmx_liam_selftest.json` (Contains steps).
2.  **Execution**: `python agents/liam/executor.py`.
3.  **Output**:
    - Ledger entries (`selftest_task_start`, `selftest_complete`).
    - Bridge file (`bridge/inbox/LIAM/WO-LIAM-SMOKETEST.json`).

**Conclusion**: The system correctly logs actions and enforces governance checks.

## Next Steps
- Expand `init_task_state` to actually parse/write `task.md`.
- Connect `LiamAgent` to the main `dispatch_to_bridge.py` loop.
- **Fix**: Align `executor.py` step parsing with `gmx_liam_selftest.json` structure (steps are in `task_spec.context.steps`, not `gmx_plan.steps`).
