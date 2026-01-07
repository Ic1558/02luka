# Raycast Scripts cheatsheet - /02luka/raycast/

## 📸 atg-snapshot.command
**Purpose**: Generate comprehensive system snapshot for debugging and AI context

**Information Provided**:
- **Git Context**:
  - Current branch and HEAD commit
  - Working tree status (`git status --porcelain`)
  - Last commit message
  - Diff stats from previous commit
  
- **Runtime Context**:
  - All Python/bridge/API server processes (PID, command line)
  - Port usage (from `ports_check.zsh`)
  
- **Telemetry Pulse**:
  - Last 50 lines of `g/telemetry/atg_runner.jsonl` (Gemini Bridge activity)
  - Last 50 lines of `g/telemetry/fs_index.jsonl` (File system changes)
  
- **System Logs**:
  - stderr/stdout logs from `fs_watcher` (`/tmp/com.02luka.fs_watcher.*.log`)
  - stderr/stdout logs from bridge (`/tmp/com.antigravity.bridge.*.log`)

**Output**: 
- Markdown file: `magic_bridge/inbox/atg_snapshot.md`
- Optional JSON: `magic_bridge/inbox/atg_snapshot.json`

**Usage**:
```bash
# MD format (default)
~/02luka/raycast/atg-snapshot.command

# JSON format
~/02luka/raycast/atg-snapshot.command json

# Both formats
~/02luka/raycast/atg-snapshot.command both
```

---

## 🌉 bridge-status.sh
**Purpose**: Quick control and status check for Gemini Bridge service

**Information Provided**:
- **For `status` command**:
  - LaunchAgent state and PID
  - pgrep results (actual running processes)
  - Health file data (PID, timestamp, last output file)
  - Three-way PID match verification (launchd ↔ pgrep ↔ health)

- **For `verify` command**:
  - Self-check results
  - Smoke test outcome (file processing verification)
  - Git hygiene check (spool artifacts tracking)

- **For `ops-status` command**:
  - Full ops report (same as ops-status.sh below)

**Commands Available**:
- `status` - Show current state
- `verify` - Run full verification suite
- `ops-status` - Generate ops report
- `start` - Start bridge via launchd
- `stop` - Stop bridge

**Default**: Shows `status` if no argument given

**Usage**:
```bash
~/02luka/raycast/bridge-status.sh [status|verify|ops-status|start|stop]
```

---

## ✅ ops-status.sh
**Purpose**: Generate operational status report with machine-readable exit codes

**Information Provided**:
- **Health**:
  - Bridge status (idle/running/error)
  - PID and uptime
  - Last heartbeat timestamp and staleness
  - Last error message (if any)

- **Verification**:
  - `bridgectl verify` result (PASS/FAIL)
  - Git status (CLEAN/DIRTY)
  - Verify command output

- **Telemetry** (best-effort):
  - Success vs Failure counts
  - Latency statistics (avg, p95 in milliseconds)

- **Spool**:
  - File counts in inbox/outbox/mock_brain
  - Largest file in each directory
  - Warnings if count > 200

- **Actions**:
  - Recommended next steps based on status

**Output**: 
- Markdown report: `g/reports/ops/ops_status.md`
- Console display

**Exit Codes**:
- `0` = ✅ Healthy (verify passed + git clean)
- `1` = ❌ Verify failed
- `2` = ❌ Git dirty
- `3` = ⚠️ Spool threshold exceeded

**Auto-refresh**: Every 5 minutes (Raycast metadata)

**Usage**:
```bash
~/02luka/raycast/ops-status.sh
```

---

## 🗑️ atg-snap.sh (Deprecated)
**Status**: Old wrapper - can be deleted
**Reason**: Replaced by `atg-snapshot.command`

---

## Quick Reference Table

| Script | Primary Info | Best For | Output Location |
|--------|-------------|----------|-----------------|
| **atg-snapshot.command** | Full system state (git, processes, logs, telemetry) | Deep debugging, AI context | `magic_bridge/inbox/` |
| **bridge-status.sh** | Bridge service status & controls | Quick health check, service management | Console |
| **ops-status.sh** | Operational metrics & health | Production monitoring, alerts | `g/reports/ops/` + Console |

---

## Raycast Hotkey Recommendations

- **Ctrl+A** → `atg-snapshot.command` (AI snapshot)
- **Ctrl+B** → `bridge-status.sh` (Bridge status)
- **Ctrl+O** → `ops-status.sh` (Ops report)

---

## Notes
- All scripts assume `~/02luka` as repo root
- Scripts are safe to run multiple times
- Exit codes can be used for automation/CI
- Telemetry files may not exist on fresh installs (reports "File not found" - this is normal)
