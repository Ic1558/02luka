# System Snapshot — 20260121_032346

- Timestamp: Wed, 21 Jan 2026 03:23:46 +0700
- Host: Ittipongs-Mac-mini.local
- Branch: main
- Commit: 89df678a
- Snapshot label: default
- Agents up: 16 running, 72 stopped, 53 failed

## Git Status
```
 M ledger/ap_io_v31.jsonl
?? ../agents/qa_v4/qa_worker.py
?? reports/system/system_snapshot_20260121_031607_default.md
?? reports/system/system_snapshot_20260121_031913_default.md
?? reports/system/system_snapshot_20260121_032319_default.md
?? reports/system/system_snapshot_20260121_032330_default.md
?? reports/system/system_snapshot_20260121_032346_default.md
?? tools/raycast_create_wo.zsh
?? ../pytest.ini
```

Recent commits:
```
89df678a fix(pro_docs): fail-closed deterministic contracts for plan/dry_run/apply
de725229 fix(snapshot): resolve zsh read-only variable error + finalize pro_docs updates
7bc9259b Add professional rules engine for doc specs
b08d44f3 feat(menu-bar): add dashboard, local server, and snapshot integration
b3ec282e chore: add finalize_merge cleanup script
```

## LaunchAgent / Services (02luka)
```
PID STATUS LABEL
-	78	com.02luka.nlp-dispatcher
-	78	com.02luka.claude.metrics.collector
-	78	com.02luka.health.dashboard
-	78	com.02luka.phase15.quickhealth
-	1	com.02luka.wo_executor.codex
2812	0	com.02luka.mls_watcher
-	0	com.02luka.gemini-context-sync
2848	0	com.02luka.n8n.server
-	127	com.02luka.expense.autodeploy
-	127	com.02luka.localtruth
2783	0	com.02luka.mary-coo
-	127	com.02luka.antigravity-claude-proxy
-	0	com.02luka.mcp.fs
-	0	com.02luka.shell-watcher
-	1	com.02luka.notify.worker
-	0	com.02luka.mls.ledger.monitor
-	0	com.02luka.followup.generator
2829	0	com.02luka.rag.api
-	0	com.02luka.adaptive.collector.daily
3155	-15	com.02luka.mls-symlink-guard
-	78	com.02luka.dashboard.daily
92553	3	com.02luka.gh-monitor
-	0	com.02luka.mary-dispatch
-	1	com.02luka.gmx-clc-orchestrator
2752	0	com.02luka.clc-executor
-	78	com.02luka.memory.metrics
23960	78	com.02luka.clc_local
-	1	com.02luka.bridge.knowledge.sync
-	2	com.02luka.antigravity.liam_worker
-	78	com.02luka.memory.digest.daily
2786	0	com.02luka.atg_runner
-	78	com.02luka.rnd.consumer
53646	-15	com.02luka.mary-bridge
-	127	com.02luka.guard-health.daily
-	127	com.02luka.json_wo_processor
-	127	com.02luka.clc.local
-	0	com.02luka.clc-bridge
-	127	com.02luka.fs_watcher
-	78	com.02luka.rnd.daily_digest
-	78	com.02luka.ci-watcher
-	1	com.02luka.shell-executor
-	2	com.02luka.clc_wo_bridge
-	1	com.02luka.mls.status.update
79580	0	com.02luka.lac-daemon
-	0	com.02luka.mls.cursor.watcher
-	0	com.02luka.governance.weekly
-	78	com.02luka.mary.metrics.daily
-	127	com.02luka.mcp.health
-	1	com.02luka.perf-collect-daily
-	78	com.02luka.gg_session_worker
-	1	com.02luka.opal-api
-	127	com.02luka.build-latest-status
2745	0	com.02luka.memory.hub
-	127	com.02luka.followup_tracker
-	0	com.02luka.adaptive.proposal.gen
-	78	com.02luka.ci-coordinator
-	254	com.02luka.mcp.memory
-	1	com.02luka.clc-worker
-	78	com.02luka.rnd.autopilot
-	0	com.02luka.atg_gc
-	0	com.02luka.pr11.healthcheck
-	0	com.02luka.redis_chain_status
2807	0	com.02luka.dashboard.server
-	0	com.02luka.health_monitor
2821	0	com.02luka.cloudflared.dashboard
-	78	com.02luka.nas_backup_daily
-	0	com.02luka.lac-metrics-exporter.daily
-	127	com.02luka.wo_executor
-	78	com.02luka.opal-healthv2
-	78	com.02luka.kim.bot
-	0	com.02luka.auto-commit
-	0	com.02luka.telemetry_rotate
-	127	com.02luka.sync.gdrive.4h
2827	0	com.02luka.mary-gateway-v3
-	78	com.02luka.lac-activity-daily
-	78	com.02luka.pr_score_rnd_dispatcher
-	78	com.02luka.gg.nlp-bridge
-	0	org.02luka.sot.render
-	0	com.02luka.ram-monitor
-	78	com.02luka.rag.probe
-	78	com.02luka.rnd.gate
-	0	com.02luka.delegation-watchdog
-	78	com.02luka.sot_dashboard_sync
-	2	com.02luka.doctor
38708	0	com.02luka.mcp.puppeteer
-	0	com.02luka.gmx_cli
-	78	com.02luka.backup.gdrive
-	0	com.02luka.telegram-bridge
```

## MCP / Health Snapshot
_No reports/mcp_health/latest.md found_

## Telemetry (unified) — basic stats
_No telemetry_unified/unified.jsonl found_

## Work Order Snapshot
⚠️ Failed to collect WO dashboard status (curl exit 7) for http://localhost:3030/api/wos

## Notes
- Report stored at reports/system/system_snapshot_20260121_032346_default.md
