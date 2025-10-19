#!/usr/bin/env bash
# Post-commit hook: Auto-record significant commits to vector memory
# Install: ln -s ../../scripts/post-commit-memory-hook.sh .git/hooks/post-commit

set -euo pipefail

# Source universal path resolver
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Only record if memory module exists and node is available
if [ ! -f "$REPO_ROOT/memory/index.cjs" ]; then
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  exit 0
fi

# Get commit information
COMMIT_HASH=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --pretty=%B | head -1)
COMMIT_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD | wc -l | tr -d ' ')

# Only record significant commits (exclude trivial changes)
# Skip: docs-only, minor fixes, formatting
if echo "$COMMIT_MSG" | grep -qE "^(docs:|style:|chore:|refactor: minor)"; then
  exit 0
fi

# Skip: Very small commits (< 3 files changed)
if [ "$COMMIT_FILES" -lt 3 ]; then
  exit 0
fi

# Determine memory kind based on commit message prefix
KIND="plan"  # default
if echo "$COMMIT_MSG" | grep -qE "^feat:"; then
  KIND="plan"
elif echo "$COMMIT_MSG" | grep -qE "^fix:"; then
  KIND="solution"
elif echo "$COMMIT_MSG" | grep -qE "^perf:|^optimize:"; then
  KIND="insight"
fi

# Build memory text
MEMORY_TEXT="Commit $COMMIT_HASH: $COMMIT_MSG ($COMMIT_FILES files changed)"

# Record in memory (silently fail if error - don't block commit)
node "$REPO_ROOT/memory/index.cjs" --remember "$KIND" "$MEMORY_TEXT" >/dev/null 2>&1 || true

exit 0
