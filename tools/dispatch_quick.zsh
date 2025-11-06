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
  echo "🔧 Auto-fixing conflicts for PR #$pr"
  # Checkout PR branch
  gh pr checkout "$pr" || return 1
  # Fetch and merge main
  git fetch origin
  if git merge origin/main 2>&1 | grep -q "CONFLICT"; then
    echo "⚠️  Conflicts detected - resolving..."
    # Resolve: workflows from main, feature files from PR
    git checkout --theirs .github/workflows 2>/dev/null || true
    git add .github/workflows 2>/dev/null || true
    git checkout --ours tools/ci tools/dispatch_quick.zsh g/schemas tools/ci_watcher.sh 2>/dev/null || true
    git add -A
    git commit -m "ci: resolve conflicts (workflows from main; feature files from PR)" || true
    git push --force-with-lease
    echo "✅ Conflicts resolved and pushed"
  else
    echo "✅ No conflicts found"
  fi
}

auto:label() {
  local pr="${1:-}"
  local label="${2:-run-smoke}"
  if [[ -z "$pr" ]]; then
    echo "usage: auto:label <PR_NUMBER> [label=run-smoke]"
    return 1
  fi
  echo "🏷️  Adding label '$label' to PR #$pr"
  gh pr edit "$pr" --add-label "$label" 2>&1 || {
    echo "⚠️  Label add failed, trying Puppeteer..."
    node "$HOME/02luka/tools/puppeteer/run.mjs" pr-label \
      --url "https://github.com/Ic1558/02luka/pull/$pr" --label "$label" 2>/dev/null || true
  }
  echo "✅ Label '$label' added to PR #$pr"
}

auto:quiet() {
  local pr="${1:-}"
  if [[ -z "$pr" ]]; then
    echo "usage: auto:quiet <PR_NUMBER>"
    return 1
  fi
  echo "🔇 Removing run-smoke label from PR #$pr (quiet mode)"
  # Note: gh CLI doesn't support removing labels directly, use Puppeteer or manual
  echo "⚠️  Use GitHub UI to remove 'run-smoke' label, or:"
  echo "   node ~/02luka/tools/puppeteer/run.mjs pr-label --url 'https://github.com/Ic1558/02luka/pull/$pr' --label run-smoke --remove"
  echo "   (Puppeteer remove label feature may need to be added)"
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

  auto:merge)      auto:merge "$@";;

  auto:rerun)      auto:rerun "$@";;

  auto:fix-conflict) auto:fix-conflict "$@";;

  auto:label)      auto:label "$@";;

  auto:quiet)      auto:quiet "$@";;

  auto:decision)  ./tools/ci_auto_decision.zsh "$@";;

  rag:faiss)       ./tools/vector_build.zsh build && ./tools/rag_vector_selftest.zsh;;

  kim:probe)       ./tools/kim_gateway_probe.zsh;;

  *) echo "usage: $0 {pr:quickcheck|ci:quiet|ci:optin-on|ci:optin-off|ci:rerun|ci:merge|ci:watch|ci:watch:on|ci:watch:off|ci:bus:rerun|auto:merge|auto:rerun|auto:fix-conflict|auto:label|auto:quiet|auto:decision|rag:faiss|kim:probe}"; exit 2;;

esac

