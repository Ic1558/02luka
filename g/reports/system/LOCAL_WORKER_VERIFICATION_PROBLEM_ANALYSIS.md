# Local Worker Verification - Problem Analysis & Solution

**Date:** 2025-11-16  
**Status:** SPEC Ready for Implementation

---

## The Real Problem

> "Root problem is we never verify that local worker > never verify or prove that it is working. Many local LaunchAgent, plist we do create new > don't know what is the update and really use."

**You identified it correctly:**

The system has a **Truth Problem**, not just a RAM problem.

---

## Current State (Broken)

### What We Have:
- ✅ LaunchAgents deployed
- ✅ Scripts that should run
- ✅ Documentation mentioning workers

### What We DON'T Have:
- ❌ Single source of truth: "These are the workers that exist"
- ❌ Proof: "This worker did real work in the last N hours"
- ❌ Verification: "This LaunchAgent's script actually exists"
- ❌ Enforcement: "Broken workers get disabled automatically"

### Result:
- LaunchAgents reference deleted scripts → infinite crash loops
- RAM consumed by "ghost workers" that never produce value
- Manual detective work to answer "which workers actually work?"
- Cleanup report (17 Nov) was manual, not system behavior

---

## The Fix: Local Worker Verification Protocol v1

**Not more agents. Not more plists.**

**One strict layer that answers:**
> "Show me all workers, and prove each one is real and doing something. If you can't prove it → disable it."

---

## Solution Components

### 1. Single Source of Truth: `WORKER_REGISTRY.yaml`

**Location:** `/Users/icmini/02luka/g/docs/WORKER_REGISTRY.yaml`

**What it contains:**
- Every worker's ID, entrypoint, LaunchAgent labels
- Health check command (how to test it)
- Verification level (L0-L3)
- Last success timestamp (proof of work)

**Rule:** No worker is "real" until it has a row in WORKER_REGISTRY.

---

### 2. Verification Levels

**L0 – Declared Only**
- In registry, never tested
- **Cannot have active LaunchAgent**

**L1 – Exists**
- Entrypoint file exists
- **LaunchAgent must be disabled**

**L2 – Launchable**
- Health check passes
- **LaunchAgent allowed to be active**

**L3 – Producing Value**
- L2 + evidence of real work (logs, Redis, WO, dashboard)
- **Fully verified, active LaunchAgent OK**

**Enforcement:** Only L2/L3 workers may have active LaunchAgents.

---

### 3. LaunchAgent Sanity: "Prove or Disable"

**Contract:**
1. Every LaunchAgent must reference a worker in WORKER_REGISTRY
2. Before enabling:
   - Verify entrypoint exists
   - Run health check
   - If fails → refuse to load, mark invalid

**Result:** Missing scripts (like `local_api_02luka.py`, `agent_watchdog.py`, `backup_to_gdrive.zsh`) would never be allowed to run as LaunchAgents.

---

### 4. CLI: `workerctl`

**Commands:**
```bash
workerctl list              # Show all workers with status
workerctl verify <id>       # Verify single worker
workerctl verify --all      # Verify all workers
workerctl scan-launchagents # Match plists vs registry
workerctl prune --dry-run   # Show what would be disabled
workerctl prune --force     # Actually disable invalid
```

**Output:**
```
ID              STATUS    LEVEL  LAST_SUCCESS          LAUNCHAGENT
local.api       OK        L2     2025-11-16 10:30:00   com.02luka.local.api ✅
backup_gdrive   BROKEN    L1     2025-11-15 08:00:00   com.02luka.backup.gdrive ❌
watchdog        ORPHAN    L0     -                     com.02luka.watchdog ⚠️
```

---

## What This Fixes

### Before:
- ❌ "Which workers are actually doing useful work today?" → Manual detective work
- ❌ Script deleted → LaunchAgent unchanged → infinite crash loops
- ❌ RAM consumed by ghost workers
- ❌ No automated verification

### After:
- ✅ `workerctl list` → instant answer
- ✅ Script deleted → LaunchAgent disabled automatically
- ✅ Only verified workers consume resources
- ✅ Automated verification runs daily

---

## Implementation Path

**For Liam/CLC:**

1. **Create `WORKER_REGISTRY.yaml`**
   - Start from `launchagents_cleanup.log` + existing plist scan
   - One row per known worker

2. **Implement `workerctl` CLI**
   - Read registry
   - Run health checks
   - Match LaunchAgents vs registry
   - Disable invalid LaunchAgents

3. **Enforce "Prove or Disable"**
   - L0/L1 workers → disable LaunchAgents
   - L2/L3 workers → allow active LaunchAgents

4. **Automate Verification**
   - Daily `workerctl verify --all`
   - Auto-disable broken workers
   - Generate reports

---

## Success Criteria

✅ Single source of truth exists (`WORKER_REGISTRY.yaml`)  
✅ All known workers have registry entries  
✅ `workerctl list` shows accurate status  
✅ LaunchAgents match registry (no orphans)  
✅ L0/L1 workers have disabled LaunchAgents  
✅ L2/L3 workers have active LaunchAgents  
✅ Periodic verification runs automatically  

---

## Next Step

**SPEC Created:** `g/reports/feature_local_worker_verification_SPEC.md`

**Ready for:** Liam → CLC implementation

**Key Files:**
- `g/docs/WORKER_REGISTRY.yaml` (to be created)
- `tools/workerctl.zsh` (to be created)
- `g/reports/worker_verification_YYYYMMDD.md` (generated)

---

**This is the missing proof layer you never had.**

**From here, RAM issues, crash loops, and "ghost workers" will drop sharply because anything that doesn't have a proof-path cannot stay enabled.**

---

**Status:** ✅ SPEC Complete - Ready for Implementation
