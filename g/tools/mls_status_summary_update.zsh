#!/usr/bin/env zsh
# MLS Status Summary Auto-Update
# Ensures status summary files are always up to date based on latest ledger entries
set -euo pipefail

BASE="$HOME/02luka"
STATUS_DIR="$BASE/mls/status"
LEDGER_DIR="$BASE/mls/ledger"
TODAY="$(TZ=Asia/Bangkok date +%Y-%m-%d)"
DATE_STR="$(TZ=Asia/Bangkok date +%y%m%d)"
TODAY_FILE="$LEDGER_DIR/${TODAY}.jsonl"
SUMMARY_JSON="$STATUS_DIR/${DATE_STR}_ci_cls_codex_summary.json"
SUMMARY_YML="$STATUS_DIR/${DATE_STR}_ci_cls_codex_summary.yml"

mkdir -p "$STATUS_DIR"

# Find latest CI entry from today's ledger
get_latest_ci_entry() {
  if [[ ! -f "$TODAY_FILE" ]]; then
    echo ""
    return
  fi
  
  # Find last entry with context="ci"
  local last_entry=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if echo "$line" | jq -e '.source.context == "ci"' >/dev/null 2>&1; then
      last_entry="$line"
    fi
  done < "$TODAY_FILE"
  
  echo "$last_entry"
}

# Generate summary from ledger entry
generate_summary() {
  local entry="$1"
  
  if [[ -z "$entry" ]]; then
    # No CI entry today - check if we should create empty summary or skip
    echo "ℹ️  No CI entries found in today's ledger"
    return 1
  fi
  
  # Extract fields from entry
  local run_id=$(echo "$entry" | jq -r '.source.run_id // ""')
  local sha=$(echo "$entry" | jq -r '.source.sha // ""')
  local repo=$(echo "$entry" | jq -r '.source.repo // "Ic1558/02luka"')
  local workflow=$(echo "$entry" | jq -r '.source.workflow // "cls-ci.yml"')
  local artifact=$(echo "$entry" | jq -r '.source.artifact // ""')
  local artifact_path=$(echo "$entry" | jq -r '.source.artifact_path // ""')
  local title=$(echo "$entry" | jq -r '.title // ""')
  
  # Try to get artifact info if available
  local artifact_size="0"
  local artifact_status="unknown"
  local artifact_summary='{"total_agents":0,"healthy_count":0,"warning_count":0,"critical_count":0,"total_issues":0}'
  
  if [[ -n "$artifact_path" ]] && [[ -f "$artifact_path" ]]; then
    artifact_size=$(stat -f%z "$artifact_path" 2>/dev/null || stat -c%s "$artifact_path" 2>/dev/null || echo "0")
    if echo "$artifact_path" | grep -q "selfcheck.json"; then
      artifact_status=$(jq -r '.status // "unknown"' "$artifact_path" 2>/dev/null || echo "unknown")
      artifact_summary=$(jq -c '.summary // {}' "$artifact_path" 2>/dev/null || echo '{}')
    fi
  fi
  
  # Determine conclusion from entry type/tags
  local conclusion="success"
  if echo "$entry" | jq -e '.type == "failure"' >/dev/null 2>&1; then
    conclusion="failure"
  fi
  
  # Use passed entry count (avoid re-counting)
  local total_ci_entries="${2:-0}"
  
  # Generate JSON summary with learning metadata
  jq -n \
    --arg date "$(TZ=Asia/Bangkok date +%Y-%m-%dT%H:%M:%S%z)" \
    --arg repo "$repo" \
    --arg run_id "$run_id" \
    --arg sha "$sha" \
    --arg conclusion "$conclusion" \
    --arg artifact_name "$artifact" \
    --arg artifact_path "$artifact_path" \
    --argjson artifact_size "$artifact_size" \
    --arg artifact_status "$artifact_status" \
    --argjson artifact_summary "$artifact_summary" \
    --argjson total_entries "$total_ci_entries" \
    '{
      date: $date,
      version: 1,
      scope: "CLS · Codex CLI · CLC — artifact & MLS integration",
      repo: $repo,
      workflows: [
        {
          name: "cls-ci.yml",
          status: "stable",
          guards: ["Guard: ensure staged artifact exists"],
          artifacts: { primary: "selfcheck-report" },
          mls: { write_on_strict_success: true, validate_if_schema_present: true }
        }
      ],
      runs: {
        total_entries: ($total_entries | tonumber),
        last_strict: {
          run_id: $run_id,
          head_sha: $sha,
          conclusion: $conclusion,
          artifact: {
            name: $artifact_name,
            path_local: $artifact_path,
            size_bytes: ($artifact_size | tonumber),
            status: $artifact_status,
            summary: ($artifact_summary | if type == "object" then . else {} end)
          }
        }
      }
    }' > "$SUMMARY_JSON"
  
  # Generate YAML summary
  if command -v yq >/dev/null 2>&1; then
    cat "$SUMMARY_JSON" | yq -P > "$SUMMARY_YML" 2>/dev/null || cp "$SUMMARY_JSON" "$SUMMARY_YML"
  else
    cp "$SUMMARY_JSON" "$SUMMARY_YML"
  fi
  
  echo "✅ Status summary updated: $SUMMARY_JSON"
  return 0
}

# Main
main() {
  local latest_entry=$(get_latest_ci_entry)
  
  if [[ -z "$latest_entry" ]]; then
    # Check if summary already exists (from CI run)
    if [[ -f "$SUMMARY_JSON" ]]; then
      echo "ℹ️  Summary file exists but no new CI entries - keeping existing"
      return 0
    else
      echo "⚠️  No CI entries found and no existing summary - skipping"
      return 1
    fi
  fi
  
  # Always update for continuous learning - check if we have new entries
  if [[ -f "$SUMMARY_JSON" ]]; then
    local existing_run_id=$(jq -r '.runs.last_strict.run_id // ""' "$SUMMARY_JSON" 2>/dev/null || echo "")
    local latest_run_id=$(echo "$latest_entry" | jq -r '.source.run_id // ""')
    
    # Count total CI entries in ledger for learning
    local total_ci_entries=0
    if [[ -f "$TODAY_FILE" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if echo "$line" | jq -e '.source.context == "ci"' >/dev/null 2>&1; then
          ((total_ci_entries++))
        fi
      done < "$TODAY_FILE"
    fi
    local existing_entry_count=$(jq -r '.runs.total_entries // 0' "$SUMMARY_JSON" 2>/dev/null || echo "0")
    existing_entry_count=${existing_entry_count:-0}
    
    # Always update for self-learning - update timestamp even if run_id/entries same
    # This enables continuous learning tracking
    if [[ "$existing_run_id" == "$latest_run_id" ]] && [[ "$total_ci_entries" == "$existing_entry_count" ]] && [[ -n "$existing_run_id" ]]; then
      # Same run_id and same entry count - still update timestamp for learning
      echo "🔄 Updating timestamp for self-learning (run_id: $existing_run_id, entries: $total_ci_entries)"
    else
      # New run_id or more entries - update everything
      echo "🔄 Updating summary for self-learning (run_id: $latest_run_id, entries: $total_ci_entries)"
    fi
  fi
  
  # Generate/update summary (always update for continuous learning)
  # Pass entry count to avoid re-counting
  generate_summary "$latest_entry" "$total_ci_entries"
}

main "$@"
