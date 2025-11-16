#!/usr/bin/env zsh
# Automate Session Summary Generation
# Generates session summaries for completed sessions

set -euo pipefail

REPO_ROOT="${LUKA_SOT:-$HOME/02luka}"
SESSION_SUMMARY_TOOL="$REPO_ROOT/tools/cls_session_summary.zsh"
LEDGER_DIR="$REPO_ROOT/g/ledger"

echo "📝 Automating Session Summary Generation"
echo "========================================"
echo ""

# Process each agent
for agent_dir in "$LEDGER_DIR"/*/; do
  agent=$(basename "$agent_dir")
  
  if [[ "$agent" == "gg" ]]; then
    continue  # Skip GG for now
  fi
  
  echo "Processing agent: $agent"
  
  # Get today's date
  today=$(date '+%Y-%m-%d')
  ledger_file="$agent_dir/$today.jsonl"
  
  if [[ ! -f "$ledger_file" ]]; then
    echo "  ⚠️  No ledger file for today: $ledger_file"
    continue
  fi
  
  # Extract unique session IDs from today's ledger
  session_ids=$(jq -r '.session_id // empty' "$ledger_file" 2>/dev/null | sort -u)
  
  if [[ -z "$session_ids" ]]; then
    echo "  ⚠️  No session IDs found in ledger"
    continue
  fi
  
  # Generate summary for each session
  for session_id in $session_ids; do
    if [[ -z "$session_id" ]] || [[ "$session_id" == "null" ]]; then
      continue
    fi
    
    sessions_dir="$REPO_ROOT/memory/$agent/sessions"
    summary_file="$sessions_dir/${session_id}.md"
    
    # Skip if summary already exists
    if [[ -f "$summary_file" ]]; then
      echo "  ⏭️  Summary already exists: $session_id"
      continue
    fi
    
    # Generate summary
    if [[ "$agent" == "cls" ]] && [[ -x "$SESSION_SUMMARY_TOOL" ]]; then
      echo "  📝 Generating summary for: $session_id"
      "$SESSION_SUMMARY_TOOL" "$session_id" "$summary_file" >/dev/null 2>&1 || {
        echo "  ❌ Failed to generate summary for: $session_id"
      }
    else
      echo "  ⚠️  Session summary tool not available for: $agent"
    fi
  done
done

echo ""
echo "✅ Session summary automation complete"
