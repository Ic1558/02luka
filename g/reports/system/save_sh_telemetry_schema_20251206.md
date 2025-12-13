# Save System Telemetry Schema

**Date:** 2025-12-06
**Version:** 1.0

## Overview

This document defines the JSONL schema for `g/telemetry/save_sessions.jsonl`. This log tracks the execution of the save system, providing metadata-only observability into when, how, and by whom the save system is triggered.

## Schema Definition

Each line in the JSONL file represents a single save execution event.

```json
{
  "ts": "ISO8601 Timestamp (UTC)",
  "agent": "Identity of the caller (e.g., GG, CLI, Auto)",
  "source": "Trigger mechanism (manual, hook, auto)",
  "project_id": "Optional project identifier",
  "topic": "Optional session topic",
  "files_written": "Number of files created/updated (Integer)",
  "save_mode": "Mode of operation (full, quick, session)",
  "repo": "Target repository (02luka, 02luka-memory)",
  "branch": "Git branch name",
  "exit_code": "Process exit code (0 = success)",
  "duration_ms": "Execution time in milliseconds",
  "truncated": "Boolean, always false for this schema (metadata only)"
}
```

## Field Details

| Field | Type | Required | Description | Source/Default |
| :--- | :--- | :--- | :--- | :--- |
| `ts` | String | Yes | ISO 8601 format (e.g., `2025-12-06T14:00:00Z`) | `date -u +"%Y-%m-%dT%H:%M:%SZ"` |
| `agent` | String | Yes | Who initiated the save | `$GG_AGENT_ID` -> `$USER` -> `unknown` |
| `source` | String | Yes | How it was triggered | `$SAVE_SOURCE` -> `manual` |
| `project_id`| String | No | Project context | `$PROJECT_ID` or `null` |
| `topic` | String | No | Session topic/summary | Argument or `null` |
| `files_written`| Integer| Yes | Count of artifacts | Calculated during execution |
| `save_mode` | String | Yes | Operational mode | `full` (default), `quick` |
| `repo` | String | Yes | Repository name | `git rev-parse --show-toplevel` basename |
| `branch` | String | Yes | Current git branch | `git branch --show-current` |
| `exit_code` | Integer| Yes | Final exit code | `$?` |
| `duration_ms` | Integer| Yes | Time taken | End time - Start time |
| `truncated` | Boolean| Yes | Legacy/Compat field | Always `false` |

## Constraints

1.  **No Content:** Specifically exclude session content, diffs, or full text.
2.  **Local Only:** File is stored in `g/telemetry/`.
3.  **Atomic Append:** Writers must append atomically to avoid corruption.

## Example Record

```json
{"ts": "2025-12-06T14:30:00Z", "agent": "GG", "source": "manual", "project_id": null, "topic": "Fix save path", "files_written": 3, "save_mode": "full", "repo": "02luka", "branch": "main", "exit_code": 0, "duration_ms": 450, "truncated": false}
```
