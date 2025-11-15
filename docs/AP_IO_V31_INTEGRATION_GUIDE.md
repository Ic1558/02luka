# AP/IO v3.1 Integration Guide

**Version:** 3.1  
**Date:** 2025-11-16  
**Status:** Active

---

## Overview

This guide explains how to integrate AP/IO v3.1 protocol into agent workflows.

---

## Integration Pattern

Each agent should have an integration script at:
```
agents/<agent>/ap_io_v31_integration.zsh
```

### Basic Integration Script Template

```bash
#!/usr/bin/env zsh
# <Agent> AP/IO v3.1 Integration

set -euo pipefail

PRIORITY="$1"
EVENT_JSON=$(cat)

EVENT_TYPE=$(echo "$EVENT_JSON" | jq -r '.event.type')

case "$EVENT_TYPE" in
  task_start)
    # Update agent status
    ;;
  task_result)
    # Update agent status
    ;;
  *)
    # Handle other events
    ;;
esac
```

---

## Agent-Specific Integration

### CLS Integration

**File:** `agents/cls/ap_io_v31_integration.zsh`

**Responsibilities:**
- Log `task_start` when CLS begins work
- Log `task_result` when CLS completes work
- Update `agents/cls/status.json` with current state
- Handle `routing_request` events

**Status Updates:**
```json
{
  "agent": "cls",
  "state": "idle",
  "protocol": "AP/IO",
  "protocol_version": "3.1",
  "last_heartbeat": "2025-11-16T10:00:00+07:00"
}
```

### Andy Integration

**File:** `agents/andy/ap_io_v31_integration.zsh`

**Responsibilities:**
- Wrap Codex CLI execution
- Log dev task events
- Track file modifications
- Update status

### Hybrid Integration

**File:** `agents/hybrid/ap_io_v31_integration.zsh`

**Responsibilities:**
- Log WO execution events
- Track execution duration
- Link via `parent_id` to WO ID
- Update status

### Liam Integration

**File:** `agents/liam/ap_io_v31_integration.zsh`

**Responsibilities:**
- Log orchestration decisions
- Create correlation IDs for multi-agent tasks
- Route events to other agents
- Track coordination

---

## Event Patterns

### task_start Pattern

```bash
tools/ap_io_v31/writer.zsh <agent> task_start \
  "$TASK_ID" \
  "$SOURCE" \
  "Task started: $TASK_ID" \
  '{"status":"started"}' \
  "parent-wo-$TASK_ID" \
  ""
```

### task_result Pattern

```bash
tools/ap_io_v31/writer.zsh <agent> task_result \
  "$TASK_ID" \
  "$SOURCE" \
  "Task completed: $TASK_ID" \
  "{\"status\":\"$STATUS\"}" \
  "parent-wo-$TASK_ID" \
  "$EXECUTION_DURATION_MS"
```

---

## Status File Management

Each agent should maintain `agents/<agent>/status.json`:

```json
{
  "agent": "<agent>",
  "state": "idle|busy|error|offline",
  "protocol": "AP/IO",
  "protocol_version": "3.1",
  "last_heartbeat": "2025-11-16T10:00:00+07:00",
  "last_task_id": "wo-251116-test",
  "session_id": "2025-11-16_<agent>_001"
}
```

---

## Best Practices

1. **Always validate** events before writing
2. **Use test isolation** (`LEDGER_BASE_DIR`) in tests
3. **Handle errors gracefully** - don't fail agent work if ledger write fails
4. **Reuse correlation_id** for related events
5. **Link via parent_id** to track relationships

---

## Testing

Use `tests/ap_io_v31/cls_testcases.zsh` as reference for integration testing.

---

**Document Owner:** Liam  
**Last Updated:** 2025-11-16
