# Agent Ledger Integration Guide

**Date:** 2025-11-16  
**Status:** Active

---

## Overview

This guide explains how to integrate Agent Ledger System hooks into agent workflows (CLS, Andy, Hybrid).

---

## Integration Points

### CLS Integration

#### Option 1: Direct Hook Calls (Recommended)

Add ledger hooks directly in CLS workflow scripts:

```bash
# At task start
tools/cls_ledger_hook.zsh task_start "wo-123" "Task description" '{"key":"value"}'

# Execute task...

# At task result
tools/cls_ledger_hook.zsh task_result "wo-123" "Task completed" '{"status":"success"}'
```

#### Option 2: Task Wrapper

Use the task wrapper for automatic logging:

```bash
tools/cls_task_wrapper.zsh "wo-123" "command" "arg1" "arg2"
```

#### Option 3: CLS Slash Command Integration

The `cls_slash.zsh` script has been updated to automatically log:
- Task start when command is executed
- Task result when prompt packet is created

**Location:** `tools/cls/cls_slash.zsh` (lines 150-165)

---

### Andy Integration

#### Codex CLI Execution

Add hooks before and after Codex CLI execution:

```bash
# Before Codex execution
tools/andy_ledger_hook.zsh task_start "wo-123" "Codex task" '{"files":["file1.js"]}'

# Execute Codex CLI...

# After Codex execution
tools/andy_ledger_hook.zsh task_result "wo-123" "Codex completed" '{"status":"success","files_touched":[...]}'
```

#### Integration Points

1. **Before file edits**: Log task_start with target files
2. **After file edits**: Log task_result with modified files
3. **On errors**: Log error event with error details

---

### Hybrid Integration

#### Luka CLI Execution

Add hooks for WO execution and command runs:

```bash
# When WO is received
tools/hybrid_ledger_hook.zsh task_start "$WO_ID" "WO execution" '{"wo_id":"'$WO_ID'"}'

# Execute WO...

# When WO completes
tools/hybrid_ledger_hook.zsh task_result "$WO_ID" "WO completed" '{"exit_code":0,"wo_id":"'$WO_ID'"}'
```

#### Integration Points

1. **WO received**: Log task_start
2. **WO execution**: Log info events for major steps
3. **WO completed**: Log task_result with exit code
4. **WO failed**: Log error event

---

## Event Types

### Available Events

- **`task_start`** - Task initiated
- **`task_result`** - Task completed (success/failure)
- **`error`** - Error occurred
- **`heartbeat`** - Periodic alive signal
- **`info`** - General information

### Event Usage Guidelines

| Event | When to Use | Required Data |
|-------|-------------|---------------|
| `task_start` | Beginning of task | `task_id`, `summary` |
| `task_result` | End of task | `status`, `duration_sec` (optional) |
| `error` | Error occurred | `error` message |
| `heartbeat` | Periodic check | None (empty data) |
| `info` | General logging | Any relevant data |

---

## Testing Integration

### Test Script

Run the test script to verify all agents can write to ledger:

```bash
tools/test_agent_ledger_writes.zsh
```

**Expected Output:**
- ✅ All hooks executable
- ✅ Ledger entries created
- ✅ Status files updated
- ✅ All tests passed

---

## Monitoring

### Ledger Growth Monitoring

Monitor ledger file growth:

```bash
tools/monitor_ledger_growth.zsh
```

**Output:**
- File sizes per agent
- Growth rates
- Status file states
- Daily comparisons

### Scheduled Monitoring

Add to cron or LaunchAgent:

```bash
# Daily monitoring
0 0 * * * /Users/icmini/02luka/tools/monitor_ledger_growth.zsh
```

---

## Session Summary Automation

### Automatic Generation

Generate session summaries automatically:

```bash
tools/automate_session_summaries.zsh
```

**What it does:**
- Scans today's ledger files
- Extracts unique session IDs
- Generates markdown summaries
- Saves to `memory/{agent}/sessions/`

### Scheduled Automation

Add to cron or LaunchAgent:

```bash
# Daily at midnight
0 0 * * * /Users/icmini/02luka/tools/automate_session_summaries.zsh
```

---

## Best Practices

### 1. Always Use Hooks

- Don't call `ledger_write.zsh` directly
- Use agent-specific hooks for proper session tracking

### 2. Include Task IDs

- Use meaningful task IDs (e.g., `wo-123`, `codex-456`)
- Include task context in summary

### 3. Error Handling

- Hooks should not crash agents
- Use `|| true` to prevent hook failures from stopping execution

### 4. Data Sanitization

- Hybrid hook automatically sanitizes sensitive data
- Other hooks should sanitize if needed

### 5. Performance

- Hooks are lightweight (append-only writes)
- Don't worry about performance impact

---

## Troubleshooting

### Hook Not Executable

```bash
chmod +x tools/*_ledger_hook.zsh
```

### Ledger File Not Created

- Check directory permissions: `g/ledger/{agent}/`
- Verify `$LUKA_SOT` or `$HOME/02luka` is set correctly

### Status File Not Updated

- Check `agents/{agent}/` directory exists
- Verify status tool is executable: `tools/status_update.zsh`

### Session ID Issues

- Session IDs are auto-generated
- Format: `YYYY-MM-DD_{agent}_NNN`
- Check `memory/{agent}/sessions/.last_session_id`

---

## Examples

### CLS Task Execution

```bash
#!/usr/bin/env zsh
TASK_ID="wo-$(date +%y%m%d-%H%M%S)"
LEDGER_HOOK="$HOME/02luka/tools/cls_ledger_hook.zsh"

# Start
"$LEDGER_HOOK" task_start "$TASK_ID" "Code review task" '{}' || true

# Execute
# ... code review logic ...

# Result
if [[ $? -eq 0 ]]; then
  "$LEDGER_HOOK" task_result "$TASK_ID" "Code review completed" '{"status":"success"}' || true
else
  "$LEDGER_HOOK" error "$TASK_ID" "Code review failed" '{"error":"..."}' || true
fi
```

### Andy Codex Execution

```bash
#!/usr/bin/env zsh
TASK_ID="codex-$(date +%y%m%d-%H%M%S)"
LEDGER_HOOK="$HOME/02luka/tools/andy_ledger_hook.zsh"

"$LEDGER_HOOK" task_start "$TASK_ID" "Codex edit task" '{"files":["app.js"]}' || true

# Execute Codex CLI
codex_cli edit app.js

"$LEDGER_HOOK" task_result "$TASK_ID" "Codex edit completed" '{"status":"success","files":["app.js"]}' || true
```

### Hybrid WO Execution

```bash
#!/usr/bin/env zsh
WO_ID="$1"
LEDGER_HOOK="$HOME/02luka/tools/hybrid_ledger_hook.zsh"

"$LEDGER_HOOK" task_start "$WO_ID" "WO execution" "{\"wo_id\":\"$WO_ID\"}" || true

# Execute WO
# ... WO execution logic ...

EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  "$LEDGER_HOOK" task_result "$WO_ID" "WO completed" "{\"exit_code\":$EXIT_CODE}" || true
else
  "$LEDGER_HOOK" error "$WO_ID" "WO failed" "{\"exit_code\":$EXIT_CODE}" || true
fi
```

---

## Related Documentation

- [AGENT_LEDGER_GUIDE.md](./AGENT_LEDGER_GUIDE.md) - User guide
- [AGENT_LEDGER_SCHEMA.md](./AGENT_LEDGER_SCHEMA.md) - Schema reference

---

**Maintained by:** GG-Orchestrator  
**Last Updated:** 2025-11-16
