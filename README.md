> **LEGACY — superseded by [LukaOS](https://github.com/Ic1558/lukaos).**
> 0luka grew old and bloated, so it was replaced by LukaOS. This repository is kept as read-only historical evidence. Do not start new work here.

<!-- badges:start -->
[![Auto-Index OK](https://img.shields.io/badge/Auto--Index-OK-brightgreen)](./.github/workflows/auto-index.yml) [![Phase15 OK](https://img.shields.io/badge/Phase15-OK-brightgreen)](./.github/workflows/phase15-quick-health.yml)
<!-- badges:end -->

# 02luka Automation Console

![CLS CI](https://github.com/Ic1558/02luka/actions/workflows/cls-ci.yml/badge.svg)
![LaunchAgent Self-Recovery Check](https://github.com/Ic1558/02luka/actions/workflows/launchd-selfcheck.yml/badge.svg?branch=main)

## Dashboard Service
- LaunchAgent: `~/Library/LaunchAgents/com.02luka.dashboard.plist`
- Port: `4100` (ENV: HOST=127.0.0.1, PORT=4100)
- Health: `GET http://127.0.0.1:4100/health` → `ok`
- NLP intents: `deploy dashboard`, `andy status`, `แอนดี้ สถานะ`

## Local OpenRouter-Style UI
The repository now includes a console that mirrors OpenRouter’s model chooser and
function runner. To launch it locally or expose it on your own domain, follow
[`docs/LOCAL_CONSOLE.md`](docs/LOCAL_CONSOLE.md) for prerequisites, startup
commands, and reverse-proxy guidance.

Quick Ops:

---

## ⚙️ CI at a Glance

| Feature | Command | Description |
|----------|----------|-------------|
| 🔁 Re-run checks | `./tools/dispatch_quick.zsh ci:rerun <PR#>` | Manually trigger CI |
| 🧩 Event bus | `./tools/dispatch_quick.zsh ci:bus:rerun <PR#>` | Redis-based rerun |
| 🕒 Watcher | `./tools/dispatch_quick.zsh ci:watch:on` | Auto-reruns every 5 min |
| 🤖 Auto-merge | `./tools/dispatch_quick.zsh auto:merge <PR#>` | Merge when green |

> See full guide: `g/reports/ci/CI_AUTOMATION_RUNBOOK.md`

## 🤖 Phase15 Operations

**Autonomous Knowledge Router (AKR), Vector Search (FAISS/RAG), Health Monitoring**

| Feature | Details |
|---------|---------|
| 🏥 Daily Health | Runs at 08:15 ICT via `phase15-quick-health.yml` |
| 🛡️ Maintenance Mode | Set `MAINTENANCE_MODE=1` to pause daily health checks |
| 📊 SLO Targets | Routing ≥95% accuracy, <100ms latency, ≥90% delegation success |
| 📦 Artifacts | `g/reports/phase15/`, `hub/`, `g/telemetry_unified/` |

> See full guide: [`docs/PHASE15_OPERATIONS.md`](docs/PHASE15_OPERATIONS.md)

<!-- metrics:start -->

### Claude Code Metrics 202511

# Claude Code Metrics 202511
- Generated: 2025-11-11T17:42:16Z
- plan_mode_usage: (stub)
- hooks: pre_commit=OK quality_gate=OK verify_deployment=OK
- subagents_used: (stub)
- deployments_success_rate: (stub)
- rollback_frequency: (stub)
<!-- metrics:end -->

<!-- router:start -->
## WO Router + Dispatch (Phase 2.5–2.6)
- `/do` → ENTRY → Mary dispatcher → CLC (fallback shell)
- `/clc` → CLC inbox (ready for SIP patches)
- `/local` → shell inbox (Redis `shell` channel)
- Logs: `logs/wo_drop_history/history.log`
<!-- router:end -->
