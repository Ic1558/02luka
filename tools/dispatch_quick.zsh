#!/usr/bin/env zsh

# Robust flags for zsh (avoid bash-only "set -euo pipefail" form)

set -e
set -u
set -o pipefail

# --- Helper: paths & deps ---
_PUPPETEER_RUN="$HOME/02luka/tools/puppeteer/run.mjs"
_CI_COORDINATOR="$HOME/02luka/tools/ci/ci_coordinator.cjs"
_REDIS_PUB="$HOME/02luka/tools/ci/redis_pub.zsh"

require() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "❌ missing dependency: $bin" >&2
    return 127
  fi
}

have_node_tool() {
  local path="$1"
  [[ -f "$path" ]] || { echo "❌ missing node tool: $path" >&2; return 2; }
}

# --- Helper: smart label operations (gh → fallback puppeteer) ---
_label_add() {
  local pr="$1"; local label="$2"
  if gh pr edit "$pr" --add-label "$label" >/dev/null 2>&1; then
    echo "✅ added label '$label' via gh"
    return 0
  fi
  echo "⚠️ gh add-label failed, trying Puppeteer..."
  have_node_tool "$_PUPPETEER_RUN" || return 1
  node "$_PUPPETEER_RUN" pr-label \
    --url "https://github.com/Ic1558/02luka/pull/$pr" \
    --label "$label" 2>/dev/null || return 1
  echo "✅ added label '$label' via Puppeteer"
}

_label_remove() {
  local pr="$1"; local label="$2"
  if gh pr edit "$pr" --remove-label "$label" >/dev/null 2>&1; then
    echo "✅ removed label '$label' via gh"
    return 0
  fi
  echo "⚠️ gh remove-label failed, trying Puppeteer..."
  have_node_tool "$_PUPPETEER_RUN" || return 1
  node "$_PUPPETEER_RUN" pr-label \
    --url "https://github.com/Ic1558/02luka/pull/$pr" \
    --label "$label" --remove 2>/dev/null || return 1
  echo "✅ removed label '$label' via Puppeteer"
}

# --- Helper: require gh login (nice error if missing scopes) ---
require_gh_auth() {
  require gh || return 127
  if ! gh auth status >/dev/null 2>&1; then
    echo "❌ gh not authenticated. Run: gh auth login" >&2
    return 1
  fi
}

# --- CI Opt-in shortcuts ---
ci:optin-on() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: ci:optin-on <PR_NUMBER>"
    return 1
  fi
  echo "🟢 adding label run-smoke to PR #$pr"
  _label_add "$pr" "run-smoke"
  if have_node_tool "$_PUPPETEER_RUN"; then
    node "$_PUPPETEER_RUN" pr-title-optin \
      --url "https://github.com/Ic1558/02luka/pull/$pr" --prefix "[run-smoke]"
  fi
}

ci:optin-off() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: ci:optin-off <PR_NUMBER>"
    return 1
  fi
  echo "🔵 removing label run-smoke from PR #$pr"
  _label_remove "$pr" "run-smoke"
}

# --- CI Rerun shortcut ---
ci:rerun() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: ci:rerun <PR_NUMBER>"
    return 1
  fi
  echo "♻️  Re-running all jobs for PR #$pr"
  have_node_tool "$_PUPPETEER_RUN" || return 2
  node "$_PUPPETEER_RUN" pr-rerun \
    --url "https://github.com/Ic1558/02luka/pull/$pr"
}

# --- CI Merge shortcut ---
ci:merge() {
  local pr="${1:-}"
  local mode="${2:-squash}"      # squash|merge|rebase
  local del="${3:-true}"         # true|false
  if [[ -z "$pr" ]]; then
    echo "usage: ci:merge <PR_NUMBER> [mode=squash|merge|rebase] [deleteBranch=true|false]"
    return 1
  fi
  echo "✅ Merging PR #$pr (mode=$mode, deleteBranch=$del)"
  have_node_tool "$_PUPPETEER_RUN" || return 2
  node "$_PUPPETEER_RUN" pr-merge \
    --url "https://github.com/Ic1558/02luka/pull/$pr" \
    --mode "$mode" \
    --delete-branch "$del"
}

# --- CI Watcher shortcuts ---
ci:watch() {
  "$HOME/02luka/tools/ci_watcher.sh" "$@"
}

ci:watch:on() {
  echo "🟢 Starting CI Watcher (LaunchAgent)"
  launchctl unload "$HOME/Library/LaunchAgents/com.02luka.ci-watcher.plist" 2>/dev/null || true
  launchctl load "$HOME/Library/LaunchAgents/com.02luka.ci-watcher.plist"
  launchctl start com.02luka.ci-watcher
  echo "✅ CI Watcher started (runs every 5 minutes)"
}

ci:watch:off() {
  echo "🔴 Stopping CI Watcher (LaunchAgent)"
  launchctl unload "$HOME/Library/LaunchAgents/com.02luka.ci-watcher.plist" 2>/dev/null || true
  echo "✅ CI Watcher stopped"
}

# --- CI Bus shortcuts ---
ci:bus:rerun() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: ci:bus:rerun <PR_NUMBER>"
    return 2
  fi
  # Ensure coordinator is running (idempotent if already running)
  have_node_tool "$_CI_COORDINATOR" && node "$_CI_COORDINATOR" &>/dev/null &
  # Publish rerun request event
  "$_REDIS_PUB" ci:events "$(jq -n \
    --arg repo "Ic1558/02luka" \
    --argjson pr "$pr" \
    --arg type "pr.rerun.request" \
    --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{type:$type, repo:$repo, pr:$pr, time:$time}')"
}

# --- Auto-merge shortcuts ---
auto:merge() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: auto:merge <PR_NUMBER>"
    return 1
  fi
  echo "🟢 Setting auto-merge for PR #$pr (squash + delete branch)"
  gh pr merge "$pr" --auto --squash --delete-branch
  echo "✅ PR #$pr will auto-merge when checks pass"
}

auto:rerun() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: auto:rerun <PR_NUMBER>"
    return 1
  fi
  echo "♻️  Waiting for CI checks to complete for PR #$pr"
  gh pr checks "$pr" -w || true
}

auto:fix-conflict() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: auto:fix-conflict <PR_NUMBER>"
    return 1
  fi
  echo "⚠️ auto:fix-conflict is not implemented in this wrapper."
  if [[ -x "$HOME/02luka/tools/auto_fix_conflict.zsh" ]]; then
    echo "↪︎ Delegating to tools/auto_fix_conflict.zsh..."
    "$HOME/02luka/tools/auto_fix_conflict.zsh" "$pr"
  else
    echo "❌ tools/auto_fix_conflict.zsh not found — aborting."
    return 2
  fi
}

# --- Smart merge (ตรวจ→ตัดสินใจ→merge) ---
pr:smart-merge() {
  local pr="${1:-}"
  local admin="${2:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: pr:smart-merge <PR_NUMBER> [--admin]"
    return 1
  fi
  "$HOME/02luka/tools/pr_smart_merge.zsh" "$pr" "$admin"
}

pr:merge() {
  # Alias for pr:smart-merge
  pr:smart-merge "$@"
}

auto:label() {
  local pr="${1:-}"
  local label="${2:-run-smoke}"
  if [[ -z "$pr" ]]; then
    echo "usage: auto:label <PR_NUMBER> [label=run-smoke]"
    return 1
  fi
  echo "🏷️  Adding label '$label' to PR #$pr"
  _label_add "$pr" "$label"
  echo "✅ Label '$label' added to PR #$pr"
}

auto:quiet() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: auto:quiet <PR_NUMBER>"
    return 1
  fi
  echo "🔇 Removing 'run-smoke' label from PR #$pr (quiet mode)"
  _label_remove "$pr" "run-smoke"
}

task="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

usage() {
  cat <<'USAGE'
usage: tools/dispatch_quick.zsh <task> [args...]

Tasks:
  pr:quickcheck | pr:smart-merge | pr:merge
  ci:quiet | ci:optin-on | ci:optin-off | ci:rerun | ci:merge
  ci:watch | ci:watch:on | ci:watch:off | ci:bus:rerun
  auto:merge | auto:rerun | auto:fix-conflict | auto:label | auto:quiet | auto:decision
  rag:faiss | kim:probe

Notes:
  - Requires: gh (authenticated), jq, node (for Puppeteer tools)
  - Falls back to Puppeteer when gh label operations fail
USAGE
}

case "$task" in

  pr:quickcheck)   ./tools/pr_quickcheck.zsh "$@";;

  ci:quiet)        ./tools/apply_ci_quiet_pack.zsh;;

  ci:optin-on)     ci:optin-on "$@";;

  ci:optin-off)    ci:optin-off "$@";;

  ci:rerun)        ci:rerun "$@";;

  ci:merge)        ci:merge "$@";;

  ci:watch)        ci:watch "$@";;

  ci:watch:on)     ci:watch:on;;

  ci:watch:off)    ci:watch:off;;

  ci:bus:rerun)    ci:bus:rerun "$@";;

  auto:merge)      auto:merge "$@";;

  auto:rerun)      auto:rerun "$@";;

  auto:fix-conflict) auto:fix-conflict "$@";;

  pr:smart-merge)   pr:smart-merge "$@";;

  pr:merge)         pr:smart-merge "$@";;

  auto:label)      auto:label "$@";;

  auto:quiet)      auto:quiet "$@";;

  auto:decision)  ./tools/ci_auto_decision.zsh "$@";;

  rag:faiss)       ./tools/vector_build.zsh build && ./tools/rag_vector_selftest.zsh;;

  kim:probe)       ./tools/kim_gateway_probe.zsh;;

  *) usage; exit 2;;

esac


# ── Phase 20: Hub Index Shortcuts ─────────────────

if [[ "${1:-}" == "hub:index" ]]; then
  shift || true
  exec ./tools/hub_index_now.zsh "$@"
fi

if [[ "${1:-}" == "hub:sync:on" ]]; then
  shift || true
  cp g/launchagents/com.02luka.hub-autoindex.plist ~/Library/LaunchAgents/
  launchctl unload ~/Library/LaunchAgents/com.02luka.hub-autoindex.plist 2>/dev/null || true
  launchctl load ~/Library/LaunchAgents/com.02luka.hub-autoindex.plist
  launchctl list | grep hub-autoindex || true
  exit 0
fi

if [[ "${1:-}" == "hub:sync:off" ]]; then
  shift || true
  launchctl unload ~/Library/LaunchAgents/com.02luka.hub-autoindex.plist 2>/dev/null || true
  exit 0
fi

# ── Session Save Shortcut ─────────────────────────

if [[ "${1:-}" == "save" ]]; then
  shift || true
  exec ~/02luka/tools/session_save.zsh "$@"
fi
