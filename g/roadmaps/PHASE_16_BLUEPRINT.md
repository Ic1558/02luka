# Phase 16 — Continuous CI Reliability Ops
## Blueprint: Local Infra + Redis + Multi-agent Ops

**Status:** Ready to start  
**Prerequisites:** Phase 1-15 complete, CI Automation Suite operational  
**Goal:** Extend CI automation to multi-agent coordination via Redis

---

## 🎯 Phase 16 Goals

1. **Redis Integration** — Centralized queue for CI operations
2. **Multi-agent Coordination** — CLS, Paula, and CI Watcher work together
3. **Event-driven Architecture** — Agents react to CI events
4. **Backward Compatible** — Existing CI Watcher continues to work

---

## 📊 Current State (Pre-Phase 16)

### ✅ What We Have

| Component | Status | Notes |
|-----------|--------|-------|
| CI Reliability Pack | ✅ Merged (PR #201) | Quiet-by-default strategy |
| Opt-in Smoke Gating | ✅ Ready | `[run-smoke]` / label trigger |
| Puppeteer Automation | ✅ Functional | Browser automation for GitHub |
| CI Workflow Guards | ✅ Active | `SKIP_BOSS_API`, `CI_QUIET` |
| CI Watcher + LaunchAgent | ✅ Running | Auto rerun + backoff + macOS notify |
| Config System | ✅ Added | `tools/ci_watcher_config.zsh` |
| Dispatch Shortcuts | ✅ Added | `ci:watch`, `ci:optin`, `ci:merge` |

---

## 🚀 Phase 16 Architecture

### Target Architecture (Post-Phase 16)

```
┌─────────────────────────────────────────────────────────┐
│                    Local Machine                         │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Redis Server (127.0.0.1:6379)                  │    │
│  │  - Channels: ci:events, ci:commands, ci:status │    │
│  │  - Queues: ci:rerun, ci:notify, ci:label        │    │
│  └─────────────────────────────────────────────────┘    │
│                          │                               │
│                          ▼                               │
│  ┌─────────────────────────────────────────────────┐    │
│  │  CI Watcher Agent (ci_watcher.sh)                 │    │
│  │  - Publishes: ci:events (PR failures)            │    │
│  │  - Subscribes: ci:commands (rerun requests)      │    │
│  │  - Mode: Standalone (current) OR Redis-backed     │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  CLS Agent (CLS_agent_latest.md)                 │    │
│  │  - Subscribes: ci:events                          │    │
│  │  - Publishes: ci:commands (orchestration)         │    │
│  │  - Can trigger: ci:rerun, ci:label, ci:merge     │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │  CI Coordinator (ci_coordinator.zsh)             │    │
│  │  - Central dispatcher for CI operations          │    │
│  │  - Handles: rerun, label, merge, notify          │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Plan

### Step 1: Redis Channel Design

**Channels:**
- `ci:events` — PR status changes (failure, success, pending)
- `ci:commands` — Commands to execute (rerun, label, merge)
- `ci:status` — Agent status updates

**Message Format:**
```json
{
  "type": "pr_failure",
  "pr_number": 197,
  "pr_title": "Implement Phase 15 Router Core",
  "pr_url": "https://github.com/Ic1558/02luka/pull/197",
  "failing_checks": ["validate", "ops-gate"],
  "timestamp": "2025-11-07T03:30:00Z",
  "source": "ci_watcher"
}
```

### Step 2: CI Watcher Redis Integration

**Changes to `ci_watcher.sh`:**
- Add Redis publish on PR failure detection
- Add Redis subscribe for commands (optional, backward compatible)
- Keep standalone mode as default (no breaking changes)

**New Mode:**
```bash
# Standalone mode (current, default)
./tools/ci_watcher.sh

# Redis-backed mode (new)
REDIS_ENABLED=1 ./tools/ci_watcher.sh
```

### Step 3: CI Coordinator

**New Script: `tools/ci_coordinator.zsh`**
- Subscribes to `ci:events`
- Dispatches commands to appropriate handlers
- Coordinates multi-agent operations

### Step 4: CLS Integration

**CLS Agent Enhancement:**
- Subscribe to `ci:events`
- Analyze PR failures
- Publish orchestration commands
- Respect governance rules (AI/OP-001 Rule 91-93)

---

## ✅ Backward Compatibility

**All changes are backward compatible:**

1. **CI Watcher** — Standalone mode remains default
2. **LaunchAgent** — No changes required
3. **Dispatch Shortcuts** — Enhanced, not replaced

---

## 🎯 Success Criteria

- [ ] Redis channels operational
- [ ] CI Watcher can publish to Redis (optional mode)
- [ ] CI Coordinator can subscribe and dispatch
- [ ] CLS can orchestrate CI operations
- [ ] All existing functionality preserved
- [ ] Zero breaking changes

---

**Status:** Ready for implementation  
**Estimated Time:** 2-3 hours for full Phase 16  
**Risk Level:** Low (backward compatible, incremental)
