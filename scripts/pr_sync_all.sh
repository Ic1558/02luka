#!/usr/bin/env bash
set -euo pipefail

# Sync all open PRs locally without needing Cursor "Apply".
# Requires: GitHub CLI (gh) authenticated.

open_prs=$(gh pr list --state open --json number --jq '.[].number' || true)

if [ -z "${open_prs}" ]; then
  echo "No open PRs found."
  exit 0
fi

for n in ${open_prs}; do
  echo "🔄 syncing PR #${n}"
  # Create or switch to the PR branch locally
  gh pr checkout "${n}" >/dev/null 2>&1 || true
  # Ensure we are tracking the upstream branch
  git fetch --all --prune
  # Reset local branch to upstream to reflect latest commits from the PR
  git reset --hard "@{u}" || true
done

echo "✅ done"


