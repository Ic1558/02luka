# AP/IO v3.1 Routing Guide

**Version:** 3.1  
**Last Updated:** 2025-11-17

---

## Overview

AP/IO v3.1 routing allows events to be sent to specific agents or broadcast to all agents.

---

## Basic Routing

### Single Agent Routing

```bash
# Create event file
cat > event.json <<EOF
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "gg",
  "ts": "2025-11-17T12:00:00+07:00",
  "event": {
    "type": "routing_request",
    "summary": "Route to CLS for review"
  },
  "routing": {
    "targets": ["cls"],
    "priority": "normal"
  }
}
EOF

# Route event
tools/ap_io_v31/router.zsh event.json
```

### Multiple Agent Routing

```bash
# Route to multiple agents
tools/ap_io_v31/router.zsh event.json --targets cls,andy
```

### Broadcast Routing

```bash
# Broadcast to all agents
tools/ap_io_v31/router.zsh event.json --broadcast
```

---

## Priority Levels

### High Priority

```bash
tools/ap_io_v31/router.zsh event.json --targets cls --priority high
```

**Use for:**
- Critical errors
- Urgent tasks
- Time-sensitive operations

### Normal Priority (Default)

```bash
tools/ap_io_v31/router.zsh event.json --targets cls --priority normal
```

**Use for:**
- Regular tasks
- Standard operations
- Default routing

### Low Priority

```bash
tools/ap_io_v31/router.zsh event.json --targets cls --priority low
```

**Use for:**
- Background tasks
- Non-urgent operations
- Batch processing

---

## Routing Patterns

### Pattern 1: Review Request

```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "gg",
  "ts": "2025-11-17T12:00:00+07:00",
  "event": {
    "type": "routing_request",
    "summary": "Request CLS review",
    "data": {
      "pr_id": "123",
      "review_type": "code_review"
    }
  },
  "routing": {
    "targets": ["cls"],
    "priority": "high"
  }
}
```

### Pattern 2: Implementation Request

```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "gg",
  "ts": "2025-11-17T12:00:00+07:00",
  "event": {
    "type": "routing_request",
    "summary": "Request Andy implementation",
    "data": {
      "task": "implement_feature",
      "files": ["file1.py", "file2.py"]
    }
  },
  "routing": {
    "targets": ["andy"],
    "priority": "normal"
  }
}
```

### Pattern 3: Multi-Agent Coordination

```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "gg",
  "ts": "2025-11-17T12:00:00+07:00",
  "event": {
    "type": "routing_request",
    "summary": "Coordinate multiple agents",
    "data": {
      "workflow": "pr_review_and_implement"
    }
  },
  "routing": {
    "targets": ["cls", "andy"],
    "priority": "normal"
  }
}
```

---

## Correlation Flow

Events in a routing chain can share a correlation ID:

```bash
# Generate correlation ID
CORR_ID=$(tools/ap_io_v31/correlation_id.zsh)

# Create initial event
cat > event1.json <<EOF
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "gg",
  "ts": "2025-11-17T12:00:00+07:00",
  "correlation_id": "$CORR_ID",
  "event": {
    "type": "routing_request",
    "summary": "Initial request"
  },
  "routing": {
    "targets": ["cls"],
    "priority": "normal"
  }
}
EOF

# Route initial event
tools/ap_io_v31/router.zsh event1.json

# Create follow-up event with same correlation ID
cat > event2.json <<EOF
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "cls",
  "ts": "2025-11-17T12:01:00+07:00",
  "correlation_id": "$CORR_ID",
  "event": {
    "type": "task_result",
    "summary": "Review complete"
  }
}
EOF

# Query all events with this correlation ID
tools/ap_io_v31/reader.zsh g/ledger/cls/2025-11-17.jsonl --correlation "$CORR_ID"
```

---

## Agent Integration

Agents can handle routed events by implementing the integration script:

```bash
# In agents/cls/ap_io_v31_integration.zsh

ap_io_v31_route() {
  local event_file="$1"
  local priority="${2:-normal}"
  
  # Read event
  local event=$(cat "$event_file")
  
  # Process based on priority
  case "$priority" in
    high)
      # Handle high priority immediately
      process_event "$event"
      ;;
    normal)
      # Handle normal priority
      process_event "$event"
      ;;
    low)
      # Queue for later processing
      queue_event "$event"
      ;;
  esac
}
```

---

## Error Handling

### Invalid Target Agent

```bash
# This will show a warning and skip invalid agents
tools/ap_io_v31/router.zsh event.json --targets cls,invalid_agent
# Output: ⚠️  Warning: Invalid agent: invalid_agent, skipping
```

### Missing Integration Script

```bash
# This will show a warning if integration script doesn't exist
tools/ap_io_v31/router.zsh event.json --targets cls
# Output: ⚠️  Warning: Agent integration not found: ...
```

### Routing Failure

```bash
# If routing fails, exit code will be non-zero
if ! tools/ap_io_v31/router.zsh event.json --targets cls; then
  echo "Routing failed"
  exit 1
fi
```

---

## Best Practices

### 1. Always Specify Targets

```bash
# Good: Explicit targets
tools/ap_io_v31/router.zsh event.json --targets cls

# Avoid: Relying on default routing
tools/ap_io_v31/router.zsh event.json
```

### 2. Use Appropriate Priority

```bash
# High priority for critical operations
tools/ap_io_v31/router.zsh critical_event.json --priority high

# Normal priority for regular operations
tools/ap_io_v31/router.zsh normal_event.json --priority normal
```

### 3. Include Correlation IDs

```bash
# Use correlation IDs to track event chains
CORR_ID=$(tools/ap_io_v31/correlation_id.zsh)
# Include in all related events
```

### 4. Handle Routing Errors

```bash
if ! tools/ap_io_v31/router.zsh event.json --targets cls; then
  # Log error and handle gracefully
  ap_io_v31_log "error" "$TASK_ID" "$SOURCE" "Routing failed"
fi
```

---

## See Also

- `AP_IO_V31_PROTOCOL.md` - Protocol specification
- `AP_IO_V31_INTEGRATION_GUIDE.md` - Integration guide
- `AP_IO_V31_MIGRATION.md` - Migration guide

