#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'USAGE'
Usage: pr_create_auto_merge.sh [options]

Creates a pull request for the current branch, generates a diff/risk summary,
pushes the branch, and optionally enables auto-merge via the GitHub CLI.

Options:
  -b, --base <branch>         Base branch for the PR (default: main)
  -r, --remote <name>         Git remote to push to (default: origin)
  -t, --title <title>         PR title (default: latest commit title)
  -m, --merge-method <type>   Auto-merge method: squash, merge, or rebase (default: squash)
  -B, --body-file <path>      File containing a custom PR body
  -l, --label <label>         Label to apply to the PR (repeatable)
      --no-auto-merge         Do not enable auto-merge after PR creation
      --draft                 Create the PR as a draft
      --dry-run               Print the summary without creating a PR
  -h, --help                  Show this help message

Environment:
  Requires the GitHub CLI (`gh`) to be installed and authenticated.
USAGE
}

BASE_BRANCH="main"
REMOTE_NAME="origin"
MERGE_METHOD="squash"
TITLE=""
BODY_FILE=""
NO_AUTO_MERGE=false
DRY_RUN=false
IS_DRAFT=false
LABELS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--base)
      BASE_BRANCH="$2"
      shift 2
      ;;
    -r|--remote)
      REMOTE_NAME="$2"
      shift 2
      ;;
    -t|--title)
      TITLE="$2"
      shift 2
      ;;
    -m|--merge-method)
      MERGE_METHOD="$2"
      shift 2
      ;;
    -B|--body-file)
      BODY_FILE="$2"
      shift 2
      ;;
    -l|--label)
      LABELS+=("$2")
      shift 2
      ;;
    --no-auto-merge)
      NO_AUTO_MERGE=true
      shift
      ;;
    --draft)
      IS_DRAFT=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is required." >&2
  exit 1
fi

case "$MERGE_METHOD" in
  squash|merge|rebase)
    ;;
  *)
    echo "Error: merge method must be one of squash, merge, or rebase." >&2
    exit 1
    ;;
esac

if [[ -n "$BODY_FILE" && ! -f "$BODY_FILE" ]]; then
  echo "Error: body file '$BODY_FILE' not found." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree must be clean before creating a PR." >&2
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == "$BASE_BRANCH" ]]; then
  echo "Error: current branch and base branch are the same ($BASE_BRANCH)." >&2
  exit 1
fi

if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
  echo "Fetching base branch '$BASE_BRANCH' from $REMOTE_NAME..."
  git fetch "$REMOTE_NAME" "$BASE_BRANCH":"refs/heads/$BASE_BRANCH"
else
  git fetch "$REMOTE_NAME" "$BASE_BRANCH" >/dev/null 2>&1 || true
fi

RANGE="$BASE_BRANCH...$CURRENT_BRANCH"

if [[ -z $(git rev-list "$RANGE") ]]; then
  echo "Error: no commits found between $BASE_BRANCH and $CURRENT_BRANCH." >&2
  exit 1
fi

SHORTSTAT=$(git diff --shortstat "$RANGE" || true)
DIFFSTAT=$(git diff --stat "$RANGE" || true)
CHANGED_FILES_LIST=$(git diff --name-only "$RANGE" || true)
COMMITS=$(git log --pretty=format:"- %s (%h)" "$BASE_BRANCH..$CURRENT_BRANCH" || true)

if [[ -z "$SHORTSTAT" ]]; then
  echo "Error: unable to compute diff against $BASE_BRANCH." >&2
  exit 1
fi

read -r CHANGED_FILES INSERTIONS DELETIONS <<EOF
$(python3 - "$SHORTSTAT" <<'PY_PARSE'
import re, sys
text = sys.stdin.read()
files = insertions = deletions = 0
files_match = re.search(r"(\d+) files? changed", text)
ins_match = re.search(r"(\d+) insertions?\(\+\)", text)
del_match = re.search(r"(\d+) deletions?\(-\)", text)
if files_match:
    files = int(files_match.group(1))
if ins_match:
    insertions = int(ins_match.group(1))
if del_match:
    deletions = int(del_match.group(1))
print(files, insertions, deletions)
PY_PARSE
)
EOF

RISK_LEVEL="Low"
RISK_NOTES="Small change surface."
if (( CHANGED_FILES >= 15 || INSERTIONS >= 800 || DELETIONS >= 800 )); then
  RISK_LEVEL="High"
  RISK_NOTES="Large diff footprint; manual review recommended."
elif (( CHANGED_FILES >= 7 || INSERTIONS >= 250 || DELETIONS >= 250 )); then
  RISK_LEVEL="Medium"
  RISK_NOTES="Moderate diff size; double-check critical paths."
fi

if [[ -z "$TITLE" ]]; then
  TITLE=$(git log -1 --pretty=%s)
fi

if [[ -n "$BODY_FILE" ]]; then
  BODY_CONTENT=$(cat "$BODY_FILE")
else
  BODY_CONTENT=$(cat <<EOF
## Summary
${COMMITS:-"- No new commits"}

## Diff Stats
\`\`\`
$DIFFSTAT
\`\`\`

## Risk Assessment
- **Level:** $RISK_LEVEL
- **Changed files:** $CHANGED_FILES
- **Insertions:** $INSERTIONS
- **Deletions:** $DELETIONS
- **Notes:** $RISK_NOTES

## Changed Files
\`\`\`
$CHANGED_FILES_LIST
\`\`\`
EOF
)
fi

cat <<EOF
=== PR Preview ===
Title: $TITLE
Base: $BASE_BRANCH
Branch: $CURRENT_BRANCH
Remote: $REMOTE_NAME
Auto-merge: $([[ "$NO_AUTO_MERGE" == true ]] && echo "disabled" || echo "enabled ($MERGE_METHOD)")
Risk Level: $RISK_LEVEL
Diff Summary: $SHORTSTAT
EOF

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run enabled; PR not created."
  exit 0
fi

echo "Pushing branch to $REMOTE_NAME..."
git push --set-upstream "$REMOTE_NAME" "$CURRENT_BRANCH"

declare -a CREATE_ARGS
CREATE_ARGS=(gh pr create --base "$BASE_BRANCH" --title "$TITLE" --body "$BODY_CONTENT" --json number,url)
if [[ "$IS_DRAFT" == true ]]; then
  CREATE_ARGS+=(--draft)
fi
for label in "${LABELS[@]}"; do
  CREATE_ARGS+=(--label "$label")
done

PR_JSON=$("${CREATE_ARGS[@]}")

read -r PR_NUMBER PR_URL <<EOF
$(python3 - "$PR_JSON" <<'PY_PARSE'
import json, sys
payload = json.loads(sys.stdin.read())
print(payload.get("number"), payload.get("url"))
PY_PARSE
)
EOF

echo "Created PR #$PR_NUMBER: $PR_URL"

if [[ "$NO_AUTO_MERGE" == true ]]; then
  echo "Auto-merge skipped."
  exit 0
fi

echo "Enabling auto-merge ($MERGE_METHOD)..."
if gh pr merge "$PR_NUMBER" --auto "--$MERGE_METHOD"; then
  echo "Auto-merge enabled for PR #$PR_NUMBER."
else
  echo "Warning: Failed to enable auto-merge for PR #$PR_NUMBER." >&2
fi
