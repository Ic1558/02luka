# 2025-02-14 Fincept Bridge Installation Report

## Overview
- Deployed Python bridge module at `/Users/icmini/02luka/g/modules/fincept_bridge.py`.
- Created LaunchAgent `~/Library/LaunchAgents/com.02luka.fincept.bridge.plist` for auto-start.
- Logging configured under `~/Library/Logs/02luka/` with rotation and stdout/stderr capture.

## HD2 Structure
- Ensured HD2 root auto-detection (`/Volumes/HD2` fallback `~/HD2`).
- Created/validated directories:
  - `trading/fincept/{stocks,forex,crypto,commodities}/raw/`
  - `trading/fincept/exports/{signals,backtests}/`
  - `trading/paula/{signals,positions,reports,logs}/`

## Redis Integration
- Subscribes: `fincept:query`
- Publishes: `paula:signal`
- Heartbeat: `fincept:bridge:health` every 60s
- Retries: 3 attempts with exponential backoff on connection issues.

## Health & Testing
1. One-shot execution:
   ```bash
   /usr/bin/python3 /Users/icmini/02luka/g/modules/fincept_bridge.py --once
   ```
2. Daemon launch via LaunchAgent:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.fincept.bridge.plist 2>/dev/null || true
   launchctl load  ~/Library/LaunchAgents/com.02luka.fincept.bridge.plist
   launchctl list | grep com.02luka.fincept.bridge
   ```
3. Redis connectivity:
   ```bash
   redis-cli ping
   ```

## Notes
- Bridge safely handles shutdown signals (SIGINT/SIGTERM).
- Publish acknowledgements when processing `fincept:query` payloads.
