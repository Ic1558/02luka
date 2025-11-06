#!/usr/bin/env zsh
set -euo pipefail

# --- CI Opt-in shortcuts ---
ci:optin-on() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: ci:optin-on <PR_NUMBER>"
    return 1
  fi
  echo "🟢 adding label run-smoke to PR #$pr"
  node "$HOME/02luka/tools/puppeteer/run.mjs" pr-label \
    --url "https://github.com/Ic1558/02luka/pull/$pr" --label run-smoke
  node "$HOME/02luka/tools/puppeteer/run.mjs" pr-title-optin \
    --url "https://github.com/Ic1558/02luka/pull/$pr" --prefix "[run-smoke]"
}

ci:optin-off() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: ci:optin-off <PR_NUMBER>"
    return 1
  fi
  echo "🔵 removing run-smoke label from PR #$pr (manual only via UI for now)"
  echo "เปิด PR แล้วเอา label ออกทาง sidebar ได้เลย"
}

# --- CI Rerun shortcut ---
ci:rerun() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: ci:rerun <PR_NUMBER>"
    return 1
  fi
  echo "♻️  Re-running all jobs for PR #$pr"
  node "$HOME/02luka/tools/puppeteer/run.mjs" pr-rerun \
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
  node "$HOME/02luka/tools/puppeteer/run.mjs" pr-merge \
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
  node "$HOME/02luka/tools/ci/ci_coordinator.cjs" &>/dev/null &
  # Publish rerun request event
  "$HOME/02luka/tools/ci/redis_pub.zsh" ci:events "$(jq -n \
    --arg repo "Ic1558/02luka" \
    --argjson pr "$pr" \
    --arg type "pr.rerun.request" \
    --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{type:$type, repo:$repo, pr:$pr, time:$time}')"
}

task="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

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

  rag:faiss)       ./tools/vector_build.zsh build && ./tools/rag_vector_selftest.zsh;;

  kim:probe)       ./tools/kim_gateway_probe.zsh;;

  *) echo "usage: $0 {pr:quickcheck|ci:quiet|ci:optin-on|ci:optin-off|ci:rerun|ci:merge|ci:watch|ci:watch:on|ci:watch:off|ci:bus:rerun|rag:faiss|kim:probe}"; exit 2;;

esac

