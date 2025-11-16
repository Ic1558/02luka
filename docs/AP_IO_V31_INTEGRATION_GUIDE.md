# AP/IO v3.1 Integration Guide

**Version:** 3.1  
**Last Updated:** 2025-11-17

---

## Overview

This guide explains how to integrate AP/IO v3.1 protocol into your agent or tool.

---

## Quick Start

### 1. Source the Integration Script

```bash
source agents/<agent>/ap_io_v31_integration.zsh
```

### 2. Log an Event

```bash
ap_io_v31_log "task_start" "wo-20251117-001" "gg_orchestrator" "Starting task"
```

### 3. Log with Data

```bash
ap_io_v31_log "task_result" "wo-20251117-001" "gg_orchestrator" "Task completed" '{"status":"success"}' "parent-wo-wo-20251117-001" 1250
```

---

## Integration Patterns

### Pattern 1: Direct Tool Call

```bash
#!/usr/bin/env zsh
# Your script

# Log task start
tools/ap_io_v31/writer.zsh cls task_start "wo-001" "gg_orchestrator" "Starting task"

# Do work
# ...

# Log task result
tools/ap_io_v31/writer.zsh cls task_result "wo-001" "gg_orchestrator" "Task completed" '{"status":"success"}' "" 1250
```

### Pattern 2: Using Integration Script

```bash
#!/usr/bin/env zsh
# Your script

source agents/cls/ap_io_v31_integration.zsh

# Log task start
ap_io_v31_log "task_start" "wo-001" "gg_orchestrator" "Starting task"

# Do work
# ...

# Log task result
ap_io_v31_log "task_result" "wo-001" "gg_orchestrator" "Task completed" '{"status":"success"}' "" 1250
```

### Pattern 3: With Error Handling

```bash
#!/usr/bin/env zsh

source agents/cls/ap_io_v31_integration.zsh

TASK_ID="wo-001"
START_TIME=$(date +%s%3N)

ap_io_v31_log "task_start" "$TASK_ID" "gg_orchestrator" "Starting task"

if perform_task; then
  END_TIME=$(date +%s%3N)
  DURATION=$((END_TIME - START_TIME))
  ap_io_v31_log "task_result" "$TASK_ID" "gg_orchestrator" "Task completed" '{"status":"success"}' "" "$DURATION"
else
  ap_io_v31_log "error" "$TASK_ID" "gg_orchestrator" "Task failed" '{"status":"error","error":"Task execution failed"}'
  exit 1
fi
```

---

## Agent-Specific Integration

### CLS Integration

```bash
source agents/cls/ap_io_v31_integration.zsh

# Log review start
ap_io_v31_log "task_start" "review-pr-123" "gg_orchestrator" "Starting PR review"

# Perform review
# ...

# Log review result
ap_io_v31_log "task_result" "review-pr-123" "gg_orchestrator" "Review complete" '{"status":"approved"}'
```

### Andy Integration

```bash
source agents/andy/ap_io_v31_integration.zsh

# Log implementation start
ap_io_v31_log "task_start" "implement-feature" "gg_orchestrator" "Starting implementation"

# Implement feature
# ...

# Log implementation result
ap_io_v31_log "task_result" "implement-feature" "gg_orchestrator" "Implementation complete" '{"files_changed":5}'
```

### Hybrid Integration

```bash
source agents/hybrid/ap_io_v31_integration.zsh

# Log hybrid operation
ap_io_v31_log "task_start" "hybrid-op" "gg_orchestrator" "Starting hybrid operation"

# Perform operation
# ...

# Log result
ap_io_v31_log "task_result" "hybrid-op" "gg_orchestrator" "Operation complete"
```

### Liam Integration

```bash
source agents/liam/ap_io_v31_integration.zsh

# Log orchestration start
ap_io_v31_log "task_start" "orchestrate" "gg_orchestrator" "Starting orchestration"

# Orchestrate
# ...

# Log result
ap_io_v31_log "task_result" "orchestrate" "gg_orchestrator" "Orchestration complete"
```

### GG Integration (Read-Only)

```bash
source agents/gg/ap_io_v31_integration.zsh

# GG only reads ledger entries, doesn't write
# Use for querying and analysis
ap_io_v31_query --agent cls --event-type task_result
```

---

## Test Isolation

For tests, use `LEDGER_BASE_DIR` to write to temporary directories:

```bash
#!/usr/bin/env zsh
# Test script

TEST_LEDGER_DIR=$(mktemp -d)
trap "rm -rf '$TEST_LEDGER_DIR'" EXIT

export LEDGER_BASE_DIR="$TEST_LEDGER_DIR"

# Run tests that write to ledger
tools/ap_io_v31/writer.zsh cls task_start "wo-test" "test" "Test task"

# Verify entries
tools/ap_io_v31/reader.zsh "$TEST_LEDGER_DIR/cls/$(date +%Y-%m-%d).jsonl"
```

---

## Best Practices

### 1. Always Log Task Start and Result

```bash
ap_io_v31_log "task_start" "$TASK_ID" "$SOURCE" "Starting task"
# ... do work ...
ap_io_v31_log "task_result" "$TASK_ID" "$SOURCE" "Task completed" "$DATA" "$PARENT_ID" "$DURATION"
```

### 2. Include Execution Duration

```bash
START=$(date +%s%3N)
# ... do work ...
END=$(date +%s%3N)
DURATION=$((END - START))
ap_io_v31_log "task_result" "$TASK_ID" "$SOURCE" "Done" "$DATA" "" "$DURATION"
```

### 3. Use Parent IDs for Related Events

```bash
PARENT_ID="parent-wo-wo-20251117-001"
ap_io_v31_log "task_start" "$TASK_ID" "$SOURCE" "Starting" "" "$PARENT_ID"
```

### 4. Include Relevant Data

```bash
DATA=$(jq -n --arg status "success" --arg files "5" '{status: $status, files_changed: ($files | tonumber)}')
ap_io_v31_log "task_result" "$TASK_ID" "$SOURCE" "Complete" "$DATA"
```

### 5. Handle Errors Gracefully

```bash
if ! perform_task; then
  ap_io_v31_log "error" "$TASK_ID" "$SOURCE" "Task failed" '{"error":"Execution failed"}'
  exit 1
fi
```

---

## Troubleshooting

### Issue: "Invalid agent"

**Solution:** Ensure agent identifier is one of: `cls`, `andy`, `hybrid`, `liam`, `gg`, `kim`

### Issue: "Validation failed"

**Solution:** Run validator with verbose mode:
```bash
tools/ap_io_v31/validator.zsh -v <entry.json>
```

### Issue: "Failed to write ledger entry"

**Solution:** 
- Check disk space
- Verify write permissions
- Check `LEDGER_BASE_DIR` if using test isolation

---

## See Also

- `AP_IO_V31_PROTOCOL.md` - Protocol specification
- `AP_IO_V31_ROUTING_GUIDE.md` - Routing guide
- `AP_IO_V31_MIGRATION.md` - Migration from v1.0

