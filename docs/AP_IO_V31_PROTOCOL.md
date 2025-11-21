# AP/IO v3.1 Protocol

**Document Owner**: Liam
**Version**: 3.1
**Status**: Active

## Overview
The **AP/IO (Agent Protocol / Input Output)** is the standard for logging agentic actions in the 02LUKA system. It ensures that every significant action taken by an agent (human or AI) is recorded in a structured, queryable format.

## Ledger Location
- **Path**: `g/ledger/ap_io_v31.jsonl`
- **Format**: JSON Lines (one JSON object per line)

## Schema Fields

Every entry MUST contain the following fields:

| Field | Type | Description |
| :--- | :--- | :--- |
| `ledger_id` | `string` (UUID) | Unique ID for this log entry. |
| `parent_id` | `string` (UUID) \| `null` | ID of the parent task/action that triggered this. |
| `correlation_id` | `string` (UUID) | ID linking a chain of related events (e.g., a single user request). |
| `timestamp` | `string` (ISO8601) | UTC timestamp of the event. |
| `agent` | `string` | Name of the agent (e.g., "Liam", "Andy", "User"). |
| `event` | `string` | Type of event (e.g., "task_start", "tool_call", "decision"). |
| `data` | `object` | Context-specific payload. |
| `execution_duration_ms` | `integer` \| `null` | Duration of the action in milliseconds (if applicable). |

## Event Types

### `task_start`
- **When**: An agent begins a new high-level task.
- **Data**: `{"task_spec": {...}}`

### `tool_call`
- **When**: An agent executes a tool or command.
- **Data**: `{"tool": "name", "args": {...}}`

### `decision`
- **When**: A router (like Mary) or Overseer makes a governance decision.
- **Data**: `{"decision": "APPROVED" | "BLOCKED", "reason": "..."}`

### `error`
- **When**: An exception or failure occurs.
- **Data**: `{"error_type": "...", "message": "..."}`

## Liam Executor (`agents/liam/executor.py`)

The **Liam Executor** is the standard entrypoint for running GMX-generated AP/IO workflows.

- **Purpose**: Executes multi-step JSON plans from `g/wo_specs/*.json`.
- **Capabilities**:
    - **Step Loading**: Prioritizes `gmx_plan.steps`, falls back to `task_spec.context.steps`.
    - **Actions**: Supports `write_ledger_entry` and `write_to_bridge`.
    - **Security**: Enforces `ensure_under` to confine writes to `bridge/inbox`.
- **Configuration**:
    - **Ledger Path**: `g/ledger/ap_io_v31.jsonl`
    - **Bridge Inbox**: `bridge/inbox`
- **Usage**:
    ```bash
    # Run default self-test
    python agents/liam/executor.py

    # Run specific spec
    python agents/liam/executor.py g/wo_specs/my_spec.json

    # Dry-run (no writes)
    python agents/liam/executor.py g/wo_specs/my_spec.json --dry-run
    ```

## Usage Guidelines

1.  **Atomic Writes**: Each line must be a complete, valid JSON object.
2.  **Immutability**: Once written, ledger entries should never be modified.
3.  **Validation**: Use `tools/ap_io_v31/validator.zsh` to check compliance.

## Example Entry

```json
{
  "ledger_id": "550e8400-e29b-41d4-a716-446655440000",
  "parent_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "correlation_id": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "timestamp": "2025-11-20T14:30:00Z",
  "agent": "Liam",
  "event": "decision",
  "data": {
    "decision": "APPROVED",
    "reason": "Intent 'refactor' is allowed in 'tools/'"
  },
  "execution_duration_ms": 45
}
```
