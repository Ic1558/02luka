# Feature SPEC: Shared Memory Phase 2 - GC/CLS Integration & Metrics

**Feature ID:** `shared_memory_phase2_gc_cls`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Objective

Enable GC (Claude Desktop) and CLS (Cursor) agents to read/write shared memory, collect metrics on token savings, and provide health checks for the shared memory system.

---

## Problem Statement

Phase 1 provided the foundation (shared memory structure, bridge system), but:
- No agent integration (GC/CLS can't use it)
- No metrics collection (can't measure token savings)
- No health checks (can't verify system health)
- No automated metrics collection

**Impact:**
- Agents can't leverage shared memory
- No visibility into token savings
- No way to verify system health
- Manual metrics collection required

---

## Solution Overview

Phase 2 adds:
1. **GC Integration:** Shell helper script for Claude Desktop
2. **CLS Integration:** Python bridge for Cursor
3. **Metrics Collection:** Automated token usage tracking
4. **Health Checks:** Comprehensive system health verification
5. **Automated Metrics:** Hourly metrics collection via LaunchAgent

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Phase 2: GC/CLS Integration & Metrics                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │ GC (Claude) │         │ CLS (Cursor) │             │
│  │             │         │              │             │
│  │ gc_memory_  │         │ cls_memory.  │             │
│  │ sync.sh     │         │ py           │             │
│  └──────┬──────┘         └──────┬───────┘             │
│         │                        │                     │
│         └────────┬────────────────┘                    │
│                  │                                     │
│         ┌────────▼────────┐                          │
│         │ Shared Memory    │                          │
│         │ (Phase 1)        │                          │
│         └────────┬─────────┘                          │
│                  │                                     │
│         ┌────────▼────────┐                          │
│         │ Metrics Collector│                          │
│         │ (hourly)         │                          │
│         └──────────────────┘                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### 1. GC Memory Sync (`tools/gc_memory_sync.sh`)

**Purpose:** Shell helper for GC (Claude Desktop) to interact with shared memory

**Commands:**
- `update` - Update GC agent status to active
- `push <json>` - Push context data to bridge inbox
- `get` - Get GC's shared context

**Usage:**
```bash
# Update status
~/02luka/tools/gc_memory_sync.sh update

# Push context
~/02luka/tools/gc_memory_sync.sh push '{"task":"current work","phase":2}'

# Get context
~/02luka/tools/gc_memory_sync.sh get
```

**Integration:**
- Uses `memory_sync.sh` for status updates
- Writes to `bridge/memory/inbox/` for context
- Reads from `shared_memory/context.json`

### 2. CLS Memory Bridge (`agents/cls_bridge/cls_memory.py`)

**Purpose:** Python bridge for CLS (Cursor) to interact with shared memory

**Functions:**
- `before_task()` - Load shared context before task
- `after_task(task_result)` - Update context after task

**Usage:**
```python
from agents.cls_bridge.cls_memory import before_task, after_task

# Load context before task
context = before_task()

# Do work...

# Update context after task
after_task({"summary": "task completed", "result": "success"})
```

**Integration:**
- Calls `memory_sync.sh` via subprocess
- Writes to `bridge/memory/inbox/` for results
- Reads from `shared_memory/context.json`

### 3. Memory Metrics (`tools/memory_metrics.zsh`)

**Purpose:** Collect token usage metrics from shared memory

**Metrics Collected:**
- Agent count (number of active agents)
- Token total (total tokens used)
- Token saved (tokens saved via shared memory)
- Saved percentage (saved/total * 100)

**Output:**
- NDJSON file: `metrics/memory_usage.ndjson`
- Format: `{"ts":"ISO8601","agents":N,"token_total":N,"token_saved":N,"saved_pct":N}`

**Schedule:**
- Manual: Run anytime
- Automated: Hourly via LaunchAgent

### 4. Shared Memory Health (`tools/shared_memory_health.zsh`)

**Purpose:** Comprehensive health check for shared memory system

**Checks:**
1. Directory structure (`shared_memory/` exists)
2. Context file (`context.json` exists)
3. JSON validity (`context.json` is valid JSON)
4. Scripts executable (`memory_sync.sh`, `bridge_monitor.sh`)
5. LaunchAgent loaded (`com.02luka.memory.bridge`)

**Output:**
- ✅ Pass: All checks pass
- ❌ Fail: Exit code 1 with error message

### 5. Metrics LaunchAgent (`com.02luka.memory.metrics`)

**Purpose:** Automatically collect metrics every hour

**Configuration:**
- Interval: 3600 seconds (1 hour)
- Run at load: true
- Logs: `logs/memory_metrics.{out,err}.log`

---

## Data Flow

### GC Update Flow

```
GC (Claude Desktop)
    ↓
gc_memory_sync.sh update
    ↓
memory_sync.sh update gc active
    ↓
Update shared_memory/context.json
    ↓
Broadcast to bridge/outbox/
```

### CLS Task Flow

```
CLS (Cursor)
    ↓
before_task() → Load context.json
    ↓
Do work...
    ↓
after_task(result) → Update context + write to bridge/inbox/
    ↓
Bridge monitor processes → Updates context.json
```

### Metrics Collection Flow

```
Hourly (LaunchAgent)
    ↓
memory_metrics.zsh
    ↓
Read context.json (token_usage)
    ↓
Calculate metrics
    ↓
Append to metrics/memory_usage.ndjson
```

---

## Integration Points

### Existing Systems
- **Phase 1:** Shared memory structure, bridge system, memory_sync.sh
- **Environment:** `LUKA_SOT`, `LUKA_HOME`

### New Integration
- **GC:** Shell helper script
- **CLS:** Python bridge module
- **Metrics:** Automated collection
- **Health:** System verification

---

## Success Criteria

✅ **Functional:**
- GC can update status and push context
- CLS can load context and save results
- Metrics collected successfully
- Health checks pass

✅ **Metrics:**
- Metrics written ≥ 1 record/hour
- Token savings tracked
- Agent activity tracked

✅ **SLO:**
- SLO-1: Health check passes 100%
- SLO-2: Metrics written ≥ 1 record/hour
- SLO-3: Token saved/total ≥ 40% (Week 1 target)

---

## Configuration

### Environment Variables
- `LUKA_SOT`: `/Users/icmini/02luka` (default)
- `LUKA_HOME`: `/Users/icmini/02luka/g` (default)

### File Locations
- GC Helper: `tools/gc_memory_sync.sh`
- CLS Bridge: `agents/cls_bridge/cls_memory.py`
- Metrics: `tools/memory_metrics.zsh`
- Health: `tools/shared_memory_health.zsh`
- Metrics Data: `metrics/memory_usage.ndjson`

---

## Future Enhancements

1. **Phase 3: Redis Integration**
   - Real-time memory sync
   - Pub/sub for live updates
   - Centralized memory hub

2. **Advanced Metrics**
   - Per-agent token usage
   - Context hit rate
   - Optimization suggestions

3. **Agent Coordination**
   - Work handoff between agents
   - Conflict resolution
   - Priority queuing

---

## References

- **Phase 1 SPEC:** `g/reports/feature_shared_memory_system_SPEC.md`
- **SOT Path:** `/Users/icmini/02luka`
- **Bridge System:** `bridge/memory/`
