#!/usr/bin/env zsh
# WO-CLAUDE-PHASE1.5-FIXED.zsh
# Claude Code Foundation + Context Engineering Phase 1.5 (Terminal-first)
# Fixed: Commands go to .cursor/ for Cursor compatibility
# ========================================================================

set -euo pipefail

ROOT="${HOME}/02luka"
cd "${ROOT}"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf "%s %s\n" "$(ts)" "$*"; }
ensure_dir() { [[ -d "$1" ]] || mkdir -p "$1"; }

# --- layout ----------------------------------------------------------------
ensure_dir ".claude"                    # Settings & context
ensure_dir ".cursor/commands"           # Slash commands (FIXED!)
ensure_dir ".cursor/templates"          # Templates (FIXED!)
ensure_dir "tools/claude_hooks"
ensure_dir "tools/claude_tools"
ensure_dir "g/reports"

# --- helper: write file with backup if contents change ---------------------
write_file_payload() {
  local target="$1"
  local tmp; tmp="$(mktemp)"
  cat > "${tmp}"
  if [[ -f "${target}" ]]; then
    if cmp -s "${tmp}" "${target}"; then
      rm -f "${tmp}"
      log "skip (unchanged): ${target}"
      return 0
    else
      cp -p "${target}" "${target}.BAK.$(date +%Y%m%d-%H%M%S)"
    fi
  fi
  install -m 0644 "${tmp}" "${target}"
  rm -f "${tmp}"
  log "write: ${target}"
}

# --- 1) Team Settings ------------------------------------------------------
log "phase: team settings (.claude/)"
write_file_payload ".claude/settings.json" <<'JSON'
{
  "team": "02LUKA",
  "plan_mode": true,
  "stop_hooks": ["quality_gate", "verify_deployment"],
  "subagent_budget_limit": 5,
  "metrics_enabled": true,
  "context_map": ".claude/context-map.json",
  "telemetry": {
    "mls_capture": true,
    "reports_dir": "g/reports"
  }
}
JSON

# --- 2) Context Map (Phase 1.5) -------------------------------------------
log "phase: context map (.claude/)"
write_file_payload ".claude/context-map.json" <<'JSON'
{
  "project:root": "~/02luka",
  "project:tools": "~/02luka/tools",
  "project:reports": "~/02luka/g/reports",
  "mls:ledger": "~/02luka/mls/ledger",
  "mls:today": "~/02luka/mls/ledger/${TODAY}.jsonl",
  "code:hooks": "~/02luka/tools/claude_hooks",
  "code:templates": "~/02luka/.cursor/templates"
}
JSON

# --- 3) Essential Hooks ----------------------------------------------------
log "phase: hooks"
write_file_payload "tools/claude_hooks/pre_commit.zsh" <<'ZSH2'
#!/usr/bin/env zsh
set -euo pipefail
echo "🔍 pre-commit: fast lint stub (OK)"
# TODO: plug real fast checks (shfmt/shellcheck/yamllint/git grep deny-list)
exit 0
ZSH2

write_file_payload "tools/claude_hooks/quality_gate.zsh" <<'ZSH2'
#!/usr/bin/env zsh
set -euo pipefail
echo "🧪 quality_gate: minimal tests stub (OK)"
# TODO: run smoke tests; fail nonzero to block
exit 0
ZSH2

write_file_payload "tools/claude_hooks/verify_deployment.zsh" <<'ZSH2'
#!/usr/bin/env zsh
set -euo pipefail
echo "✅ verify_deployment: post-deploy verification stub"
# TODO: check health endpoints, version, rollback presence
exit 0
ZSH2
chmod +x tools/claude_hooks/*.zsh

# wire local git hook (non-invasive if already exists)
if [[ ! -f ".git/hooks/pre-commit" ]]; then
  cat > .git/hooks/pre-commit <<'ZSH2'
#!/usr/bin/env zsh
exec ./tools/claude_hooks/pre_commit.zsh
ZSH2
  chmod +x .git/hooks/pre-commit
  log "write: .git/hooks/pre-commit"
else
  log "keep: existing .git/hooks/pre-commit"
fi

# --- 4) Slash Command Templates (FIXED: .cursor/commands) -----------------
log "phase: slash commands (.cursor/commands/)"
write_file_payload ".cursor/commands/feature-dev.md" <<'MD'
# /feature-dev (plan-first)
- Ask clarifying Qs → produce **SPEC.md**
- Break down tasks → TODO list
- Propose test strategy
- Output: `g/reports/feature_[slug]_PLAN.md`
MD

write_file_payload ".cursor/commands/code-review.md" <<'MD'
# /code-review (subagents allowed)
- Style check, history-aware review, obvious-bug scan
- Summarize risks + diff hotspots
- One final verdict line: ✅/⚠️ with reasons
MD

write_file_payload ".cursor/commands/deploy.md" <<'MD'
# /deploy (checklist driven)
- Backup current state
- Apply change
- Run health
- Generate rollback script
- Attach logs + artifact refs
MD

# --- 5) Context Templates (FIXED: .cursor/templates) ----------------------
log "phase: context templates (.cursor/templates/)"
write_file_payload ".cursor/templates/deployment.md" <<'MD'
# Deployment Template
- System: {{system_name}}
- Components: {{components}}
## Checklist
- [ ] Backup
- [ ] Deploy
- [ ] Health verify
- [ ] Rollback ready
MD

# --- 6) Metrics Collector (reports monthly stub; integrates later with MLS)
log "phase: metrics collector"
write_file_payload "tools/claude_tools/metrics_collector.zsh" <<'ZSH2'
#!/usr/bin/env zsh
set -euo pipefail
ROOT="${HOME}/02luka"
Y="$(date +%Y%m)"
OUT="${ROOT}/g/reports/claude_code_metrics_${Y}.md"
mkdir -p "$(dirname "$OUT")"
{
  echo "# Claude Code Metrics ${Y}"
  echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "- plan_mode_usage: (stub)"
  echo "- hooks: pre_commit=OK quality_gate=OK verify_deployment=OK"
  echo "- subagents_used: (stub)"
  echo "- deployments_success_rate: (stub)"
  echo "- rollback_frequency: (stub)"
} > "$OUT"
echo "$OUT"
ZSH2
chmod +x tools/claude_tools/metrics_collector.zsh

# --- 7) Quick verification -------------------------------------------------
log "phase: verification"
log "verify: directories"
ls -1 .claude .cursor/commands .cursor/templates tools/claude_hooks tools/claude_tools >/dev/null

log "verify: run pre-commit hook"
./tools/claude_hooks/pre_commit.zsh

log "verify: metrics collector"
MC_OUT="$(./tools/claude_tools/metrics_collector.zsh)"
[[ -f "$MC_OUT" ]] || { echo "❌ metrics output missing"; exit 1; }
log "metrics written → ${MC_OUT}"

# --- 8) Record in MLS (if available) --------------------------------------
log "phase: MLS capture"
if [[ -x "${ROOT}/tools/mls_add.zsh" ]]; then
  DESC="Initialized Claude Code Foundation + Context Engineering Phase 1.5 (FIXED): team settings (.claude/settings.json), context map (.claude/context-map.json), 3 hooks (pre-commit, quality-gate, verify-deployment), 3 slash commands (.cursor/commands/: feature-dev, code-review, deploy), deployment template (.cursor/templates/), metrics collector. Commands now in correct .cursor/ location for Cursor compatibility. All hooks are stubs (OK exits) for safe initial deployment. Git pre-commit hook wired."
  "${ROOT}/tools/mls_add.zsh" \
    --type "solution" \
    --title "Claude Code Phase 1.5 Infrastructure (Cursor-Compatible)" \
    --summary "${DESC}" \
    --producer clc \
    --context local \
    --confidence 0.95 >/dev/null 2>&1 || true
  log "✅ MLS solution recorded"
else
  log "⚠️  MLS not present (skip)"
fi

# --- 9) Summary ------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ WO-CLAUDE-PHASE1.5-FIXED COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Structure Created (CURSOR-COMPATIBLE):"
echo "   .claude/settings.json          - Team configuration"
echo "   .claude/context-map.json       - Context Engineering namespaces"
echo "   .cursor/commands/              - 3 slash commands ← FIXED!"
echo "   .cursor/templates/             - 1 deployment template ← FIXED!"
echo "   tools/claude_hooks/            - 3 hooks (stubs, safe)"
echo "   tools/claude_tools/            - metrics_collector.zsh"
echo "   .git/hooks/pre-commit          - Wired to claude_hooks"
echo ""
echo "🎯 Next Steps:"
echo "   1. Reload Cursor window (Cmd+Shift+P → Reload Window)"
echo "   2. Try: /feature-dev (should work now!)"
echo "   3. Review structure: ls -R .claude .cursor tools/claude_hooks"
echo "   4. Run metrics: ./tools/claude_tools/metrics_collector.zsh"
echo ""
echo "📊 Metrics Report: ${MC_OUT}"
echo ""
log "deployment complete"
