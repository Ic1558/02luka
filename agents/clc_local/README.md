# Local CLC Executor (v0.1)

This is the local version of the CLC (Claude Code) agent, responsible for applying safe, idempotent file operations on the local filesystem as a direct executor of structured tasks.

## Role

The Local CLC Executor is a "dumb but precise file worker." It does not have any planning or reasoning capabilities. Its sole function is to receive a `TASK_SPEC_v4` JSON object and execute the `operations` within it, while strictly enforcing the project's governance rules (Writer Policy).

## Supported Modes

-   **CLI Mode (Phase 1):** The executor is invoked directly from the command line with a path to a task spec file.
    ```bash
    python agents/clc_local/clc_local.py --spec-file /path/to/your_task_spec.json
    ```
-   **Bridge Inbox Mode (Phase 3):** The executor will be hooked up to a Bridge inbox (e.g., Redis or a file-based queue) to process `TASK_SPEC_v4` objects automatically as they arrive.

## Supported Operations (v0.1)

-   `write_file`
-   `apply_patch` (Currently a placeholder, does not support modifying existing files)

## Governance Enforcement

-   **Writer Policy v3.5:** Before every file operation, the target path is checked against a list of forbidden zones (`02luka.md`, `/bridge/`, etc.). Any violation immediately blocks the operation and is logged as an error.

## Output

The executor outputs a final `EXEC_RESULT` JSON object to `stdout`, summarizing the outcome of the task execution.
