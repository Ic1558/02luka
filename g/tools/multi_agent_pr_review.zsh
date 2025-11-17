#!/usr/bin/env zsh
# Multi-Agent PR Review CLI

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SYSTEM_ROOT="$(cd -- "$REPO_ROOT/.." && pwd)"
REPORT_DIR="$REPO_ROOT/reports/system"
CONTRACT_FILE="$SYSTEM_ROOT/docs/MULTI_AGENT_PR_CONTRACT.md"
ORCHESTRATOR="$REPO_ROOT/tools/claude_subagents/orchestrator.zsh"

usage() {
  cat <<'USAGE'
Usage: tools/multi_agent_pr_review.zsh <PR_NUMBER> [--agents N] [--mode review|compete|collab] [--meta-file PATH] [--diff-file PATH]

Required:
  PR_NUMBER          GitHub pull request number

Options:
  --agents N         Number of reviewer agents (default: 2)
  --mode MODE        review | compete | collab (default: review)
  --meta-file PATH   Use saved gh metadata JSON instead of calling GitHub (sandbox/testing)
  --diff-file PATH   Use local diff file instead of gh pr diff (sandbox/testing)
  -h, --help         Show this help message
USAGE
}

log() {
  echo "[multi-agent-pr-review] $*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

PR_NUMBER="$1"
shift || true

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  die "PR_NUMBER must be numeric"
fi

NUM_AGENTS=2
MODE="review"
META_FILE=""
DIFF_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agents)
      shift || die "Missing value for --agents"
      [[ "$1" =~ ^[0-9]+$ ]] || die "--agents must be numeric"
      if (( "$1" < 1 || "$1" > 10 )); then
        die "--agents must be between 1 and 10"
      fi
      NUM_AGENTS="$1"
      ;;
    --mode)
      shift || die "Missing value for --mode"
      case "$1" in
        review)
          MODE="review"
          ;;
        compete)
          MODE="compete"
          ;;
        collab|collaborate)
          MODE="collaborate"
          ;;
        *)
          die "Unknown mode: $1"
          ;;
      esac
      ;;
    --meta-file)
      shift || die "Missing value for --meta-file"
      META_FILE="$1"
      ;;
    --diff-file)
      shift || die "Missing value for --diff-file"
      DIFF_FILE="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift || true
done

if [[ -n "$META_FILE" && ! -r "$META_FILE" ]]; then
  die "Cannot read --meta-file: $META_FILE"
fi
if [[ -n "$DIFF_FILE" && ! -r "$DIFF_FILE" ]]; then
  die "Cannot read --diff-file: $DIFF_FILE"
fi

if [[ -z "$META_FILE" || -z "$DIFF_FILE" ]]; then
  command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) is required unless both --meta-file and --diff-file are provided"
fi
command -v jq >/dev/null 2>&1 || die "jq is required"
[[ -x "$ORCHESTRATOR" ]] || die "Orchestrator not found at $ORCHESTRATOR"
[[ -f "$CONTRACT_FILE" ]] || die "Contract file missing at $CONTRACT_FILE"

mkdir -p "$REPORT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'test -d "$TMP_DIR" && (cd "$TMP_DIR" && find . -delete && cd .. && rmdir "$TMP_DIR")' EXIT

if [[ -n "$META_FILE" ]]; then
  log "Using metadata override from $META_FILE"
  PR_DATA="$(cat "$META_FILE")" || die "Failed to read metadata file"
else
  log "Fetching metadata for PR #$PR_NUMBER"
  if ! PR_DATA=$(gh pr view "$PR_NUMBER" --json number,title,body,author,headRefName,baseRefName,isDraft,mergeable,url,files --repo . 2>/dev/null); then
    die "Unable to fetch PR #$PR_NUMBER via gh"
  fi
fi

PR_TITLE="$(echo "$PR_DATA" | jq -r '.title // ""')"
PR_BODY="$(echo "$PR_DATA" | jq -r '.body // ""')"
PR_AUTHOR="$(echo "$PR_DATA" | jq -r '.author.login // "unknown"')"
PR_HEAD="$(echo "$PR_DATA" | jq -r '.headRefName // "unknown"')"
PR_BASE="$(echo "$PR_DATA" | jq -r '.baseRefName // "unknown"')"
PR_URL="$(echo "$PR_DATA" | jq -r '.url // ""')"

PR_FILES_BLOCK="$(echo "$PR_DATA" | jq -r '.files[]? | "- " + (.path // "") + " (" + (.status // "modified") + ", +" + ((.additions // 0)|tostring) + "/-" + ((.deletions // 0)|tostring) + ")"' )"
if [[ -z "$PR_FILES_BLOCK" ]]; then
  PR_FILES_BLOCK="- (no files listed by gh)"
fi

if [[ -n "$DIFF_FILE" ]]; then
  log "Using diff override from $DIFF_FILE"
  PR_DIFF="$(cat "$DIFF_FILE")" || die "Failed to read diff file"
else
  log "Fetching diff for PR #$PR_NUMBER"
  if ! PR_DIFF=$(gh pr diff "$PR_NUMBER" --color=never --repo . 2>/dev/null); then
    die "Unable to fetch diff for PR #$PR_NUMBER"
  fi
fi

CONTRACT_TEXT="$(cat "$CONTRACT_FILE")"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
REPORT_STEM="$REPORT_DIR/code_review_pr${PR_NUMBER}_${TIMESTAMP}"
REPORT_MD="$REPORT_STEM.md"
REPORT_JSON="$REPORT_STEM.json"

log "Building orchestrator payload"
TASK_PAYLOAD_JSON=$(jq -n \
  --arg pr_number "$PR_NUMBER" \
  --arg title "$PR_TITLE" \
  --arg body "$PR_BODY" \
  --arg author "$PR_AUTHOR" \
  --arg head "$PR_HEAD" \
  --arg base "$PR_BASE" \
  --arg url "$PR_URL" \
  --arg files_summary "$PR_FILES_BLOCK" \
  --arg diff "$PR_DIFF" \
  --arg contract "$CONTRACT_TEXT" \
  --arg contract_path "$CONTRACT_FILE" \
  --arg cli_mode "$MODE" \
  --arg num_agents "$NUM_AGENTS" \
  --arg generated_at "$TIMESTAMP" \
  '{cli:"multi_agent_pr_review", pr_number:$pr_number, title:$title, body:$body, author:$author, head:$head, base:$base, url:$url, files_summary:$files_summary, diff:$diff, contract_path:$contract_path, contract:$contract, cli_mode:$cli_mode, num_agents:$num_agents, generated_at:$generated_at}'
)

echo "$TASK_PAYLOAD_JSON" > "$TMP_DIR/payload.json"
PAYLOAD_FILE="$TMP_DIR/payload.json"

REVIEW_AGENT="$TMP_DIR/review_agent.py"
cat <<'PY' > "$REVIEW_AGENT"
#!/usr/bin/env python3
import json
import random
import sys
from datetime import datetime

def summarize_contract(contract: str) -> str:
    lines = [line.strip() for line in contract.splitlines() if line.strip()]
    snippet = " ".join(lines[:40])
    if len(lines) > 40:
        snippet += " ..."
    return snippet

def build_findings(diff: str) -> list[str]:
    findings = []
    if "TODO" in diff or "FIXME" in diff:
        findings.append("Found TODO/FIXME markers in the diff; ensure they are resolved before merge.")
    additions = sum(1 for line in diff.splitlines() if line.startswith('+') and not line.startswith('+++'))
    if additions > 500:
        findings.append("Large addition set detected; consider breaking the PR down or adding more tests.")
    if "console.log" in diff or "print(" in diff:
        findings.append("Debug logging detected; confirm it is intentional or remove before merge.")
    if not findings:
        findings.append("No automatic blockers detected; manual contract review still required.")
    return findings

def main() -> int:
    if len(sys.argv) < 2:
        print("payload missing", file=sys.stderr)
        return 1
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    focus_pool = [
        "contract alignment",
        "risk assessment",
        "regression checks",
        "spec verification",
        "governance compliance",
    ]
    focus = random.choice(focus_pool)

    pr_number = payload.get("pr_number", "?")
    title = payload.get("title", "")
    files_summary = payload.get("files_summary", "")
    diff = payload.get("diff", "")
    contract = payload.get("contract", "")

    print(f"# Multi-Agent Review Focus: {focus.title()}")
    print(f"Generated: {datetime.utcnow().isoformat()}Z")
    print()
    print(f"## PR #{pr_number}: {title}")
    print(f"Author: {payload.get('author', 'unknown')} | Head: {payload.get('head')} -> Base: {payload.get('base')}")
    print()
    print("### Files changed")
    print(files_summary or "(no file summary available)")
    print()
    print("### Governance contract snapshot")
    print(summarize_contract(contract))
    print()
    print("### Findings")
    for item in build_findings(diff):
        print(f"- {item}")
    print()
    print("### Next steps")
    print("- Ensure automated + manual tests cover the diff")
    print("- Confirm PR template references the multi-agent contract")
    print("- Capture results under reports/system once merged")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x "$REVIEW_AGENT"

TASK_CMD=$(printf '%q ' python3 "$REVIEW_AGENT" "$PAYLOAD_FILE")
TASK_CMD="${TASK_CMD% }"

log "Running orchestrator in $MODE mode with $NUM_AGENTS agent(s)"
set +e
ORCH_OUTPUT=$(LUKA_SOT="$SYSTEM_ROOT" zsh "$ORCHESTRATOR" "$MODE" "$TASK_CMD" "$NUM_AGENTS" 2>&1)
ORCH_STATUS=$?
set -e

[[ $ORCH_STATUS -eq 0 ]] || log "Orchestrator exited with status $ORCH_STATUS (continuing to collate output)"

SUMMARY_FILE="$REPORT_DIR/claude_orchestrator_summary.json"
[[ -f "$SUMMARY_FILE" ]] || die "Expected orchestrator summary at $SUMMARY_FILE"
SUMMARY_JSON_TMP="$TMP_DIR/orchestrator_summary_clean.json"

AGENT_REPORT=$(SUMMARY_JSON_PATH="$SUMMARY_FILE" SUMMARY_JSON_OUTPUT="$SUMMARY_JSON_TMP" python3 - <<'PY'
import json
import os
import sys

summary_path = os.environ.get("SUMMARY_JSON_PATH")
output_path = os.environ.get("SUMMARY_JSON_OUTPUT")
if not summary_path or not output_path:
    print("(summary path unavailable)")
    sys.exit(0)

def build_blocks(payload: dict) -> str:
    parts = []
    for agent in payload.get("agents", []):
        stdout = agent.get("stdout", "")
        try:
            stdout = stdout.encode("utf-8").decode("unicode_escape")
        except UnicodeDecodeError:
            pass
        block = [
            f"### Agent {agent.get('id')} (score: {agent.get('score')}, exit: {agent.get('exit_code')})",
            "",
            "```",
            stdout.strip(),
            "```",
        ]
        parts.append("\n".join(block))
    return "\n\n".join([p for p in parts if p.strip()])

try:
    with open(summary_path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception as exc:  # noqa: BLE001
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(
            {
                "error": "invalid_orchestrator_summary",
                "summary_path": summary_path,
                "reason": str(exc),
            },
            handle,
        )
    print(f"(unable to parse orchestrator summary JSON: {exc})")
else:
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(data, handle)
    rendered = build_blocks(data)
    print(rendered if rendered.strip() else "(no agent output captured)")
PY
)
SUMMARY_JSON="$(cat "$SUMMARY_JSON_TMP")"

cat > "$REPORT_MD" <<EOF
# Multi-Agent PR Review Report

- **PR:** #$PR_NUMBER — $PR_TITLE
- **Author:** $PR_AUTHOR
- **Head → Base:** $PR_HEAD → $PR_BASE
- **URL:** $PR_URL
- **Mode:** $MODE
- **Agents:** $NUM_AGENTS
- **Generated (UTC):** $TIMESTAMP

## Files Summary
$PR_FILES_BLOCK

## Review Payload Notes
- Payload captured at: $TIMESTAMP
- Contract source: $CONTRACT_FILE
- Diff length: $(echo "$PR_DIFF" | wc -l | tr -d ' ' ) lines

## Multi-Agent Findings
${AGENT_REPORT:-"(no agent output captured)"}

## Raw Orchestrator Output
EOF

{
  printf '```\n%s\n```\n\n' "$ORCH_OUTPUT"
  cat <<'EOF'
classification:
  task_type: PR_FEAT
  primary_tool: codex_cli
  needs_pr: true
  security_sensitive: false
  reason: "Multi-agent CLI to automate PR reviews using existing orchestrator and governance contract."

EOF
} >> "$REPORT_MD"

REPORT_JSON_CONTENT=$(jq -n \
  --arg pr_number "$PR_NUMBER" \
  --arg title "$PR_TITLE" \
  --arg mode "$MODE" \
  --arg timestamp "$TIMESTAMP" \
  --argjson payload "$TASK_PAYLOAD_JSON" \
  --argjson orchestrator "$SUMMARY_JSON" \
  --arg report_path "$REPORT_MD" \
  --arg agents "$NUM_AGENTS" \
  '{pr_number:$pr_number, title:$title, mode:$mode, timestamp:$timestamp, agents:($agents|tonumber), payload:$payload, orchestrator:$orchestrator, report_path:$report_path}'
)

echo "$REPORT_JSON_CONTENT" > "$REPORT_JSON"

log "Review complete"
log "Markdown report: $REPORT_MD"
log "JSON report: $REPORT_JSON"
log "Done"
