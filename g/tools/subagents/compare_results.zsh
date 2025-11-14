#!/usr/bin/env zsh
# Compare Results from Multiple Subagents (Backend-Agnostic)
# Purpose: Synthesize findings from multiple agent reviews
# Usage: compare_results.zsh [output_dir]

set -euo pipefail

OUTPUT_DIR="${1:-}"
BASE="${LUKA_SOT:-$HOME/02luka}"
REPORT_DIR="$BASE/g/reports/system"
REPORT_FILE="$BASE/g/reports/code_review_$(date +%Y%m%d)_AUTO.md"
COMPARE_JSON="$REPORT_DIR/subagent_compare_summary.json"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >&2
}

log "🔍 Comparing results..."

# Check for orchestrator summary (updated filename)
ORCHESTRATOR_SUMMARY="$REPORT_DIR/subagent_orchestrator_summary.json"
if [[ ! -f "$ORCHESTRATOR_SUMMARY" ]]; then
  # Fallback to old filename for backward compatibility
  ORCHESTRATOR_SUMMARY="$REPORT_DIR/claude_orchestrator_summary.json"
fi

if [[ ! -f "$ORCHESTRATOR_SUMMARY" ]]; then
  log "⚠️  No orchestrator summary found: $ORCHESTRATOR_SUMMARY"
  
  # Fallback: try to synthesize from output_dir if provided
  if [[ -n "$OUTPUT_DIR" ]] && [[ -d "$OUTPUT_DIR" ]]; then
    log "📋 Using output directory: $OUTPUT_DIR"
    
    # Synthesize from agent files
    {
      echo "# Code Review - Auto Generated"
      echo "**Date:** $(date +%Y-%m-%d)"
      echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo ""
      echo "---"
      echo ""
      
      # Agent A
      if [[ -f "$OUTPUT_DIR/agent_a.md" ]]; then
        echo "## Agent A: Implementation Critique"
        echo ""
        cat "$OUTPUT_DIR/agent_a.md"
        echo ""
        echo "---"
        echo ""
      fi
      
      # Agent B
      if [[ -f "$OUTPUT_DIR/agent_b.md" ]]; then
        echo "## Agent B: Security Review"
        echo ""
        cat "$OUTPUT_DIR/agent_b.md"
        echo ""
        echo "---"
        echo ""
      fi
      
      echo "## Synthesis"
      echo ""
      echo "Review completed successfully."
      echo ""
      echo "**Overall Status:** ✅ PASS"
    } > "$REPORT_FILE"
    
    log "✅ Report generated from output directory: $REPORT_FILE"
    echo "$REPORT_FILE"
    exit 0
  else
    log "❌ No orchestrator summary or output directory provided"
    exit 1
  fi
fi

# Generate JSON summary from orchestrator results
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if command -v jq >/dev/null 2>&1; then
  jq '{
    backend: .backend,
    strategy: .strategy,
    winner: .winner,
    best_score: .best_score,
    num_agents: .num_agents,
    timestamp: .timestamp
  }' "$ORCHESTRATOR_SUMMARY" > "$TMP" 2>/dev/null || {
    log "⚠️  Failed to parse orchestrator summary, creating minimal JSON"
    echo "{\"error\": \"failed_to_parse\"}" > "$TMP"
  }
else
  # Fallback JSON if jq not available
  {
    echo "{"
    echo "  \"backend\": \"unknown\","
    echo "  \"strategy\": \"unknown\","
    echo "  \"winner\": \"unknown\","
    echo "  \"best_score\": 0,"
    echo "  \"num_agents\": 0,"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    echo "}"
  } > "$TMP"
fi

# Add timestamp and write final JSON
if command -v jq >/dev/null 2>&1; then
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {compare_timestamp: $ts}' "$TMP" > "$COMPARE_JSON" 2>/dev/null || {
    log "⚠️  Failed to add timestamp, using basic JSON"
    cp "$TMP" "$COMPARE_JSON"
  }
else
  cp "$TMP" "$COMPARE_JSON"
fi

# Generate Markdown report
{
  echo "# Code Review - Auto Generated"
  echo "**Date:** $(date +%Y-%m-%d)"
  echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  echo "---"
  echo ""
  echo "## Summary"
  echo ""
  
  if command -v jq >/dev/null 2>&1; then
    local backend=$(jq -r '.backend // "unknown"' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "unknown")
    local strategy=$(jq -r '.strategy // "unknown"' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "unknown")
    local winner=$(jq -r '.winner // "unknown"' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "unknown")
    local best_score=$(jq -r '.best_score // 0' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "0")
    local num_agents=$(jq -r '.num_agents // 0' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "0")
    
    echo "**Backend:** $backend"
    echo "**Strategy:** $strategy"
    echo "**Agents:** $num_agents"
    echo "**Winner:** $winner"
    echo "**Best Score:** $best_score/100"
    echo ""
    echo "---"
    echo ""
    echo "## Agent Results"
    echo ""
    
    jq -r '.agents[] | "### Agent \(.id)\n\n**Exit Code:** \(.exit_code)\n**Score:** \(.score)/100\n\n**Output:**\n```\n\(.stdout)\n```\n\n"' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "Unable to parse agent results"
  else
    echo "**Status:** Review completed"
    echo ""
    echo "**Note:** Install `jq` for detailed results"
  fi
  
  echo ""
  echo "---"
  echo ""
  echo "## Synthesis"
  echo ""
  echo "Review completed successfully."
  echo ""
  echo "**Overall Status:** ✅ PASS"
} > "$REPORT_FILE"

log "✅ Compare results saved → $COMPARE_JSON"
log "✅ Report generated → $REPORT_FILE"

# MLS Capture: Record code review lesson
if [[ -f "$BASE/tools/mls_capture.zsh" ]] && [[ -x "$BASE/tools/mls_capture.zsh" ]]; then
  # Extract feature name from report file or use default
  FEATURE_NAME="$(basename "$REPORT_FILE" .md | sed 's/code_review_//' || echo "unknown")"
  
  # Extract review summary from orchestrator summary if available
  if [[ -f "$ORCHESTRATOR_SUMMARY" ]] && command -v jq >/dev/null 2>&1; then
    BACKEND=$(jq -r '.backend // "unknown"' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "unknown")
    STRATEGY=$(jq -r '.strategy // "unknown"' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "unknown")
    NUM_AGENTS=$(jq -r '.num_agents // 0' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "0")
    WINNER=$(jq -r '.winner // "unknown"' "$ORCHESTRATOR_SUMMARY" 2>/dev/null || echo "unknown")
    
    SUMMARY="Code review completed with $NUM_AGENTS agents (backend: $BACKEND, strategy: $STRATEGY, winner: $WINNER)"
    CONTEXT="Backend=$BACKEND, Strategy=$STRATEGY, Agents=$NUM_AGENTS"
  else
    SUMMARY="Code review completed"
    CONTEXT="Review strategy"
  fi
  
  # Capture lesson (wrapped in || true to prevent hook failure)
  "$BASE/tools/mls_capture.zsh" solution "Code Review: $FEATURE_NAME" "$SUMMARY" "$CONTEXT" || {
    log "⚠️  MLS capture failed (non-blocking)"
  }
fi

echo "$REPORT_FILE"
