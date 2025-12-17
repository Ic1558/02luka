# LaunchAgent Priority Classification (P0 vs Optional)
**Generated:** 2025-12-18  
**Purpose:** Dashboard status classification for "fully green" monitoring

---

## P0 (Critical) - Must Be Running

These LaunchAgents are essential for core system operation. Dashboard should show RED if any are not running.

**Note**: This P0 set reflects the **actual execution surface** (what's running and used daily), not aspirational architecture.

### Core Execution
- `com.02luka.mary-gateway-v3` - Gateway v3 router (if deployed)
- `com.02luka.clc-executor` - Executes CLC work orders (recently fixed)
- `com.02luka.rag.api` - RAG API server (recently fixed, port 8765)
- `com.02luka.memory.hub` - Memory hub (if using shared memory system)
- `com.02luka.mcp.fs` - MCP filesystem bridge

---

## Optional - Nice to Have Running

These LaunchAgents provide useful features but system can operate without them. Dashboard can show YELLOW if not running.

### WO Pipeline (Legacy/Alternative)
- `com.02luka.json_wo_processor` - Parses WO files and enriches state (alternative to direct CLC)
- `com.02luka.wo_executor` - Runs or routes work orders (alternative to CLC executor)
- `com.02luka.followup_tracker` - Computes derived metadata (age, staleness)
- `com.02luka.wo_pipeline_guardrail` - Validates end-to-end WO pipeline health
- `com.02luka.lpe.worker` - Local Patch Engine worker (applies patches)

### Routing (Legacy)
- `com.02luka.mary-dispatch` - Routes internal work orders to correct agent (legacy, gateway-v3 replaces)
- `com.02luka.mary-bridge` - Bridge for Mary routing system (legacy)

### CLC (Backup/Alternative)
- `com.02luka.clc_local` - Local CLC executor (backup/alternative to clc-executor)

### MLS (Optional Enhancement)
- `com.02luka.mls.cursor.watcher` - Monitors Cursor IDE for prompts, records to MLS
- `com.02luka.mls.ledger.monitor` - Monitors MLS ledger health

### MCP (Optional)
- `com.02luka.gg.mcp-bridge` - MCP bridge routes tasks from external sources to GG

### Monitoring & Health
- `com.02luka.health_monitor` - System health monitoring
- `com.02luka.health.dashboard` - Health dashboard server
- `com.02luka.phase15.quickhealth` - Phase 15 quick health check
- `com.02luka.opal-healthv2` - Opal health check v2
- `com.02luka.pr11.healthcheck` - PR11 health check
- `com.02luka.mcp.health` - MCP health monitoring
- `com.02luka.rag.probe` - RAG probe/monitoring

### Shell & Execution
- `com.02luka.shell-watcher` - Watches shell commands
- `com.02luka.shell-executor` - Executes shell commands from Redis

### NLP & Communication
- `com.02luka.gg.nlp-bridge` - NLP bridge for GG
- `com.02luka.nlp-dispatcher` - NLP dispatcher
- `com.02luka.telegram-bridge` - Telegram bridge

### MLS Extensions
- `com.02luka.mls_watcher` - MLS watcher (alternative to cursor.watcher)
- `com.02luka.mls.status.update` - MLS status updater

### Memory Extensions
- `com.02luka.memory.metrics` - Memory metrics collector
- `com.02luka.memory.digest.daily` - Daily memory digest

### MCP Extensions
- `com.02luka.mcp.memory` - MCP memory bridge
- `com.02luka.mcp.puppeteer` - MCP puppeteer bridge

### Work Order Extensions
- `com.02luka.clc-bridge` - CLC bridge
- `com.02luka.clc-worker` - CLC worker
- `com.02luka.clc_wo_bridge` - CLC WO bridge
- `com.02luka.cls.wo.cleanup` - CLS WO cleanup
- `com.02luka.followup.generator` - Followup generator

### Dashboard & UI
- `com.02luka.dashboard.server` - Dashboard server
- `com.02luka.dashboard.daily` - Daily dashboard updates
- `com.02luka.cloudflared.dashboard` - Cloudflare tunnel for dashboard
- `com.02luka.sot_dashboard_sync` - SOT dashboard sync

### Notifications
- `com.02luka.notify.worker` - Notification worker

### Automation & Scheduling
- `com.02luka.auto-commit` - Auto git commit
- `com.02luka.governance.weekly` - Weekly governance reports
- `com.02luka.guard-health.daily` - Daily guard health check
- `com.02luka.lac-activity-daily` - LAC daily activity
- `com.02luka.lac-manager` - LAC manager

### Integrations
- `com.02luka.gh-monitor` - GitHub monitor
- `com.02luka.kim.bot` - Kim bot
- `com.02luka.opal-api` - Opal API
- `com.02luka.n8n.server` - n8n server
- `com.02luka.antigravity.liam_worker` - Antigravity Liam worker

### Metrics & Telemetry
- `com.02luka.claude.metrics.collector` - Claude metrics collector
- `com.02luka.mary.metrics.daily` - Mary daily metrics
- `com.02luka.perf-collect-daily` - Performance collection daily
- `com.02luka.ram-monitor` - RAM monitor

### Backup & Sync
- `com.02luka.nas_backup_daily` - NAS daily backup
- `com.02luka.sync.gdrive.4h` - Google Drive sync (4h interval)
- `com.02luka.backup.gdrive` - Google Drive backup
- `com.02luka.bridge.knowledge.sync` - Knowledge bridge sync

### R&D & Experimental
- `com.02luka.rnd.autopilot` - R&D autopilot
- `com.02luka.rnd.consumer` - R&D consumer
- `com.02luka.rnd.daily_digest` - R&D daily digest
- `com.02luka.rnd.gate` - R&D gate
- `com.02luka.pr_score_rnd_dispatcher` - PR score R&D dispatcher

### Adaptive Systems
- `com.02luka.adaptive.collector.daily` - Adaptive daily collector
- `com.02luka.adaptive.proposal.gen` - Adaptive proposal generator

### Other
- `com.02luka.build-latest-status` - Build latest status
- `com.02luka.ci-coordinator` - CI coordinator
- `com.02luka.ci-watcher` - CI watcher
- `com.02luka.delegation-watchdog` - Delegation watchdog
- `com.02luka.doctor` - Doctor agent
- `com.02luka.expense.autodeploy` - Expense autodeploy
- `com.02luka.gmx-clc-orchestrator` - GMX CLC orchestrator
- `com.02luka.gmx_cli` - GMX CLI
- `com.02luka.gg_session_worker` - GG session worker
- `com.02luka.hub-autoindex` - Hub auto-index
- `com.02luka.localtruth` - Local truth
- `com.02luka.redis_chain_status` - Redis chain status

---

## Dashboard Status Logic

### "Fully Green" Criteria:
- ✅ All P0 LaunchAgents must be running (have PID)
- ⚠️ Optional LaunchAgents can be stopped (not critical)

### Status Colors:
- **GREEN**: All P0 agents running
- **YELLOW**: Some optional agents stopped (but all P0 running)
- **RED**: One or more P0 agents not running

### Status Check Command:
```bash
# Check P0 agents
for agent in com.02luka.json_wo_processor com.02luka.wo_executor com.02luka.followup_tracker com.02luka.wo_pipeline_guardrail com.02luka.lpe.worker com.02luka.mary-dispatch com.02luka.mary-bridge com.02luka.clc-executor com.02luka.mls.cursor.watcher com.02luka.mls.ledger.monitor com.02luka.gg.mcp-bridge com.02luka.mcp.fs com.02luka.memory.hub com.02luka.rag.api; do
  pid=$(launchctl list "$agent" 2>/dev/null | grep -E "^\s*\"PID\"" | awk '{print $3}' | tr -d ';')
  if [ -z "$pid" ] || [ "$pid" = "0" ]; then
    echo "❌ $agent: NOT RUNNING"
  else
    echo "✅ $agent: RUNNING (PID: $pid)"
  fi
done
```

### Recommended (JSON/MD dashboard helper)
```bash
# JSON
python3 g/tools/launchagent_status.py

# Markdown block
python3 g/tools/launchagent_status.py --md
```

---

## Notes

- This list is based on:
  - `g/docs/LAUNCHAGENT_REGISTRY.md` (Critical flag)
  - `g/reports/system/launchagent_repair_PLAN_v01.md` (Core Services)
  - Recent fixes (clc-executor, rag.api)
  
- If a LaunchAgent is not listed here, assume it's **Optional** until verified.

- P0 agents are those that would break core functionality if stopped:
  - WO processing pipeline
  - Routing/dispatch system
  - CLC execution
  - MLS recording
  - MCP bridges
  - RAG API (if used)
