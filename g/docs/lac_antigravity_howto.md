# Antigravity LAC Integration HOWTO

## Overview
Antigravity is now a first-class citizen of the 02luka ecosystem. This means it can be managed, refactored, and maintained using the Local Agentic Coding (LAC) pipeline, just like any other project.

## Integration Status
- **Source:** `/Users/icmini/02luka/system/antigravity`
- **Link:** `g/src/antigravity` (Symlink)
- **Policy:** Covered by `shared/policy.py`
- **Lane:** `dev_oss` (via `bridge/inbox/LIAM`)

## How to Use

### 1. Sending Work Orders (Recommended)
To trigger the autonomous pipeline (DEV -> QA -> DOCS -> MERGE), drop a JSON Work Order into `bridge/inbox/LIAM`.

**Format:**
```json
{
  "wo_id": "WO-ANT-REFACTOR-001",
  "objective": "Refactor core service",
  "routing_hint": "dev_oss",
  "priority": "normal",
  "files": [
    "g/src/antigravity/core/service.py"
  ],
  "task_spec": {
    "task_id": "TASK-ANT-REFACTOR-001",
    "operations": [
      {
        "op": "write_file",
        "file": "g/src/antigravity/core/service.py",
        "content": "# Refactored content..."
      }
    ]
  }
}
```

### 2. Manual Execution (CLI)
For quick tasks or testing, use the `clc_local.py` executor directly. **Note:** The CLI expects a raw `task_spec` (flat JSON), not a full WO wrapper.

**Format (flat.json):**
```json
{
  "task_id": "TASK-QUICK-FIX",
  "operations": [
    {
      "op": "write_file",
      "file": "g/src/antigravity/README.md",
      "content": "# Updated Readme"
    }
  ]
}
```

**Command:**
```bash
python3 agents/clc_local/clc_local.py --spec-file flat.json
```

## Verification
To verify the integration is active:
1.  Check the symlink: `ls -l g/src/antigravity`
2.  Run a smoke test (dry-run):
    ```python
    from shared.policy import apply_patch
    print(apply_patch("g/src/antigravity/test.txt", "content", dry_run=True))
    ```

## Troubleshooting
-   **Policy Blocked:** Ensure you are writing to `g/src/antigravity/...`. Paths outside `g/src` or containing forbidden fragments (e.g., `.git`, `02luka.md`) are blocked.
-   **No Execution:** Check `logs/clc_local_debug.log`. If using Inbox, ensure JSON is valid and wrapped in `task_spec`. If using CLI, ensure JSON is flat.
