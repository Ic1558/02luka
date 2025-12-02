# MLS Trigger Layer v1.0 - Implementation Plan

## 1. Objective
Transform MLS from a passive CI-only ledger to an active, real-time system memory by implementing automatic event capture across all system layers.

## 2. Scope
- **In Scope**: Git hooks, File watcher, Agent protocol, Orchestrator middleware
- **Out of Scope**: Web UI, External integrations, Predictive analytics

## 3. Task Breakdown

### Phase 1: Git Hooks Layer (Week 1)

#### Task 1.1: Create Post-Commit Hook
- [ ] Create `.git/hooks/post-commit`
- [ ] Script calls `mls_add.zsh` with commit metadata
- [ ] Extract: commit message, SHA, branch, changed files
- [ ] Test: Verify event written to `mls/ledger/$(date +%Y-%m-%d).jsonl`

#### Task 1.2: Create Post-Checkout Hook
- [ ] Create `.git/hooks/post-checkout`
- [ ] Log branch switches
- [ ] Test: Switch branches, verify MLS event

#### Task 1.3: Create Post-Merge Hook
- [ ] Create `.git/hooks/post-merge`
- [ ] Log merge operations
- [ ] Test: Merge branch, verify MLS event

#### Task 1.4: Error Handling
- [ ] Wrap all hook scripts in `try/catch` (zsh: `|| true`)
- [ ] Log failures to `g/logs/mls_git_hook_errors.log`
- [ ] Verify: Hook failure does NOT block git operation

#### Task 1.5: Documentation
- [ ] Update `mls/README.md` with Git Hooks section
- [ ] Create `manuals/MLS_GIT_HOOKS.md` setup guide

---

### Phase 2: Agent Protocol Layer (Week 2)

#### Task 2.1: Create MLS Logging Function
- [ ] Create `g/tools/mls_log.py` (Python wrapper)
- [ ] Function signature: `mls_log(type, title, summary, agent_name, state={})`
- [ ] Async execution (non-blocking)
- [ ] Test: Call from Python script, verify ledger write

**Integration Pattern**:
- Call `mls_log()` in async callback **AFTER** `execute_task()` returns
- Example (threading):
  ```python
  import threading
  
  def execute_task(self, task):
      result = {...}  # Execute task
      
      # Return FIRST, then log async
      threading.Thread(
          target=mls_log,
          args=("solution", "Task done", result, "agent"),
          daemon=True
      ).start()
      
      return result  # ← Workflow completes here
  ```
- Never call `mls_log()` synchronously before return statement
- Fire-and-forget: Don't wait for MLS response

#### Task 2.2: Update GMX Protocol
- [ ] Edit `agents/gmx/PERSONA_PROMPT.md`
- [ ] Add section: "MLS Logging Protocol"
- [ ] Rule: "On task completion, call `mls_log.py`"
- [ ] Add `session_state` event requirement

#### Task 2.3: Update QA Worker
- [ ] Edit `agents/qa_v4/qa_worker.py`
- [ ] Add `from g.tools.mls_log import mls_log`
- [ ] Call `mls_log()` in `_log_telemetry()`
- [ ] Test: Run QA worker, verify MLS event

#### Task 2.4: Update Other Agents
- [ ] Dev Worker (`agents/dev_oss/dev_worker.py`)
- [ ] R&D Worker (`agents/rnd/rnd_worker.py`)
- [ ] CLC (if applicable)
- [ ] Test: Each agent logs correctly

#### Task 2.5: Session State Protocol
- [ ] Define when to write `session_state` events
  - Start of task
  - Major decision points
  - End of task
- [ ] Create `g/tools/mls_session.py` helper
- [ ] Test: Multi-turn conversation, verify state continuity

---

### Phase 3: File Watcher Layer (Week 3)

#### Task 3.1: Create File Watcher Script
- [ ] Create `g/tools/mls_file_watcher.zsh`
- [ ] Use `fswatch` to monitor: `agents/`, `g/specs/`, `tools/`
- [ ] Debounce: 3-second window
- [ ] Filter: Ignore `.pyc`, `.log`, `__pycache__`
- [ ] Test: Save file, verify MLS event

#### Task 3.2: Rate Limiting
- [ ] Implement rolling 1-minute window
- [ ] Max 10 events/minute
- [ ] Drop excess, log to `g/logs/mls_watcher_drops.log`
- [ ] Test: Rapid file saves, verify rate limit

#### Task 3.3: Create LaunchAgent
- [ ] Create `LaunchAgents/com.02luka.mls_watcher.plist`
- [ ] Point to `g/tools/mls_file_watcher.zsh`
- [ ] KeepAlive: true
- [ ] Test: Load with `launchctl load`, verify running

#### Task 3.4: Resource Monitoring
- [ ] Monitor CPU usage (`top -pid <pid>`)
- [ ] Monitor memory usage
- [ ] If CPU > 5%, add stricter rate limit
- [ ] Test: Run for 24 hours, verify < 5% CPU

#### Task 3.5: Installation Script
- [ ] Create `g/tools/install_mls_watcher.zsh`
- [ ] Auto-load launchd agent
- [ ] Verify installation
- [ ] Test: Fresh install on clean system

---

### Phase 4: Orchestrator Middleware (Week 4)

#### Task 4.1: Create MLS Event Sink
- [ ] Create `g/tools/mls_event_sink.py`
- [ ] Queue-based async writer
- [ ] Batch writes (max 100 events/batch)
- [ ] Backpressure: Drop oldest if queue > 1000
- [ ] Test: Flood with 10,000 events, verify no crash

#### Task 4.2: Integrate with GG/GC
- [ ] (Pending GG/GC architecture - defer to Boss)
- [ ] Hook into Work Order lifecycle
- [ ] Hook into LAC lane transitions
- [ ] Test: WO creation → MLS event

#### Task 4.3: System Health Events
- [ ] Create health check cron job
- [ ] Log system status to MLS (hourly)
- [ ] Include: Disk usage, process count, error rates
- [ ] Test: Verify hourly health events

---

### Phase 5: Schema & Validation (Week 5)

#### Task 5.1: Update MLS Schema
- [ ] Edit `mls/schema/mls_event.schema.json`
- [ ] Add `session_state` to `type` enum
- [ ] Add `state` object definition
- [ ] Test: Validate new events with `ajv-cli`

#### Task 5.2: CI Validation Update
- [ ] Update `.github/workflows/mls-deep-validate.yml`
- [ ] Include new event types in validation
- [ ] Test: Trigger workflow, verify pass

#### Task 5.3: Backfill Historical Events (Manual)
- [ ] Review last 30 days of git history
- [ ] Manually log major commits to MLS
- [ ] Mark as `confidence: 0.5` (backfilled)
- [ ] Test: Ledger completeness check

#### Task 5.4: Performance Tuning
- [ ] Measure event write latency
- [ ] Optimize `mls_add.zsh` (if needed)
- [ ] Consider batching for high-frequency sources
- [ ] Test: Benchmark 1000 events/minute

---

## 4. Verification Plan

### Layer-by-Layer Verification

**Git Hooks**:
- Make 10 commits → Verify 10 MLS events
- Switch branches 3 times → Verify 3 MLS events
- Merge branch → Verify 1 MLS event

**Agent Protocol**:
- Run QA Worker → Verify MLS event with `type: solution|failure`
- Complete GMX task → Verify `session_state` events (start, end)
- Run Dev Worker → Verify MLS event

**File Watcher**:
- Save 5 files → Verify ≤ 5 MLS events (debouncing may merge)
- Save 20 files in 1 minute → Verify max 10 events (rate limit)
- Stop launchd agent → Verify no events

**Orchestrator**:
- (Pending GG/GC integration)

### Integration Verification

**End-to-End Flow**:
1. Make a commit → Git hook logs
2. Save a file → File watcher logs
3. Run QA Worker → Agent logs
4. Check `mls/ledger/$(date +%Y-%m-%d).jsonl` → All events present

**Data Quality**:
- All events have required fields
- No schema validation errors
- Confidence scores are appropriate
- Tags are consistent

---

## 5. Rollback Plan

### Git Hooks
- Delete `.git/hooks/post-commit`, `post-checkout`, `post-merge`
- No state to revert

### File Watcher
- `launchctl unload com.02luka.mls_watcher.plist`
- Delete `LaunchAgents/com.02luka.mls_watcher.plist`

### Agent Protocol
- Remove `mls_log()` calls from agent code
- Revert persona changes

### Orchestrator
- Disable `mls_event_sink.py` middleware

---

## 6. Deployment Checklist

**Pre-Deployment**:
- [ ] MLS ledger directory exists (`mls/ledger/`)
- [ ] `mls_add.zsh` is executable
- [ ] `fswatch` is installed (`brew install fswatch`)
- [ ] Git hooks directory is writable (`.git/hooks/`)

**Deployment Steps**:
1. Deploy Git Hooks (Phase 1)
2. Verify for 7 days
3. Deploy Agent Protocol (Phase 2)
4. Verify for 7 days
5. Deploy File Watcher (Phase 3)
6. Monitor resource usage for 7 days
7. Deploy Orchestrator (Phase 4)
8. Full system validation (Phase 5)

**Post-Deployment**:
- [ ] Monitor `g/logs/mls_*_errors.log` daily
- [ ] Check MLS event rate (should be 50-200/day)
- [ ] Verify schema validation passes
- [ ] Measure storage growth (< 10MB/day)

---

## 7. Files to Create

| File | Purpose | Owner |
|------|---------|-------|
| `.git/hooks/post-commit` | Git commit logging | GMX |
| `.git/hooks/post-checkout` | Branch switch logging | GMX |
| `.git/hooks/post-merge` | Merge logging | GMX |
| `g/tools/mls_log.py` | Agent logging function | GMX |
| `g/tools/mls_session.py` | Session state helper | GMX |
| `g/tools/mls_file_watcher.zsh` | File watcher daemon | GMX |
| `LaunchAgents/com.02luka.mls_watcher.plist` | Daemon config | GMX |
| `g/tools/install_mls_watcher.zsh` | Installer script | GMX |
| `g/tools/mls_event_sink.py` | Orchestrator middleware | GG |
| `manuals/MLS_TRIGGER_LAYER.md` | User guide | GMX |

---

## 8. Files to Modify

| File | Change | Reason |
|------|--------|--------|
| `agents/gmx/PERSONA_PROMPT.md` | Add MLS protocol | Agent compliance |
| `agents/qa_v4/qa_worker.py` | Add `mls_log()` call | Auto-logging |
| `agents/dev_oss/dev_worker.py` | Add `mls_log()` call | Auto-logging |
| `agents/rnd/rnd_worker.py` | Add `mls_log()` call | Auto-logging |
| `mls/schema/mls_event.schema.json` | Add `session_state` type | Schema extension |
| `mls/README.md` | Document trigger layer | User documentation |

---

## 9. Success Criteria

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| Event Capture | > 80% of operations | Manual audit |
| Zero Performance Impact | < 50ms latency | Benchmark tests |
| Agent Compliance | 100% | Code review |
| Schema Compliance | 100% | CI validation |
| Error Rate | < 0.1% | Log analysis |
| Storage Efficiency | < 10MB/day | Ledger growth |

---

## 10. Timeline

| Phase | Duration | Start | End | Deliverables |
|-------|----------|-------|-----|--------------|
| Phase 1: Git Hooks | 1 week | Week 1 | Week 1 | 3 hooks, tests, docs |
| Phase 2: Agent Protocol | 1 week | Week 2 | Week 2 | `mls_log.py`, agent updates |
| Phase 3: File Watcher | 1 week | Week 3 | Week 3 | Daemon, launchd config |
| Phase 4: Orchestrator | 1 week | Week 4 | Week 4 | Event sink, GG integration |
| Phase 5: Validation | 1 week | Week 5 | Week 5 | Schema, backfill, tuning |

**Total Duration**: 5 weeks

---

## 11. Risks & Dependencies

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Git hook breaks commit | Low | Critical | Silent failure, logging only |
| fswatch CPU spike | Medium | Medium | Rate limiting, targeted dirs |
| Agent non-compliance | Medium | High | Protocol enforcement, audits |
| GG/GC not ready | High | Medium | Defer Phase 4, proceed with 1-3 |
| Schema drift | Low | Medium | CI validation on every push |

**Critical Dependency**: GG/GC orchestrator architecture (for Phase 4)

---

## 12. Next Steps

**Immediate** (This Week):
1. Review this plan with Boss
2. Get approval on architecture
3. Clarify GG/GC integration points

**Week 1**:
1. Implement Git Hooks (Phase 1)
2. Test and verify
3. Deploy to production

**Week 2+**:
Follow the 5-week timeline.
