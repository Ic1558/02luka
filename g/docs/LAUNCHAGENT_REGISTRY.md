# 02luka LaunchAgent Registry
**Last updated:** 2025-11-17 05:38 AM
**Purpose:** Single source of truth for all `com.02luka.*` LaunchAgents

---

## Purpose

This registry documents all LaunchAgent services in the 02luka system:
- **What**: Service name and description
- **Where**: Script path and dependencies
- **When**: Run schedule (interval, calendar, watch path)
- **Why**: Business purpose and criticality
- **Health**: Current operational status

**Maintenance:** Update this registry when adding, removing, or modifying agents.

---

## Legend

### Classification
- **Critical**: System cannot function without this agent
- **Important**: Significant degradation if missing
- **Optional**: Nice-to-have, non-blocking
- **Deprecated**: Scheduled for removal

### Status
- **ok**: Running normally, no errors
- **warning**: Running but with issues
- **error**: Failing, needs attention
- **disabled**: Intentionally stopped
- **missing**: Script not found (needs restore or removal)

---

## Agents

| Label | Script / Command | Channel | Role / Description | Class | Status |
|-------|------------------|---------|-------------------|-------|--------|
| **Core System** |
| com.02luka.runtime_state | g/tools/validate_runtime_state.zsh | runtime_state | Runtime LaunchAgent validator | Critical | ok |
| com.02luka.health.dashboard | g/run/health_dashboard.cjs | health | Generate health JSON dashboard | Critical | ok |
| com.02luka.mls.cursor.watcher | g/tools/mls_cursor_watcher.zsh | mls | Capture prompts to MLS from Cursor | Critical | ok |
| **Backup & Sync** |
| com.02luka.backup.gdrive | g/tools/backup_to_gdrive.zsh | backup | Smart rsync to Google Drive | Critical | **missing** |
| com.02luka.nas_backup | g/tools/nas_backup.zsh | backup | Backup to NAS storage | Important | ok |
| **Data Collection** |
| com.02luka.adaptive.collector.daily | g/tools/adaptive_collector_daily.zsh | adaptive | Daily adaptive data collection | Important | ok |
| com.02luka.adaptive.proposal.gen | g/tools/adaptive_proposal_gen.zsh | adaptive | Generate improvement proposals | Optional | ok |
| com.02luka.claude.metrics.collector | g/tools/claude_metrics_collector.zsh | metrics | Collect Claude API usage | Important | ok |
| **CLS (Claude Loop System)** |
| com.02luka.cls.cmdin | g/tools/cls/cls_cmdin_worker.zsh | cls_cmdin | CLS command inbox processor | Critical | **missing** |
| com.02luka.cls.reflection.daily | g/tools/cls/cls_reflect.zsh | cls_reflect | Daily CLS reflection | Important | **missing** |
| com.02luka.cls.rotate | g/tools/cls/cls_rotate_logs.zsh | cls | Rotate CLS logs | Optional | **missing** |
| com.02luka.cls.alerts | g/tools/cls/cls_alerts.zsh | cls_alerts | CLS alert notifications | Optional | **missing** |
| com.02luka.cls.wo.cleanup | g/tools/cls/cls_wo_cleanup.zsh | cls | Clean up old work orders | Optional | ok |
| com.02luka.cls.brain.update | g/tools/cls/cls_brain_update.zsh | cls | Update CLS brain | Optional | **missing** |
| **Dashboard & UI** |
| com.02luka.dashboard | g/tools/dashboard.zsh | dashboard | Launch dashboard server | Important | **missing** |
| com.02luka.expense.autodeploy | g/tools/deploy_expense_pages.zsh | expense | Auto-deploy expense pages | Important | ok |
| com.02luka.expense.watch | g/tools/deploy_expense_pages_watch.zsh | expense | Watch expense files for changes | Optional | **missing** |
| com.02luka.expense.ocr | g/tools/expense/ocr_and_append.zsh | expense | OCR expense receipts | Optional | **missing** |
| **Governance & Logging** |
| com.02luka.governance.logger | g/tools/governance_logger.zsh | governance | Log governance events | Important | **missing** |
| com.02luka.log.rotate | g/tools/log_rotate.zsh | logs | Rotate system logs | Optional | **missing** |
| com.02luka.context-summary | g/tools/run_context_summary.zsh | context | Generate context summaries | Optional | **missing** |
| **GG (Governance Gate)** |
| com.02luka.gg.nlp-bridge | g/tools/gg_nlp_bridge.zsh | gg | NLP bridge for governance | Important | ok |
| com.02luka.gg.mcp-bridge | g/tools/gg_mcp_bridge.zsh | gg | MCP bridge for governance | Important | **missing** |
| **CI/CD & Automation** |
| com.02luka.auto.commit | g/tools/auto_commit.zsh | ci | Auto-commit WIP changes | Optional | ok |
| com.02luka.ci-coordinator | g/tools/ci_coordinator.zsh | ci | Coordinate CI workflows | Important | ok |
| com.02luka.ci-watcher | g/tools/ci_watcher.zsh | ci | Watch CI status | Optional | ok |
| **Watchers** |
| com.02luka.mary.dispatcher | g/tools/watchers/mary_dispatcher.zsh | mary | Dispatch Mary work orders | Critical | **missing** |
| com.02luka.watcher.acct_docs | g/tools/watchers/acct_docs.zsh | watchers | Watch accounting docs | Optional | **missing** |
| com.02luka.watcher.expense_slips | g/tools/watchers/expense_slips.zsh | watchers | Watch expense slips | Optional | **missing** |
| com.02luka.watcher.notes_rollup | g/tools/watchers/notes_rollup.zsh | watchers | Rollup notes | Optional | **missing** |
| **Agents & Processors** |
| com.02luka.json_wo_processor | agents/json_wo_processor/json_wo_processor.zsh | wo | Process JSON work orders | Important | **missing** |
| com.02luka.wo_executor | agents/wo_executor/wo_executor.zsh | wo | Execute work orders | Important | **missing** |
| com.02luka.apply_patch_processor | agents/apply_patch_processor/apply_patch_processor.zsh | patches | Process and apply patches | Optional | **missing** |
| **R&D & Experiments** |
| com.02luka.autoapprove.rd | g/tools/autoapprove_rd.zsh | rd | Auto-approve R&D proposals | Optional | **missing** |
| com.02luka.autopilot.digest | g/tools/autopilot_digest.zsh | autopilot | Autopilot daily digest | Optional | **missing** |
| **Redis & Integration** |
| com.02luka.shell.subscriber | g/tools/shell_subscriber.zsh | redis | Redis shell subscriber | Optional | **missing** |
| com.02luka.redis_to_telegram | g/tools/redis_to_telegram.py | redis | Forward Redis to Telegram | Optional | **missing** |
| com.02luka.integration | g/tools/integration.zsh | integration | System integration glue | Important | **missing** |
| **Memory & Knowledge** |
| com.02luka.mem.sync_from_core | g/tools/mem_sync_from_core.zsh | mem | Sync memory from core | Optional | **missing** |
| **RAG & Search** |
| com.02luka.rag.api | g/rag/run_api.zsh | rag | RAG API server | Optional | **missing** |
| com.02luka.rag.refresh_index | g/rag/refresh_rag_index.zsh | rag | Refresh RAG index | Optional | **missing** |
| com.02luka.mcp-search | mcp/servers/mcp-search/index.js | mcp | MCP search server | Optional | **missing** |

---

## Critical Path

**Minimum Viable System (must be running):**

1. ✅ `runtime_state` - Health monitoring
2. ✅ `health.dashboard` - Status visibility
3. ✅ `mls.cursor.watcher` - Learning capture
4. ❌ `backup.gdrive` - Data protection (**RESTORE REQUIRED**)
5. ❌ `mary.dispatcher` - Work orchestration (**RESTORE REQUIRED**)

---

## Missing Scripts Analysis

**Total missing:** 29 scripts
**Critical missing:** 2 (backup.gdrive, mary.dispatcher)
**Important missing:** 7
**Optional missing:** 20

### Next Actions

1. **Restore from git history:**
   ```bash
   # Find deletion commit
   git log --all --full-history -- "path/to/script.zsh"

   # Restore from commit before deletion
   git checkout <commit>^ -- "path/to/script.zsh"
   ```

2. **Disable obsolete agents:**
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.AGENT_NAME.plist
   mv ~/Library/LaunchAgents/com.02luka.AGENT_NAME.plist ~/02luka/LaunchAgents/disabled/
   ```

3. **Create stubs for reimplemented:**
   - If functionality moved elsewhere, create stub that points to new location
   - Update plist or remove agent if no longer needed

---

## Validation

**Pre-commit check:**
```bash
bash ~/02luka/g/tools/check_launchagent_scripts.sh
```

**Runtime validation:**
```bash
bash ~/02luka/g/tools/validate_runtime_state.zsh
```

**Health check:**
```bash
launchctl list | grep com.02luka | awk '{print $3, $1}'
```

---

## Maintenance Protocol

### Adding New Agent

1. Create script in `g/tools/` or `g/run/`
2. Create plist in `~/Library/LaunchAgents/`
3. Test: `launchctl load <plist> && launchctl start <label>`
4. Add entry to this registry
5. Run validation: `bash g/tools/check_launchagent_scripts.sh`
6. Commit both script and registry update

### Modifying Agent

1. Update script
2. If path changes: Update plist
3. Reload: `launchctl unload <plist> && launchctl load <plist>`
4. Update registry if classification/description changes
5. Run validation

### Removing Agent

1. Unload: `launchctl unload <plist>`
2. Move plist to `~/02luka/LaunchAgents/disabled/`
3. Update registry (mark as deprecated or remove entry)
4. Git commit with explanation

### Refactoring (Moving Files)

**CRITICAL:** Follow refactoring safety protocol from `CONTEXT_ENGINEERING_AND_LAUNCHAGENT_FIX_20251117.md`

1. **BEFORE moving files:**
   ```bash
   # Find all references
   grep -r "filename.zsh" ~/Library/LaunchAgents/

   # Document impact
   echo "Moving X affects: ..." > /tmp/refactor_impact.txt
   ```

2. **Create new location:**
   ```bash
   # COPY first (don't move yet)
   cp old/path/script.zsh new/path/script.zsh
   git add new/path/script.zsh
   git commit -m "feat: add script at new location"
   ```

3. **Update plists:**
   ```bash
   # Update all affected plists
   sed -i.bak 's|old/path|new/path|g' ~/Library/LaunchAgents/*.plist

   # Reload agents
   for plist in ~/Library/LaunchAgents/com.02luka.*.plist; do
     launchctl unload "$plist" 2>/dev/null || true
     launchctl load "$plist" 2>/dev/null || true
   done
   ```

4. **Validate:**
   ```bash
   bash ~/02luka/g/tools/check_launchagent_scripts.sh
   ```

5. **THEN delete old files:**
   ```bash
   git rm old/path/script.zsh
   git commit -m "refactor: remove old script location"
   ```

---

## Troubleshooting

### Agent Not Starting
```bash
# Check plist syntax
plutil -lint ~/Library/LaunchAgents/com.02luka.AGENT.plist

# Check script exists
ls -lh $(plutil -extract ProgramArguments.1 raw ~/Library/LaunchAgents/com.02luka.AGENT.plist)

# Check permissions
chmod +x /path/to/script.zsh

# Check logs
tail -f ~/Library/Logs/com.02luka.AGENT/launchd.err
```

### Mass Failures

**Symptoms:** Many agents failing simultaneously, high system load

**Likely Cause:** Path refactoring without plist updates

**Solution:**
```bash
# Run path fixer (updates paths and reloads)
bash ~/02luka/g/tools/fix_launchagent_paths.zsh

# Verify
bash ~/02luka/g/tools/check_launchagent_scripts.sh
```

---

## Related Documentation

- **Fix Report:** `g/reports/system/CONTEXT_ENGINEERING_AND_LAUNCHAGENT_FIX_20251117.md`
- **Runtime Reports:** `g/reports/system/launchagents_runtime/`
- **Backups:** `~/02luka/LaunchAgents/backups/`
- **Tools:**
  - `g/tools/fix_launchagent_paths.zsh` - Automated path fixer
  - `g/tools/check_launchagent_scripts.sh` - Script existence validator
  - `g/tools/validate_launchagent_paths.zsh` - Enhanced validator with warnings

---

**Registry Status:** Initial version based on Nov 17 LaunchAgent audit
**Next Update:** After Phase 3 (restore/disable missing scripts)
