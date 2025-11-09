#!/usr/bin/env zsh

# ======================================================================
# 02LUKA CI CHECK — one-shot automation for CLS CI workflow
# Runs both soft & strict modes, waits for completion,
# downloads the selfcheck artifact, and prints summary.
# ======================================================================

set -euo pipefail

# --- CONFIG ------------------------------------------------------------
REPO="Ic1558/02luka"
WF="cls-ci.yml"
OUTDIR="$HOME/02luka/__artifacts__/cls_strict"
POLL_INTERVAL=5       # seconds
POLL_MAX=400          # 400 * 5 = ~33 min max wait

print_section() { echo; echo "== $1 =="; }
die() { echo "❌ $1" >&2; exit 1; }

# --- REQUIREMENTS ------------------------------------------------------
command -v gh >/dev/null || die "GitHub CLI (gh) not found."
command -v jq >/dev/null || die "jq not found."

# --- VIEW MLS OPTION ---------------------------------------------------
if [[ "${1:-}" == "--view-mls" ]]; then
  LEDGER_DIR="$HOME/02luka/mls/ledger"
  if [[ ! -d "$LEDGER_DIR" ]]; then
    echo "ℹ️  No MLS ledger directory: $LEDGER_DIR"
    exit 0
  fi
  LAST_FILE="$(ls -1 "$LEDGER_DIR"/*.jsonl 2>/dev/null | tail -n 1 || true)"
  if [[ -z "$LAST_FILE" ]]; then
    echo "ℹ️  No MLS ledger files found."
    exit 0
  fi
  echo "== MLS latest entries ($LAST_FILE) =="
  tail -n 10 "$LAST_FILE" | jq -r '
    . as $e |
    "• [" + (.type|tostring) + "] " + .title
    + "\n  ts: " + .ts
    + "\n  src: " + .source.producer + "@" + (.source.context // "n/a")
    + " run: " + ((.source.run_id // "n/a")|tostring)
    + " sha: " + (.source.sha // "n/a")
    + "\n  summary: " + .summary
    + "\n  tags: " + ((.tags // [])|join(", "))
    + "\n"
  '
  exit 0
fi

print_section "Trigger runs (soft & strict)"
gh workflow run "$WF" -R "$REPO" -r main -f ci_strict=0 >/dev/null
gh workflow run "$WF" -R "$REPO" -r main -f ci_strict=1 >/dev/null
sleep 2

# --- FIND STRICT RUN ID ------------------------------------------------
get_strict_rid() {
  gh run list -R "$REPO" --workflow "$WF" -L 20 --json databaseId,displayTitle,event \
  | jq -r '[.[] | select(.event=="workflow_dispatch") | select(.displayTitle|test("strict=1"))][0].databaseId'
}
RID="$(get_strict_rid)"
[[ -n "$RID" && "$RID" != "null" ]] || die "strict RUN_ID not found"

echo "STRICT RUN: $RID"

# --- WAIT FOR COMPLETION ----------------------------------------------
print_section "Wait for completion"
i=0
while (( i < POLL_MAX )); do
  run_status=$(gh run view -R "$REPO" "$RID" --json status | jq -r '.status')
  [[ "$run_status" == "completed" ]] && break
  (( i++ ))
  (( i % 10 == 0 )) && echo "⏳ waiting... ($((i * POLL_INTERVAL))s)"
  sleep "$POLL_INTERVAL"
done
[[ "$run_status" == "completed" ]] || die "run did not complete within timeout"

conclusion=$(gh run view -R "$REPO" "$RID" --json conclusion | jq -r '.conclusion')
echo "Conclusion: $conclusion"

# --- DOWNLOAD ARTIFACT -------------------------------------------------
print_section "Download artifact"
mkdir -p "$OUTDIR"
rm -f "$OUTDIR/selfcheck.json" 2>/dev/null || true
if ! gh run download -R "$REPO" "$RID" -n selfcheck-report -D "$OUTDIR" >/dev/null 2>&1; then
  die "No artifact found (selfcheck-report)"
fi
ls -la "$OUTDIR"
[[ -f "$OUTDIR/selfcheck.json" ]] || die "selfcheck.json missing after download"

# --- PRINT SUMMARY -----------------------------------------------------
print_section "Quick summary"
jq -r '
  "status: " + .status,
  "total_agents: " + (.summary.total_agents|tostring),
  "healthy: "      + (.summary.healthy_count|tostring),
  "warnings: "     + (.summary.warning_count|tostring),
  "critical: "     + (.summary.critical_count|tostring),
  "issues: "       + (.summary.total_issues|tostring)
' "$OUTDIR/selfcheck.json"

# --- SAVE RUN INFO -----------------------------------------------------
echo "$RID" > "$HOME/02luka/__artifacts__/last_strict_run.txt"
echo "Saved last strict RUN_ID → $HOME/02luka/__artifacts__/last_strict_run.txt"

# --- WRITE MLS EVENT (if successful) ------------------------------------
if [[ "$conclusion" == "success" ]]; then
  print_section "Write MLS event"
  SHA=$(git -C ~/02luka rev-parse HEAD 2>/dev/null || echo "")
  ~/02luka/tools/mls_add.zsh \
    --type solution \
    --title "CLS strict CI stable" \
    --summary "artifact uploaded ok; bridge healthy" \
    --producer cls \
    --context ci \
    --repo "$REPO" \
    --run-id "$RID" \
    --workflow "$WF" \
    --sha "$SHA" \
    --artifact "selfcheck-report" \
    --artifact-path "$OUTDIR/selfcheck.json" \
    --tags "strict,artifact,bridge" \
    --author gg \
    --confidence 0.9 || echo "⚠️  MLS write failed (non-critical)"
fi

# --- EXIT CODES --------------------------------------------------------
if [[ "$conclusion" != "success" ]]; then
  echo "❌ CI concluded: $conclusion"
  exit 2
fi

echo
echo "✅ Done → $OUTDIR/selfcheck.json"
exit 0
