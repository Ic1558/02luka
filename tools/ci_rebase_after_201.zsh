#!/usr/bin/env zsh
set -euo pipefail

REPO="${1:-Ic1558/02luka}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
need gh; need jq; need git

echo "🔎 Scanning open PRs that modify .github/workflows/ci.yml (excluding #201)…"
TMP="$(mktemp)"
gh pr list --repo "$REPO" --state open --limit 100 --json number,title,headRefName > "$TMP"

PRS=()
while read -r PR; do
  if gh pr view "$PR" --repo "$REPO" --json files | jq -e '.files[].path | select(.==".github/workflows/ci.yml")' >/dev/null; then
    [[ "$PR" == "201" ]] && continue
    PRS+=("$PR")
  fi
done < <(jq -r '.[].number' "$TMP")

if [[ ${#PRS[@]} -eq 0 ]]; then
  echo "✅ No PRs (other than #201) modify ci.yml"
  exit 0
fi

echo "➡️  Will rebase onto origin/main: ${PRS[@]}"
git fetch origin main

for PR in "${PRS[@]}"; do
  META="$(gh pr view "$PR" --repo "$REPO" --json headRefName,title,mergeable)"
  BRANCH="$(echo "$META" | jq -r '.headRefName')"
  TITLE="$(echo "$META" | jq -r '.title')"

  echo ""
  echo "────────────────────────────────────────────────────"
  echo "PR #$PR  ($BRANCH)"
  echo "$TITLE"
  echo "────────────────────────────────────────────────────"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] git fetch origin $BRANCH"
    echo "[DRY-RUN] git checkout -B $BRANCH origin/$BRANCH"
    echo "[DRY-RUN] git rebase origin/main"
    echo "[DRY-RUN] git push --force-with-lease origin $BRANCH"
    continue
  fi

  git fetch origin "$BRANCH"
  git checkout -B "$BRANCH" "origin/$BRANCH"
  git branch -f "backup-before-rebase-$BRANCH" "origin/$BRANCH" || true

  set +e
  git rebase origin/main
  RB=$?
  set -e

  if [[ $RB -ne 0 ]]; then
    echo "❌ Rebase conflict on $BRANCH. Resolve and push manually:"
    echo "   git status ; git rebase --continue  # or --abort"
    continue
  fi

  git push --force-with-lease origin "$BRANCH"
  echo "✅ Rebased & pushed: $BRANCH"
done

echo ""
echo "🎯 Done. Re-run PR checks after #201 merges."
