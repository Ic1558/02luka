# Phase 17 — CI Observer (Redis → status files)

## What it does

- Subscribes Redis channels: `ci:events`, `ci:status`
- Writes rolling log → `g/reports/ci/observer.log`
- Maintains summary JSON → `g/reports/ci/observer_status.json`
  - `counts` per channel
  - `lastEvent` snapshot
  - `lastSeenAt` heartbeat

## Run locally

```bash
# ensure redis is up (or set LUKA_REDIS_URL)
brew services start redis
export LUKA_REDIS_URL=${LUKA_REDIS_URL:-redis://127.0.0.1:6379}

node tools/ci_observer.cjs
```

## LaunchAgent (optional)

1. Copy the sample to `~/Library/LaunchAgents/com.02luka.ci-observer.plist`
2. `launchctl load ~/Library/LaunchAgents/com.02luka.ci-observer.plist`

## Files

- `tools/ci_observer.cjs`
- `g/launchagents/com.02luka.ci-observer.plist.sample`
- Outputs at `g/reports/ci/observer_*`
