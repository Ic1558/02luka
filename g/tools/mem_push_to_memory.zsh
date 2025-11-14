#!/usr/bin/env zsh
# Push local _memory/ changes to the memory repo's main branch using subtree split
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

if [ ! -d "_memory" ]; then
  echo "ERR: _memory/ directory not found. Did you add the subtree?" >&2
  exit 1
fi

# Ensure everything under _memory is staged/committed before splitting
if ! git diff --quiet -- _memory || ! git diff --cached --quiet -- _memory; then
  echo "📝 Committing local _memory changes..."
  git add _memory
  git commit -m "chore(memory): update subtree contents"
fi

TMP_BRANCH="_mem_split_$(date +%s)"
echo "🔧 Creating subtree split branch: $TMP_BRANCH"
git subtree split --prefix=_memory -b "$TMP_BRANCH" || {
  echo "❗️ Subtree split failed." >&2
  exit 1
}

echo "🚀 Pushing subtree to memory:main ..."
# Push the split branch to the memory remote main
git push memory "$TMP_BRANCH:main" || {
  echo "❗️ Push to memory repo failed." >&2
  git branch -D "$TMP_BRANCH" || true
  exit 1
}

echo "🧹 Cleaning up temp branch..."
git branch -D "$TMP_BRANCH" || true

echo "✅ mem_push_to_memory complete."
# make executable: chmod +x tools/$(basename "$0")
