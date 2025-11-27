# CLC GMX Orchestrator Specification v1.1

**WO-ID:** `WO-CLC-GMX-ORCH-SPEC-V1` → Updated via `WO-PATCH-CLC-ORCH-SPEC-ENV`  
**Title:** GMX-based CLC Orchestrator - Sensing Mode  
**Owner:** CLC  
**Status:** Implemented (v1.1 – Sensing Mode)  
**Last Updated:** 2025-11-27T21:00:00+07:00

## 1. Overview

This document specifies the architecture for a "GMX-based CLC Orchestrator". The goal is to evolve the CLC (Code & Logic Companion) from a passive executor into a proactive agent capable of self-initiating tasks, mirroring the behavior of a "Claude Desktop sidecar".

This is achieved by introducing a role split:
- **GMX (Gemini CLI):** The **Planner/Brain**. It receives system context, reasons about it, and produces structured Work Orders (WOs). All complex reasoning, planning, and chain-of-thought processes are centralized here.
- **CLC Worker:** The **Executor/Hands**. It operates deterministically, executing the `ops` within a WO safely and idempotently without performing its own complex reasoning.

The orchestrator is implemented as a periodic, `launchd`-driven script that creates a "sense-plan-act" loop, enabling the system to self-initiate work without direct, per-task user commands.

### Current Mode: v1.1 Sensing Mode

**Important:** The orchestrator currently operates in **sensing-only mode**:
- ✅ Gathers system context (health checks, ACKs, session states)
- ✅ Calls GMX CLI for planning (or uses mock when unavailable)
- ✅ Parses GMX output into candidate WOs via `gmx_clc_parse_plan.py`
- ✅ Logs all activity for observability
- ❌ **Does NOT create WO files in `bridge/inbox/CLC/`**

This ensures stability while the integration matures.

## 2. Data Flow

The core orchestration loop follows this data flow:

```
┌─────────────────────────────────────────────────────────────────┐
│                    GMX CLC Orchestrator v1.1                    │
│                       (Sensing Mode)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │ Health  │          │  ACKs   │          │Sessions │
   │  JSON   │          │  JSON   │          │  YAML   │
   └────┬────┘          └────┬────┘          └────┬────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             ▼
                    ┌────────────────┐
                    │ Context Bundle │
                    │   (temp file)  │
                    └───────┬────────┘
                            ▼
                    ┌────────────────┐
                    │   GMX CLI      │
                    │ (or mock plan) │
                    └───────┬────────┘
                            ▼
                    ┌────────────────┐
                    │ Plan JSON      │
                    │ (temp file)    │
                    └───────┬────────┘
                            ▼
                    ┌────────────────┐
                    │ gmx_clc_parse_ │
                    │ plan.py        │
                    │ (dry-run)      │
                    └───────┬────────┘
                            ▼
                    ┌────────────────┐
                    │ Candidate WOs  │
                    │ (logged only)  │
                    └────────────────┘
                            │
                            ▼
                    ┌────────────────┐
                    │ Log + Summary  │
                    │ WOs_Created=0  │
                    └────────────────┘
```

### Detailed Steps:

1. **Sense:** The `gmx_clc_orchestrator.zsh` script, running every 5 minutes via LaunchAgent, gathers context from:
   - `g/telemetry/health_check_latest.json` (System health)
   - `bridge/outbox/LIAM/*.ack.json` (Recent CLC Worker results)
   - `state/clc_sessions/*.yaml` (Long-running task states)

2. **Plan:** The collected context is sent to **GMX CLI** with the `clc-orchestrator` profile. If GMX is unavailable, a mock empty plan is used.

3. **Parse:** The `gmx_clc_parse_plan.py` script validates the GMX output against the plan schema and extracts candidate WOs.

4. **Log (Sensing Mode):** In v1.1, the orchestrator **logs the candidates but does NOT create WO files**. The SUMMARY line shows `WOs_Created=0`.

## 3. Directory Layout

```
02luka/
├── g/
│   ├── tools/
│   │   ├── gmx_clc_orchestrator.zsh      # Main orchestrator script
│   │   ├── gmx_clc_parse_plan.py         # Plan parser (dry-run only)
│   │   └── samples/                       # Sample plan files
│   │       ├── gmx_plan_idle.json
│   │       ├── gmx_plan_single_task.json
│   │       └── gmx_plan_multi_task.json
│   ├── docs/
│   │   ├── CLC_GMX_ORCHESTRATOR_SPEC_v1.md  # This document
│   │   └── GMX_PLAN_SCHEMA_v1.md            # Plan schema (planned)
│   ├── telemetry/
│   │   ├── health_check_latest.json      # Health check output
│   │   └── gmx_clc_orch.jsonl            # Orchestrator telemetry
│   └── knowledge/clc/
│       └── README.md                      # CLC memory zone
├── state/clc_sessions/
│   └── SESSION-*.yaml                     # Session state files
├── logs/
│   ├── gmx_clc_orchestrator.log          # Main log
│   ├── gmx_clc_orchestrator.stdout.log   # LaunchAgent stdout
│   ├── gmx_clc_orchestrator.stderr.log   # LaunchAgent stderr
│   └── gmx_clc_parse_plan.log            # Parser log
└── LaunchAgents/
    └── com.02luka.gmx-clc-orchestrator.plist
```

## 4. GMX Plan Schema v1

The GMX orchestrator expects plans in the following JSON format:

```json
{
  "timestamp": "2025-11-27T20:00:00Z",
  "source": "gmx_clc_orchestrator",
  "context_summary": "Brief description of system state",
  "items": [
    {
      "type": "clc_task | health_fix | telemetry | noop | info",
      "priority": "low | medium | high",
      "target": "opal_api | clc_worker | bridge_inbox | ...",
      "action": "create_wo | log | noop | alert",
      "wo_suggestion": {
        "wo_id_hint": "FIX-OPAL-API",
        "title": "Human-readable title",
        "summary": "What this WO will accomplish",
        "tasks": [
          "Step 1: ...",
          "Step 2: ..."
        ]
      }
    }
  ]
}
```

### Valid Values:

| Field | Values |
|-------|--------|
| `type` | `clc_task`, `health_fix`, `telemetry`, `noop`, `info` |
| `priority` | `low`, `medium`, `high` |
| `action` | `create_wo`, `log`, `noop`, `alert` |

### Sample Plans:

Located in `g/tools/samples/`:
- `gmx_plan_idle.json` - No action needed
- `gmx_plan_single_task.json` - One WO candidate
- `gmx_plan_multi_task.json` - Multiple candidates + skipped items

## 5. Security & Governance

This system operates under the existing `AI:OP-001` Governance framework.

- **Safe Zones:** The orchestrator and CLC Worker are restricted to writing only within designated safe zones (e.g., `g/tools`, `g/docs`, `bridge/`, `logs/`, `state/`).
- **Forbidden Zones:** Direct modification of core agent definitions in `CLC/` and `CLS/` is strictly prohibited.
- **Idempotency:** All generated scripts and file operations (`ops`) should strive to be idempotent.
- **Atomic Operations:** When WO creation is enabled (future), WOs will be delivered to the inbox using an atomic `mv` operation.

### v1.1 Safety Guardrails:

1. **`GMX_ORCH_MODE=sensing`** - Environment variable enforces read-only behavior
2. **Parser dry-run flag** - `gmx_clc_parse_plan.py` always runs in dry-run mode
3. **No inbox writes** - Code paths that write to `bridge/inbox/CLC/` are disabled
4. **Observability first** - All activity logged before any action considered

## 6. Implementation Status (v1.1 – Sensing Mode)

### Current Capabilities:

| Feature | Status | Notes |
|---------|--------|-------|
| Context gathering | ✅ | Health JSON, ACKs, Sessions |
| GMX CLI integration | ✅ | Falls back to mock if unavailable |
| Plan parsing | ✅ | `gmx_clc_parse_plan.py` validates schema |
| Candidate extraction | ✅ | Builds WO structures in memory |
| Structured logging | ✅ | JSONL telemetry + summary line |
| LaunchAgent | ✅ | Runs every 5 minutes |
| Sample plans | ✅ | 3 samples for testing |

### Key Limitations (Sensing Mode):

| Limitation | Reason |
|------------|--------|
| No WO file creation | Safety - sensing mode only |
| No automated execution | Plans are logged, not acted upon |
| No feedback loop | Results don't feed into next cycle |
| GMX CLI optional | Mock fallback when unavailable |

### Why Sensing Mode?

1. **Safety:** Prevents unintended automated actions while integration matures
2. **Observability:** Allows monitoring of GMX planning quality and system behavior
3. **Iterative Rollout:** Enables gradual activation of automation features
4. **Trust Building:** Demonstrates reliability before enabling autonomous actions

## 7. Verification Plan (v1.1 – Sensing Mode)

### Prerequisites:

- LaunchAgent installed: `~/Library/LaunchAgents/com.02luka.gmx-clc-orchestrator.plist`
- `GMX_ORCH_MODE=sensing` set in plist
- Parser available: `g/tools/gmx_clc_parse_plan.py`

### Verification Steps:

```bash
# 1. Check LaunchAgent status
launchctl list | grep gmx-clc-orchestrator
# Expected: PID (number), 0, com.02luka.gmx-clc-orchestrator

# 2. Run orchestrator manually
cd ~/02luka
zsh g/tools/gmx_clc_orchestrator.zsh

# 3. Check log for SUMMARY line
grep "SUMMARY" logs/gmx_clc_orchestrator.log | tail -1
# Expected: ... GMX_Call_Status=OK, WOs_Created=0, WO_IDs=[]

# 4. Test parser with samples
python g/tools/gmx_clc_parse_plan.py --input g/tools/samples/gmx_plan_idle.json
# Expected: candidate_count: 0

python g/tools/gmx_clc_parse_plan.py --input g/tools/samples/gmx_plan_single_task.json
# Expected: candidate_count: 1

python g/tools/gmx_clc_parse_plan.py --input g/tools/samples/gmx_plan_multi_task.json
# Expected: candidate_count: 2, skipped: 2

# 5. CRITICAL: Verify NO new WOs created
ls -la bridge/inbox/CLC/*.yaml 2>/dev/null | wc -l
# Expected: 0 (or only pre-existing files)

# 6. Check environment variable
grep GMX_ORCH_MODE ~/Library/LaunchAgents/com.02luka.gmx-clc-orchestrator.plist
# Expected: <string>sensing</string>
```

### Success Criteria:

- ✅ LaunchAgent loads and runs without errors
- ✅ Script executes every 5 minutes (or on manual trigger)
- ✅ GMX is called (or gracefully falls back to mock)
- ✅ Parser validates plans correctly
- ✅ **ZERO new WO files created in `bridge/inbox/CLC/`**
- ✅ SUMMARY line shows `WOs_Created=0`
- ✅ Telemetry logged to `g/telemetry/gmx_clc_orch.jsonl`

## 8. LaunchAgent Configuration

**File:** `LaunchAgents/com.02luka.gmx-clc-orchestrator.plist`

| Setting | Value |
|---------|-------|
| Label | `com.02luka.gmx-clc-orchestrator` |
| Program | `/bin/zsh` |
| Script | `/Users/icmini/02luka/g/tools/gmx_clc_orchestrator.zsh` |
| WorkingDirectory | `/Users/icmini/02luka` |
| StartInterval | 300 (5 minutes) |
| RunAtLoad | true |
| ThrottleInterval | 5 |

**Environment Variables:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `PATH` | `.venv/bin:/usr/local/bin:...` | Include venv for Python |
| `PYTHONPATH` | `/Users/icmini/02luka` | Module imports |
| `GMX_ORCH_MODE` | `sensing` | **Enforce read-only mode** |

**Log Paths:**

| Log | Path |
|-----|------|
| stdout | `logs/gmx_clc_orchestrator.stdout.log` |
| stderr | `logs/gmx_clc_orchestrator.stderr.log` |
| Main | `logs/gmx_clc_orchestrator.log` |

## 9. Implementation Artifacts

| File | Purpose |
|------|---------|
| `g/tools/gmx_clc_orchestrator.zsh` | Main orchestrator script |
| `g/tools/gmx_clc_parse_plan.py` | Plan parser (dry-run only) |
| `g/tools/samples/gmx_plan_*.json` | Sample plan files |
| `LaunchAgents/com.02luka.gmx-clc-orchestrator.plist` | LaunchAgent config |
| `g/docs/CLC_GMX_ORCHESTRATOR_SPEC_v1.md` | This specification |
| `state/clc_sessions/SESSION-DEMO-001.yaml` | Example session state |
| `g/knowledge/clc/README.md` | CLC memory zone definition |

## 10. Roadmap to Full Automation

| Phase | Mode | WO Creation | Parser | Status |
|-------|------|-------------|--------|--------|
| v1.0 | Skeleton | ❌ | ❌ | Completed |
| **v1.1** | **Sensing** | **❌** | **✅ (dry-run)** | **Current** |
| v1.2 | Dry-run+ | Logged to file | ✅ | Planned |
| v2.0 | Supervised | ✅ (with approval) | ✅ | Future |
| v3.0 | Autonomous | ✅ (fully automated) | ✅ | Future |

### v1.2 Preview:

- Parser outputs candidate WOs to `g/reports/wo_candidates/`
- Boss can review and approve via Opal UI
- Approved WOs manually moved to inbox

### v2.0 Preview:

- Approval workflow in Opal UI
- One-click WO deployment
- Rate limiting and quota enforcement

---

**Document Version:** 1.1  
**WO Reference:** WO-PATCH-CLC-ORCH-SPEC-ENV  
**Maintainer:** GC Orchestrator  
**Last Verified:** 2025-11-27
