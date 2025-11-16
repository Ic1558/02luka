# Agent Ledger Schema Reference

**Date:** 2025-11-16  
**Version:** 1.0

---

## Ledger Entry Schema

### File Format

- **Format**: JSONL (JSON Lines)
- **File Pattern**: `g/ledger/<agent>/YYYY-MM-DD.jsonl`
- **Encoding**: UTF-8
- **Line Endings**: Unix (LF)

### Entry Structure

```json
{
  "ts": "2025-11-16T02:12:34+07:00",
  "agent": "cls",
  "session_id": "2025-11-16_cls_001",
  "event": "task_result",
  "task_id": "wo-251116-agents-layout",
  "source": "gg_orchestrator",
  "summary": "Completed /agents layout SPEC + PLAN",
  "data": {
    "status": "success",
    "duration_sec": 132,
    "files_touched": ["path1", "path2"]
  }
}
```

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `ts` | string | ISO-8601 timestamp | `"2025-11-16T02:12:34+07:00"` |
| `agent` | string | Agent identifier (lowercase) | `"cls"`, `"andy"`, `"hybrid"` |
| `session_id` | string | Session identifier | `"2025-11-16_cls_001"` |
| `event` | string | Event type (enum) | `"task_start"`, `"task_result"` |
| `task_id` | string | Task identifier | `"wo-251116-agents-layout"` |
| `source` | string | Source of event | `"gg_orchestrator"`, `"user"` |
| `summary` | string | Human-readable summary | `"Task completed successfully"` |
| `data` | object | Additional event data | `{"status": "success"}` |

### Event Types

| Event Type | Description | Typical `data` Fields |
|------------|-------------|---------------------|
| `heartbeat` | Periodic agent alive signal | `{}` |
| `task_start` | Task initiated | `{"task_type": "..."}` |
| `task_result` | Task completed | `{"status": "success\|failure", "duration_sec": 120}` |
| `error` | Error occurred | `{"error": "Error message", "stack": "..."}` |
| `info` | General information | `{"message": "..."}` |

### Session ID Format

- **Pattern**: `YYYY-MM-DD_<agent>_NNN`
- **Example**: `2025-11-16_cls_001`
- **Rules**:
  - Date: `YYYY-MM-DD`
  - Agent: Lowercase alphanumeric, underscore, hyphen
  - Counter: Zero-padded 3-digit number (001, 002, ...)

### Timestamp Format

- **Format**: ISO-8601 (`YYYY-MM-DDTHH:MM:SS±HH:MM`)
- **Examples**:
  - `2025-11-16T02:12:34+07:00` (with timezone)
  - `2025-11-16T02:12:34Z` (UTC)
- **Validation**: Must parse with `datetime.fromisoformat()`

---

## Status File Schema

### File Format

- **Format**: JSON
- **File Pattern**: `agents/<agent>/status.json`
- **Encoding**: UTF-8
- **Write Pattern**: Safe write (temp → mv)

### Status Structure

```json
{
  "agent": "cls",
  "state": "idle",
  "last_heartbeat": "2025-11-16T02:10:00+07:00",
  "last_task_id": "wo-251116-agents-layout",
  "session_id": "2025-11-16_cls_001",
  "last_error": null
}
```

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `agent` | string | Agent identifier | `"cls"` |
| `state` | string | Agent state (enum) | `"idle"`, `"busy"`, `"error"`, `"offline"` |
| `last_heartbeat` | string | ISO-8601 timestamp | `"2025-11-16T02:10:00+07:00"` |

### Optional Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `last_task_id` | string | Current/last task ID | `"wo-251116-agents-layout"` |
| `session_id` | string | Current session ID | `"2025-11-16_cls_001"` |
| `last_error` | string\|null | Last error message (if state=error) | `"Task failed"` or `null` |

### Agent States

| State | Description |
|-------|-------------|
| `idle` | Agent is idle, ready for tasks |
| `busy` | Agent is processing a task |
| `error` | Agent encountered an error |
| `offline` | Agent is offline/unavailable |

---

## Session Summary Schema

### File Format

- **Format**: Markdown
- **File Pattern**: `memory/<agent>/sessions/YYYY-MM-DD_<agent>_NNN.md`
- **Encoding**: UTF-8
- **Optional**: Yes (generated on-demand)

### Summary Structure

```markdown
# CLS Session Summary: 2025-11-16_cls_001

**Date:** 2025-11-16
**Total Events:** 5

## Timeline

- **2025-11-16T02:10:00+07:00** [task_start] Starting task
  - Task: `wo-123`
- **2025-11-16T02:12:00+07:00** [task_result] Task completed
  - Task: `wo-123`

## Tasks Completed

- **wo-123**: Task completed
  - Status: success
  - Duration: 120s

## Errors

(none)

## Notes

_Session summary generated from ledger entries._
```

---

## Validation Rules

### Ledger Entry Validation

1. **JSON Validity**: Must be valid JSON
2. **Required Fields**: All required fields must be present
3. **Event Type**: Must be one of: `heartbeat`, `task_start`, `task_result`, `error`, `info`
4. **Timestamp**: Must be valid ISO-8601 format
5. **Session ID**: Must match pattern `YYYY-MM-DD_<agent>_NNN`
6. **Data Field**: Must be an object (not array, string, etc.)

### Status File Validation

1. **JSON Validity**: Must be valid JSON
2. **Required Fields**: `agent`, `state`, `last_heartbeat` must be present
3. **State**: Must be one of: `idle`, `busy`, `error`, `offline`
4. **Timestamp**: `last_heartbeat` must be valid ISO-8601 format
5. **Error Field**: If `state=error`, `last_error` should be non-null

### Validation Tool

```bash
# Validate ledger file
tools/ledger_schema_validate.zsh g/ledger/cls/2025-11-16.jsonl

# Validate status file
python3 -m json.tool agents/cls/status.json
```

---

## Common Data Patterns

### Task Result Data

```json
{
  "status": "success",
  "duration_sec": 120,
  "files_touched": ["path1", "path2"],
  "exit_code": 0
}
```

### Error Data

```json
{
  "error": "Task failed: timeout",
  "stack": "Traceback...",
  "task_id": "wo-123"
}
```

### Task Start Data

```json
{
  "task_type": "code_review",
  "target_files": ["file1.js", "file2.js"]
}
```

### Heartbeat Data

```json
{}
```

---

## Schema Evolution

### Versioning

- Current version: **1.0**
- Schema changes require:
  1. Update this document
  2. Update validation tool
  3. Update all agent hooks
  4. Document migration path

### Backward Compatibility

- New optional fields can be added
- Existing required fields cannot be removed
- Event types can be added (not removed)

---

## Examples

### Complete Ledger Entry Examples

**Task Start:**
```json
{"ts":"2025-11-16T02:10:00+07:00","agent":"cls","session_id":"2025-11-16_cls_001","event":"task_start","task_id":"wo-123","source":"gg_orchestrator","summary":"Starting code review","data":{"task_type":"code_review"}}
```

**Task Result:**
```json
{"ts":"2025-11-16T02:12:00+07:00","agent":"cls","session_id":"2025-11-16_cls_001","event":"task_result","task_id":"wo-123","source":"gg_orchestrator","summary":"Code review completed","data":{"status":"success","duration_sec":120}}
```

**Error:**
```json
{"ts":"2025-11-16T02:15:00+07:00","agent":"cls","session_id":"2025-11-16_cls_001","event":"error","task_id":"wo-123","source":"cls_agent","summary":"Task failed","data":{"error":"Timeout after 300s"}}
```

**Heartbeat:**
```json
{"ts":"2025-11-16T02:20:00+07:00","agent":"cls","session_id":"2025-11-16_cls_001","event":"heartbeat","task_id":"system","source":"cls_agent","summary":"Heartbeat","data":{}}
```

---

**Maintained by:** GG-Orchestrator  
**Last Updated:** 2025-11-16
