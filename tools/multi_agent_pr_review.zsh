#!/usr/bin/env zsh
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tools/multi_agent_pr_review.zsh <pr-number> [--agents N] [--mode review|compete|collab] [--agent-command "cmd {TASK_FILE}"]

Arguments:
  pr-number             GitHub PR number to review

Options:
  --agents N            Number of agents to run via orchestrator (default: 2)
  --mode MODE           review, compete, or collab (default: review)
  --agent-command CMD   Command template executed for each agent. Use {TASK_FILE} placeholder
                        to reference the generated task file. Defaults to "cat {TASK_FILE}".
USAGE
  exit 1
}

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "❌ Required command not found: $cmd"
    exit 1
  fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
G_DIR="$REPO_ROOT/g"
REPORT_DIR="$G_DIR/reports/system"
TMP_ROOT="$G_DIR/tmp"
ORCHESTRATOR="$REPO_ROOT/tools/claude_subagents/orchestrator.zsh"

[[ $# -lt 1 ]] && usage

PR_NUMBER=""
NUM_AGENTS=2
MODE="review"
AGENT_CMD_TEMPLATE="${MULTI_AGENT_REVIEW_CMD:-cat {TASK_FILE}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agents)
      shift || usage
      NUM_AGENTS="$1"
      ;;
    --mode)
      shift || usage
      MODE="$1"
      ;;
    --agent-command)
      shift || usage
      AGENT_CMD_TEMPLATE="$1"
      ;;
    -h|--help)
      usage
      ;;
    --*)
      log "Unknown option: $1"
      usage
      ;;
    *)
      if [[ -n "$PR_NUMBER" ]]; then
        log "Multiple PR numbers provided"
        usage
      fi
      PR_NUMBER="$1"
      ;;
  esac
  shift || true
done

[[ -z "$PR_NUMBER" ]] && usage

if ! [[ "$NUM_AGENTS" =~ ^[0-9]+$ ]] || [[ "$NUM_AGENTS" -lt 1 ]]; then
  log "⚠️  Invalid --agents value ($NUM_AGENTS); defaulting to 2"
  NUM_AGENTS=2
fi

case "$MODE" in
  review)
    ORCH_MODE="review"
    ;;
  compete)
    ORCH_MODE="compete"
    ;;
  collab|collaborate)
    ORCH_MODE="collaborate"
    ;;
  *)
    log "⚠️  Unknown mode '$MODE'; using 'review'"
    ORCH_MODE="review"
    ;;
esac

require_cmd gh
require_cmd jq

if [[ ! -x "$ORCHESTRATOR" ]]; then
  log "❌ Orchestrator not found or not executable: $ORCHESTRATOR"
  exit 1
fi

mkdir -p "$REPORT_DIR" "$TMP_ROOT"
TMP_DIR="$(mktemp -d "$TMP_ROOT/multi_agent_pr_review.XXXXXX")"
trap 'test -d "$TMP_DIR" && (cd "$TMP_DIR" && find . -delete && cd .. && rmdir "$TMP_DIR")' EXIT

log "📥 Fetching PR #$PR_NUMBER metadata via gh"
PR_JSON="$TMP_DIR/pr.json"
if ! gh pr view "$PR_NUMBER" --json number,title,body,author,baseRefName,headRefName,url,labels,files >"$PR_JSON"; then
  log "❌ Failed to fetch PR $PR_NUMBER via GitHub CLI"
  exit 1
fi

TITLE=$(jq -r '.title' "$PR_JSON")
BODY=$(jq -r '.body // ""' "$PR_JSON")
AUTHOR=$(jq -r '.author.login // "unknown"' "$PR_JSON")
BASE_BRANCH=$(jq -r '.baseRefName' "$PR_JSON")
HEAD_BRANCH=$(jq -r '.headRefName' "$PR_JSON")
PR_URL=$(jq -r '.url' "$PR_JSON")
LABELS=$(jq -r '[.labels[]?.name] | if length==0 then "none" else join(", ") end' "$PR_JSON")

FILES_SUMMARY=$(jq -r '.files[]? | "- \(.path) (+\((.additions // 0)) / -\((.deletions // 0)), status: \(.status))"' "$PR_JSON" || true)
if [[ -z "$FILES_SUMMARY" ]]; then
  FILES_SUMMARY="- (no tracked file changes reported)"
fi

if ! gh pr diff "$PR_NUMBER" --stat >"$TMP_DIR/diff.stat" 2>"$TMP_DIR/diff.stat.err"; then
  log "⚠️  Unable to compute diff stat (see $TMP_DIR/diff.stat.err)"
  echo "Diff stat unavailable" >"$TMP_DIR/diff.stat"
fi
if ! gh pr diff "$PR_NUMBER" >"$TMP_DIR/diff.patch" 2>"$TMP_DIR/diff.patch.err"; then
  log "⚠️  Unable to fetch full diff (see $TMP_DIR/diff.patch.err)"
  echo "Diff unavailable" >"$TMP_DIR/diff.patch"
fi

[[ -z "$BODY" || "$BODY" == "null" ]] && BODY="_No PR description provided._"

read -r -d '' CONTRACT_SNIPPET <<'CONTRACT'
Key guardrails from the multi-agent PR contract (#287):
1. Identify the PR routing type (PR/Feature, Local Fix, WO/Automation, Asking/Docs) and stick to its rules.
2. Enumerate affected agents (GG, GC, CLS, Mary, Kim, Lisa, Paula) and note required coordination.
3. Describe before/after behavior plus rollback expectations.
4. Honor sandbox + security policies (e.g., CODEX_SANDBOX_MODE.md) and flag sensitive surfaces.
5. Reviews must conclude with an explicit classification block for downstream automation.
CONTRACT

read -r -d '' OUTPUT_FORMAT <<'FORMAT'
Produce a Markdown report with:
1. "Summary" – key findings + overall assessment (block/pass/follow-up?).
2. "Risks" – security, data, sandbox, or routing issues.
3. "Testing" – what was run or must be run.
4. "Recommendations" – concrete fixes or approvals.
5. Append the classification block exactly as:

classification:
  task_type: <PR_FIX|PR_FEAT|PR_DOCS>
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: true|false
  reason: "..."
FORMAT

PAYLOAD_FILE="$TMP_DIR/pr${PR_NUMBER}_task.md"
{
  echo "# Multi-Agent PR Review Task"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## PR Metadata"
  echo "- Number: #$PR_NUMBER"
  echo "- Title: $TITLE"
  echo "- Author: @$AUTHOR"
  echo "- Branches: $HEAD_BRANCH → $BASE_BRANCH"
  echo "- Labels: $LABELS"
  echo "- URL: $PR_URL"
  echo "- Requested agents: $NUM_AGENTS"
  echo "- Mode: $MODE"
  echo
  echo "## PR Description"
  echo "$BODY"
  echo
  echo "## Changed Files"
  echo "$FILES_SUMMARY"
  echo
  echo "## Diff Summary"
  echo '```'
  cat "$TMP_DIR/diff.stat"
  echo '```'
  echo
  echo "## Full Diff"
  echo '```diff'
  cat "$TMP_DIR/diff.patch"
  echo '```'
  echo
  echo "## Contract Guardrails"
  echo "$CONTRACT_SNIPPET"
  echo
  echo "## Expected Output"
  echo "$OUTPUT_FORMAT"
} >"$PAYLOAD_FILE"

TASK_FILE_ESCAPED=$(printf '%q' "$PAYLOAD_FILE")
if [[ "$AGENT_CMD_TEMPLATE" != *"{TASK_FILE}"* ]]; then
  AGENT_CMD_TEMPLATE+=" {TASK_FILE}"
fi
TASK_COMMAND=${AGENT_CMD_TEMPLATE//\{TASK_FILE\}/$TASK_FILE_ESCAPED}

# Set LUKA_SOT to repo root so orchestrator writes summary to correct location
export LUKA_SOT="$REPO_ROOT"
log "🤖 Launching orchestrator ($ORCH_MODE) with $NUM_AGENTS agents"
ORCH_STDOUT="$TMP_DIR/orchestrator.stdout"
ORCH_STDERR="$TMP_DIR/orchestrator.stderr"
if ! "$ORCHESTRATOR" "$ORCH_MODE" "$TASK_COMMAND" "$NUM_AGENTS" >"$ORCH_STDOUT" 2>"$ORCH_STDERR"; then
  log "❌ Orchestrator execution failed (see $ORCH_STDERR)"
  cat "$ORCH_STDERR" >&2
  exit 1
fi

SUMMARY_JSON="$REPORT_DIR/claude_orchestrator_summary.json"
if [[ ! -f "$SUMMARY_JSON" ]]; then
  log "❌ Expected orchestrator summary not found at $SUMMARY_JSON"
  exit 1
fi

TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
ARCHIVE_PAYLOAD="$G_DIR/tmp/multi_agent_pr_payload_pr${PR_NUMBER}_${TIMESTAMP}.md"
cp "$PAYLOAD_FILE" "$ARCHIVE_PAYLOAD"
PAYLOAD_FILE="$ARCHIVE_PAYLOAD"
REPORT_FILE="$REPORT_DIR/code_review_pr${PR_NUMBER}_${TIMESTAMP}.md"
JSON_FILE="$REPORT_DIR/code_review_pr${PR_NUMBER}_${TIMESTAMP}.json"

CLASS_TASK_TYPE="PR_FIX"
LABELS_LOWER=$(echo "$LABELS" | tr '[:upper:]' '[:lower:]')
if [[ "$LABELS_LOWER" == *"feat"* || "$LABELS_LOWER" == *"feature"* ]]; then
  CLASS_TASK_TYPE="PR_FEAT"
elif [[ "$LABELS_LOWER" == *"doc"* ]]; then
  CLASS_TASK_TYPE="PR_DOCS"
fi
CLASS_SECURITY="false"
if [[ "$LABELS_LOWER" == *"security"* ]]; then
  CLASS_SECURITY="true"
fi
CLASS_REASON="Automated multi-agent review generated via multi_agent_pr_review CLI."

log "📝 Writing review report → $REPORT_FILE"
{
  echo "# Multi-Agent PR Review for PR #$PR_NUMBER"
  echo "**Title:** $TITLE"
  echo "**Author:** @$AUTHOR"
  echo "**Branches:** $HEAD_BRANCH → $BASE_BRANCH"
  echo "**Mode:** $MODE"
  echo "**Agents Requested:** $NUM_AGENTS"
  echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## PR Snapshot"
  echo "- URL: $PR_URL"
  echo "- Labels: $LABELS"
  echo "- Payload: $PAYLOAD_FILE"
  echo
  echo "## Agent Outputs"
  if jq -e '.agents | length > 0' "$SUMMARY_JSON" >/dev/null 2>&1; then
    jq -r '.agents[] | "### Agent \(.id)\n\n- Exit Code: \(.exit_code)\n- Score: \(.score)/100\n\nOutput:\n```\n\(.stdout)\n```\n"' "$SUMMARY_JSON" 2>/dev/null
  else
    echo "_No agent output captured._"
  fi
  echo
  echo "## Strategy Summary"
  if command -v jq >/dev/null 2>&1; then
    STRATEGY=$(jq -r '.strategy // "review"' "$SUMMARY_JSON" 2>/dev/null)
    WINNER=$(jq -r '.winner // "n/a"' "$SUMMARY_JSON" 2>/dev/null)
    BEST_SCORE=$(jq -r '.best_score // 0' "$SUMMARY_JSON" 2>/dev/null)
    echo "- Strategy: $STRATEGY"
    echo "- Winner: $WINNER"
    echo "- Best Score: $BEST_SCORE/100"
  else
    echo "- Strategy data unavailable (jq missing)"
  fi
  echo
  echo "## Classification"
  echo "classification:"
  echo "  task_type: $CLASS_TASK_TYPE"
  echo "  primary_tool: codex_cli"
  echo "  needs_pr: true"
  echo "  security_sensitive: $CLASS_SECURITY"
  echo "  reason: \"$CLASS_REASON\""
} >"$REPORT_FILE"

log "📦 Writing JSON mirror → $JSON_FILE"
jq -n \
  --arg pr "$PR_NUMBER" \
  --arg title "$TITLE" \
  --arg author "$AUTHOR" \
  --arg url "$PR_URL" \
  --arg mode "$MODE" \
  --arg agents "$NUM_AGENTS" \
  --arg payload "$PAYLOAD_FILE" \
  --arg report "$REPORT_FILE" \
  --arg classification_task "$CLASS_TASK_TYPE" \
  --arg classification_reason "$CLASS_REASON" \
  --argjson classification_security $CLASS_SECURITY \
  --slurpfile summary "$SUMMARY_JSON" \
  '{
    pr_number: ($pr | tonumber),
    title: $title,
    author: $author,
    url: $url,
    mode: $mode,
    agents_requested: ($agents | tonumber),
    payload_file: $payload,
    report_file: $report,
    classification: {
      task_type: $classification_task,
      primary_tool: "codex_cli",
      needs_pr: true,
      security_sensitive: $classification_security,
      reason: $classification_reason
    },
    orchestrator_summary: $summary[0]
  }' >"$JSON_FILE"

log "✅ Review complete"
echo "$REPORT_FILE"
