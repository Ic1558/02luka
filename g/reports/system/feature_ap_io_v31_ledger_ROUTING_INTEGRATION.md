# AP/IO v3.1 Ledger - Routing Integration Specification

**Date:** 2025-11-16  
**Feature:** Routing Integration for All Agents

---

## Overview

AP/IO v3.1 routing enables cross-agent event correlation and coordination. Each agent can send events to other agents, enabling multi-agent workflows.

---

## Routing Architecture

### Components

1. **Router** (`tools/ap_io_v31/router.zsh`)
   - Routes events to target agents
   - Supports single/multiple/broadcast modes
   - Priority-based queuing

2. **Agent Integrations** (`agents/<agent>/ap_io_v31_integration.zsh`)
   - Agent-specific event handlers
   - Process incoming events
   - Update agent state

3. **Writer** (`tools/ap_io_v31/writer.zsh`)
   - Writes events to ledger
   - Generates correlation IDs
   - Validates protocol

---

## Routing Modes

### 1. Single Agent
```json
{
  "routing": {
    "targets": ["cls"],
    "broadcast": false,
    "priority": "normal"
  }
}
```

### 2. Multiple Agents
```json
{
  "routing": {
    "targets": ["cls", "andy"],
    "broadcast": false,
    "priority": "high"
  }
}
```

### 3. Broadcast
```json
{
  "routing": {
    "targets": [],
    "broadcast": true,
    "priority": "critical"
  }
}
```

---

## Priority Levels

- **critical** - Immediate delivery, highest priority
- **high** - Priority queue, processed quickly
- **normal** - Standard queue, default
- **low** - Background processing, lowest priority

---

## Agent Integration Patterns

### CLS Integration

**File:** `agents/cls/ap_io_v31_integration.zsh`

**Responsibilities:**
- Receive events from other agents
- Process task coordination events
- Update CLS status
- Write response events

**Event Types Handled:**
- `task_start` - Coordinate task execution
- `task_result` - Receive task results
- `routing_request` - Handle routing requests
- `correlation_query` - Respond to correlation queries

### Andy Integration

**File:** `agents/andy/ap_io_v31_integration.zsh`

**Responsibilities:**
- Receive dev task events
- Coordinate with Codex CLI
- Write dev task events
- Respond to task queries

**Event Types Handled:**
- `task_start` - Start dev task
- `task_result` - Report dev task completion
- `routing_request` - Handle routing requests

### Hybrid Integration

**File:** `agents/hybrid/ap_io_v31_integration.zsh`

**Responsibilities:**
- Receive WO execution events
- Coordinate with Luka CLI
- Write execution events
- Report execution status

**Event Types Handled:**
- `task_start` - Start WO execution
- `task_result` - Report execution completion
- `error` - Report execution errors

### Liam Integration

**File:** `agents/liam/ap_io_v31_integration.zsh`

**Responsibilities:**
- Receive orchestration events
- Coordinate multi-agent workflows
- Write orchestration decisions
- Query agent status

**Event Types Handled:**
- `task_start` - Start orchestration
- `task_result` - Report orchestration completion
- `routing_request` - Handle routing requests
- `correlation_query` - Query event correlations

### GG Integration (Read-Only)

**File:** `agents/gg/ap_io_v31_integration.zsh`

**Responsibilities:**
- Read events for system overview
- Query agent status
- Generate system reports
- No direct writes (cloud orchestrator)

**Event Types Handled:**
- `correlation_query` - Query event correlations
- `info` - Read system information

---

## Integration Workflow

### 1. Event Creation

Agent creates event using writer:
```bash
tools/ap_io_v31/writer.zsh cls task_start "wo-251116-test" "gg_orchestrator" "Starting test"
```

### 2. Routing

Event is routed to target agents:
```bash
tools/ap_io_v31/router.zsh event.json --targets cls,andy
```

### 3. Agent Processing

Target agents receive and process events:
```bash
agents/cls/ap_io_v31_integration.zsh normal < event.json
```

### 4. Response

Agents write response events:
```bash
tools/ap_io_v31/writer.zsh cls task_result "wo-251116-test" "cls" "Task completed"
```

---

## Correlation Flow

### Example: Multi-Agent Task

1. **Liam** creates orchestration event:
   ```json
   {
     "correlation_id": "corr-20251116-001",
     "event": {"type": "task_start", "task_id": "wo-251116-multi"},
     "routing": {"targets": ["cls", "andy"], "priority": "high"}
   }
   ```

2. **Router** delivers to CLS and Andy

3. **CLS** processes and writes result:
   ```json
   {
     "correlation_id": "corr-20251116-001",
     "event": {"type": "task_result", "task_id": "wo-251116-multi"},
     "data": {"status": "success"}
   }
   ```

4. **Andy** processes and writes result:
   ```json
   {
     "correlation_id": "corr-20251116-001",
     "event": {"type": "task_result", "task_id": "wo-251116-multi"},
     "data": {"status": "success"}
   }
   ```

5. **Liam** queries correlation:
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

## Testing

### Unit Tests
- Router: Test single/multiple/broadcast routing
- Agent Integration: Test event processing
- Priority: Test priority queuing

### Integration Tests
- Multi-agent workflow: Test correlation flow
- Error handling: Test error scenarios
- Performance: Test routing overhead

---

## Implementation Checklist

- [ ] Create router (`tools/ap_io_v31/router.zsh`)
- [ ] Create CLS integration (`agents/cls/ap_io_v31_integration.zsh`)
- [ ] Create Andy integration (`agents/andy/ap_io_v31_integration.zsh`)
- [ ] Create Hybrid integration (`agents/hybrid/ap_io_v31_integration.zsh`)
- [ ] Create Liam integration (`agents/liam/ap_io_v31_integration.zsh`)
- [ ] Create GG integration (`agents/gg/ap_io_v31_integration.zsh`)
- [ ] Test routing (single/multiple/broadcast)
- [ ] Test correlation flow
- [ ] Test error handling

---

**Spec Owner:** Liam  
**Implementer:** Andy  
**Verifier:** CLS
