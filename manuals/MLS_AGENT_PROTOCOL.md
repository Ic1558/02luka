# MLS Agent Protocol - User Manual

## Overview

The MLS Agent Protocol enables AI agents to automatically log their operations to the MLS ledger for observability, analytics, and system improvement.

## Integrated Agents

| Agent | File | Auto-Logging |
|-------|------|--------------|
| GMX | `agents/gmx/` | ✅ Enabled (persona level) |
| Dev Worker (OSS) | `agents/dev_oss/dev_worker.py` | ✅ Enabled |
| R&D Worker | `agents/rnd/rnd_worker.py` | ✅ Enabled |

## How It Works

### 1. Fire-and-Forget Pattern

Agents call `mls_log()` **AFTER** returning results to the user:

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
        args=("solution", "Task completed", result, "agent_name"),
        daemon=True
    ).start()
    
    return result  # ← Workflow COMPLETE here
```

### 2. Silent Failure

If MLS logging fails:
- Agent operations continue normally
- Error is logged to `g/logs/mls_agent_errors.log`
- No user-facing impact

### 3. Event Types

| Type | Usage |
|------|-------|
| `solution` | Successful task completion |
| `failure` | Task failed |
| `improvement` | Incremental improvements |
| `session_state` | Agent session tracking |

## Usage Examples

### Dev Worker Logging

```python
mls_log(
    "solution" if final_status == "approved" else "failure",
    f"Dev Worker ({lane}): Task {task_id}",
    f"Status: {final_status}, Files: {len(files_touched)}",
    f"dev_worker_{lane}",
    state={"files_touched": files_touched, "final_status": final_status},
    tags=["dev", lane, "qa_handoff"],
    confidence=0.9,
    wo_id=task_id
)
```

### R&D Worker Logging

```python
mls_log(
    "solution" if len(patterns) > 0 else "improvement",
    f"R&D Worker: Analyzed LAC telemetry",
    f"Found {len(patterns)} patterns from {len(dev_data)} dev events",
    "rnd_worker",
    state={"pattern_count": len(patterns), "dev_events": len(dev_data)},
    tags=["rnd", "analysis", "telemetry"],
    confidence=0.85
)
```

### GMX Logging (Persona-Driven)

GMX logs via its persona protocol:

```python
from g.tools.mls_log import mls_log, mls_session_start, mls_session_end

# Session start
mls_session_start(
    "gmx",
    "Planning work order",
    [],
    conversation_id=<conv_id>
)

# Task completion
mls_log(
    "solution",
    f"GMX: Planned WO for {intent}",
    f"{description}",
    "gmx",
    state={"target_files": target_files, "intent": intent},
    tags=["planning", intent],
    confidence=0.9,
    wo_id=wo_id
)
```

## Verification

### Check MLS Ledger

After an agent runs:

```bash
# View last event
tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl | jq .

# Filter by agent
grep '"producer":"dev_worker_oss"' mls/ledger/$(date +%Y-%m-%d).jsonl | jq .

# Filter by event type
grep '"type":"solution"' mls/ledger/$(date +%Y-%m-%d).jsonl | jq .
```

### Check Error Log

If MLS logging fails:

```bash
cat g/logs/mls_agent_errors.log
```

## Event Schema

```json
{
  "ts": "2025-12-03T02:50:00+0700",
  "type": "solution",
  "title": "Dev Worker (oss): Task WO-123",
  "summary": "Status: approved, Files: 3, QA: pass",
  "source": {
    "producer": "dev_worker_oss",
    "context": "antigravity",
    ...
  },
  "state": {
    "files_touched": ["file1.py", "file2.py"],
    "final_status": "approved"
  },
  "tags": ["dev", "oss", "qa_handoff"],
  "wo_id": "WO-123",
  "confidence": 0.9
}
```

## Adding MLS Logging to New Agents

### Step 1: Import

```python
import threading

# Import MLS logging
try:
    from g.tools.mls_log import mls_log
except ImportError:
    # Silent failure if MLS not available
    def mls_log(*args, **kwargs):
        pass
```

### Step 2: Call After Task Completion

```python
def execute_task(self, task):
    # ... task logic ...
    result = {...}
    
    # Log async (after return)
    threading.Thread(
        target=mls_log,
        args=("solution", "Task done", summary, "agent_name"),
        kwargs={"state": {...}, "tags": [...], "confidence": 0.9},
        daemon=True
    ).start()
    
    return result
```

### Step 3: Test

```bash
# Run agent
python3 agents/your_agent/your_worker.py

# Check MLS ledger
tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl | jq .
```

## Best Practices

1. **Always log AFTER returning result** (fire-and-forget)
2. **Use appropriate event types** (solution, failure, improvement)
3. **Include state context** (files_touched, decisions, metrics)
4. **Set realistic confidence scores** (0.0-1.0)
5. **Tag consistently** (agent name, operation type)
6. **Include wo_id** when available (for traceability)

## Troubleshooting

### "Agent doesn't log to MLS"

1. Check import works: `python3 -c "from agents.your_agent.worker import YourWorker"`
2. Verify `g/tools/mls_log.py` exists
3. Check error log: `cat g/logs/mls_agent_errors.log`
4. Ensure `tools/mls_add.zsh` is executable

### "MLS events are delayed"

- Normal. Async logging has 1-2 second delay.
- Check ledger after waiting: `sleep 2 && tail -1 mls/ledger/$(date +%Y-%m-%d).jsonl`

## Related Documentation

- **MLS README**: `mls/README.md`
- **Spec**: `g/specs/mls_trigger_layer_v1_SPEC.md`
- **Plan**: `g/reports/feature-dev/mls_trigger_layer_v1_PLAN.md`
- **Git Hooks**: `manuals/MLS_GIT_HOOKS.md`
