# CLS Enhancement Roadmap - Achieving CLC Parity

**Goal:** Elevate CLS (Cognitive Local System) to match CLC's sophistication while maintaining governance boundaries.

## Current Gap Analysis

### CLS (Current State)
```
Role: Orchestrator in Cursor
Capabilities:
  ✅ Read anywhere
  ✅ Write to safe zones (memory/cls, logs, telemetry)
  ✅ Create Work Orders via bridge
  ✅ Heartbeat monitoring
  ❌ Limited decision-making
  ❌ No result polling
  ❌ Basic observability
  ❌ Manual context management
```

### CLC (Target Benchmark)
```
Role: System Administrator
Capabilities:
  ✅ Full system access
  ✅ Complex workflows
  ✅ Tool integrations
  ✅ Advanced decision-making
  ✅ Evidence-based operations
  ✅ CI/CD integration
  ✅ Rich observability
  ✅ Context persistence
```

---

## Enhancement Phases

### Phase 1: Bidirectional Bridge (High Impact)

**Problem:** CLS drops WOs but never knows the outcome.

**Solution:** Add result polling and status updates.

#### 1.1 Redis Result Channel
```zsh
# ~/tools/cls_poll_results.zsh
#!/usr/bin/env zsh
set -euo pipefail

WO_ID="${1:?WO-ID required}"
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASS="${REDIS_PASS:-gggclukaic}"

# Poll for result
RESULT_KEY="wo:result:${WO_ID}"
TIMEOUT=60  # seconds

echo "Polling for result of $WO_ID (timeout: ${TIMEOUT}s)..."

for i in {1..$TIMEOUT}; do
  RESULT=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASS" \
    GET "$RESULT_KEY" 2>/dev/null || true)
  
  if [[ -n "$RESULT" ]]; then
    echo "✅ Result received:"
    echo "$RESULT" | jq .
    exit 0
  fi
  
  sleep 1
done

echo "⏱️ Timeout: No result after ${TIMEOUT}s"
exit 1
```

#### 1.2 WO Status Tracking
```yaml
# ~/02luka/memory/cls/wo_status.jsonl
{"wo_id":"WO-20251030-XXXXX","status":"pending","created":"2025-10-30T05:00:00Z"}
{"wo_id":"WO-20251030-XXXXX","status":"in_progress","updated":"2025-10-30T05:01:00Z"}
{"wo_id":"WO-20251030-XXXXX","status":"completed","result":"success","updated":"2025-10-30T05:05:00Z"}
```

#### 1.3 Bridge Enhancement
Add `--wait` flag to bridge script:
```zsh
# In bridge_cls_clc.zsh
WAIT_FOR_RESULT=0
while (( $# )); do
  case "$1" in
    --wait) WAIT_FOR_RESULT=1;;
    # ... existing args ...
  esac
done

# After dropping WO
if (( WAIT_FOR_RESULT )); then
  echo "$(ts) ⏳ Waiting for result..."
  ~/tools/cls_poll_results.zsh "$WO_ID"
fi
```

**Impact:** CLS can now create WO → wait → receive result → act on outcome

---

### Phase 2: Enhanced Observability (Medium Impact)

**Problem:** CLS has minimal metrics, hard to debug.

**Solution:** Rich metrics, dashboards, alerting.

#### 2.1 Metrics Collection
```zsh
# ~/tools/cls_collect_metrics.zsh
#!/usr/bin/env zsh
# Runs every minute via cron or LaunchAgent

METRICS_DIR="$HOME/02luka/g/metrics"
TIMESTAMP=$(date -u +%s)

# Agent uptime
AGENT_PID=$(cat "$METRICS_DIR/cls_agent.pid" 2>/dev/null || echo 0)
UPTIME_SECONDS=$(ps -p "$AGENT_PID" -o etime= 2>/dev/null | awk -F: '{print $1*3600+$2*60+$3}' || echo 0)

# WO stats
WO_TOTAL=$(ls -1 ~/02luka/bridge/inbox/CLC/ 2>/dev/null | wc -l | tr -d ' ')
WO_TODAY=$(find ~/02luka/bridge/inbox/CLC/ -type d -newermt "today" | wc -l | tr -d ' ')

# Redis health
REDIS_OK=0
redis-cli -h 127.0.0.1 -p 6379 -a gggclukaic PING >/dev/null 2>&1 && REDIS_OK=1

# Write metrics
cat >> "$METRICS_DIR/cls_metrics.jsonl" <<METRICS
{"ts":$TIMESTAMP,"agent_uptime_sec":$UPTIME_SECONDS,"wo_total":$WO_TOTAL,"wo_today":$WO_TODAY,"redis_ok":$REDIS_OK}
METRICS
```

#### 2.2 Dashboard Generator
```zsh
# ~/tools/cls_dashboard.zsh
#!/usr/bin/env zsh
# Generate HTML dashboard from metrics

METRICS_FILE="$HOME/02luka/g/metrics/cls_metrics.jsonl"
DASHBOARD_FILE="$HOME/02luka/g/reports/cls_dashboard.html"

# Last 24h metrics
LAST_24H=$(tail -1440 "$METRICS_FILE" | jq -s '
  {
    uptime_avg: (map(.agent_uptime_sec) | add / length),
    wo_total: (.[0].wo_total),
    wo_today: (.[0].wo_today),
    redis_uptime_pct: (map(select(.redis_ok==1)) | length / (input | length) * 100)
  }
')

cat > "$DASHBOARD_FILE" <<HTML
<!DOCTYPE html>
<html>
<head><title>CLS Dashboard</title></head>
<body>
  <h1>CLS System Dashboard</h1>
  <pre>$LAST_24H</pre>
  <!-- Add charts with Chart.js -->
</body>
</html>
HTML

echo "Dashboard: file://$DASHBOARD_FILE"
```

**Impact:** Visibility into CLS health, WO throughput, Redis stability

---

### Phase 3: Context Management (High Impact)

**Problem:** CLS loses context between sessions, no learning.

**Solution:** Persistent memory, learning from outcomes.

#### 3.1 Context Database
```zsh
# ~/02luka/memory/cls/context.db (SQLite)
# Tables:
# - wo_history (wo_id, title, priority, result, duration_sec, created_at)
# - patterns (pattern_id, description, success_count, fail_count, last_seen)
# - lessons (lesson_id, context, action, outcome, confidence)
```

#### 3.2 Learning Script
```zsh
# ~/tools/cls_learn.zsh
#!/usr/bin/env zsh
set -euo pipefail

WO_ID="${1:?WO-ID required}"
RESULT="${2:?result required}"  # success|failure
DURATION="${3:-0}"

DB="$HOME/02luka/memory/cls/context.db"

# Record outcome
sqlite3 "$DB" <<SQL
INSERT INTO wo_history (wo_id, result, duration_sec, created_at)
VALUES ('$WO_ID', '$RESULT', $DURATION, datetime('now'));
SQL

# Extract patterns
if [[ "$RESULT" == "success" ]]; then
  # What worked? Increment pattern confidence
  echo "Learning: WO succeeded in ${DURATION}s"
else
  # What failed? Record for avoidance
  echo "Learning: WO failed - analyze root cause"
fi
```

#### 3.3 Proactive Suggestions
```zsh
# When CLS sees a task, query context DB:
# "Have we done this before? What was the outcome?"
# "Are there known patterns for this type of request?"
# "What's the estimated duration based on history?"
```

**Impact:** CLS becomes smarter over time, suggests optimizations

---

### Phase 4: Advanced Decision-Making (Medium Impact)

**Problem:** CLS is reactive, no autonomous decisions.

**Solution:** Policy-based automation, approval workflows.

#### 4.1 Policy Engine
```yaml
# ~/02luka/memory/cls/policies.yaml
policies:
  - name: "auto_approve_low_priority"
    condition:
      priority: P3
      tags_include: ["test", "docs"]
    action: auto_approve
    
  - name: "require_approval_critical"
    condition:
      priority: P1
      tags_include: ["prod", "database"]
    action: require_human_approval
    
  - name: "auto_retry_transient_failures"
    condition:
      result: failure
      error_pattern: "connection timeout"
    action: retry
    max_retries: 3
```

#### 4.2 Approval Workflow
```zsh
# ~/tools/cls_approval.zsh
#!/usr/bin/env zsh
# Check if WO needs approval

WO_ID="$1"
WO_YAML="$HOME/02luka/bridge/inbox/CLC/${WO_ID}/${WO_ID}.yaml"

# Parse WO
PRIORITY=$(yq -r .priority "$WO_YAML")
TAGS=$(yq -r '.tags' "$WO_YAML")

# Check policy
if [[ "$PRIORITY" == "P1" ]]; then
  # Notify for approval
  osascript -e "display dialog \"Approve $WO_ID?\" buttons {\"Approve\", \"Reject\"}"
  # Or: Send to Telegram/Slack
fi
```

**Impact:** CLS can automate safe operations, escalate risky ones

---

### Phase 5: Tool Integrations (Low-Medium Impact)

**Problem:** CLS only has bridge script, limited capabilities.

**Solution:** Add specialized tools for common tasks.

#### 5.1 Tool Registry
```yaml
# ~/02luka/memory/cls/tools.yaml
tools:
  - name: "health_check"
    command: "~/tools/check_cls_status.zsh"
    category: "monitoring"
    
  - name: "deploy_validation"
    command: "~/02luka/02luka-repo/a/section/clc/commands/validate.sh"
    category: "ci_cd"
    
  - name: "backup_config"
    command: "~/tools/backup_config.zsh"
    category: "maintenance"
```

#### 5.2 Tool Executor
```zsh
# ~/tools/cls_exec_tool.zsh
#!/usr/bin/env zsh
TOOL_NAME="$1"
TOOL_CMD=$(yq -r ".tools[] | select(.name==\"$TOOL_NAME\") | .command" ~/02luka/memory/cls/tools.yaml)

if [[ -n "$TOOL_CMD" ]]; then
  echo "Executing: $TOOL_CMD"
  eval "$TOOL_CMD"
else
  echo "Unknown tool: $TOOL_NAME"
  exit 1
fi
```

**Impact:** CLS has a toolbox for common operations

---

### Phase 6: Evidence & Compliance (High Impact)

**Problem:** CLS tracks WOs but lacks deep evidence chains.

**Solution:** Screenshot capture, diff tracking, validation gates.

#### 6.1 Evidence Capture
```zsh
# When CLS creates WO, automatically:
# 1. Capture state snapshot (git diff, file checksums)
# 2. Screenshot relevant UI (if applicable)
# 3. Record command history
# 4. Link to related docs/issues
```

#### 6.2 Validation Gates
```zsh
# Before dropping WO to CLC:
# 1. Schema validation (is WO well-formed?)
# 2. Safety check (does it violate policies?)
# 3. Dependency check (are prerequisites met?)
# 4. Dry-run if possible
```

**Impact:** Full compliance with AI/OP-001, audit-ready

---

## Implementation Priority

### Phase 1 (Week 1) - Quick Wins
1. ✅ Bidirectional bridge (result polling)
2. ✅ Enhanced metrics collection
3. ✅ Basic dashboard

### Phase 2 (Week 2) - Intelligence
1. Context database setup
2. Learning from outcomes
3. Pattern recognition

### Phase 3 (Week 3) - Automation
1. Policy engine
2. Approval workflows
3. Auto-retry logic

### Phase 4 (Week 4) - Integration
1. Tool registry
2. Evidence capture
3. Validation gates

---

## Quick Start: Phase 1.1 (Bidirectional Bridge)

Run this now to get immediate improvement:

```bash
# 1. Create result polling script
cat > ~/tools/cls_poll_results.zsh <<'POLL'
#!/usr/bin/env zsh
set -euo pipefail
WO_ID="${1:?WO-ID required}"
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASS="${REDIS_PASS:-gggclukaic}"
RESULT_KEY="wo:result:${WO_ID}"
TIMEOUT=60

for i in {1..$TIMEOUT}; do
  RESULT=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASS" GET "$RESULT_KEY" 2>/dev/null || true)
  [[ -n "$RESULT" ]] && { echo "$RESULT" | jq .; exit 0; }
  sleep 1
done
echo "Timeout"
exit 1
POLL

chmod +x ~/tools/cls_poll_results.zsh

# 2. Test it
# (CLC would write: redis-cli SET wo:result:WO-TEST '{"status":"success","duration":5}')
# ~/tools/cls_poll_results.zsh WO-TEST
```

---

## Success Metrics

After enhancements, CLS should achieve:

- **Observability:** 95%+ visibility into system state
- **Intelligence:** 70%+ of decisions automated
- **Efficiency:** 50% reduction in manual WO tracking
- **Reliability:** 99%+ uptime with auto-recovery
- **Compliance:** 100% evidence chains for SOT changes
- **Speed:** <5s average WO→result cycle (for simple ops)

---

## Architecture After Enhancements

```
┌────────────────────────────────────────────────────────┐
│ CLS Agent (Enhanced)                                   │
│ • Heartbeat monitoring                                 │
│ • Context database (learning)                          │
│ • Policy engine (decisions)                            │
│ • Tool registry (capabilities)                         │
│ • Result polling (feedback loop)                       │
│ • Metrics collection (observability)                   │
│ • Evidence capture (compliance)                        │
└────────────────────────────────────────────────────────┘
              ↓                           ↑
     [Drop WO]                    [Poll Result]
              ↓                           ↑
┌────────────────────────────────────────────────────────┐
│ Redis (Bidirectional Channel)                          │
│ • wo:queue:* (WO submissions)                          │
│ • wo:result:* (results/status)                         │
│ • cls:ack (ACK notifications)                          │
└────────────────────────────────────────────────────────┘
              ↓                           ↑
     [Process WO]                 [Publish Result]
              ↓                           ↑
┌────────────────────────────────────────────────────────┐
│ CLC (Execution)                                        │
│ • Processes WO                                         │
│ • Executes with evidence                               │
│ • Publishes result to Redis                            │
└────────────────────────────────────────────────────────┘
```

**Key Difference from Current:**
- **Before:** CLS → drops WO → blind (no feedback)
- **After:** CLS → drops WO → polls → receives result → learns → improves

---

## Next Steps

1. **Immediate (Today):**
   - Implement result polling script
   - Test bidirectional flow
   
2. **This Week:**
   - Add metrics collection
   - Create basic dashboard
   
3. **This Month:**
   - Set up context database
   - Implement learning loop
   - Add policy engine

Want me to implement Phase 1.1 (bidirectional bridge) now as a proof of concept?
