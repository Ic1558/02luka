# Feature SPEC: Shared Memory Phase 4 - Redis Real-time Hub & Mary/R&D Integration

**Feature ID:** `shared_memory_phase4_redis_hub`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Implementation

---

## Objective

Add Redis-based real-time memory hub for live synchronization across all agents, and integrate Mary/R&D systems to record results to shared memory + Redis for unified real-time state visibility.

---

## Problem Statement

Current system (Phase 1-3) is file-based:
- Updates are polling-based (not real-time)
- No live synchronization between agents
- Mary/R&D results not integrated
- No pub/sub for instant updates
- Agents may see stale context

**Impact:**
- Delayed context updates
- Potential conflicts from stale data
- Mary/R&D work not visible to other agents
- No real-time coordination

---

## Solution Overview

Phase 4 adds:
1. **Redis Memory Hub:** Centralized service with pub/sub
2. **Real-time Sync:** Live updates via Redis channels
3. **Mary Integration:** Record Mary dispatcher results
4. **R&D Integration:** Record R&D proposal outcomes
5. **Unified State:** All agents see same real-time state

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Phase 4: Redis Real-time Hub                            │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐         ┌──────────────┐            │
│  │ File-based   │ ←──────→ │ Redis Hub    │            │
│  │ context.json │         │ (Real-time)  │            │
│  └──────────────┘         └──────┬───────┘            │
│         ↑                         │                     │
│         │                         │ pub/sub             │
│         │                         ▼                     │
│  ┌──────┴────────────────────────┴──────┐             │
│  │         All Agents                    │             │
│  │  GC, CLS, GPT, Gemini, Mary, R&D     │             │
│  └───────────────────────────────────────┘             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Memory Hub Service (`agents/memory_hub/memory_hub.py`)

**Purpose:** Centralized Redis-based memory hub with pub/sub

**Features:**
- Syncs file-based context to Redis
- Publishes updates via `memory:updates` channel
- Subscribes to updates from all agents
- Merges contexts (Redis takes precedence)
- Handles conflicts and versioning

**Functions:**
- `sync_from_file()` - Load context from file
- `sync_to_file(data)` - Save context to file
- `update_agent_context(agent, context)` - Update agent context
- `get_unified_context()` - Get merged context
- `publish_update(event)` - Publish to Redis channel
- `subscribe_updates()` - Subscribe to Redis channel

**Usage:**
```python
from agents.memory_hub.memory_hub import UnifiedMemoryHub

hub = UnifiedMemoryHub()

# Update agent context
hub.update_agent_context("mary", {
    "last_task": "deployment",
    "status": "completed",
    "result": "success"
})

# Get unified context
context = hub.get_unified_context()
```

### 2. Memory Hub LaunchAgent

**Purpose:** Run memory hub continuously

**Configuration:**
- Label: `com.02luka.memory.hub`
- KeepAlive: true
- RunAtLoad: true
- Logs: `logs/memory_hub.{out,err}.log`

### 3. Mary Integration

**Purpose:** Record Mary dispatcher results to shared memory

**Integration Points:**
- `tools/mary_dispatcher.zsh` - After task completion
- `tools/mary_dispatcher_health_check.zsh` - Health status
- Work Order results → shared memory

**Updates:**
- Task completion status
- Work Order outcomes
- Error logs
- Performance metrics

### 4. R&D Integration

**Purpose:** Record R&D proposal outcomes to shared memory

**Integration Points:**
- `tools/rnd_consumer.zsh` - After proposal processing
- `tools/rnd_apply.zsh` - After proposal approval
- Proposal outcomes → shared memory

**Updates:**
- Proposal status
- Improvement results
- Score changes
- Learning outcomes

---

## Data Flow

### Real-time Update Flow

```
Agent (any) updates context
    ↓
Memory Hub receives update
    ↓
Update Redis (HSET memory:agents:<agent>)
    ↓
Publish to memory:updates channel
    ↓
All subscribed agents receive update
    ↓
Sync to file (periodic backup)
```

### Mary Integration Flow

```
Mary dispatcher completes task
    ↓
Record result to shared memory
    ↓
Update Redis via hub
    ↓
Publish update
    ↓
All agents see Mary's work
```

### R&D Integration Flow

```
R&D proposal processed
    ↓
Record outcome to shared memory
    ↓
Update Redis via hub
    ↓
Publish update
    ↓
All agents see R&D improvements
```

---

## Redis Configuration

### Connection
- Host: `localhost`
- Port: `6379`
- Password: `changeme-02luka` (from existing config)
- Database: `0` (default)

### Data Structures

**Hash: `memory:agents:<agent_name>`**
```
HSET memory:agents:mary status active
HSET memory:agents:mary context '{"last_task":"..."}'
HSET memory:agents:mary last_update "2025-11-12T08:00:00Z"
```

**Channel: `memory:updates`**
```json
{
  "agent": "mary",
  "event": "context_update",
  "timestamp": "2025-11-12T08:00:00Z",
  "data": {...}
}
```

### Commands

**Update Agent:**
```bash
redis-cli -a changeme-02luka HSET memory:agents:mary status active
```

**Get Agent Context:**
```bash
redis-cli -a changeme-02luka HGETALL memory:agents:mary
```

**Subscribe to Updates:**
```bash
redis-cli -a changeme-02luka SUBSCRIBE memory:updates
```

---

## Integration Points

### Existing Systems
- **Phase 1-3:** File-based shared memory
- **Mary Dispatcher:** `tools/mary_dispatcher.zsh`
- **R&D Consumer:** `tools/rnd_consumer.zsh`
- **Redis:** Existing Redis instance

### New Integration
- **Memory Hub:** Centralized service
- **Mary Hook:** Record results
- **R&D Hook:** Record outcomes
- **Pub/Sub:** Real-time updates

---

## Success Criteria

✅ **Functional:**
- Memory hub running continuously
- Redis sync working
- Pub/sub updates working
- Mary results recorded
- R&D outcomes recorded

✅ **Real-time:**
- Updates propagate < 1 second
- All agents see updates immediately
- No stale context

✅ **Integration:**
- Mary integrated
- R&D integrated
- All agents coordinated

---

## Configuration

### Environment Variables
- `LUKA_SOT`: `/Users/icmini/02luka` (default)
- `REDIS_HOST`: `localhost` (default)
- `REDIS_PORT`: `6379` (default)
- `REDIS_PASSWORD`: `changeme-02luka` (from config)

### File Locations
- Memory Hub: `agents/memory_hub/memory_hub.py`
- LaunchAgent: `~/Library/LaunchAgents/com.02luka.memory.hub.plist`
- Logs: `logs/memory_hub.{out,err}.log`

---

## Safety & Guardrails

### Redis Failover
- Graceful fallback to file-based
- No blocking if Redis unavailable
- Automatic recovery when Redis returns

### Conflict Resolution
- Timestamp-based ordering
- Last-write-wins for conflicts
- Version tracking for audit

### Data Consistency
- Periodic file sync (backup)
- Redis as source of truth
- File as persistent storage

---

## Future Enhancements

1. **Advanced Pub/Sub:**
   - Agent-specific channels
   - Event filtering
   - Priority queuing

2. **Conflict Resolution:**
   - Merge strategies
   - Conflict detection
   - Automatic resolution

3. **Performance:**
   - Connection pooling
   - Batch updates
   - Caching

---

## References

- **Phase 1:** `g/reports/feature_shared_memory_system_SPEC.md`
- **Phase 2:** `g/reports/feature_shared_memory_phase2_gc_cls_SPEC.md`
- **Phase 3:** `g/reports/feature_shared_memory_phase3_remaining_agents_SPEC.md`
- **Redis Config:** `localhost:6379` (password: `changeme-02luka`)
