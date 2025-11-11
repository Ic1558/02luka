#!/usr/bin/env zsh
# Pull latest from memory subtree into _memory/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERR: not inside a git repository: $REPO_ROOT" >&2
  exit 1
fi

if ! git remote get-url memory >/dev/null 2>&1; then
  echo "ERR: remote 'memory' not found. Add it with:" >&2
  echo "  git remote add memory https://github.com/Ic1558/02luka-memory.git" >&2
  exit 1
fi

# Ensure subtree prefix exists
mkdir -p _memory

# Stash uncommitted changes to keep working tree clean
had_stash=false
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ℹ️  Stashing local changes..."
  git stash push -u -m "mem_sync_from_core auto-stash $(date -u +%FT%TZ)"
  had_stash=true
fi

echo "🔄 Pulling subtree from 'memory/main' into _memory/ ..."
# Use --squash to keep repository history small
git subtree pull --prefix=_memory memory main --squash || {
  echo "❗️ Subtree pull failed. If you have conflicts, resolve them and try again." >&2
  if $had_stash; then
    echo "ℹ️  Stash is preserved. After resolving conflicts, run:" >&2
    echo "  git stash pop" >&2
  fi
  exit 1
}

echo "✅ Subtree updated."

if $had_stash; then
  echo "ℹ️  Restoring stashed changes..."
  # If apply fails due to conflicts, leave the stash and exit non-zero so CI hooks can surface it
  git stash pop || {
    echo "❗️ Could not auto-apply stash; please resolve conflicts and run again." >&2
    exit 2
  }
fi

echo "OK: mem_sync_from_core complete."
# make executable: chmod +x tools/$(basename "$0")
