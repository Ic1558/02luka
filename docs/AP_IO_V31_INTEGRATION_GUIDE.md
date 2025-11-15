# AP/IO v3.1 Integration Guide

**Date:** 2025-11-16  
**Target:** All agents (CLS, Andy, Hybrid, Liam, GG)

---

## Overview

This guide explains how to integrate AP/IO v3.1 protocol into your agent.

---

## Integration Steps

### 1. Create Integration Script

Create `agents/<agent>/ap_io_v31_integration.zsh`:

```zsh
#!/usr/bin/env zsh
# <Agent> AP/IO v3.1 Integration

set -euo pipefail

# Parse arguments
PRIORITY="$1"
EVENT_JSON=$(cat)

# Parse event
EVENT_TYPE=$(echo "$EVENT_JSON" | jq -r '.event.type')

# Handle event
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

### 2. Hook into Agent Workflow

#### CLS Integration
```zsh
# On task start
tools/ap_io_v31/writer.zsh cls task_start "$TASK_ID" "gg_orchestrator" "Starting task"

# On task completion
tools/ap_io_v31/writer.zsh cls task_result "$TASK_ID" "cls" "Task completed" '{"status":"success"}'
```

#### Andy Integration
```zsh
# Wrap Codex CLI execution
tools/ap_io_v31/writer.zsh andy task_start "$TASK_ID" "andy" "Starting dev task"
# ... execute Codex CLI ...
tools/ap_io_v31/writer.zsh andy task_result "$TASK_ID" "andy" "Dev task completed"
```

#### Hybrid Integration
```zsh
# On WO execution
tools/ap_io_v31/writer.zsh hybrid task_start "$WO_ID" "hybrid" "Executing WO"
# ... execute WO ...
tools/ap_io_v31/writer.zsh hybrid task_result "$WO_ID" "hybrid" "WO completed"
```

### 3. Update Status File

Update `agents/<agent>/status.json`:
```json
{
  "agent": "cls",
  "state": "idle",
  "protocol": "AP/IO",
  "protocol_version": "3.1",
  "last_heartbeat": "2025-11-16T10:00:00+07:00"
}
```

---

## Event Handling Patterns

### Task Start
```zsh
# Update status to busy
# Write acknowledgment event
# Log task metadata
```

### Task Result
```zsh
# Update status to idle
# Write result event
# Include duration, files touched, etc.
```

### Routing Request
```zsh
# Process routing request
# Route to target agents
# Update delivered_to field
```

### Correlation Query
```zsh
# Query ledger for correlated events
# Return matching events
# Support cross-agent queries
```

---

## Best Practices

1. **Always validate** events before processing
2. **Use safe writes** for status files (temp → mv)
3. **Handle errors gracefully** (don't crash agent)
4. **Log important events** to ledger
5. **Use correlation IDs** for multi-agent workflows

---

## Testing

Run agent-specific tests:
```bash
tests/ap_io_v31/cls_testcases.zsh
```

---

## Troubleshooting

### Event not written
- Check ledger directory exists
- Check file permissions
- Check validator output

### Routing not working
- Check agent integration script exists
- Check integration script is executable
- Check router output

### Status not updating
- Check status file permissions
- Check safe write pattern (temp → mv)
- Check JSON validity

---

**Guide Owner:** Liam  
**Last Updated:** 2025-11-16
