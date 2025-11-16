# AP/IO v3.1 Routing Guide

**Date:** 2025-11-16

---

## Overview

AP/IO v3.1 routing enables cross-agent event communication and coordination.

---

## Routing Modes

### Single Agent
Route to one agent:
```bash
tools/ap_io_v31/router.zsh event.json --targets cls
```

### Multiple Agents
Route to multiple agents:
```bash
tools/ap_io_v31/router.zsh event.json --targets cls,andy
```

### Broadcast
Route to all agents:
```bash
tools/ap_io_v31/router.zsh event.json --broadcast
```

---

## Priority Levels

- `critical` - Immediate delivery
- `high` - Priority queue
- `normal` - Standard queue (default)
- `low` - Background processing

Example:
```bash
tools/ap_io_v31/router.zsh event.json --targets cls --priority high
```

---

## Event Routing Flow

1. **Create Event**
   ```bash
   tools/ap_io_v31/writer.zsh cls task_start "wo-test" "gg_orchestrator" "Starting task"
   ```

2. **Route Event**
   ```bash
   tools/ap_io_v31/router.zsh event.json --targets cls,andy
   ```

3. **Agent Processing**
   - Agent receives event via integration script
   - Agent processes event
   - Agent updates status

4. **Response**
   - Agent writes response event
   - Router updates delivered_to field

---

## Correlation Flow

### Example: Multi-Agent Task

1. **Liam creates orchestration event:**
   ```json
   {
     "correlation_id": "corr-20251116-001",
     "routing": {"targets": ["cls", "andy"]}
   }
   ```

2. **Router delivers to CLS and Andy**

3. **CLS and Andy process and write results**

4. **Liam queries correlation:**
   ```bash
   tools/ap_io_v31/reader.zsh g/ledger/cls/2025-11-16.jsonl --correlation corr-20251116-001
   ```

---

## Error Handling

### Router Errors
- Agent integration not found → Warning, skip agent
- Invalid event format → Error, reject event
- Target agent unavailable → Queue for retry

### Agent Integration Errors
- Invalid event → Log error, skip processing
- Processing failure → Write error event
- State update failure → Log warning, continue

---

## Best Practices

1. **Use correlation IDs** for multi-agent workflows
2. **Set appropriate priority** based on urgency
3. **Handle errors gracefully** in integration scripts
4. **Log routing decisions** for debugging
5. **Test routing** before production use

---

**Guide Owner:** Liam  
**Last Updated:** 2025-11-16
