# AP/IO v3.1 Protocol Specification

**Version:** 3.1  
**Last Updated:** 2025-11-17  
**Status:** Active

---

## Overview

AP/IO (Agent Protocol Input/Output) v3.1 is a standardized protocol for inter-agent communication and event logging in the 02LUKA system. It provides a consistent format for events, correlation tracking, and ledger persistence.

---

## Message Format

### Basic Structure

```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "cls",
  "ts": "2025-11-17T12:00:00+07:00",
  "correlation_id": "corr-20251117-001",
  "session_id": "2025-11-17_cls_001",
  "event": {
    "type": "task_start",
    "task_id": "wo-20251117-001",
    "source": "gg_orchestrator",
    "summary": "Starting task",
    "data": {}
  }
}
```

### Required Fields

- `protocol`: Must be `"AP/IO"`
- `version`: Must be `"3.1"`
- `agent`: One of `cls`, `andy`, `hybrid`, `liam`, `gg`, `kim`
- `ts`: ISO 8601 timestamp (e.g., `"2025-11-17T12:00:00+07:00"`)
- `event`: Event object (see Event Types below)

### Optional Fields

- `correlation_id`: Format `corr-YYYYMMDD-NNN` (for event chains)
- `session_id`: Session identifier
- `routing`: Routing information (see Routing section)

---

## Ledger Extension Fields

When entries are written to the ledger, additional fields are added:

### `ledger_id`

**Format:** `ledger-YYYYMMDD-HHMMSS-<agent>-<seq>`

**Example:** `ledger-20251117-120000-cls-001`

**Purpose:** Unique identifier for each ledger entry

**Generation:**
- Date: `YYYYMMDD` (8 digits)
- Time: `HHMMSS` (6 digits)
- Agent: Agent identifier
- Sequence: 3-digit sequence number (001-999)

### `parent_id`

**Format:** `parent-<type>-<id>`

**Examples:**
- `parent-wo-wo-20251117-001` (Work Order parent)
- `parent-event-event-12345` (Event parent)
- `parent-session-session-abc` (Session parent)

**Purpose:** Links ledger entry to a parent Work Order, event, or session

### `execution_duration_ms`

**Type:** Integer (milliseconds)

**Purpose:** Precise execution time for performance analysis

**Example:** `1250` (1.25 seconds)

---

## Event Types

### `heartbeat`

Periodic status update from an agent.

```json
{
  "event": {
    "type": "heartbeat",
    "summary": "Agent is alive",
    "data": {
      "status": "active",
      "uptime_sec": 3600
    }
  }
}
```

### `task_start`

Task execution has started.

```json
{
  "event": {
    "type": "task_start",
    "task_id": "wo-20251117-001",
    "source": "gg_orchestrator",
    "summary": "Starting task execution",
    "data": {
      "task_type": "pr_change",
      "complexity": "medium"
    }
  }
}
```

### `task_result`

Task execution has completed.

```json
{
  "event": {
    "type": "task_result",
    "task_id": "wo-20251117-001",
    "source": "gg_orchestrator",
    "summary": "Task completed successfully",
    "data": {
      "status": "success",
      "output": "..."
    }
  },
  "execution_duration_ms": 1250
}
```

### `error`

An error occurred.

```json
{
  "event": {
    "type": "error",
    "summary": "Validation failed",
    "data": {
      "error_code": "VALIDATION_ERROR",
      "message": "Invalid format",
      "field": "ledger_id"
    }
  }
}
```

### `info`

Informational message.

```json
{
  "event": {
    "type": "info",
    "summary": "Processing complete",
    "data": {
      "items_processed": 42
    }
  }
}
```

### `routing_request`

Request to route event to other agents.

```json
{
  "event": {
    "type": "routing_request",
    "summary": "Route to CLS for review",
    "data": {
      "targets": ["cls"],
      "priority": "high"
    }
  },
  "routing": {
    "targets": ["cls"],
    "priority": "high"
  }
}
```

### `correlation_query`

Query for correlated events.

```json
{
  "event": {
    "type": "correlation_query",
    "summary": "Find related events",
    "data": {
      "correlation_id": "corr-20251117-001"
    }
  }
}
```

---

## Correlation IDs

Correlation IDs link related events across agents and time.

**Format:** `corr-YYYYMMDD-NNN`

**Example:** `corr-20251117-001`

**Usage:**
- All events in the same chain share the same correlation ID
- Used to trace event flow across agents
- Generated automatically by `correlation_id.zsh`

---

## Routing

Events can be routed to specific agents using the `routing` field:

```json
{
  "routing": {
    "targets": ["cls", "andy"],
    "priority": "high"
  }
}
```

**Targets:** Array of agent identifiers  
**Priority:** `high`, `normal`, or `low`

---

## Backward Compatibility

AP/IO v3.1 supports reading v1.0 format entries:

**v1.0 Format:**
```json
{
  "ts": "2025-11-17T12:00:00+07:00",
  "agent": "cls",
  "event": "task_start",
  "task_id": "wo-test",
  "source": "gg_orchestrator",
  "summary": "Test task"
}
```

**v3.1 Format:**
```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "cls",
  "ts": "2025-11-17T12:00:00+07:00",
  "event": {
    "type": "task_start",
    "task_id": "wo-test",
    "source": "gg_orchestrator",
    "summary": "Test task"
  }
}
```

The reader automatically handles both formats.

---

## Tools

### Writer

```bash
tools/ap_io_v31/writer.zsh <agent> <event_type> <task_id> <source> <summary> [data_json] [parent_id] [execution_duration_ms]
```

### Reader

```bash
tools/ap_io_v31/reader.zsh <ledger_file> [--agent <agent>] [--event-type <type>] [--correlation <id>] [--parent <id>]
```

### Validator

```bash
tools/ap_io_v31/validator.zsh [file] [-v|--verbose]
```

### Router

```bash
tools/ap_io_v31/router.zsh <event_file> [--targets <agents>] [--priority <level>] [--broadcast]
```

---

## Schema Files

- `schemas/ap_io_v31.schema.json` - Protocol message schema
- `schemas/ap_io_v31_ledger.schema.json` - Ledger entry schema

---

**See Also:**
- `AP_IO_V31_INTEGRATION_GUIDE.md` - Integration instructions
- `AP_IO_V31_ROUTING_GUIDE.md` - Routing guide
- `AP_IO_V31_MIGRATION.md` - Migration from v1.0

