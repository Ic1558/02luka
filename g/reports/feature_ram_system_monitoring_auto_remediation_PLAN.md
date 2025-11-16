# Feature PLAN: RAM/System Monitoring & Auto-Remediation

**Feature:** Comprehensive RAM and system resource monitoring with 5-layer defensive architecture  
**Date:** 2025-11-17  
**Status:** Draft  
**Estimated Time:** ~13 hours (4 phases over 4 weeks)

---

## Implementation Roadmap

### Phase 1: Emergency Monitoring (Week 1, ~4 hours)
**Goal:** Real-time detection and alerting

### Phase 2: Prevention (Week 2, ~3 hours)
**Goal:** Prevent issues before they occur

### Phase 3: Auto-Remediation (Week 3, ~4 hours)
**Goal:** Automatic crisis recovery

### Phase 4: Learning Loop (Week 4, ~2 hours)
**Goal:** Capture incidents and learn from them

---

## Phase 1: Emergency Monitoring (Week 1, ~4 hours)

### Task 1.1: Create `tools/ram_guard.zsh` (60 min)

**Description:** Monitor swap/load/memory pressure every 60s, publish alerts to Redis

**Requirements:**
- Check swap usage (`vm_stat` or `sysctl`)
- Check load average (`sysctl vm.loadavg`)
- Calculate swap percentage
- Publish to Redis channel `02luka:alerts:ram` if threshold breached
- Log to `~/02luka/logs/ram_guard.log`

**Implementation:**
```zsh
#!/usr/bin/env zsh
# RAM Guard - Monitor swap/load/memory pressure
set -euo pipefail

SWAP_WARNING=75
SWAP_CRITICAL=90
LOAD_WARNING=10

# Get swap usage
swap_used=$(sysctl vm.swapusage | awk '{print $7}' | sed 's/M//')
swap_total=$(sysctl vm.swapusage | awk '{print $9}' | sed 's/M//')
swap_pct=$((swap_used * 100 / swap_total))

# Get load average
load_avg=$(sysctl vm.loadavg | awk '{print $3}')

# Check thresholds and publish alerts
if [[ $swap_pct -gt $SWAP_CRITICAL ]]; then
  redis-cli PUBLISH 02luka:alerts:ram "{\"type\":\"ram_critical\",\"swap_pct\":$swap_pct,...}"
elif [[ $swap_pct -gt $SWAP_WARNING ]]; then
  redis-cli PUBLISH 02luka:alerts:ram "{\"type\":\"ram_warning\",\"swap_pct\":$swap_pct,...}"
fi
```

**Test Strategy:**
- Unit test: Mock `sysctl` output, verify threshold logic
- Integration test: Run for 2 minutes, verify Redis messages
- Manual test: Trigger high swap, verify alerts

**Acceptance Criteria:**
- ✅ Runs every 60s (LaunchAgent)
- ✅ Publishes alerts to Redis when thresholds breached
- ✅ Logs to file
- ✅ Handles Redis connection failures gracefully

---

### Task 1.2: Create `tools/process_watchdog.zsh` (45 min)

**Description:** Track all processes >500MB, detect memory leaks

**Requirements:**
- Use `ps` to list all processes with RSS >500MB
- Track process growth over time (store in temp file)
- Detect leaks: Process growing >100MB in 5 minutes
- Publish alerts to Redis `02luka:alerts:ram`

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Process Watchdog - Detect memory leaks
set -euo pipefail

THRESHOLD_MB=500
LEAK_THRESHOLD_MB=100
TRACK_FILE="/tmp/process_watchdog_track.json"

# Get processes >500MB
ps aux | awk 'NR>1 && $6 > 500000 {print $2, $6, $11}' | while read pid rss cmd; do
  # Check if process is growing
  # Store previous RSS, compare
done
```

**Test Strategy:**
- Unit test: Mock `ps` output, verify leak detection
- Integration test: Run for 10 minutes, verify tracking
- Manual test: Start memory-heavy process, verify detection

**Acceptance Criteria:**
- ✅ Tracks processes >500MB
- ✅ Detects leaks (>100MB growth in 5min)
- ✅ Publishes alerts to Redis
- ✅ Handles process death gracefully

---

### Task 1.3: Create `tools/agent_health_monitor.zsh` (45 min)

**Description:** Detect crash loops and log bloat

**Requirements:**
- Monitor LaunchAgent status via `launchctl list`
- Track restart counts (store in temp file)
- Detect crash loops: >5 restarts in 5 minutes
- Check log file sizes, alert if >50MB
- Publish alerts to Redis

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Agent Health Monitor - Detect crash loops and log bloat
set -euo pipefail

CRASH_LOOP_THRESHOLD=5
LOG_SIZE_THRESHOLD_MB=50

# Check LaunchAgent exit codes
launchctl list | grep -E "Exit [^0]" | while read line; do
  # Extract agent name and exit code
  # Track restart count
done

# Check log sizes
find ~/02luka/logs -name "*.log" -size +50M | while read logfile; do
  # Alert on large logs
done
```

**Test Strategy:**
- Unit test: Mock `launchctl list`, verify crash loop detection
- Integration test: Create test agent with crash loop, verify detection
- Manual test: Check existing failing agents, verify alerts

**Acceptance Criteria:**
- ✅ Detects crash loops (>5 restarts in 5min)
- ✅ Detects log bloat (>50MB)
- ✅ Publishes alerts to Redis
- ✅ Handles missing LaunchAgents gracefully

---

### Task 1.4: Create `tools/alert_router.zsh` (30 min)

**Description:** Route Redis alerts to macOS notifications and Telegram

**Requirements:**
- Subscribe to Redis channel `02luka:alerts:ram`
- Route WARNING to macOS notifications
- Route CRITICAL to macOS + Telegram (if configured)
- Format messages for readability

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Alert Router - Route Redis alerts to notifications
set -euo pipefail

redis-cli SUBSCRIBE 02luka:alerts:ram | while read line; do
  # Parse JSON alert
  # Route based on severity
  if [[ $severity == "critical" ]]; then
    osascript -e "display notification \"$message\" with title \"02luka RAM Alert\""
    # Also send to Telegram if configured
  fi
done
```

**Test Strategy:**
- Unit test: Mock Redis messages, verify routing
- Integration test: Publish test alerts, verify notifications
- Manual test: Trigger real alerts, verify delivery

**Acceptance Criteria:**
- ✅ Subscribes to Redis channel
- ✅ Routes WARNING to macOS notifications
- ✅ Routes CRITICAL to macOS + Telegram
- ✅ Handles Redis disconnections gracefully

---

### Task 1.5: Add `/api/system/resources` endpoint (30 min)

**Description:** Add API endpoint for dashboard to fetch RAM/swap metrics

**Requirements:**
- Add endpoint to existing `g/apps/dashboard/api_server.py` (or create new)
- Return JSON with swap usage, load average, top processes
- Update every 5 seconds (client polling)

**Implementation:**
```python
# In api_server.py
def handle_system_resources(self, query):
    swap_used = get_swap_usage()
    swap_total = get_swap_total()
    load_avg = get_load_average()
    top_processes = get_top_processes(limit=10)
    
    return {
        "swap": {
            "used_gb": swap_used,
            "total_gb": swap_total,
            "pct": (swap_used / swap_total) * 100
        },
        "load_avg": load_avg,
        "top_processes": top_processes,
        "timestamp": datetime.now().isoformat()
    }
```

**Test Strategy:**
- Unit test: Mock system calls, verify JSON format
- Integration test: Call endpoint, verify response
- Manual test: Open dashboard, verify metrics display

**Acceptance Criteria:**
- ✅ Endpoint returns valid JSON
- ✅ Includes swap, load, top processes
- ✅ Updates in real-time (5s polling)

---

### Task 1.6: Create LaunchAgent `com.02luka.ram.guard.plist` (20 min)

**Description:** LaunchAgent to run `ram_guard.zsh` every 60s

**Requirements:**
- Run `tools/ram_guard.zsh` every 60 seconds
- KeepAlive: true (restart if crashes)
- ThrottleInterval: 60 (prevent feedback loops)
- Logs to `~/02luka/logs/ram_guard.stdout.log`

**Implementation:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.ram.guard</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>zsh</string>
    <string>/Users/icmini/02luka/tools/ram_guard.zsh</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>60</integer>
  <key>StandardOutPath</key>
  <string>/Users/icmini/02luka/logs/ram_guard.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/icmini/02luka/logs/ram_guard.stderr.log</string>
</dict>
</plist>
```

**Test Strategy:**
- Manual test: Load LaunchAgent, verify runs every 60s
- Integration test: Check logs, verify Redis messages

**Acceptance Criteria:**
- ✅ Runs every 60 seconds
- ✅ Logs to files
- ✅ Restarts on crash (KeepAlive)

---

### Task 1.7: Fix broken health agents (20 min)

**Description:** Fix path issues in `com.02luka.health.dashboard.plist` and `com.02luka.phase15.quickhealth.plist`

**Requirements:**
- Verify script paths exist
- Update paths if needed
- Reload LaunchAgents
- Verify they run successfully

**Test Strategy:**
- Manual test: Check LaunchAgent status, verify Exit 0

**Acceptance Criteria:**
- ✅ Both agents run successfully (Exit 0)
- ✅ No path errors

---

## Phase 2: Prevention (Week 2, ~3 hours)

### Task 2.1: Create `tools/validate_launchagents.zsh` (45 min)

**Description:** Pre-commit hook to validate LaunchAgent plists

**Requirements:**
- Parse all `.plist` files in `~/Library/LaunchAgents/`
- Extract script paths from `ProgramArguments`
- Verify scripts exist and are executable
- Verify paths are absolute (no `~/` expansion issues)
- Exit 1 if validation fails

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Validate LaunchAgents - Pre-commit hook
set -euo pipefail

FAILED=0
for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
  # Extract ProgramArguments
  script_path=$(plutil -extract ProgramArguments.2 raw "$plist")
  
  # Expand ~ if needed
  script_path="${script_path/#\~/$HOME}"
  
  # Validate
  if [[ ! -f "$script_path" ]]; then
    echo "ERROR: $plist references missing script: $script_path"
    FAILED=1
  fi
done

exit $FAILED
```

**Test Strategy:**
- Unit test: Mock plist files, verify validation logic
- Integration test: Run on actual LaunchAgents, verify catches errors
- Manual test: Create test plist with invalid path, verify failure

**Acceptance Criteria:**
- ✅ Validates all LaunchAgent plists
- ✅ Catches missing scripts
- ✅ Catches non-executable scripts
- ✅ Can be used as pre-commit hook

---

### Task 2.2: Generate `g/docs/AGENT_REGISTRY.md` (60 min)

**Description:** Document all 75 agents (purpose, critical/optional)

**Requirements:**
- Auto-generate from LaunchAgents (or manual documentation)
- Include: name, purpose, criticality, dependencies, health checks
- Format: Markdown table

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Generate Agent Registry
set -euo pipefail

echo "# Agent Registry" > g/docs/AGENT_REGISTRY.md
echo "" >> g/docs/AGENT_REGISTRY.md
echo "| Name | Purpose | Criticality | Dependencies | Health Check |" >> g/docs/AGENT_REGISTRY.md
echo "|------|---------|-------------|--------------|--------------|" >> g/docs/AGENT_REGISTRY.md

for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
  name=$(basename "$plist" .plist)
  # Extract info from plist or manual lookup
  echo "| $name | ... | ... | ... | ... |" >> g/docs/AGENT_REGISTRY.md
done
```

**Test Strategy:**
- Manual test: Generate registry, verify completeness
- Integration test: Verify all agents documented

**Acceptance Criteria:**
- ✅ All 75 agents documented
- ✅ Includes purpose, criticality, dependencies
- ✅ Markdown format, readable

---

### Task 2.3: Setup log rotation for `logs/` directory (30 min)

**Description:** Fix 50MB `mls_cursor_watcher.log` bloat

**Requirements:**
- Rotate logs when >10MB
- Keep last 7 days
- Compress old logs
- Use `logrotate` or custom script

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Log Rotation - Rotate logs in ~/02luka/logs/
set -euo pipefail

MAX_SIZE_MB=10
KEEP_DAYS=7

for logfile in ~/02luka/logs/*.log; do
  size_mb=$(du -m "$logfile" | cut -f1)
  if [[ $size_mb -gt $MAX_SIZE_MB ]]; then
    # Rotate: move to .log.1, compress .log.1.gz
    mv "$logfile" "${logfile}.1"
    gzip "${logfile}.1"
    # Delete old logs
    find ~/02luka/logs -name "*.log.*.gz" -mtime +$KEEP_DAYS -delete
  fi
done
```

**Test Strategy:**
- Unit test: Mock log files, verify rotation logic
- Integration test: Create test log >10MB, verify rotation
- Manual test: Run on actual logs, verify compression

**Acceptance Criteria:**
- ✅ Rotates logs >10MB
- ✅ Keeps last 7 days
- ✅ Compresses old logs
- ✅ Can be run daily (LaunchAgent)

---

### Task 2.4: Enhance `backup_to_gdrive.zsh` with load checks (45 min)

**Description:** Add load average checks to prevent backup during high load

**Requirements:**
- Check load average before starting backup
- Skip backup if load >10
- Log skip reason
- Retry on next schedule if skipped

**Implementation:**
```zsh
# In backup_to_gdrive.zsh
LOAD_THRESHOLD=10
load_avg=$(sysctl vm.loadavg | awk '{print $3}')

if (( $(echo "$load_avg > $LOAD_THRESHOLD" | bc -l) )); then
  echo "[$(date)] Skipping backup: load average too high ($load_avg > $LOAD_THRESHOLD)" >> "$LOG"
  exit 0  # Exit 0 = success, but skipped
fi

# Proceed with backup
```

**Test Strategy:**
- Unit test: Mock load average, verify skip logic
- Integration test: Set high load, verify backup skipped
- Manual test: Run backup during high load, verify behavior

**Acceptance Criteria:**
- ✅ Checks load average before backup
- ✅ Skips if load >10
- ✅ Logs skip reason
- ✅ Retries on next schedule

---

## Phase 3: Auto-Remediation (Week 3, ~4 hours)

### Task 3.1: Create `tools/ram_crisis_handler.zsh` (90 min)

**Description:** Auto-kill non-critical processes at swap >90%

**Requirements:**
- Monitor swap usage (via Redis or direct check)
- When swap >90%, identify non-critical processes
- Kill processes >2GB RSS (potential leaks)
- Kill processes from safe kill list
- Log all actions to MLS

**Implementation:**
```zsh
#!/usr/bin/env zsh
# RAM Crisis Handler - Auto-remediate swap crisis
set -euo pipefail

SWAP_CRITICAL=90
SAFE_KILL_LIST=("com.docker.backend" "com.apple.Safari" ...)  # User-provided

# Get swap usage
swap_pct=$(get_swap_percentage)

if [[ $swap_pct -gt $SWAP_CRITICAL ]]; then
  # Find processes >2GB
  ps aux | awk 'NR>1 && $6 > 2000000 {print $2, $11}' | while read pid cmd; do
    # Check if in safe kill list
    if [[ " ${SAFE_KILL_LIST[@]} " =~ " ${cmd} " ]]; then
      kill -9 "$pid"
      log_to_mls "ram_crisis_handler" "Killed process $pid ($cmd) during swap crisis"
    fi
  done
fi
```

**Test Strategy:**
- Unit test: Mock swap usage, verify kill logic
- Integration test: Trigger high swap, verify processes killed
- Manual test: Run during actual crisis, verify recovery

**Acceptance Criteria:**
- ✅ Monitors swap usage
- ✅ Kills non-critical processes at >90%
- ✅ Logs to MLS
- ✅ Never kills critical services

---

### Task 3.2: Create crash loop circuit breaker (60 min)

**Description:** Disable agents after 5 restarts in 5 minutes

**Requirements:**
- Track agent restart counts (store in temp file)
- If >5 restarts in 5min → disable agent (unload LaunchAgent)
- Log to MLS with tag `crash_loop_auto_disable`
- Alert user via notification

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Crash Loop Circuit Breaker
set -euo pipefail

TRACK_FILE="/tmp/crash_loop_track.json"
THRESHOLD=5
WINDOW_MINUTES=5

# Check LaunchAgent exit codes
launchctl list | grep -E "Exit [^0]" | while read line; do
  agent_name=$(echo "$line" | awk '{print $1}')
  # Update restart count
  # If >5 in 5min → unload LaunchAgent
  launchctl unload ~/Library/LaunchAgents/${agent_name}.plist
  log_to_mls "crash_loop_breaker" "Disabled $agent_name after crash loop"
done
```

**Test Strategy:**
- Unit test: Mock restart counts, verify disable logic
- Integration test: Create test agent with crash loop, verify disable
- Manual test: Check existing failing agents, verify disable

**Acceptance Criteria:**
- ✅ Tracks restart counts
- ✅ Disables agents after >5 restarts
- ✅ Logs to MLS
- ✅ Alerts user

---

### Task 3.3: Create `tools/process_watchdog.zsh` (enhanced) (30 min)

**Description:** Enhanced version with leak detection and auto-kill

**Requirements:**
- Detect leaks: Process growing >100MB in 5 minutes
- Auto-kill leaking processes (if in safe kill list)
- Publish alerts to Redis

**Test Strategy:**
- Unit test: Mock process growth, verify leak detection
- Integration test: Start leaking process, verify kill
- Manual test: Run during actual leak, verify behavior

**Acceptance Criteria:**
- ✅ Detects leaks
- ✅ Auto-kills leaking processes
- ✅ Publishes alerts

---

## Phase 4: Learning Loop (Week 4, ~2 hours)

### Task 4.1: Capture RAM crisis to MLS (30 min)

**Description:** Capture the 2025-11-17 crisis to MLS

**Requirements:**
- Use `mls_capture.zsh` with type `failure`
- Tags: `ram`, `crisis`, `auto-heal`
- Problem: What happened
- Solution: What was done
- Prevention: What can prevent this

**Implementation:**
```bash
~/02luka/tools/mls_capture.zsh failure "RAM Exhaustion Crisis 2025-11-17" \
  "Swap reached 22GB/23.5GB (94%), 50+ LaunchAgents in crash loops" \
  "Disabled 12 agents, restored 2 scripts, stopped Docker/VSCode" \
  "Implement 5-layer monitoring system"
```

**Test Strategy:**
- Manual test: Run command, verify MLS entry

**Acceptance Criteria:**
- ✅ Crisis captured in MLS
- ✅ Includes problem, solution, prevention

---

### Task 4.2: Create incident report generator (45 min)

**Description:** Auto-generate incident reports for CRITICAL events

**Requirements:**
- Trigger on CRITICAL alerts
- Generate Markdown report in `g/reports/incidents/`
- Include: timeline, root cause, actions taken, lessons learned
- Format: `RAM_CRISIS_YYYYMMDD.md`

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Incident Report Generator
set -euo pipefail

generate_incident_report() {
  local incident_type="$1"
  local timestamp="$2"
  local report_file="g/reports/incidents/${incident_type}_$(date +%Y%m%d).md"
  
  cat > "$report_file" <<EOF
# $incident_type - $(date +%Y-%m-%d)

## Timeline
- $(date): Incident detected
- ...

## Root Cause
...

## Actions Taken
...

## Lessons Learned
...
EOF
}
```

**Test Strategy:**
- Unit test: Mock incident data, verify report format
- Integration test: Trigger CRITICAL alert, verify report generated
- Manual test: Check report, verify completeness

**Acceptance Criteria:**
- ✅ Generates reports for CRITICAL events
- ✅ Includes timeline, root cause, actions, lessons
- ✅ Markdown format, readable

---

### Task 4.3: Setup weekly health digest (45 min)

**Description:** Track RAM/swap trends over time

**Requirements:**
- Run weekly (Sunday)
- Collect: RAM/swap trends, top consumers, agent health, incidents
- Generate Markdown report in `g/reports/health/weekly_digest_YYYYMMDD.md`
- Include charts/graphs (text-based or JSON for dashboard)

**Implementation:**
```zsh
#!/usr/bin/env zsh
# Weekly Health Digest
set -euo pipefail

generate_weekly_digest() {
  local report_file="g/reports/health/weekly_digest_$(date +%Y%m%d).md"
  
  # Collect data from logs
  # Generate report
  cat > "$report_file" <<EOF
# Weekly Health Digest - $(date +%Y-%m-%d)

## RAM/Swap Trends
- Average swap usage: ...
- Peak swap usage: ...
- ...

## Top Memory Consumers
...

## Agent Health
...

## Incidents
...
EOF
}
```

**Test Strategy:**
- Unit test: Mock log data, verify report format
- Integration test: Run weekly digest, verify completeness
- Manual test: Check report, verify trends

**Acceptance Criteria:**
- ✅ Runs weekly
- ✅ Includes RAM/swap trends, top consumers, agent health, incidents
- ✅ Markdown format, readable

---

## Test Strategy

### Unit Tests
- Mock system calls (`sysctl`, `ps`, `launchctl`)
- Test threshold logic
- Test alert formatting
- Test kill list logic

### Integration Tests
- Run monitoring tools for extended periods
- Trigger test alerts
- Verify Redis pub/sub
- Verify notifications
- Verify dashboard updates

### Manual Tests
- Run during actual high load
- Trigger real alerts
- Verify auto-remediation
- Check MLS entries
- Review incident reports

### Test Files
- `tests/test_ram_guard.zsh` - Test ram_guard threshold logic
- `tests/test_process_watchdog.zsh` - Test leak detection
- `tests/test_agent_health_monitor.zsh` - Test crash loop detection
- `tests/test_ram_crisis_handler.zsh` - Test auto-remediation
- `tests/test_validate_launchagents.zsh` - Test validation logic

---

## Rollback Plan

### If Monitoring Overhead Too High
- Increase check interval (60s → 120s)
- Reduce process tracking (500MB → 1GB threshold)
- Disable non-critical monitors

### If False Positives
- Adjust thresholds (75% → 80% warning, 90% → 95% critical)
- Refine safe kill list
- Add user approval for critical kills

### If Auto-Remediation Too Aggressive
- Disable auto-kill, alert only
- Require user confirmation for kills
- Add more processes to safe kill list

### Rollback Steps
1. Unload LaunchAgents: `launchctl unload ~/Library/LaunchAgents/com.02luka.ram.*.plist`
2. Stop monitoring tools: `pkill -f ram_guard`
3. Remove pre-commit hook: `rm .git/hooks/pre-commit`
4. Restore original `backup_to_gdrive.zsh` from git

---

## Success Metrics

### Prevention
- ✅ Never exceed 80% swap usage
- ✅ All LaunchAgent plists validated
- ✅ Crash loops detected and disabled

### Detection
- ✅ Alerts within 1 minute
- ✅ Process leaks detected within 5 minutes
- ✅ Crash loops detected within 5 minutes

### Remediation
- ✅ Auto-recovery in <5 minutes
- ✅ Non-critical processes killed automatically
- ✅ Crash-looping agents disabled automatically

### Learning
- ✅ All incidents captured in MLS
- ✅ Incident reports auto-generated
- ✅ Weekly health digest tracks trends

### Visibility
- ✅ Dashboard shows real-time RAM/swap status
- ✅ Top memory consumers displayed
- ✅ Agent health status visible

---

## Deliverables Summary

### New Tools (9 files)
1. `tools/ram_guard.zsh` - Swap/load monitoring
2. `tools/process_watchdog.zsh` - Leak detection
3. `tools/agent_health_monitor.zsh` - Crash loop detection
4. `tools/alert_router.zsh` - Alert routing
5. `tools/validate_launchagents.zsh` - Pre-commit validation
6. `tools/ram_crisis_handler.zsh` - Auto-remediation
7. `LaunchAgents/com.02luka.ram.guard.plist` - Monitoring agent
8. `g/docs/AGENT_REGISTRY.md` - Agent documentation
9. `g/reports/incidents/RAM_CRISIS_20251117.md` - Initial incident report

### Enhanced Files (4 existing)
1. `g/apps/dashboard/api_server.py` - Add `/api/system/resources` endpoint
2. `g/apps/dashboard/dashboard.js` - Add RAM/swap panel
3. `tools/system_health_check.zsh` - Add memory checks
4. `tools/backup_to_gdrive.zsh` - Add load checks

### Fixed Files (2 broken agents)
1. `LaunchAgents/com.02luka.health.dashboard.plist` - Fix path
2. `LaunchAgents/com.02luka.phase15.quickhealth.plist` - Fix path

---

## Timeline

- **Week 1:** Emergency Monitoring (4 hours)
- **Week 2:** Prevention (3 hours)
- **Week 3:** Auto-Remediation (4 hours)
- **Week 4:** Learning Loop (2 hours)
- **Total:** ~13 hours over 4 weeks

---

**Status:** Ready for implementation  
**Next Step:** Begin Phase 1, Task 1.1 (Create `ram_guard.zsh`)
