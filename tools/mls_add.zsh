#!/usr/bin/env zsh
set -euo pipefail

# mls_add.zsh — append an MLS event into daily JSONL
# Usage:
#   mls_add.zsh \
#     --type solution \
#     --title "CLS artifact stable" \
#     --summary "added stage+guard; artifact OK" \
#     --producer cls \
#     --context ci \
#     --repo Ic1558/02luka \
#     --run-id 19213412721 \
#     --workflow cls-ci.yml \
#     --sha fd066bc9 \
#     --artifact selfcheck-report \
#     --artifact-path "$HOME/02luka/__artifacts__/cls_strict/selfcheck.json" \
#     --followup-id "" \
#     --wo-id "" \
#     --tags "bridge,artifact,strict,stable" \
#     --author gg \
#     --confidence 0.9

# --- parse args ---
TYPE="solution"
TITLE=""
SUMMARY=""
PRODUCER=""
CONTEXT=""
REPO=""
RUN_ID=""
WORKFLOW=""
SHA=""
ARTIFACT=""
ARTIFACT_PATH=""
FOLLOWUP_ID=""
WO_ID=""
TAGS=""
AUTHOR="${AUTHOR:-gg}"
CONFIDENCE="0.8"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) TYPE="$2"; shift 2;;
    --title) TITLE="$2"; shift 2;;
    --summary) SUMMARY="$2"; shift 2;;
    --producer) PRODUCER="$2"; shift 2;;
    --context) CONTEXT="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --run-id) RUN_ID="$2"; shift 2;;
    --workflow) WORKFLOW="$2"; shift 2;;
    --sha) SHA="$2"; shift 2;;
    --artifact) ARTIFACT="$2"; shift 2;;
    --artifact-path) ARTIFACT_PATH="$2"; shift 2;;
    --followup-id) FOLLOWUP_ID="$2"; shift 2;;
    --wo-id) WO_ID="$2"; shift 2;;
    --tags) TAGS="$2"; shift 2;;
    --author) AUTHOR="$2"; shift 2;;
    --confidence) CONFIDENCE="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

[[ -n "$TITLE" && -n "$SUMMARY" && -n "$PRODUCER" ]] || {
  echo "Missing required fields: --title --summary --producer" >&2; exit 2;
}

LEDGER_DIR="$HOME/02luka/mls/ledger"
mkdir -p "$LEDGER_DIR"

TS="$(date +%Y-%m-%dT%H:%M:%S%z)"
DAY="$(date +%Y-%m-%d)"
F="$LEDGER_DIR/${DAY}.jsonl"

# build JSON safely with jq
jq -n --arg ts "$TS" \
      --arg type "$TYPE" \
      --arg title "$TITLE" \
      --arg summary "$SUMMARY" \
      --arg producer "$PRODUCER" \
      --arg context "$CONTEXT" \
      --arg repo "$REPO" \
      --arg run_id "$RUN_ID" \
      --arg workflow "$WORKFLOW" \
      --arg sha "$SHA" \
      --arg artifact "$ARTIFACT" \
      --arg artifact_path "$ARTIFACT_PATH" \
      --arg followup_id "$FOLLOWUP_ID" \
      --arg wo_id "$WO_ID" \
      --arg tags "$TAGS" \
      --arg author "$AUTHOR" \
      --argjson confidence "$CONFIDENCE" '
{
  ts: $ts,
  type: $type,
  title: $title,
  summary: $summary,
  source: {
    producer: $producer,
    context: $context,
    repo: $repo,
    run_id: $run_id,
    workflow: $workflow,
    sha: $sha,
    artifact: $artifact,
    artifact_path: $artifact_path
  },
  links: {
    followup_id: ( $followup_id | if . == "" then null else . end ),
    wo_id: ( $wo_id | if . == "" then null else . end )
  },
  tags: ( if ($tags|length) > 0 then ($tags | split(",") | map(.|gsub("^\\s+|\\s+$";""))) else [] end ),
  author: $author,
  confidence: ($confidence | tonumber)
}
' >> "$F"

echo "Appended MLS event → $F"

