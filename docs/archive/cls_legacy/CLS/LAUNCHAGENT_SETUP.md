# CLS LaunchAgent Setup - Complete

**Date:** 2025-10-30  
**Status:** ✅ OPERATIONAL

## What's Running

### CLS Agent Daemon (via LaunchAgent)
- **Service:** `com.02luka.cls-agent`
- **PID:** 41086
- **Script:** `~/tools/start_cls_agent.zsh`
- **Auto-start:** On login
- **Keep-alive:** Yes (restarts if crashes)

### Bridge Script (On-Demand CLI Tool)
- **Script:** `~/tools/bridge_cls_clc.zsh`
- **Mode:** One-shot (called by CLS in Cursor)
- **Usage:** `bridge_cls_clc.zsh --title "..." --body /path/to/payload.yaml`
- **Not daemonized** - runs only when CLS needs to drop a WO

## Architecture Clarification

```
┌─────────────────────────────────────────────────────────────┐
│ CLS Agent Daemon (LaunchAgent)                              │
│ • Runs 24/7                                                  │
│ • Heartbeat every 10s                                        │
│ • Redis health monitoring                                    │
│ • PID: ~/02luka/g/metrics/cls_agent.pid                     │
│ • Log: ~/02luka/g/logs/cls_agent.log                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CLS in Cursor                                                │
│ • Reads files                                                │
│ • Writes to safe zones (memory/cls, logs, telemetry)        │
│ • For SOT changes → calls bridge script                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Bridge Script (One-Shot)                                     │
│ • Called on-demand with args                                 │
│ • Builds WO with SHA256 evidence                             │
│ • Drops to CLC inbox                                         │
│ • Publishes Redis ACK                                        │
│ • Exits                                                       │
│ • Log: ~/02luka/g/logs/bridge_cls_clc.log                   │
└─────────────────────────────────────────────────────────────┘
```

## LaunchAgent Configuration

**Plist:** `~/Library/LaunchAgents/com.02luka.cls-agent.plist`

```xml
<key>Label</key><string>com.02luka.cls-agent</string>
<key>ProgramArguments</key>
<array>
  <string>/bin/zsh</string>
  <string>-lc</string>
  <string>exec ~/tools/start_cls_agent.zsh</string>
</array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
```

**Environment Variables Set:**
- `PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin`
- `REDIS_HOST=127.0.0.1`
- `REDIS_PORT=6379`
- `REDIS_PASSWORD=gggclukaic`

## Verification

### Check LaunchAgent Status
```bash
launchctl list | grep com.02luka.cls-agent
# Should show: 41086	0	com.02luka.cls-agent
```

### Check Agent Health
```bash
~/tools/check_cls_status.zsh
# Should show:
# - Process running
# - Heartbeat updating
# - Redis pings OK
# - PID file exists
```

### Check Logs
```bash
# Agent daemon log (main location)
tail -f ~/02luka/g/logs/cls_agent.log

# LaunchAgent logs (should be empty - agent redirects to its own log)
tail -f /tmp/cls_agent.launchd.out
tail -f /tmp/cls_agent.launchd.err
```

### Test Bridge Manually
```bash
# Bridge is NOT a daemon - test it directly
export REDIS_HOST=127.0.0.1 REDIS_PORT=6379 REDIS_PASS=gggclukaic
~/tools/bridge_cls_clc.zsh \
  --title "Manual Test" \
  --priority P3 \
  --tags "test" \
  --body /tmp/wo_test.yaml

# Check result
ls -lah ~/02luka/bridge/inbox/CLC/
tail ~/02luka/g/telemetry/cls_audit.jsonl | jq .
```

## Management Commands

### Start/Stop/Restart LaunchAgent
```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.02luka.cls-agent.plist

# Start
launchctl load ~/Library/LaunchAgents/com.02luka.cls-agent.plist

# Restart
launchctl unload ~/Library/LaunchAgents/com.02luka.cls-agent.plist
launchctl load ~/Library/LaunchAgents/com.02luka.cls-agent.plist
```

### Check Service Details
```bash
launchctl print gui/$(id -u)/com.02luka.cls-agent
```

### View Active Processes
```bash
ps aux | grep start_cls_agent.zsh
```

## What Fixed from Before

### 1. **PID File Now Works** ✅
- Before: PIDFILE showed "(missing)"
- After: PIDFILE shows actual PID (41086)
- Reason: LaunchAgent starts fresh process cleanly

### 2. **Auto-Start on Login** ✅
- Before: Manual `nohup` start needed
- After: Starts automatically via LaunchAgent
- Benefit: Survives reboots, crashes auto-recover

### 3. **Clean Process Management** ✅
- Before: Multiple zombie processes possible
- After: LaunchAgent ensures single instance
- Benefit: KeepAlive=true restarts if crashes

### 4. **Proper Environment** ✅
- Before: Environment differences between shells
- After: Explicit env vars in plist
- Benefit: Consistent Redis connectivity

## Current Status

```
Agent Process: PID 41086 (LaunchAgent-managed)
Heartbeat: iter:2+ (updating every 10s)
Redis: ✅ Connected to 127.0.0.1:6379
Logs: ✅ Clean, no errors
PID File: ✅ /Users/icmini/02luka/g/metrics/cls_agent.pid
Auto-start: ✅ On login
Keep-alive: ✅ Restarts if crashes
```

## Optional: Convert Bridge to Daemon

If you later want the bridge to run as a daemon (listening to Redis queue), here's the pattern:

```zsh
#!/usr/bin/env zsh
# Bridge daemon mode
while true; do
  # BLPOP from Redis queue (blocking)
  wo_json=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASS \
    BLPOP bridge:wo:inbox 1 | tail -n1)
  
  [[ -z "$wo_json" ]] && continue
  
  # Parse WO
  wo_id=$(echo "$wo_json" | jq -r .id)
  title=$(echo "$wo_json" | jq -r .title)
  body_path=$(echo "$wo_json" | jq -r .body_path)
  
  # Process (existing bridge logic)
  # ... build WO, drop to inbox, publish ACK ...
  
  echo "Processed $wo_id"
done
```

But for now, **the one-shot bridge design is correct** - CLS calls it when needed.

## Next Steps

1. ✅ LaunchAgent running CLS agent daemon
2. ✅ Bridge available as CLI tool for CLS
3. ⏭️ Test in Cursor (follow `CURSOR_TEST_GUIDE.md`)
4. ⏭️ CLS in Cursor will call bridge when needed

---

**Status: Production Ready with Auto-Start** 🚀
