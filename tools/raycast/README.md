# Raycast Scripts for 02luka

Quick access scripts for Raycast to interact with the 02luka project.

## Installation

1. Open Raycast Settings → Extensions → Script Commands
2. Add this directory: `~/02luka/tools/raycast`
3. Raycast will automatically discover all scripts

## Available Scripts

### 🌉 Bridge Status (`bridge-status.sh`)
**Command**: `bridge-status [command]`

Quick access to Gemini Bridge controls:
- `status` - Show bridge PID, health, and three-way verification
- `verify` - Run smoke test + hygiene check
- `ops-status` - Full ops report (health, telemetry, spool)
- `start` - Start bridge via launchd
- `stop` - Stop bridge

**Usage in Raycast**: Type "bridge" → select command → optionally specify subcommand

### ✅ Ops Status (`ops-status.sh`)
**Command**: `ops-status`

Dedicated quick-access for ops reporting. Shows:
- Health (PID, uptime, heartbeat)
- Verification status
- Git cleanliness
- Telemetry (success/fail, latency avg/p95)
- Spool counts

Refreshes every 5 minutes automatically.

### 📸 ATG Snapshot (`atg-snap.sh`)
**Command**: `atg-snap [format]`

Generate Antigravity system snapshot:
- `md` (default) - Markdown format
- `json` - JSON format
- `both` - Both formats

Output goes to `magic_bridge/inbox/` for AI consumption.

## Quick Reference

| Raycast Command | What It Does |
|-----------------|-------------|
| `bridge-status` | Check bridge health |
| `ops-status` | Full ops report |
| `atg-snap` | System snapshot |

## Tips

- Scripts auto-cd to `~/02luka` before running
- All scripts are executable and follow Raycast schema v1
- Icons: 🌉 (bridge), ✅ (ops), 📸 (snapshot)
