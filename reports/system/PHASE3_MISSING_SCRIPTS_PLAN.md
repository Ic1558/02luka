# Phase 3: Missing Scripts Recovery Plan
**Date:** 2025-11-17 05:38 AM
**Status:** READY TO EXECUTE
**Objective:** Restore or disable 29 missing LaunchAgent scripts

---

## Executive Summary

**Current State:**
- ✅ 53 LaunchAgents path-fixed and working
- ❌ 29 scripts completely missing (deleted during refactor)
- ✅ Prevention tools in place
- ✅ LaunchAgent Registry created

**Phase 3 Goal:**
Restore critical/important scripts, disable obsolete agents, achieve 100% operational state.

---

## Missing Scripts Classification

### 🔴 Critical (RESTORE IMMEDIATELY - 2 scripts)

| Script | Agent | Why Critical | Action |
|--------|-------|-------------|--------|
| `g/tools/backup_to_gdrive.zsh` | com.02luka.backup.gdrive | **Data protection** - Smart rsync to Google Drive | **RESTORE** from git |
| `g/tools/watchers/mary_dispatcher.zsh` | com.02luka.mary.dispatcher | **Work orchestration** - Dispatch work orders | **RESTORE** from git |

**Impact if not restored:** Data loss risk, work orchestration broken

---

### 🟡 Important (RESTORE NEXT - 7 scripts)

| Script | Agent | Purpose | Action |
|--------|-------|---------|--------|
| `agents/json_wo_processor/json_wo_processor.zsh` | com.02luka.json_wo_processor | Process JSON work orders | RESTORE |
| `agents/wo_executor/wo_executor.zsh` | com.02luka.wo_executor | Execute work orders | RESTORE |
| `g/tools/gg_mcp_bridge.zsh` | com.02luka.gg.mcp-bridge | GG MCP bridge | RESTORE |
| `g/tools/governance_logger.zsh` | com.02luka.governance.logger | Log governance events | RESTORE |
| `g/tools/dashboard.zsh` | com.02luka.dashboard | Dashboard server | RESTORE or REPLACE (if dashboard_export.zsh replaces it) |
| `g/tools/integration.zsh` | com.02luka.integration | System integration glue | RESTORE |
| `g/tools/cls/cls_cmdin_worker.zsh` | com.02luka.cls.cmdin | CLS command processor | RESTORE |

**Impact if not restored:** Work order system degraded, governance gaps, integration issues

---

### 🟢 Optional (EVALUATE - 20 scripts)

| Script | Agent | Purpose | Action |
|--------|-------|---------|--------|
| **CLS Scripts (4)** |
| `g/tools/cls/cls_reflect.zsh` | com.02luka.cls.reflection.daily | Daily reflection | Evaluate: Still used? |
| `g/tools/cls/cls_rotate_logs.zsh` | com.02luka.cls.rotate | Log rotation | Evaluate: Redundant with log_rotate.zsh? |
| `g/tools/cls/cls_brain_update.zsh` | com.02luka.cls.brain.update | Brain updates | Evaluate: Still relevant? |
| `g/tools/cls/cls_alerts.zsh` | com.02luka.cls.alerts | CLS alerts | Evaluate: Still used? |
| **R&D Scripts (2)** |
| `g/tools/autoapprove_rd.zsh` | com.02luka.autoapprove.rd | Auto-approve R&D | Disable: Manual approval better |
| `g/tools/autopilot_digest.zsh` | com.02luka.autopilot.digest | Daily digest | Evaluate: Still needed? |
| **Watcher Scripts (3)** |
| `g/tools/watchers/acct_docs.zsh` | com.02luka.watcher.acct_docs | Watch acct docs | Evaluate: Still monitoring? |
| `g/tools/watchers/expense_slips.zsh` | com.02luka.watcher.expense_slips | Watch expense slips | Evaluate: Redundant with ocr? |
| `g/tools/watchers/notes_rollup.zsh` | com.02luka.watcher.notes_rollup | Rollup notes | Evaluate: Still used? |
| **Expense Scripts (2)** |
| `g/tools/deploy_expense_pages_watch.zsh` | com.02luka.expense.watch | Watch expense files | Evaluate: deploy_expense_pages.zsh enough? |
| `g/tools/expense/ocr_and_append.zsh` | com.02luka.expense.ocr | OCR receipts | Evaluate: Still using OCR? |
| **Infrastructure (5)** |
| `g/tools/run_context_summary.zsh` | com.02luka.context-summary | Context summaries | Evaluate: Generated where now? |
| `g/tools/log_rotate.zsh` | com.02luka.log.rotate | Rotate logs | Evaluate: System handles this? |
| `g/tools/shell_subscriber.zsh` | com.02luka.shell.subscriber | Redis subscriber | Evaluate: Still using? |
| `g/tools/redis_to_telegram.py` | com.02luka.redis_to_telegram | Redis→Telegram bridge | Evaluate: Telegram integration active? |
| `g/tools/mem_sync_from_core.zsh` | com.02luka.mem.sync_from_core | Memory sync | Evaluate: MLS replaces this? |
| **RAG/Search (3)** |
| `g/rag/run_api.zsh` | com.02luka.rag.api | RAG API | Evaluate: knowledge/index.cjs replaces? |
| `g/rag/refresh_rag_index.zsh` | com.02luka.rag.refresh_index | Refresh index | Evaluate: Auto-updated now? |
| `mcp/servers/mcp-search/index.js` | com.02luka.mcp-search | MCP search | Evaluate: MCP still used? |
| **Patches (1)** |
| `agents/apply_patch_processor/apply_patch_processor.zsh` | com.02luka.apply_patch_processor | Apply patches | Evaluate: Still using patch workflow? |

**Decision Criteria:**
- If functionality moved → Create redirect stub
- If obsolete → Disable agent
- If uncertain → Ask user

---

## Execution Plan

### Step 1: Restore Critical Scripts (15 min)

```bash
cd ~/02luka

# 1. backup_to_gdrive.zsh
git log --all --full-history -- "**/backup_to_gdrive.zsh" | head -20
# Find last commit that had it
git checkout <commit>^ -- tools/backup_to_gdrive.zsh
mv tools/backup_to_gdrive.zsh g/tools/
git add g/tools/backup_to_gdrive.zsh

# 2. mary_dispatcher.zsh
git log --all --full-history -- "**/mary_dispatcher.zsh" | head -20
git checkout <commit>^ -- tools/watchers/mary_dispatcher.zsh
mv tools/watchers/mary_dispatcher.zsh g/tools/watchers/
git add g/tools/watchers/mary_dispatcher.zsh

# Commit
cd g
git commit -m "fix(ops): restore critical LaunchAgent scripts (Phase 3.1)

- Restored backup_to_gdrive.zsh (data protection)
- Restored mary_dispatcher.zsh (work orchestration)

Related: Phase 3 missing scripts recovery"

# Test agents start
launchctl start com.02luka.backup.gdrive
launchctl start com.02luka.mary.dispatcher
```

### Step 2: Restore Important Scripts (20 min)

```bash
# Work order processors
git checkout <commit>^ -- agents/json_wo_processor/json_wo_processor.zsh
git checkout <commit>^ -- agents/wo_executor/wo_executor.zsh

# Infrastructure
git checkout <commit>^ -- tools/gg_mcp_bridge.zsh
git checkout <commit>^ -- tools/governance_logger.zsh
git checkout <commit>^ -- tools/dashboard.zsh
git checkout <commit>^ -- tools/integration.zsh
git checkout <commit>^ -- tools/cls/cls_cmdin_worker.zsh

# Move to proper locations and commit
```

### Step 3: Evaluate Optional Scripts (30 min)

**For each optional script:**

1. **Check if functionality exists elsewhere:**
   ```bash
   # Example: Is RAG API replaced by knowledge/index.cjs?
   ls -lh ~/02luka/knowledge/index.cjs
   # If yes → Disable agent, don't restore
   ```

2. **Check recent usage:**
   ```bash
   # Example: When was cls_reflect.zsh last used?
   tail -f ~/Library/Logs/com.02luka.cls.reflection.daily/*.err
   # If no recent activity → Disable agent
   ```

3. **Decision matrix:**
   - **Replaced:** Create redirect stub (optional) + disable agent
   - **Obsolete:** Disable agent
   - **Still needed:** Restore from git
   - **Uncertain:** Ask user

### Step 4: Disable Obsolete Agents (10 min)

```bash
#!/bin/bash
# disable_obsolete_agents.sh

OBSOLETE_AGENTS=(
  "com.02luka.autoapprove.rd"
  "com.02luka.rag.api"
  "com.02luka.rag.refresh_index"
  # ... add more after evaluation
)

mkdir -p ~/02luka/LaunchAgents/disabled/phase3_obsolete

for agent in "${OBSOLETE_AGENTS[@]}"; do
  plist="$HOME/Library/LaunchAgents/${agent}.plist"
  if [[ -f "$plist" ]]; then
    echo "Disabling: $agent"
    launchctl unload "$plist" 2>/dev/null || true
    mv "$plist" ~/02luka/LaunchAgents/disabled/phase3_obsolete/
  fi
done

echo "✅ Obsolete agents disabled"
```

### Step 5: Update Registry & Validate (10 min)

```bash
# Update LAUNCHAGENT_REGISTRY.md with final status
# Mark restored scripts as "ok"
# Mark disabled as "disabled"

# Run validation
bash ~/02luka/g/tools/check_launchagent_scripts.sh

# Check all agents
launchctl list | grep com.02luka

# Generate final report
```

---

## Quick Decision Questions (for user)

**Before starting Phase 3, please confirm:**

1. **Dashboard:** Is `dashboard.zsh` still needed or replaced by `dashboard_export.zsh`?
   - [ ] Restore dashboard.zsh
   - [ ] Disable (dashboard_export.zsh is enough)

2. **RAG System:** Is RAG still using `g/rag/run_api.zsh` or replaced by `knowledge/index.cjs`?
   - [ ] Restore RAG scripts
   - [ ] Disable (knowledge/index.cjs replaces it)

3. **CLS Alerts:** Still using `cls_alerts.zsh` for notifications?
   - [ ] Restore
   - [ ] Disable (not used)

4. **Autopilot Digest:** Still want daily autopilot digest?
   - [ ] Restore
   - [ ] Disable (not needed)

5. **Telegram Bridge:** Is `redis_to_telegram.py` still in use?
   - [ ] Restore
   - [ ] Disable (Telegram not used)

**OR:**
- [ ] Auto-decide: Disable all optional scripts marked "Evaluate", only restore Critical + Important

---

## Success Criteria

- [x] LaunchAgent Registry created
- [ ] 2 critical scripts restored and tested
- [ ] 7 important scripts restored and tested
- [ ] 20 optional scripts evaluated (restore or disable)
- [ ] All agents either "ok" or "disabled" (no "missing")
- [ ] Validation passes: 0 errors
- [ ] Final report generated

---

## Timeline

- **Critical:** 15 min (IMMEDIATE)
- **Important:** 20 min (TODAY)
- **Optional Evaluation:** 30 min (user input + execution)
- **Cleanup:** 10 min
- **Total:** ~75 min (1.25 hours)

---

## Rollback Plan

If any restored script causes issues:

```bash
# Disable problematic agent
launchctl unload ~/Library/LaunchAgents/com.02luka.PROBLEM.plist

# Move to quarantine
mv ~/Library/LaunchAgents/com.02luka.PROBLEM.plist ~/02luka/LaunchAgents/disabled/quarantine/

# Revert script from git
cd ~/02luka/g
git revert <commit>

# Or just delete
rm g/tools/problematic_script.zsh
```

---

## Post-Phase 3 Actions

1. **Add pre-commit hook:**
   ```bash
   cp ~/02luka/g/tools/check_launchagent_scripts.sh .git/hooks/pre-commit
   chmod +x .git/hooks/pre-commit
   ```

2. **Schedule monthly validation:**
   ```bash
   # Add to cron or LaunchAgent
   # Run: bash ~/02luka/g/tools/validate_runtime_state.zsh
   ```

3. **Update documentation:**
   - Remove aspirational features from 02luka.md
   - Update CLAUDE.md with actual system state
   - Create REFACTORING_CHECKLIST.md

---

## Ready to Execute

**Current Status:** Plan complete, awaiting user decision on optional scripts

**Recommended Action:** Start with Critical + Important (Step 1-2), then ask user about Optional

**Next Command:**
```bash
# Start Phase 3.1: Restore critical scripts
cd ~/02luka && git log --all --full-history --oneline -- "**/backup_to_gdrive.zsh" | head -10
```

---

**Report Generated:** 2025-11-17 05:38 AM
**Phase:** 3 (Recovery)
**Dependencies:** Phase 2.2 complete (path fixes done)
