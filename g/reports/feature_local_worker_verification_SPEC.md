# Local Worker Verification Protocol v1

**Status:** SPEC  
**Date:** 2025-11-16  
**Owner:** CLC (governance-level enforcement)  
**Implementer:** Liam → CLC

---

## Problem Statement

**Root Cause:** No single source of truth for worker existence, health, or proof of work.

**Symptoms:**
- LaunchAgents reference deleted/moved scripts → infinite crash loops
- RAM consumed by "ghost workers" that never produce value
- Manual detective work required to answer "which workers actually work?"
- No automated verification that workers do real work

**Impact:** System accumulates broken workers, wasted resources, and untrustworthy state.

---

## Solution: Worker Registry + Verification Levels

### 1. Single Source of Truth: `WORKER_REGISTRY.yaml`

**Location:** `/Users/icmini/02luka/g/docs/WORKER_REGISTRY.yaml`

**Format:**
```yaml
workers:
  - id: local.api
    type: launchagent
    criticality: critical
    entrypoint: /Users/icmini/02luka/tools/local_api_02luka.sh
    launchagent_labels:
      - com.02luka.local.api
    health_check:
      command: /Users/icmini/02luka/tools/local_api_02luka.sh --selftest
      expected: exit_code=0, output_contains="OK"
      timeout_sec: 10
    evidence:
      last_verified: null
      last_success: null
      verification_level: L0

  - id: backup_to_gdrive
    type: launchagent
    criticality: normal
    entrypoint: /Users/icmini/02luka/tools/backup_to_gdrive.zsh
    launchagent_labels:
      - com.02luka.backup.gdrive
    health_check:
      command: /Users/icmini/02luka/tools/backup_to_gdrive.zsh --health
      expected: exit_code=0
      timeout_sec: 30
    evidence:
      last_verified: null
      last_success: null
      verification_level: L0

  - id: mls_cursor_watcher
    type: launchagent
    criticality: normal
    entrypoint: /Users/icmini/02luka/tools/mls_capture.zsh
    launchagent_labels:
      - com.02luka.mls.cursor
    health_check:
      command: test -f /Users/icmini/02luka/tools/mls_capture.zsh && /Users/icmini/02luka/tools/mls_capture.zsh --test
      expected: exit_code=0
      timeout_sec: 5
    evidence:
      last_verified: null
      last_success: null
      verification_level: L0
```

**Fields:**
- `id`: Unique worker identifier (e.g., `local.api`, `backup_to_gdrive`)
- `type`: `launchagent` | `cli` | `service` | `cron-like`
- `criticality`: `critical` | `normal` | `optional`
- `entrypoint`: Absolute path to executable script/binary
- `launchagent_labels`: Array of LaunchAgent plist labels (e.g., `com.02luka.*`)
- `health_check.command`: Command to verify worker health
- `health_check.expected`: `exit_code=0` and/or `output_contains="text"`
- `health_check.timeout_sec`: Max seconds for health check
- `evidence.*`: Runtime data (updated by verification tool)

---

### 2. Verification Levels

**L0 – Declared Only**
- Exists in registry
- Files may or may not exist
- Never tested
- **Action:** Cannot have active LaunchAgent

**L1 – Exists**
- Entrypoint path exists
- File is executable
- **Action:** Can exist but LaunchAgent must be disabled until L2+

**L2 – Launchable**
- Entrypoint exists
- Health check command runs and exits 0
- Self-test passes
- **Action:** LaunchAgent allowed to be active

**L3 – Producing Value**
- L2 + evidence of real work in last N hours/days:
  - Wrote log line
  - Produced Redis event
  - Processed WO
  - Updated dashboard metric
- **Action:** Fully verified, active LaunchAgent OK

**Enforcement Rule:**
- Only L2/L3 workers may have active LaunchAgents
- L0/L1 = must be disabled or in "lab" zone

---

### 3. LaunchAgent Sanity: "Prove or Disable"

**Contract:**
1. Every LaunchAgent plist must reference a worker in `WORKER_REGISTRY.yaml`
2. Before enabling a new plist:
   - Verify entrypoint exists
   - Run `--selftest` or health check
   - If fails → refuse to load, mark as invalid

**Validation:**
- Scan `~/Library/LaunchAgents/com.02luka.*.plist`
- Extract `ProgramArguments[0]` (entrypoint)
- Match against registry `entrypoint` field
- If no match → mark as "ORPHAN"
- If match but L0/L1 → mark as "INVALID (not verified)"
- If match and L2/L3 → mark as "VALID"

---

### 4. CLI: `workerctl`

**Location:** `/Users/icmini/02luka/tools/workerctl.zsh`

**Commands:**

```bash
# List all workers with status
workerctl list

# Verify single worker (run health check, update evidence)
workerctl verify <worker-id>

# Verify all workers
workerctl verify --all

# Scan LaunchAgents and match against registry
workerctl scan-launchagents

# Show what would be disabled (dry-run)
workerctl prune --dry-run

# Actually disable invalid LaunchAgents
workerctl prune --force
```

**Output Format:**
```
ID              STATUS    LEVEL  LAST_SUCCESS          LAUNCHAGENT
local.api       OK        L2     2025-11-16 10:30:00   com.02luka.local.api ✅
backup_gdrive   BROKEN    L1     2025-11-15 08:00:00   com.02luka.backup.gdrive ❌
mls_cursor      OK        L3     2025-11-16 11:00:00   com.02luka.mls.cursor ✅
watchdog        ORPHAN    L0     -                     com.02luka.watchdog ⚠️
```

---

### 5. Evidence Collection

**For L3 (Producing Value), check:**
- Log files: `grep -l "worker-id" ~/02luka/logs/*.log | head -1`
- Redis events: `redis-cli --scan --pattern "*worker-id*" | head -1`
- WO processing: `grep -l "worker-id" ~/02luka/g/reports/wo/*.md | head -1`
- Dashboard metrics: Check dashboard API for worker activity

**Update `evidence.last_success` with timestamp of most recent proof.**

---

### 6. Governance Rules

**Rule 1: No Worker Without Registry**
- New worker = must add row to `WORKER_REGISTRY.yaml` first
- No LaunchAgent may point to entrypoint not in registry

**Rule 2: Prove or Disable**
- L0/L1 workers cannot have active LaunchAgents
- `workerctl prune` will disable LaunchAgents for L0/L1 workers

**Rule 3: Periodic Verification**
- Run `workerctl verify --all` daily/weekly
- Update evidence levels
- Generate report: `g/reports/worker_verification_YYYYMMDD.md`

**Rule 4: Registry Maintenance**
- CLC maintains `WORKER_REGISTRY.yaml` (governance file)
- Liam/Andy can propose additions via PR
- CLC approves and merges

---

### 7. Migration Path

**Phase 1: Discovery**
1. Scan existing LaunchAgents: `find ~/Library/LaunchAgents -name "com.02luka.*.plist"`
2. Extract entrypoints from plists
3. Create initial `WORKER_REGISTRY.yaml` with all known workers
4. Mark all as L0 initially

**Phase 2: Verification**
1. Implement `workerctl verify --all`
2. Run verification, update evidence levels
3. Generate report of current state

**Phase 3: Enforcement**
1. Implement `workerctl prune --dry-run`
2. Review what would be disabled
3. Fix broken workers or disable LaunchAgents
4. Enable "Prove or Disable" policy

**Phase 4: Automation**
1. Add `workerctl verify --all` to daily cron/LaunchAgent
2. Auto-disable LaunchAgents for workers that drop to L0/L1
3. Alert on critical workers dropping below L2

---

### 8. Success Criteria

✅ Single source of truth: `WORKER_REGISTRY.yaml` exists  
✅ All known workers have registry entries  
✅ `workerctl list` shows accurate status  
✅ `workerctl verify --all` runs successfully  
✅ LaunchAgents match registry (no orphans)  
✅ L0/L1 workers have disabled LaunchAgents  
✅ L2/L3 workers have active LaunchAgents  
✅ Periodic verification runs automatically  

---

## Implementation Notes

**For Liam/CLC:**
1. Start with `launchagents_cleanup.log` + existing plist scan
2. Create initial `WORKER_REGISTRY.yaml` with all known workers
3. Implement `workerctl` CLI skeleton (read registry, run health checks)
4. Add `scan-launchagents` to match plists vs registry
5. Add `prune` to disable invalid LaunchAgents
6. Document in system manuals

**Dependencies:**
- YAML parser (Python `yaml` or `yq` for shell)
- LaunchAgent plist parser (`plutil` or `defaults read`)
- Health check execution (timeout support)

**Files to Create:**
- `g/docs/WORKER_REGISTRY.yaml`
- `tools/workerctl.zsh`
- `g/reports/worker_verification_YYYYMMDD.md` (generated)

---

**End of SPEC**
