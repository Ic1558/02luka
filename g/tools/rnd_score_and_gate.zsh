#!/usr/bin/env zsh
set -euo pipefail
setopt null_glob

R="$HOME/02luka"
IN="$R/bridge/inbox/RND"
ENTRY="$R/bridge/inbox/ENTRY"
REVIEW="$R/bridge/inbox/CLS"
DONE="$R/bridge/processed/RND"
POL="$R/config/rnd_policy.yaml"
LOG="$R/logs/rnd_gate.log"

mkdir -p "$ENTRY" "$REVIEW" "$DONE" "${LOG:h}"

ts(){ date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Helper: ensure numeric value
to_int() {
  local val="${1:-0}"
  val=$(echo "$val" | tr -d ' ' | sed 's/[^0-9]//g')
  [[ -z "$val" ]] && val=0
  echo "$val"
}

for y in "$IN"/RND-PR-*.yaml(N); do
  [[ -e "$y" ]] || { echo "$(ts) idle" >> "$LOG"; exit 0; }

  pr=$(grep '^pr_number:' "$y" 2>/dev/null | awk '{print $2}' || echo "")
  score=$(grep '^current_score:' "$y" 2>/dev/null | awk '{print $2}' || echo "")
  tgt=$(grep '^target_score:' "$y" 2>/dev/null | awk '{print $2}' || echo "")
  kind=$(grep '^kind:' "$y" 2>/dev/null | awk '{print $2}' || echo "")
  id=$(basename "$y" .yaml)

  if [[ -z "$pr" ]]; then
    echo "$(ts) WARN: missing pr_number in $(basename "$y")" >> "$LOG"
    continue
  fi

  # Gather quick signals from GH (best-effort)
  changed_files=$(gh pr view "$pr" --json files 2>/dev/null | jq '.files | length' 2>/dev/null || echo "0")
  diff_lines=$(gh pr diff "$pr" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
  tests_touched=$(gh pr view "$pr" --json files 2>/dev/null | jq -r '[.files[].path | test("(test|spec)")] | any' 2>/dev/null || echo "false")
  ci_green=$(gh pr checks "$pr" --required 2>/dev/null | grep -q "PASS" && echo "true" || echo "false")
  secrets_found=0  # hook in your scanner later
  
  # Ensure numeric values (handle empty strings)
  [[ -z "$changed_files" || "$changed_files" == "null" ]] && changed_files=0
  [[ -z "$diff_lines" || "$diff_lines" == "null" ]] && diff_lines=0

  # Policy reads
  target_score=${tgt:-$(grep 'target_score:' "$POL" 2>/dev/null | awk '{print $2}' || echo "85")}
  live=$(grep '^  live:' "$POL" 2>/dev/null | awk '{print $2}' | tr 'A-Z' 'a-z' || echo "false")
  allow_doc_only_auto=$(grep 'allow_doc_only_auto:' "$POL" 2>/dev/null | awk '{print $2}' | tr 'A-Z' 'a-z' || echo "true")
  allow_test_only_auto=$(grep 'allow_test_only_auto:' "$POL" 2>/dev/null | awk '{print $2}' | tr 'A-Z' 'a-z' || echo "true")
  allow_ci_fix_auto=$(grep 'allow_ci_fix_auto:' "$POL" 2>/dev/null | awk '{print $2}' | tr 'A-Z' 'a-z' || echo "true")
  max_files=$(grep 'max_touch_files:' "$POL" 2>/dev/null | awk '{print $2}' || echo "5")
  max_lines=$(grep 'max_diff_lines:' "$POL" 2>/dev/null | awk '{print $2}' || echo "200")

  # Heuristic bucket
  tier=medium
  [[ "$kind" =~ ^(docs|tests|ci|lint)$ ]] && tier=low
  [[ "$kind" = "core_logic" || "$kind" = "security" || "$kind" = "finance" ]] && tier=high

  # Guard checks (ensure numeric values with defaults)
  changed_files=$(to_int "$changed_files")
  diff_lines=$(to_int "$diff_lines")
  max_files=$(to_int "${max_files:-5}")
  max_lines=$(to_int "${max_lines:-200}")
  secrets_found=$(to_int "$secrets_found")
  
  if (( changed_files <= max_files )); then
    ok_touch=1
  else
    ok_touch=0
  fi
  
  if (( diff_lines <= max_lines )); then
    ok_diff=1
  else
    ok_diff=0
  fi
  
  if (( secrets_found == 0 )); then
    ok_secrets=1
  else
    ok_secrets=0
  fi
  
  if [[ "$tests_touched" == "true" ]]; then
    if [[ "$ci_green" == "true" ]]; then
      ok_tests=1
    else
      ok_tests=0
    fi
  else
    ok_tests=1
  fi

  guards=$(( ok_touch * ok_diff * ok_secrets * ok_tests ))

  # Auto-approve rules
  auto=false
  if [[ "$tier" = "low" && $guards -eq 1 ]]; then
    if [[ "$kind" = "docs" && "$allow_doc_only_auto" = "true" ]]; then auto=true; fi
    if [[ "$kind" = "tests" && "$allow_test_only_auto" = "true" ]]; then auto=true; fi
    if [[ "$kind" = "ci" && "$allow_ci_fix_auto" = "true" ]]; then auto=true; fi
  fi

  # Decide route
  if [[ "$auto" = "true" ]]; then
    # Send straight to Mary with concrete actions
    wo="$ENTRY/WO-${id}-GATED.yaml"
    cat > "$wo" <<EOF
id: ${id}-GATED
intent: improve_pr_readiness
strict_target: mary
payload:
  pr_number: ${pr}
  current_score: ${score}
  target_score: ${target_score}
  actions:
    - auto_small_docs_tests_ci: true
    - respect_touch_limit: ${max_files}
    - respect_diff_limit: ${max_lines}
meta:
  source: rnd_gate
  tier: ${tier}
  guards_ok: ${guards}
  ci_green: ${ci_green}
EOF
    echo "$(ts) AUTO→MARY pr=${pr} tier=${tier} guards=${guards} wo=$(basename "$wo") live=${live}" >> "$LOG"
  else
    # Park for CLS review
    rev="$REVIEW/REVIEW-${id}.yaml"
    cat > "$rev" <<EOF
id: REVIEW-${id}
intent: rnd_review
strict_target: cls
payload:
  pr_number: ${pr}
  current_score: ${score}
  target_score: ${target_score}
  summary: "Tier=${tier}, guards_ok=${guards}, changed_files=${changed_files}, diff_lines=${diff_lines}, ci_green=${ci_green}"
meta:
  source: rnd_gate
  reason: "Not safe for auto-approve"
EOF
    echo "$(ts) HOLD→CLS pr=${pr} tier=${tier} guards=${guards}" >> "$LOG"
  fi

  mv "$y" "$DONE/${id}.yaml"
done

echo "$(ts) cycle complete" >> "$LOG"
