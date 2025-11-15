# Agent Ledger System - User Guide

**Date:** 2025-11-16  
**Version:** 1.0  
**Status:** Active

---

## Overview

The Agent Ledger System provides persistent, append-only event logging for all agents in the 02LUKA system. It replaces the temporary telemetry buffer with a 3-layer ledger architecture:

1. **Ledger** (long-term) - Append-only JSONL event logs per agent per day
2. **Status** (current) - Real-time agent state snapshots
3. **Session Summary** (per-session) - Human-readable markdown summaries

---

## Architecture

### Directory Structure

```
g/
  ledger/
    cls/
      2025-11-16.jsonl      # Append-only event log
      2025-11-17.jsonl
    andy/
      2025-11-16.jsonl
    hybrid/
      2025-11-16.jsonl

agents/
  cls/
    status.json              # Current state snapshot
  andy/
    status.json
  hybrid/
    status.json

memory/
  cls/
    sessions/
      2025-11-16_cls_001.md # Session summary
  andy/
    sessions/
      2025-11-16_andy_001.md
```

### Key Principles

- **Ledger = SOT (Source of Truth)**: Append-only, never delete
- **Telemetry = Buffer**: Temporary, can overwrite (existing behavior preserved)
- **Status = Snapshot**: Safe write pattern (temp → mv)
- **Session Summary = Optional**: Human-readable review

---

## Usage

### Writing Ledger Entries

#### Direct Usage (Low-Level)

```bash
# Write a ledger entry
tools/ledger_write.zsh <agent> <event_type> <task_id> <source> <summary> [data_json]

# Examples
tools/ledger_write.zsh cls task_start "wo-123" "gg_orchestrator" "Starting task"
tools/ledger_write.zsh cls task_result "wo-123" "gg_orchestrator" "Task completed" '{"status":"success","duration_sec":120}'
```

#### Agent Hooks (Recommended)

```bash
# CLS hook
tools/cls_ledger_hook.zsh task_start "wo-123" "Task description" '{"key":"value"}'
tools/cls_ledger_hook.zsh task_result "wo-123" "Task completed" '{"status":"success"}'
tools/cls_ledger_hook.zsh error "wo-123" "Error occurred" '{"error":"Details"}'

# Andy hook
tools/andy_ledger_hook.zsh task_start "wo-123" "Codex task" '{}'

# Hybrid hook
tools/hybrid_ledger_hook.zsh task_result "wo-123" "Command executed" '{"exit_code":0}'
```

### Updating Agent Status

```bash
# Update agent status
tools/status_update.zsh <agent> <state> <last_heartbeat> [task_id] [session_id] [last_error]

# Examples
tools/status_update.zsh cls idle "2025-11-16T10:00:00+07:00"
tools/status_update.zsh cls busy "2025-11-16T10:05:00+07:00" "wo-123" "2025-11-16_cls_001"
tools/status_update.zsh cls error "2025-11-16T10:10:00+07:00" "" "" "Task failed"
```

### Validating Ledger Files

```bash
# Validate ledger schema
tools/ledger_schema_validate.zsh g/ledger/cls/2025-11-16.jsonl
```

### Generating Session Summaries

```bash
# Generate session summary
tools/cls_session_summary.zsh 2025-11-16_cls_001
tools/cls_session_summary.zsh 2025-11-16_cls_001 memory/cls/sessions/2025-11-16_cls_001.md
```

---

## Event Types

- **`heartbeat`** - Periodic agent alive signal
- **`task_start`** - Task initiated
- **`task_result`** - Task completed (success/failure)
- **`error`** - Error occurred
- **`info`** - General information

---

## Agent States

- **`idle`** - Agent is idle, ready for tasks
- **`busy`** - Agent is processing a task
- **`error`** - Agent encountered an error
- **`offline`** - Agent is offline/unavailable

---

## Integration Patterns

### CLS Integration

CLS should call ledger hooks at key points:

1. **Task Start**: `tools/cls_ledger_hook.zsh task_start "$TASK_ID" "$SUMMARY"`
2. **Task Complete**: `tools/cls_ledger_hook.zsh task_result "$TASK_ID" "$SUMMARY" '{"status":"success"}'`
3. **Error**: `tools/cls_ledger_hook.zsh error "$TASK_ID" "$ERROR_MSG" '{"error":"..."}'`
4. **Heartbeat**: `tools/cls_ledger_hook.zsh heartbeat "system" "Heartbeat" '{}'`

### Andy Integration

Andy (Codex worker) should hook into Codex CLI execution:

1. Before Codex execution: `tools/andy_ledger_hook.zsh task_start "$TASK_ID" "Codex task"`
2. After Codex execution: `tools/andy_ledger_hook.zsh task_result "$TASK_ID" "Completed" '{"files_touched":[...]}'`

### Hybrid Integration

Hybrid (Luka CLI) should log WO execution:

1. WO received: `tools/hybrid_ledger_hook.zsh task_start "$WO_ID" "WO execution"`
2. WO completed: `tools/hybrid_ledger_hook.zsh task_result "$WO_ID" "Completed" '{"exit_code":0}'`

---

## Safety & Best Practices

### Append-Only Pattern

- **Always use `>>` (append)**, never `>` (overwrite)
- Ledger files are append-only by design
- Use `tools/ledger_write.zsh` which enforces append-only

### Safe Write Pattern

- Status files use temp → mv pattern (atomic)
- Use `tools/status_update.zsh` which implements safe write

### Error Handling

- Ledger writes should not crash agents
- Use graceful degradation if ledger unavailable
- Log warnings but continue execution

### Directory Auto-Creation

- All tools auto-create directories with `mkdir -p`
- No manual directory setup required

---

## Schema Reference

See [AGENT_LEDGER_SCHEMA.md](./AGENT_LEDGER_SCHEMA.md) for detailed schema documentation.

---

## Troubleshooting

### Ledger file not found

```bash
# Check directory exists
ls -la g/ledger/<agent>/

# Auto-create if missing
mkdir -p g/ledger/<agent>
```

### Invalid JSON in ledger

```bash
# Validate schema
tools/ledger_schema_validate.zsh g/ledger/<agent>/YYYY-MM-DD.jsonl
```

### Status file corruption

```bash
# Check JSON validity
python3 -m json.tool agents/<agent>/status.json

# Recreate if needed
tools/status_update.zsh <agent> idle "$(date -Iseconds)"
```

---

## Migration from Telemetry

The existing `g/telemetry/*.jsonl` files remain as buffers (can overwrite). To migrate telemetry to ledger:

1. Read telemetry file
2. Parse entries
3. Write to ledger using `tools/ledger_write.zsh`
4. Validate with `tools/ledger_schema_validate.zsh`

---

## Examples

### Complete CLS Task Flow

```bash
# Task start
tools/cls_ledger_hook.zsh task_start "wo-123" "Agent layout task" '{}'
tools/status_update.zsh cls busy "$(date -Iseconds)" "wo-123" "2025-11-16_cls_001"

# ... task execution ...

# Task complete
tools/cls_ledger_hook.zsh task_result "wo-123" "Task completed" '{"status":"success","duration_sec":120}'
tools/status_update.zsh cls idle "$(date -Iseconds)" "wo-123" "2025-11-16_cls_001"
```

### Querying Ledger

```bash
# Count events by type
grep -c '"event":"task_result"' g/ledger/cls/2025-11-16.jsonl

# Find all errors
grep '"event":"error"' g/ledger/cls/2025-11-16.jsonl

# Extract task IDs
jq -r '.task_id' g/ledger/cls/2025-11-16.jsonl | sort -u
```

---

## Related Documentation

- [AGENT_LEDGER_SCHEMA.md](./AGENT_LEDGER_SCHEMA.md) - Schema reference
- [feature_agent_ledger_SPEC.md](../g/reports/feature_agent_ledger_SPEC.md) - Feature specification
- [feature_agent_ledger_PLAN.md](../g/reports/feature_agent_ledger_PLAN.md) - Implementation plan

---

**Maintained by:** GG-Orchestrator  
**Last Updated:** 2025-11-16
