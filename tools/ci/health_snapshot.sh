#!/usr/bin/env bash
set -euo pipefail

# CI Health Snapshot — summarize open PR checks quickly
# Usage: tools/ci/health_snapshot.sh [limit]
limit="${1:-20}"

ts="$(date -u +%Y%m%dT%H%M%SZ)"
out="g/reports/ci/health_${ts}.md"
mkdir -p "$(dirname "$out")"

echo "# CI Health Snapshot (${ts}Z)" > "$out"
echo >> "$out"

if ! command -v gh >/dev/null 2>&1; then
  echo "**gh not found** — install GitHub CLI to use this tool." >> "$out"
  echo "Wrote: $out"
  exit 0
fi

# List open PRs (basic)
echo "## Open PRs (top ${limit})" >> "$out"
gh pr list --state open --limit "$limit" \
  --json number,title,headRefName,author,labels \
  --jq '.[] | "- PR #\(.number): \(.title)  (`\(.headRefName)`)  by \(.author.login)  labels=" + ( [.labels[].name] | join(",") )' \
  >> "$out" || echo "- (failed to list PRs)" >> "$out"

echo -e "\n## Checks (quick status)" >> "$out"
# For each PR, show checks compactly
mapfile -t prs < <(gh pr list --state open --limit "$limit" --json number --jq '.[].number' 2>/dev/null || true)
for pr in "${prs[@]:-}"; do
  echo -e "\n### PR #${pr}" >> "$out"
  gh pr checks "$pr" 2>/dev/null >> "$out" || echo "(no checks yet)" >> "$out"
done

echo -e "\n---\nGenerated at ${ts}Z" >> "$out"
echo "Wrote: $out"

