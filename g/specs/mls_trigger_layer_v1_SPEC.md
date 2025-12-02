# MLS Trigger Layer v1.0 - Specification

## 1. Executive Summary

**Problem**: MLS (Machine Learning System) ledger exists with robust infrastructure (schema, validation, aggregation) but receives events only from CI workflows. Local development, agent operations, and real-time system changes are not automatically captured.

**Solution**: Implement a 4-layer trigger architecture that automatically captures events from Git, File System, Agents, and Orchestrator operations.

**Impact**: Transform MLS from passive storage to active system memory, enabling:
- Real-time development tracking
- Autonomous agent accountability
- Complete system observability
- Predictive pattern detection

---

## 2. Architecture Overview

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     MLS Ledger                          │
│            (mls/ledger/YYYY-MM-DD.jsonl)               │
└─────────────────────────────────────────────────────────┘
                           ▲
                           │ (All layers feed here)
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼─────┐      ┌────▼─────┐      ┌────▼─────┐
   │   Git    │      │   File   │      │  Agent   │
   │  Hooks   │      │ Watcher  │      │ Protocol │
   └──────────┘      └──────────┘      └──────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                      ┌────▼─────┐
                      │  GG/GC   │
                      │Middleware│
                      └──────────┘
```

### 2.2 Workflow Integration (No Bottleneck Design)

**Critical**: MLS is an **observability layer**, not a **workflow gate**.

```
LAC validates task
    ↓
Routes to Dev Worker
    ↓
Dev Worker executes
    ↓ (returns status="success")
QA handoff runs
    ↓ (returns qa_status="pass", final_status="approved")
[WORKFLOW COMPLETE] ← User receives result
    ↓
[MLS logs async] ← Fire-and-forget, doesn't block
```

**Key Properties**:
- MLS logging happens **AFTER** `execute_task()` returns
- Workflow: `LAC → Dev → QA → Approved → [MLS logs async]`
- If MLS fails, workflow continues normally (silent failure)
- No blocking, no waiting, fire-and-forget pattern

---

## 3. Layer Specifications

### Layer 1: Git Hooks (40% Coverage)

**Purpose**: Capture all git operations (commits, checkouts, merges)

**Trigger Points**:
- `post-commit`: After every commit
- `post-checkout`: After branch switches
- `post-merge`: After merge operations

**Event Schema**:
```json
{
  "type": "improvement",
  "title": "Commit: <message>",
  "summary": "<git show --stat>",
  "source": {
    "producer": "git",
    "context": "local",
    "sha": "<commit-hash>",
    "branch": "<branch-name>"
  },
  "tags": ["git", "commit", "local"],
  "confidence": 0.8
}
```

**Implementation**: `.git/hooks/post-commit`

**Safety**: Read-only operations, no git state modification

---

### Layer 2: File Watcher (30% Coverage)

**Purpose**: Track real-time file modifications during development

**Trigger Points**:
- File saves in `agents/`, `g/`, `tools/`
- Creation of new files
- Deletion of tracked files

**Technology**: `fswatch` (macOS) with debouncing (3-second window)

**Event Schema**:
```json
{
  "type": "improvement",
  "title": "File modified: <basename>",
  "summary": "Path: <full-path>",
  "source": {
    "producer": "fswatch",
    "context": "local",
    "file_path": "<path>",
    "event_type": "created|modified|deleted"
  },
  "tags": ["dev", "file-save", "local"],
  "confidence": 0.7
}
```

**Implementation**: `com.02luka.mls_watcher.plist` (launchd)

**Safety**: Rate limiting (max 10 events/minute), ignore temp files

---

### Layer 3: Agent Protocol (50% Coverage)

**Purpose**: Auto-log AI agent operations and decisions

**Trigger Points**:
- GMX task completion
- QA Worker execution
- Dev Lane completion
- R&D Worker insights
- CLC Work Order dispatch

**Timing & Integration**:
- MLS logging happens **AFTER** `execute_task()` returns
- Workflow: `LAC → Dev → QA → Approved → [MLS logs async]`
- MLS is observability layer, **not workflow gate**
- If MLS fails, workflow continues normally (silent failure)
- No blocking, no waiting, fire-and-forget pattern

**Integration Pattern** (Python example):
```python
import threading
from g.tools.mls_log import mls_log

def execute_task(self, task):
    # ... execute task logic ...
    result = {"status": "success", ...}
    
    # Return result FIRST (workflow completes)
    # Then log to MLS async (doesn't block)
    threading.Thread(
        target=mls_log,
        args=("solution", "Task completed", result, "dev_worker"),
        daemon=True
    ).start()
    
    return result  # ← Workflow COMPLETE here
```

**Event Schema**:
```json
{
  "type": "solution|failure",
  "title": "<agent>: <task-name>",
  "summary": "<outcome-description>",
  "source": {
    "producer": "<agent-name>",
    "context": "antigravity|cursor|cli",
    "task_id": "<task-id>",
    "conversation_id": "<conv-id>"
  },
  "state": {
    "files_modified": ["<list>"],
    "decisions": ["<list>"],
    "next_steps": ["<list>"]
  },
  "tags": ["agent", "<agent-name>", "<outcome>"],
  "confidence": 0.9
}
```

**Implementation**: 
- `mls_log()` function in each agent
- Protocol enforcement via `AGENT_PROTOCOL.md`

**Safety**: Async logging, no blocking operations

---

### Layer 4: Orchestrator Middleware (100% Coverage)

**Purpose**: Central event sink for all high-level operations

**Trigger Points**:
- Work Order lifecycle events
- LAC lane transitions
- Governance checkpoints
- System health events

**Event Schema**:
```json
{
  "type": "pattern",
  "title": "System event: <description>",
  "summary": "<context>",
  "source": {
    "producer": "gg|gc|gm",
    "context": "orchestrator",
    "wo_id": "<wo-id>",
    "lane": "<lane-name>"
  },
  "tags": ["orchestrator", "system", "<wo-id>"],
  "confidence": 1.0
}
```

**Implementation**: `mls_event_sink.py` middleware

**Safety**: Queue-based (async), backpressure handling

---

## 4. New MLS Event Type: `session_state`

**Purpose**: Track ephemeral agent state for context continuity

**Schema Extension**:
```json
{
  "type": "session_state",
  "title": "<agent>: <current-focus>",
  "summary": "<what-agent-is-doing>",
  "source": {
    "producer": "<agent>",
    "context": "antigravity|cursor",
    "conversation_id": "<id>"
  },
  "state": {
    "current_task": "<task>",
    "active_files": ["<list>"],
    "decisions": ["<list>"],
    "next_steps": ["<list>"]
  },
  "tags": ["session", "<agent>"],
  "confidence": 1.0
}
```

**Lifecycle**:
- Written at task start
- Updated at major decision points
- Closed at task completion

**Retention**: 7 days (ephemeral)

---

## 5. Safety & Performance

### Rate Limiting
- Git Hooks: No limit (low frequency)
- File Watcher: Max 10 events/min
- Agent Protocol: Max 1 event/task
- Orchestrator: Max 100 events/hour

### Backpressure Handling
- Queue-based async writes
- Drop oldest events if queue > 1000
- Alert if drop rate > 10%

### Error Handling
- All layers: `try/catch` with silent failure
- Never block primary operation (git commit, file save, agent execution)
- Log errors to `g/logs/mls_trigger_errors.log`

### Privacy
- No PII in events
- No credential logging
- File paths are relative, not absolute

---

## 6. Schema Updates Required

Add to `mls/schema/mls_event.schema.json`:

```json
{
  "type": {
    "enum": ["solution", "failure", "improvement", "pattern", "antipattern", "session_state"]
  },
  "state": {
    "type": "object",
    "properties": {
      "current_task": {"type": "string"},
      "active_files": {"type": "array"},
      "decisions": {"type": "array"},
      "next_steps": {"type": "array"}
    }
  }
}
```

---

## 7. Rollout Strategy

### Phase 1: Git Hooks (Week 1)
- Install post-commit hook
- Verify ledger writes
- Monitor for 7 days

### Phase 2: Agent Protocol (Week 2)
- Update GMX, QA Worker personas
- Add `mls_log()` function
- Verify agent events

### Phase 3: File Watcher (Week 3)
- Deploy launchd daemon
- Test rate limiting
- Monitor resource usage

### Phase 4: Orchestrator (Week 4)
- Integrate GG middleware
- Full system observability
- Performance tuning

### Phase 5: Validation (Week 5)
- Deep validation of all event types
- Backfill missing events (manual)
- Production cutover

---

## 8. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Event Capture Rate | > 80% of operations | Daily MLS audit |
| Latency Impact | < 50ms per event | Benchmark tests |
| Error Rate | < 0.1% | Error log analysis |
| Storage Growth | < 10MB/day | Ledger file size |
| Agent Compliance | 100% | Protocol audit |

---

## 9. Dependencies

| Component | Requirement | Status |
|-----------|-------------|--------|
| MLS Ledger | v1.0 (current) | ✅ Ready |
| `mls_add.zsh` | v1.0 | ✅ Ready |
| `fswatch` | macOS native | ✅ Installed |
| `jq` | v1.6+ | ✅ Installed |
| Agent Personas | Writable | ✅ Ready |
| launchd | macOS native | ✅ Ready |

---

## 10. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Event flood | High storage | Rate limiting + debouncing |
| Hook failure blocks git | Critical | Silent failure + logging |
| fswatch CPU usage | Medium | Targeted directories only |
| Agent non-compliance | Medium | Protocol enforcement + audits |
| Schema drift | Low | CI validation on every push |

---

## 11. Future Enhancements (Out of Scope)

- Real-time MLS viewer (web UI)
- Predictive analytics on patterns
- Auto-escalation on repeated failures
- Integration with external observability (Datadog, etc.)
