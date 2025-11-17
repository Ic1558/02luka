# Feature SPEC: Agent Ledger System

**Date:** 2025-11-16  
**Feature:** Multi-Agent Ledger System (Append-Only Event Logging)  
**Type:** Infrastructure / Observability  
**Target:** All agents (CLS, Andy, Hybrid, Kim, etc.)

---

## 1. Problem Statement

Current agent telemetry system has limitations:
- `g/telemetry/*.jsonl` files are **buffers** (can be overwritten, not SOT)
- No persistent, append-only ledger for historical analysis
- No agent status snapshots for quick health checks
- No session summaries for retrospective review
- Telemetry files are temporary and may be lost

**Goal:** Create a 3-layer ledger system:
1. **Ledger** (long-term) - Append-only event logs per agent
2. **Status** (current) - Snapshot of agent state
3. **Session Summary** (per-session) - Markdown summaries for review

---

## 2. Goals

1. **Persistent Ledger**
   - Append-only JSONL files per agent per day
   - Never overwrite (use `>>` append only)
   - Historical analysis capability

2. **Status Snapshots**
   - Real-time agent state (idle/busy/error/offline)
   - Quick health checks for dashboards
   - Safe write pattern (temp → mv)

3. **Session Summaries**
   - Human-readable markdown per session
   - Key events and lessons learned
   - Optional but recommended

4. **Separation of Concerns**
   - Ledger = SOT (append-only, never delete)
   - Telemetry = Buffer (can overwrite, temporary)
   - Clear migration path from telemetry → ledger

---

## 3. Scope

### ✅ Included

**Directory Structure:**
- `g/ledger/<agent>/YYYY-MM-DD.jsonl` - Append-only event logs
- `agents/<agent>/status.json` - Current state snapshot
- `memory/<agent>/sessions/YYYY-MM-DD_<agent>_NNN.md` - Session summaries

**Agents:**
- CLS (primary implementation target)
- Andy (dev agent, via Codex CLI)
- Hybrid (Luka CLI)
- Kim (future)

**Behaviors:**
- Append-only ledger writes
- Safe status.json writes (temp → mv)
- Event schema validation
- Directory auto-creation

### ❌ Excluded

- Telemetry file removal (keep existing `g/telemetry/*.jsonl`)
- Automatic telemetry → ledger migration (manual/script-based)
- Ledger rotation/archival (future enhancement)
- Web dashboard (out of scope)

---

## 4. Requirements

### 4.1 Functional Requirements

1. **Ledger Schema (g/ledger/<agent>/YYYY-MM-DD.jsonl)**
   ```json
   {
     "ts": "2025-11-16T02:12:34+07:00",
     "agent": "cls",
     "session_id": "2025-11-16_cls_001",
     "event": "task_result",
     "task_id": "wo-251116-agents-layout",
     "source": "gg_orchestrator",
     "summary": "Completed /agents layout SPEC + PLAN",
     "data": {
       "status": "success",
       "duration_sec": 132,
       "files_touched": ["path1", "path2"]
     }
   }
   ```

2. **Status Schema (agents/<agent>/status.json)**
   ```json
   {
     "agent": "cls",
     "state": "idle",
     "last_heartbeat": "2025-11-16T02:10:00+07:00",
     "last_task_id": "wo-251116-agents-layout",
     "session_id": "2025-11-16_cls_001",
     "last_error": null
   }
   ```

3. **Session Summary (memory/<agent>/sessions/*.md)**
   - Markdown format
   - Key events timeline
   - Tasks completed
   - Lessons learned

### 4.2 Non-Functional Requirements

1. **Safety**
   - Ledger: Append-only (`>>`), never overwrite (`>`)
   - Status: Safe write (temp → mv)
   - Directory auto-creation if missing

2. **Performance**
   - Minimal overhead on agent operations
   - Async writes where possible

3. **Reliability**
   - Write failures must not crash agent
   - Graceful degradation if ledger unavailable

---

## 5. Directory Layout

```
g/
  ledger/
    cls/
      2025-11-16.jsonl
      2025-11-17.jsonl
    andy/
      2025-11-16.jsonl
    hybrid/
      2025-11-16.jsonl
    kim/
      2025-11-16.jsonl

agents/
  cls/
    status.json
  andy/
    status.json
  hybrid/
    status.json

memory/
  cls/
    sessions/
      2025-11-16_cls_001.md
  andy/
    sessions/
      2025-11-16_andy_001.md
  hybrid/
    sessions/
      2025-11-16_hybrid_001.md

g/
  telemetry/
    cls_audit.jsonl        # buffer (existing, can overwrite)
    andy_audit.jsonl       # optional
```

---

## 6. Event Types

- `heartbeat` - Periodic agent alive signal
- `task_start` - Task initiated
- `task_result` - Task completed (success/failure)
- `error` - Error occurred
- `info` - General information

---

## 7. Agent-Specific Behaviors

### 7.1 CLS
- Write: `g/ledger/cls/YYYY-MM-DD.jsonl` (append-only)
- Write: `agents/cls/status.json` (safe write)
- Optional: `memory/cls/sessions/*.md` (via WO)
- Keep: `g/telemetry/cls_audit.jsonl` as buffer (can overwrite)

### 7.2 Andy (Dev Agent)
- Hook into Codex CLI execution
- Write: `g/ledger/andy/YYYY-MM-DD.jsonl` on task start/end
- Update: `agents/andy/status.json` on state change
- Implementation: Helper script or Python wrapper around Codex CLI

### 7.3 Hybrid / Luka CLI
- Write: `g/ledger/hybrid/YYYY-MM-DD.jsonl` on WO execution
- Update: `agents/hybrid/status.json` on completion
- Record: Command executed (sanitized), exit code, summary

---

## 8. Constraints

1. **Ledger Protection**
   - Never delete `g/ledger/**` files (except via special WO from CLC)
   - Never overwrite ledger (use `>>` only)
   - File rotation: Create new daily file, archive old ones

2. **Telemetry Relationship**
   - `g/telemetry/*.jsonl` remains as buffer (can overwrite)
   - Optional process can tail/copy telemetry → ledger
   - Telemetry is NOT SOT

3. **Governance**
   - All paths in allowed zones (normal_code)
   - No prohibited zone violations
   - CLS will verify schema/paths compliance

---

## 9. Success Criteria

1. ✅ CLS can write to `g/ledger/cls/YYYY-MM-DD.jsonl`
2. ✅ Status files update correctly with safe write pattern
3. ✅ Ledger files are append-only (verified)
4. ✅ Directory structure created automatically
5. ✅ Schema validation passes
6. ✅ No governance violations

---

## 10. Dependencies

- Existing telemetry system (no breaking changes)
- Agent execution hooks (CLS, Andy, Hybrid)
- Safe write utilities (temp → mv pattern)

---

**Spec Owner:** GG-Orchestrator  
**Implementer:** Andy + CLC  
**Verifier:** CLS
