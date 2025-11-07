# CI Automation Runbook (Phase 16)

**Scope:** PR auto-rerun, auto-merge, and event-bus coordination.

## Quick Commands
- Enable watcher (every 5m): `./tools/dispatch_quick.zsh ci:watch:on`
- Manual rerun via browser: `./tools/dispatch_quick.zsh ci:rerun <PR#>`
- Rerun via bus: `./tools/dispatch_quick.zsh ci:bus:rerun <PR#>`
- Auto-merge (set & forget): `./tools/dispatch_quick.zsh auto:merge <PR#>`
- One-tap decision loop: `./tools/dispatch_quick.zsh auto:decision <PR#>`

## Required/Optional checks
- **Required:** Phase 4/5/6 smoke (local) → must pass for merge
- Optional: ops-gate, RAG, summary → non-blocking (quiet-by-default)

## Logs & Health
- Watcher logs: `~/02luka/logs/ci_watcher.log`
- Puppeteer logs: `tools/puppeteer/.logs/`
- Event bus: `redis-cli MONITOR` (if `LUKA_REDIS_URL` set)

## Troubleshooting
- Validate red → `./tools/dispatch_quick.zsh ci:rerun <PR#>`
- Stuck status → empty commit on PR branch:
  `git commit --allow-empty -m "chore(ci): retrigger" && git push`
- Coordinator restart:
  `launchctl unload ~/Library/LaunchAgents/com.02luka.ci-coordinator.plist && launchctl load ~/Library/LaunchAgents/com.02luka.ci-coordinator.plist`
