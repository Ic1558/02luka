#!/usr/bin/env zsh
# Rebase CI-touching branches onto origin/main and push the updates.
# Usage: ~/02luka/tools/rebase_ci_branches.zsh [branch ...]

set -euo pipefail

REPO="/Users/icmini/02luka"
cd "$REPO"

BRANCHES=(
  "claude/fix-ocr-validation-telemetry-011CUsYubsSeeV6r8Dhzeaay"  # PR #217
  "claude/phase-19.1-gc-hardening"                               # PR #208
  "claude/phase-19-ci-hygiene-health"                            # PR #207
  "claude/phase-18-ops-sandbox-runner"                           # PR #206
  "claude/phase-17-ci-observer"                                  # PR #205
  "claude/fix-dangling-symlink-chmod-011CUrnthGyres339RYKRCTj"   # PR #193
  "claude/exploration-and-research-011CUrRfU1hPvBmZXZqjgN9M"     # PR #184
)

if (( $# > 0 )); then
  BRANCHES=("$@")
fi

if git status --porcelain | grep -q '.'; then
  echo "❌ Working tree is dirty. Please commit or stash changes first." >&2
  exit 1
fi

git fetch origin --prune

current_branch=$(git rev-parse --abbrev-ref HEAD)
success_list=()
failure_list=()

rebased_branches=()

for branch in "${BRANCHES[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚙️  Processing ${branch}"

  if ! git ls-remote --exit-code --heads origin "${branch}" >/dev/null 2>&1; then
    echo "  ↪️  Skipping (branch not found on origin)"
    failure_list+=("${branch} (missing on origin)")
    continue
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}"; then
    git switch "${branch}"
    git reset --hard "origin/${branch}"
  else
    git switch --force-create "${branch}" "origin/${branch}"
  fi

  echo "  ↪️  Rebasing onto origin/main..."
  if git rebase origin/main; then
    echo "  ✅ Rebase successful. Pushing updated branch..."
    git push --force-with-lease origin "${branch}"
    success_list+=("${branch}")
    rebased_branches+=("${branch}")
  else
    echo "  ❌ Rebase failed for ${branch}. Aborting..."
    git rebase --abort || true
    failure_list+=("${branch}")
  fi
done

git switch "${current_branch}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Rebase Summary"
echo "  ✅ Successful: ${#success_list[@]}"
for b in "${success_list[@]:-}"; do
  echo "    - ${b}"
done

echo "  ❌ Failed: ${#failure_list[@]}"
for b in "${failure_list[@]:-}"; do
  echo "    - ${b}"
done

if (( ${#failure_list[@]} > 0 )); then
  exit 1
fi
