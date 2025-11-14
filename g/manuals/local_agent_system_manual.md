# Local Agent System - Operations Manual

**Version:** 5.5
**Last Updated:** 2025-11-01
**Maintainer:** CLC

---

## Quick Start

### Check System Health

```bash
# Verify LaunchAgent is running
launchctl list | grep com.02luka.agent_listener

# Check all LightRAG agents
for p in {7210..7217}; do
  printf "%s " $p
  curl -s --max-time 2 http://127.0.0.1:$p/health | jq -r .status
done

# Test end-to-end flow
redis-cli PUBLISH gg:agent_router '{"intent":"check_health"}'
sleep 2
tail -5 ~/02luka/logs/agent/listener.log
```

### Send a Task

```bash
# Via Redis pub/sub (JSON format)
redis-cli PUBLISH gg:agent_router '{"intent":"check_health"}'

# Via Redis pub/sub (plain text - will be normalized)
redis-cli PUBLISH gg:agent_router 'check system health'

# Check result
tail ~/02luka/logs/agent/listener.log
```

---

## Architecture Overview

```
Redis Pub/Sub → agent_listener.py → agent_router.py → skills → results
                    (daemon)          (stateless)      (8 skills)
```

### Components

1. **agent_listener.py** - Persistent daemon (LaunchAgent)
   - Subscribes to 7 Redis channels
   - Spawns agent_router per task
   - Writes receipts + results to disk
   - Auto-restarts on failure

2. **agent_router.py** - Stateless executor
   - Maps intents to skill chains
   - Executes skills sequentially
   - Aggregates results
   - Returns JSON output

3. **Skills (8 total)**
   - `http_fetch.py` - HTTP requests
   - `run_shell.zsh` - Whitelisted shell commands
   - `launchctl_ctl.zsh` - LaunchAgent control
   - `file_ops.zsh` - File operations
   - `redis_ops.zsh` - Redis operations
   - `log_tail.zsh` - Log viewing
   - `process_info.zsh` - Process monitoring
   - `system_health.zsh` - System health checks

---

## Configuration

### LaunchAgent Plist
**Location:** `~/Library/LaunchAgents/com.02luka.agent_listener.plist`

**Key Settings:**
```xml
<key>LUKA_HOME</key>
<string>/Users/icmini/LocalProjects/02luka_local_g/g</string>

<key>PATH</key>
<string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>

<key>RunAtLoad</key>
<true/>

<key>KeepAlive</key>
<true/>
```

### Redis Channels
- `gg:agent_router` - Main agent dispatch
- `gg:nlp_router` - NLP processing
- `gg:direct_router` - Direct commands
- `kim:agent` - Kim agent tasks
- `telegram:agent` - Telegram bot tasks
- `clc:agent` - CLC tasks
- `cls:agent` - CLS tasks

### Intent Mappings
**Location:** `$LUKA_HOME/config/intent_map.yaml`

**Examples:**
- `check_health` → http_fetch.py + run_shell.zsh
- `restart_service` → launchctl_ctl.zsh
- `tail_logs` → log_tail.zsh
- `system_status` → system_health.zsh + process_info.zsh

---

## Operations

### Start/Stop/Restart

```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.02luka.agent_listener.plist

# Start
launchctl load ~/Library/LaunchAgents/com.02luka.agent_listener.plist

# Restart (reload)
launchctl unload ~/Library/LaunchAgents/com.02luka.agent_listener.plist
launchctl load ~/Library/LaunchAgents/com.02luka.agent_listener.plist
```

### View Logs

```bash
# Real-time runtime log
tail -f ~/02luka/logs/agent/listener.log

# Recent task receipts
ls -lt ~/02luka/logs/agent/receipts/ | head -10

# Recent task results
ls -lt ~/02luka/logs/agent/results/ | head -10

# View specific result
cat ~/02luka/logs/agent/results/lsn_TIMESTAMP.json | jq .
```

### Debugging

```bash
# Check LaunchAgent status
launchctl list | grep com.02luka.agent_listener

# Check error log
tail -50 ~/02luka/logs/agent/listener.err

# Check stdout log
tail -50 ~/02luka/logs/agent/listener.log

# Test Redis connection
redis-cli PING

# Test skill execution directly
echo '{"skill":"run_shell","params":{"cmd":"echo test"}}' | \
  /Users/icmini/LocalProjects/02luka_local_g/g/skills/run_shell.zsh
```

---

## Common Issues

### LaunchAgent Not Running

**Symptoms:** `launchctl list` shows no PID or exit code ≠ 0

**Solutions:**
1. Check error log: `tail ~/02luka/logs/agent/listener.err`
2. Verify LUKA_HOME exists: `ls /Users/icmini/LocalProjects/02luka_local_g/g`
3. Check Python script is executable: `ls -l $LUKA_HOME/agent_listener.py`
4. Restart LaunchAgent: `launchctl unload/load`

### redis-cli Command Not Found

**Symptoms:** Skills fail with "command not found: redis-cli"

**Solutions:**
1. Verify PATH in plist includes `/opt/homebrew/bin`
2. Check redis-cli location: `which redis-cli`
3. Restart LaunchAgent after PATH change

### Timestamp Errors (macOS)

**Symptoms:** `date: illegal option -- N` or similar

**Solutions:**
1. Verify skills use Python timestamps: `grep "python3 -c 'import time" $LUKA_HOME/skills/*.zsh`
2. Never use `date +%s%3N` (not macOS compatible)
3. Use: `python3 -c 'import time; print(int(time.time()*1000))'`

### Tasks Not Processing

**Symptoms:** Messages published but no results

**Solutions:**
1. Check listener is subscribed: `grep "start.*mode=" ~/02luka/logs/agent/listener.log | tail -1`
2. Verify channel name is correct
3. Check agent_router has intent mapping
4. Review result file for errors: `cat ~/02luka/logs/agent/results/TASK_ID.json | jq .error`

---

## Maintenance

### Log Rotation (Recommended)

Create `/etc/newsyslog.d/02luka.conf`:
```
# logfilename                    [owner:group] mode count size when flags
/Users/icmini/02luka/logs/agent/*.log           644  7    10240 *    GJ
```

Then: `sudo newsyslog -v`

### Monitoring

```bash
# Watch for new tasks
watch -n 1 'tail -5 ~/02luka/logs/agent/listener.log'

# Count tasks processed today
grep "$(date +%Y-%m-%d)" ~/02luka/logs/agent/listener.log | grep -c "\[done\]"

# Success rate
total=$(grep "\[done\]" ~/02luka/logs/agent/listener.log | wc -l)
success=$(grep "\[done\].*ok=True" ~/02luka/logs/agent/listener.log | wc -l)
echo "Success: $success / $total"
```

### Performance Tuning

- **DEFAULT_TIMEOUT:** 180s (configurable in agent_router.py)
- **Concurrent Tasks:** Listener processes one task at a time per channel
- **Skill Execution:** Sequential (not parallel)
- **Memory Usage:** ~25MB for listener daemon
- **CPU Usage:** <1% idle, <5% during execution

---

## File Locations

### Core Files
- **Listener Daemon:** `$LUKA_HOME/agent_listener.py`
- **Router:** `$LUKA_HOME/agent_router.py`
- **Skills:** `$LUKA_HOME/skills/*.{py,zsh}`
- **Config:** `$LUKA_HOME/config/intent_map.yaml`

### LaunchAgent
- **Plist:** `~/Library/LaunchAgents/com.02luka.agent_listener.plist`

### Logs
- **Runtime:** `~/02luka/logs/agent/listener.log`
- **Errors:** `~/02luka/logs/agent/listener.err`
- **Receipts:** `~/02luka/logs/agent/receipts/`
- **Results:** `~/02luka/logs/agent/results/`

### Reports
- **Deployment:** `$LUKA_HOME/reports/phase_5_5_deployment_report.md`
- **Architecture:** `$LUKA_HOME/reports/local_agent_system_report.md`

---

## Safety & Security

### Whitelisted Commands Only

The `run_shell.zsh` skill only executes whitelisted commands:
- `*health_server_ctl.zsh*`
- `*deploy_dashboard.zsh*`
- `*update_docker_yaml.zsh*`
- `*redis_bridge_ctl.zsh*`
- `*launchctl*`
- `*docker *`
- `*git *`
- `*curl *`
- `*redis-cli*`
- `*andy *`
- `*clcctl*`

### CloudStorage Path Blocking

agent_listener.py blocks any payload containing CloudStorage paths:
```python
if re.search(r"Library/CloudStorage|My Drive/02luka", s):
    raise RuntimeError("Blocked non-local CloudStorage path")
```

### Timeout Protection

All tasks have 180s timeout (DEFAULT_TIMEOUT in agent_router.py)

---

## Support

### Quick Health Check
```bash
bash /tmp/verify_deployment.sh
```

### Full System Report
```bash
cat $LUKA_HOME/reports/phase_5_5_deployment_report.md
```

### Contact
- **Owner:** CLC
- **Delegate:** core, r&d
- **Documentation:** `$LUKA_HOME/manuals/`

---

**Manual Version:** 1.0
**Phase:** 5.5 Complete
**Status:** Production Ready ✅
