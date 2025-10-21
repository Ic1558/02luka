# 02luka System Map (auto)

## Roots & Roles
- g/: infra tools, validators, helpers
- run/: runtime artifacts, status, reports
- boss/: your workspace (inbox/sent/deliverables/dropbox)
- f/ai_context/: resolver mapping & context data
- Forbidden for AI writes: a/, c/, o/, s/ (human-only)

## Tree (depth 2)
    .
    ├── .DS_Store
    ├── .backup
    │   ├── phase1_fixes_20251021_120610
    │   ├── phase2_fixes_20251021_123028
    │   └── phase3_fixes_20251021_175543
    ├── .codex
    │   ├── .last_autosave_hash
    │   ├── CONTEXT_SEED.md
    │   ├── GUARDRAILS.md
    │   ├── PATH_KEYS.md
    │   ├── PREPROMPT.md
    │   ├── TASK_RECIPES.md
    │   ├── adapt_style.sh
    │   ├── auto_start.sh
    │   ├── auto_stop.sh
    │   ├── autoload.md
    │   ├── autosave
    │   ├── autosave_memory.sh
    │   ├── behavioral_learning.py
    │   ├── codex.env.yml
    │   ├── codex_memory_bridge.yml
    │   ├── context_summary.md
    │   ├── doc_write_through.sh
    │   ├── hybrid_memory_system.md
    │   ├── load_context.sh
    │   ├── locks
    │   ├── memory_dedupe.sh
    │   ├── memory_merge_bridge.sh
    │   ├── memory_merge_rules.yml
    │   ├── patch_codex_review_fix.sh
    │   ├── preflight.sh
    │   ├── prompts
    │   ├── save_context.sh
    │   ├── startup_hook.sh
    │   ├── style_adaptations.yml
    │   └── user_profile.yml
    ├── .cursor
    │   ├── mcp.example.json
    │   ├── memory_context.md
    │   └── settings.json
    ├── .cursorignore
    ├── .cursorrules
    ├── .devcontainer
    │   ├── devcontainer.json
    │   └── mcp_config.json
    ├── .env.example
    ├── .env.local.example
    ├── .gitattributes
    ├── .github
    │   ├── PULL_REQUEST_TEMPLATE.md
    │   └── workflows
    ├── .gitignore
    ├── .gitignore.tmp
    ├── .nojekyll
    ├── .secrets
    │   ├── README.md
    │   ├── github_pat
    │   └── secrets.template
    ├── .trash
    │   ├── backup
    │   ├── parent_backups_251011_0216
    │   └── temp
    ├── .vscode
    │   ├── launch.json
    │   ├── settings.json
    │   └── tasks.json
    ├── 02luka.md
    ├── 02luka_daily.md
    ├── CLAUDE.md
    ├── Library
    │   └── LaunchAgents
    ├── Makefile
    ├── README.md
    ├── SYSTEM_VERIFICATION.md
    ├── a
    │   ├── memory
    │   ├── memory_center
    │   └── section
    ├── agents
    │   ├── boss
    │   ├── clc
    │   ├── codex
    │   ├── discord
    │   ├── gc
    │   ├── gg
    │   ├── index.md
    │   ├── local
    │   ├── lukacode
    │   ├── mary
    │   ├── paula
    │   ├── reflection
    │   ├── reportbot
    │   └── suggestions
    ├── apps
    │   ├── assistant-api
    │   └── assistant-ui
    ├── boss
    │   ├── alerts
    │   ├── deliverables
    │   ├── dropbox
    │   ├── inbox
    │   ├── legacy_parent
    │   ├── memory
    │   ├── outbox
    │   ├── reports
    │   └── sent
    ├── boss-api
    │   ├── .env
    │   ├── .env.sample
    │   ├── .wrangler
    │   ├── README.md
    │   ├── data
    │   ├── package-lock.json
    │   ├── package.json
    │   ├── scripts
    │   ├── server.cjs
    │   ├── src
    │   ├── telemetry.cjs
    │   ├── worker.js
    │   └── wrangler.toml
    ├── boss-ui
    │   ├── README.md
    │   ├── apps
    │   ├── dist
    │   ├── index.html
    │   ├── luka.html
    │   ├── package-lock.json
    │   ├── package.json
    │   ├── public
    │   ├── shared
    │   ├── src
    │   ├── vite.config.js
    │   └── workspace.html
    ├── bridge
    │   └── inbox
    ├── cls_dev_bootcheck.sh
    ├── config
    │   ├── findability_queries.txt
    │   ├── migration.enforced
    │   ├── project_keywords.tsv
    │   └── zones.txt
    ├── contracts
    │   ├── chat.request.example.json
    │   ├── chat.response.example.json
    │   └── mcp-tools.schema.json
    ├── crawler
    │   ├── crawl.py
    │   ├── ingest.py
    │   └── requirements.txt
    ├── data
    ├── docs
    │   ├── 02luka.md
    │   ├── ARCH_OVERVIEW.md
    │   ├── ASSISTANT_ROLES.md
    │   ├── AUTOSTART_CONFIG.md
    │   ├── BREAKGLASS.md
    │   ├── CHAT_WINDOW_README.md
    │   ├── CODEX_DEV_RUNBOOK.md
    │   ├── CODEX_MASTER_READINESS.md
    │   ├── CODEx_INSTRUCTIONS.md
    │   ├── CONTEXT_ENGINEERING.md
    │   ├── DEPLOY.md
    │   ├── DISCORD_OPS_INTEGRATION.md
    │   ├── GITHUB_SECRETS_SETUP.md
    │   ├── HOST_SYMLINK_SETUP.md
    │   ├── MANUAL_SETUP_CHECKLIST.md
    │   ├── MCP_FINAL_CONFIG.md
    │   ├── MCP_SIMPLIFIED_CONFIG.md
    │   ├── MEMORY_HOOKS_SETUP.md
    │   ├── MEMORY_SHARING_GUIDE.md
    │   ├── MIGRATION_OCT2025.md
    │   ├── ONBOARDING_BOSS.md
    │   ├── PHASE5_CHECKLIST.md
    │   ├── PHASE7_2_DELEGATION.md
    │   ├── PHASE7_5_KNOWLEDGE.md
    │   ├── PHASE7_COGNITIVE_LAYER.md
    │   ├── PROJECT_SUMMARY.md
    │   ├── PROMPTS_STANDARD.md
    │   ├── REMOTE_ACCESS.md
    │   ├── REPOSITORY_STRUCTURE.md
    │   ├── SECRETS_SETUP.md
    │   ├── SECURITY_GOVERNANCE.md
    │   ├── TASK_BUS_SYSTEM.md
    │   ├── TELEMETRY.md
    │   ├── api_endpoints.md
    │   ├── architecture.md
    │   ├── chatgpt_native_app.md
    │   ├── context
    │   ├── gg-local-bridge.md
    │   ├── integrations
    │   ├── ops
    │   └── persistent_change_workflow.md
    ├── f
    │   ├── ai_context
    │   └── bridge
    ├── g
    │   ├── .DS_Store
    │   ├── DELEGATION_QUICK_REF.md
    │   ├── FILE_DISCOVERY_PROTOCOL.md
    │   ├── backups
    │   ├── bridge
    │   ├── bridges
    │   ├── concepts
    │   ├── connectors
    │   ├── fixed_launchagents
    │   ├── logs
    │   ├── manuals
    │   ├── memory
    │   ├── metrics
    │   ├── reports
    │   ├── state
    │   ├── telemetry
    │   ├── tests
    │   ├── tools
    │   └── web
    ├── gateway
    │   └── health_proxy.js
    ├── index.html
    ├── integrations
    │   ├── mt4
    │   └── mt5
    ├── knowledge
    │   ├── 02luka.db
    │   ├── README.md
    │   ├── cli
    │   ├── cls_metrics_schema.sql
    │   ├── evaluator.cjs
    │   ├── exports
    │   ├── index.cjs
    │   ├── init.cjs
    │   ├── lib
    │   ├── package.json
    │   ├── schema.sql
    │   └── sync.cjs
    ├── luka.html
    ├── memory
    │   ├── clc
    │   └── index.cjs
    ├── package-lock.json
    ├── package.json
    ├── packages
    │   ├── context
    │   ├── fs
    │   ├── io
    │   ├── memory
    │   └── skills
    ├── playwright.config.ts
    ├── projects
    │   ├── diplomat110
    │   ├── ideo-mobi-rama9
    │   └── system-stabilization
    ├── prompts
    │   ├── golden_prompt.md
    │   └── master_prompt.md
    ├── queue
    │   ├── done
    │   ├── examples
    │   ├── failed
    │   ├── inbox
    │   └── running
    ├── reports
    │   └── proof
    ├── run
    │   ├── auto_context
    │   ├── auto_train.sh
    │   ├── change_units
    │   ├── crawl.sh
    │   ├── daily_reports
    │   ├── deploy_self_healing_node.sh
    │   ├── dev_debug_suite.sh
    │   ├── dev_morning.sh
    │   ├── dev_up.sh
    │   ├── dev_up_final.sh
    │   ├── dev_up_simple.sh
    │   ├── dev_up_working.sh
    │   ├── discord_notify_example.sh
    │   ├── install_auto_recovery_launchagent.sh
    │   ├── merge_discovery_20251006_043155.log
    │   ├── morning_auto_check_drive_recovery.sh
    │   ├── ops_atomic.sh
    │   ├── setup_self_healing_node.sh
    │   ├── smoke_api_ui.sh
    │   ├── status
    │   ├── system_discovery_20251006_043124.json
    │   ├── system_discovery_20251006_043124.log
    │   ├── system_discovery_20251007_015950.json
    │   ├── system_discovery_20251007_015950.log
    │   ├── system_discovery_20251007_025445.json
    │   ├── system_discovery_20251007_025445.log
    │   ├── system_discovery_20251007_025445_P2.json
    │   ├── system_status.v2.json
    │   ├── tickets
    │   ├── validate_full.sh
    │   └── worklog
    ├── sample_ea
    │   └── SolunaSignalSample.mq4
    ├── scripts
    │   ├── agent_audit.sh
    │   ├── apply_moveplan.zsh
    │   ├── apply_option_c_hardening.sh
    │   ├── apply_wrapper.sh
    │   ├── archive_legacy.sh
    │   ├── auto_resolve_conflicts.sh
    │   ├── auto_tunnel.zsh
    │   ├── backfill_project_by_keywords.sh
    │   ├── boss_find.sh
    │   ├── boss_refresh.sh
    │   ├── centralize.sh
    │   ├── cleanup_home_backups.sh
    │   ├── cleanup_memory.sh
    │   ├── cls_activate.sh
    │   ├── cls_daily_monitoring.sh
    │   ├── cls_devcontainer_bootcheck.sh
    │   ├── cls_discord_report.sh
    │   ├── cls_final_cutover.sh
    │   ├── cls_final_night_setup.sh
    │   ├── cls_go_live_5min.sh
    │   ├── cls_go_live_final.sh
    │   ├── cls_go_live_validation.sh
    │   ├── cls_go_live_verification.sh
    │   ├── cls_headless_verification.sh
    │   ├── cls_immediate_fix.sh
    │   ├── cls_macos_headless_complete.sh
    │   ├── cls_macos_launchagent.sh
    │   ├── cls_morning_check.sh
    │   ├── cls_night_mode.sh
    │   ├── cls_ops_runbook_pdf.sh
    │   ├── cls_quick_test.sh
    │   ├── cls_rollback.sh
    │   ├── cls_runbook.sh
    │   ├── cls_shell_fix.sh
    │   ├── cls_shell_test.sh
    │   ├── cls_sleep_mode.sh
    │   ├── cls_troubleshooting.sh
    │   ├── cls_verification_with_upload.sh
    │   ├── cls_workflow_orchestrator.sh
    │   ├── codex_batch_apply.sh
    │   ├── codex_workflow_assistant.sh
    │   ├── cutover_launchagents.sh
    │   ├── deploy_dashboard.sh
    │   ├── dev-setup.zsh
    │   ├── dev_server.sh
    │   ├── disable_headless_mode.sh
    │   ├── discord_ops_notify.sh
    │   ├── enable_headless_mode.sh
    │   ├── expose_gateways.sh
    │   ├── fix_xcode_for_node_gyp.sh
    │   ├── generate_boss_catalogs.sh
    │   ├── generate_boss_daily_html.sh
    │   ├── generate_moveplan.zsh
    │   ├── generate_telemetry_report.sh
    │   ├── gg_local_bridge_setup.sh
    │   ├── health_check.sh
    │   ├── health_proxy_launcher.sh
    │   ├── init_agents_spine.sh
    │   ├── install_all_workflow_automation.sh
    │   ├── install_cls_launchagent.sh
    │   ├── install_workflow_launchagent.sh
    │   ├── knowledge_full_sync.sh
    │   ├── migrate_parent_legacy.sh
    │   ├── new_mem.zsh
    │   ├── new_ops_menu.zsh
    │   ├── new_report.zsh
    │   ├── post-commit-memory-hook.sh
    │   ├── pr_push_reportbot.sh
    │   ├── pr_sync_all.sh
    │   ├── proof_harness.zsh
    │   ├── proof_harness_simple.sh
    │   ├── remember_task.sh
    │   ├── repo_root_resolver.sh
    │   ├── run_cls_review.sh
    │   ├── run_local.sh
    │   ├── run_self_review.sh
    │   ├── setup-artifact-retention.sh
    │   ├── setup-branch-protection.sh
    │   ├── setup_cursor_memory_bridge.sh
    │   ├── setup_github_secrets_cli.sh
    │   ├── setup_memory_merge_bridge.zsh
    │   ├── smoke.sh
    │   ├── smoke_wrapper.sh
    │   ├── sync_smoke_test.sh
    │   ├── test_ci_after_secrets.sh
    │   ├── tunnel
    │   ├── uninstall_cls_launchagent.sh
    │   ├── validate_cls_launchagent.sh
    │   ├── validate_workspace.sh
    │   └── verify_system.sh
    ├── setup
    │   └── post_setup.sh
    ├── signals
    │   ├── models
    │   ├── requirements.txt
    │   └── server.py
    ├── test-results
    │   ├── .last-run.json
    │   └── g-tests-ui-ui.smoke-Luka-U-e2c6f--html-and-shows-key-widgets-chromium
    └── views
        ├── agents
        ├── ops
        └── projects
    
    140 directories, 261 files

## Known Services
- boss-api:     boss-api/.env.sample:3:PORT=4000
    boss-api/.env.sample:4:PORT=11434
    boss-api/package.json:7:PORT=4000
    boss-api/package.json:8:PORT=4000
    boss-api/.env:6:PORT=4000
    boss-api/.env:7:PORT=11434
    boss-api/server.cjs:14:PORT = process.env.PORT || 4000
    boss-api/src/index.js:18:PORT = process.env.PORT || 4000

## Data Flow
dropbox → (router) → inbox/sent (query/answer) → deliverables
