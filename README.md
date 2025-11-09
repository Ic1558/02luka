# 02luka Automation Console

![CLS CI](https://github.com/Ic1558/02luka/actions/workflows/cls-ci.yml/badge.svg)

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
