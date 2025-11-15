# Feature SPEC: AP/IO v3.1 Ledger System

**Date:** 2025-11-16  
**Feature:** Application Protocol / Input-Output v3.1 Ledger  
**Type:** Infrastructure / Observability / Protocol  
**Target:** All agents (CLS, Andy, Hybrid, Kim, Liam, GG)

---

## 1. Problem Statement

Current Agent Ledger System (v1.0) has limitations:
- No standardized Application Protocol layer
- Input/Output formats vary by agent
- No unified event routing
- Limited cross-agent event correlation
- No protocol versioning

**Goal:** Create **AP/IO v3.1 Ledger** - a protocol-aware ledger system that:
1. Standardizes Application Protocol for all agents
2. Provides unified Input/Output interfaces
3. Enables cross-agent event correlation
4. Supports protocol versioning (v3.1)
5. Integrates with existing Agent Ledger infrastructure

---

## 2. Goals

1. **Application Protocol Layer**
   - Standardized event protocol (v3.1)
   - Unified message format
   - Protocol versioning support

2. **Input/Output Standardization**
   - Consistent input parsing
   - Standardized output formatting
   - Cross-agent compatibility

3. **Enhanced Ledger Schema**
   - Protocol version field
   - Enhanced metadata
   - Cross-agent correlation IDs

4. **Routing Integration**
   - Event routing to all agents
   - Multi-agent event broadcasting
   - Agent-specific filtering

5. **Backward Compatibility**
   - Support existing Agent Ledger v1.0
   - Gradual migration path
   - Dual-mode operation

---

## 3. Scope

### ✅ Included

**Protocol Layer:**
- AP/IO v3.1 protocol definition
- Message format specification
- Version negotiation

**Ledger Enhancements:**
- Enhanced schema with protocol fields
- Cross-agent correlation
- Event routing metadata

**Integration:**
- Writer/Reader stubs for all agents
- Routing integration
- Backward compatibility layer

**Testing:**
- CLS testcases
- Integration tests
- Protocol validation tests

### ❌ Excluded

- Breaking changes to existing Agent Ledger v1.0
- Agent-specific protocol extensions (future)
- Real-time event streaming (future)
- Web dashboard (out of scope)

---

## 4. Requirements

### 4.1 Application Protocol v3.1

**Protocol Header:**
```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "agent": "cls",
  "timestamp": "2025-11-16T02:12:34+07:00",
  "correlation_id": "corr-20251116-001",
  "session_id": "2025-11-16_cls_001"
}
```

**Message Format:**
```json
{
  "header": { /* protocol header */ },
  "event": {
    "type": "task_result",
    "task_id": "wo-251116-agents-layout",
    "source": "gg_orchestrator",
    "summary": "Completed /agents layout SPEC + PLAN"
  },
  "data": {
    "status": "success",
    "duration_sec": 132,
    "files_touched": ["path1", "path2"],
    "metadata": {
      "complexity": "medium",
      "risk_level": "guarded"
    }
  },
  "routing": {
    "targets": ["cls", "andy"],
    "broadcast": false,
    "priority": "normal"
  }
}
```

### 4.2 Enhanced Ledger Schema

**Ledger Entry (g/ledger/<agent>/YYYY-MM-DD.jsonl):**
```json
{
  "protocol": "AP/IO",
  "version": "3.1",
  "ts": "2025-11-16T02:12:34+07:00",
  "agent": "cls",
  "correlation_id": "corr-20251116-001",
  "session_id": "2025-11-16_cls_001",
  "event": {
    "type": "task_result",
    "task_id": "wo-251116-agents-layout",
    "source": "gg_orchestrator",
    "summary": "Completed /agents layout SPEC + PLAN"
  },
  "data": {
    "status": "success",
    "duration_sec": 132,
    "files_touched": ["path1", "path2"],
    "metadata": {
      "complexity": "medium",
      "risk_level": "guarded",
      "impact_zone": "normal_code"
    }
  },
  "routing": {
    "targets": ["cls", "andy"],
    "broadcast": false,
    "priority": "normal",
    "delivered_to": ["cls", "andy"]
  }
}
```

### 4.3 Input/Output Interfaces

**Input Interface:**
- Parse AP/IO v3.1 messages
- Validate protocol version
- Extract event data
- Handle backward compatibility (v1.0)

**Output Interface:**
- Format events as AP/IO v3.1
- Generate correlation IDs
- Apply routing rules
- Write to ledger

### 4.4 Routing Integration

**Routing Rules:**
- Route events to target agents
- Support broadcast mode
- Priority-based routing
- Agent-specific filtering

**Integration Points:**
- CLS: Direct integration
- Andy: Via Codex CLI wrapper
- Hybrid: Via Luka CLI
- Liam: Direct integration
- GG: Cloud orchestrator (read-only)

---

## 5. Directory Layout

```
g/
  ledger/
    cls/
      2025-11-16.jsonl      # AP/IO v3.1 format
    andy/
      2025-11-16.jsonl
    hybrid/
      2025-11-16.jsonl
    liam/
      2025-11-16.jsonl
    gg/
      2025-11-16.jsonl      # Read-only, cloud events

schemas/
  ap_io_v31.schema.json     # Protocol schema
  ap_io_v31_ledger.schema.json  # Ledger entry schema

tools/
  ap_io_v31/
    writer.zsh               # Writer stub
    reader.zsh               # Reader stub
    router.zsh               # Routing logic
    validator.zsh            # Protocol validator

agents/
  cls/
    status.json
    ap_io_v31_integration.zsh
  andy/
    status.json
    ap_io_v31_integration.zsh
  hybrid/
    status.json
    ap_io_v31_integration.zsh
  liam/
    status.json
    ap_io_v31_integration.zsh
```

---

## 6. Protocol Versioning

**Version Format:** `MAJOR.MINOR` (e.g., `3.1`)

**Version Compatibility:**
- v3.1: Current version
- v3.0: Backward compatible
- v1.0: Legacy support (Agent Ledger)

**Migration:**
- Gradual migration from v1.0 to v3.1
- Dual-mode operation during transition
- Automatic version detection

---

## 7. Event Types

- `heartbeat` - Agent alive signal
- `task_start` - Task initiated
- `task_result` - Task completed
- `error` - Error occurred
- `info` - General information
- `routing_request` - Request event routing
- `correlation_query` - Query correlated events

---

## 8. Routing Integration

### 8.1 Agent-Specific Integration

**CLS:**
- Direct integration via `ap_io_v31_integration.zsh`
- Write events on task start/end
- Read events for correlation

**Andy:**
- Integration via Codex CLI wrapper
- Hook into Codex execution
- Write events for dev tasks

**Hybrid:**
- Integration via Luka CLI
- Write events for WO execution
- Read events for status updates

**Liam:**
- Direct integration (local orchestrator)
- Write events for orchestration decisions
- Read events for multi-agent coordination

**GG:**
- Read-only access (cloud orchestrator)
- Query events for system overview
- No direct writes (delegates to local agents)

### 8.2 Routing Rules

**Target Selection:**
- Single agent: `targets: ["cls"]`
- Multiple agents: `targets: ["cls", "andy"]`
- Broadcast: `broadcast: true` (all agents)

**Priority Levels:**
- `critical` - Immediate delivery
- `high` - Priority queue
- `normal` - Standard queue
- `low` - Background processing

---

## 9. Success Criteria

1. ✅ AP/IO v3.1 protocol defined and validated
2. ✅ Enhanced ledger schema implemented
3. ✅ Writer/Reader stubs created for all agents
4. ✅ Routing integration working for all agents
5. ✅ Backward compatibility with v1.0 maintained
6. ✅ CLS testcases passing
7. ✅ Cross-agent event correlation working
8. ✅ Protocol versioning working

---

## 10. Dependencies

- Existing Agent Ledger System (v1.0)
- Agent infrastructure (CLS, Andy, Hybrid, Liam, GG)
- Codex Sandbox Mode (safety)
- Routing system

---

**Spec Owner:** Liam  
**Implementer:** Andy (primary) + CLS (validation)  
**Verifier:** CLS
