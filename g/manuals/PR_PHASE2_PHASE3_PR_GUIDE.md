# PR creation steps for Phase 2.2 + Phase 3 runtime state work

Use these commands when preparing the `feature/phase2-runtime-state-validator` branch for review.

## 1) Terminal commands to run

1. Move to the repo and confirm the working tree is clean:

   ```bash
   cd ~/02luka/g
   git status
   ```

2. Push the latest branch state:

   ```bash
   git push origin feature/phase2-runtime-state-validator
   ```

3. Create the PR body file:

   ```bash
   cat > /tmp/pr_phase2_runtime_state_validator.md <<'EOF'
   ## Summary
   
   This PR delivers the full Phase 2.2 + Phase 3 runtime state work:
   
   - Phase 2.2: LaunchAgent runtime validator (cross-check launchctl + Redis)
   - Phase 3.0–3.4: Restore missing scripts, clean up phantom agents, and harden governance
   - Context: First draft of CONTEXT_ENGINEERING_GLOBAL (single-writer + fallback spec)
   
   All changes are already deployed and verified locally; this PR aligns git history with the real running system.
   
   ---
   
   ## Changes
   
   ### 1. Runtime State Validator (Phase 2.2)
   
   - Added `tools/validate_runtime_state.zsh`
   - Scans `~/02luka/LaunchAgents` and `~/Library/LaunchAgents` for `com.02luka.*.plist`
   - For each agent, collects:
     - `launchctl list` PID / exit code
     - Redis `PUBSUB NUMSUB` subscribers for inferred channel (label minus `com.02luka.`)
   - Classifies status: `ok / warn / error`
   - Writes runtime reports to:
   
     - `g/reports/system/launchagents_runtime/RUNTIME_YYYYMMDD_HHMMSS.md`
     - `g/reports/system/launchagents_runtime/RUNTIME_YYYYMMDD_HHMMSS.jsonl`
   
   - Logs operations to `~/02luka/logs/runtime_state.out.log`
   
   This replaces the previous "logical only" health checks with real runtime + Redis validation.
   
   ### 2. LaunchAgent Path Repair (Phase 2.x)
   
   - Fixed 53 LaunchAgent plists that still pointed to pre-migration paths:
     - `~/02luka/tools/...` → `~/02luka/g/tools/...`
     - `~/02luka/run/...`   → `~/02luka/g/run/...` (where applicable)
   - Backed up all modified plists under:
     - `~/02luka/LaunchAgents/backups/20251117_051850/`
   - Documented in:
     - `g/reports/system/launchagent_path_fix_20251117_051850.md`
     - `g/reports/system/CONTEXT_ENGINEERING_AND_LAUNCHAGENT_FIX_20251117.md`
   
   Result: 0 path errors, all referenced scripts now exist under the migrated layout.
   
   ### 3. Phase 3 – Missing Script Restoration
   
   - Examined 29 missing scripts reported by the validator.
   - Restored **10** scripts (2 critical, 2 important, 5 optional shims, 1 more infra) via git history or compat shims:
   
     - Critical:
       - `tools/backup_to_gdrive.zsh`
       - `tools/mary_dispatcher.zsh`
     - Important:
       - `tools/json_wo_processor.zsh`
       - `tools/wo_executor.zsh`
     - Optional (shimmed as delegates to new infrastructure):
       - `tools/dashboard.zsh` → wraps current dashboard/export flow
       - `g/rag/run_api.zsh` → RAG API shim
       - `g/rag/refresh_rag_index.zsh` → RAG refresh shim
       - `tools/redis_to_telegram.py` → Telegram bridge
       - `tools/cls/cls_alerts.zsh` → CLS alerts shim
   
   - Re-ran validators:
     - `g/tools/check_launchagent_scripts.sh` → 0 missing scripts
     - Runtime validator → no LaunchAgent pointing at non-existent scripts
   
   ### 4. Phase 3.4 – Remove Phantom Agents
   
   - Identified agents whose scripts never existed in git history (purely aspirational).
   - Disabled 18 "never-existed" LaunchAgents by moving plists into:
   
     - `~/02luka/LaunchAgents/disabled/never_existed/`
   
   - Updated `LAUNCHAGENT_REGISTRY.md` to match the new reality:
     - Only real, backed-by-script agents remain active.
     - Health reports are now signal-only (no phantom noise).
   
   ### 5. Agent Registry & Governance Docs
   
   - Added `g/docs/LAUNCHAGENT_REGISTRY.md`:
     - Lists all `com.02luka.*` agents, their scripts, purpose, and criticality.
     - Tracks disabled vs active agents.
     - Defines maintenance and refactor safety protocol.
   
   - Added `g/reports/system/PHASE3_MISSING_SCRIPTS_PLAN.md` and `PHASE3_COMPLETION_REPORT_20251117.md`:
     - Document the analysis of missing scripts.
     - Capture the execution steps and final state (29 → 0 missing scripts).
   
   ### 6. Context Engineering Global Spec (DRAFT)
   
   - Added `g/docs/CONTEXT_ENGINEERING_GLOBAL.md` (v1.0.0-DRAFT):
     - Defines layered context architecture (data → context → routing → guardrails → execution).
     - Encodes the **single-writer law**:
       - CLC = primary writer (SIP only)
       - LPE = local fallback writer (SIP only)
       - Codex/Gemini = diff-only / sandbox, no direct writes
       - GG/GC/Mary = orchestrate, plan, and dispatch (no direct writes)
     - Describes fallback ladder when CLC is out of tokens:
       - CLC → LPE → GC (planning only) → queue.
     - Integrates LaunchAgent runtime validator + registry into the context stream.
     - Ties WO routing into the architecture:
       - GG issues WO → Mary dispatches → CLC/LPE apply SIP → GC verifies → MLS logs the lifecycle.
   
   Status: This doc is intentionally marked as **DRAFT**; it reflects current reality + near-term design and will be refined in a separate review.
   
   ---
   
   ## Validation
   
   - `g/tools/check_launchagent_scripts.sh`:
     - ✅ All LaunchAgent program paths exist (0 errors).
   
   - Runtime validator (`tools/validate_runtime_state.zsh`):
     - ✅ LaunchAgents now report real PID/exit/Redis status.
     - ❌ Agents that were previously broken by migration now show correct runtime states.
   
   - Smoke checks:
     - `com.02luka.mary.dispatcher` → started and exited cleanly.
     - `com.02luka.backup.gdrive` → runs, exit 23 due to expected rsync partial transfer (pre-existing behaviour).
   
   ---
   
   ## Risks & Notes
   
   - A small number of "never-existed" LaunchAgents have been disabled rather than implemented; if we later implement those features, their plists can be restored from `LaunchAgents/disabled/never_existed/`.
   - `CONTEXT_ENGINEERING_GLOBAL.md` is a **DRAFT**; it’s meant to be reviewed and tightened in a follow-up PR or commit, but is already useful as a single-source reference.
   
   ---
   
   ## Follow-up Work (Not in this PR)
   
   1. Review and finalize `CONTEXT_ENGINEERING_GLOBAL.md` (DRAFT → OFFICIAL).
   2. Implement the planned components:
      - `core/context/context_loader.zsh`
      - `core/context/normalize_context.zsh`
      - `.context_cache/*` consolidation layer
      - `core/orchestrator/token_monitor.zsh`
   3. Expand dashboards to surface:
      - LaunchAgent runtime reports (`launchagents_runtime/`)
      - Token/fallback events in MLS.
   4. Optionally add a git pre-commit hook to block commits if `check_launchagent_scripts.sh` fails.
   EOF
   ```

4. Create the PR using GitHub CLI:

   ```bash
   gh pr create \
     --base main \
     --head feature/phase2-runtime-state-validator \
     --title "feat(ops): runtime LaunchAgent validator + Phase 3 restoration" \
     --body-file /tmp/pr_phase2_runtime_state_validator.md
   ```

If `gh pr create` opens an editor, review and adjust the body before submitting.

## 2) After the PR exists

- No immediate review steps are required; the follow-up review can finalize `CONTEXT_ENGINEERING_GLOBAL.md` and lock in any checklist items.
- Keep the same branch for any small edits, or open follow-up commits to address review feedback.
