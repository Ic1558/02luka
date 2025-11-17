#!/usr/bin/env zsh
# CLC 3-Layer Save System with Auto-Verify
# Layer 1: Session file → g/reports/sessions/session_TIMESTAMP.md
# Layer 2: Updates 02luka.md and ALL AI context files (simultaneously)
# Layer 3: Appends to CLAUDE_MEMORY_SYSTEM.md
# Layer 4: Verification (NEW) - runs safety checks before completion

set -euo pipefail

# Parse arguments
SKIP_VERIFY=false
SESSION_SUMMARY=""
SESSION_ACTIONS=""
SESSION_STATUS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-verify)
      SKIP_VERIFY=true
      echo "⚠️  WARNING: Verification will be skipped (--skip-verify flag)" >&2
      echo "⚠️  This bypasses safety checks and may lead to incomplete or invalid saves" >&2
      shift
      ;;
    --summary)
      if [[ $# -lt 2 ]]; then
        echo "Error: --summary requires a value" >&2
        exit 1
      fi
      SESSION_SUMMARY="$2"
      shift 2
      ;;
    --actions)
      if [[ $# -lt 2 ]]; then
        echo "Error: --actions requires a value" >&2
        exit 1
      fi
      SESSION_ACTIONS="$2"
      shift 2
      ;;
    --status)
      if [[ $# -lt 2 ]]; then
        echo "Error: --status requires a value" >&2
        exit 1
      fi
      SESSION_STATUS="$2"
      shift 2
      ;;
    --help|-h)
      cat <<EOF
Usage: tools/save.sh [OPTIONS]

Save session to 3-layer memory system with automatic verification.

Options:
  --skip-verify       Skip verification step (not recommended)
  --summary TEXT     Session summary text
  --actions TEXT     Actions taken during session
  --status TEXT      Current system status
  --help, -h         Show this help message

Examples:
  tools/save.sh --summary "Fixed CI issues" --actions "Updated workflows"
  tools/save.sh --skip-verify  # Not recommended - bypasses safety checks

Verification:
  By default, save.sh runs verification after saving all layers.
  Verification ensures data integrity and system health.
  Use --skip-verify only in exceptional circumstances.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Get base directory from environment or default
BASE_DIR="${LUKA_SOT:-$HOME/02luka}"
REPO_DIR="$BASE_DIR"
SESSION_DIR="$REPO_DIR/g/reports/sessions"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_FILE="$SESSION_DIR/session_$TIMESTAMP.md"
LUKA_MD="$REPO_DIR/02luka.md"
MEMORY_FILE="$BASE_DIR/memory/CLAUDE_MEMORY_SYSTEM.md"

# Create directories if needed
mkdir -p "$SESSION_DIR"
mkdir -p "$(dirname "$MEMORY_FILE")"

# Default session content if not provided
if [[ -z "$SESSION_SUMMARY" ]]; then
  SESSION_SUMMARY="Session saved at $TIMESTAMP"
fi

if [[ -z "$SESSION_ACTIONS" ]]; then
  SESSION_ACTIONS="(No actions specified)"
fi

if [[ -z "$SESSION_STATUS" ]]; then
  SESSION_STATUS="(No status specified)"
fi

# Layer 1: Create session file
cat > "$SESSION_FILE" <<EOF
# CLC Session - $TIMESTAMP

## Summary
$SESSION_SUMMARY

## Actions Taken
$SESSION_ACTIONS

## Status
$SESSION_STATUS

Saved: $TIMESTAMP
EOF

echo "✅ Layer 1: Session saved → $SESSION_FILE"

# Layer 2: Update 02luka.md and all AI context files
LAYER2_UPDATED=0

# Update 02luka.md
if [[ -f "$LUKA_MD" ]]; then
    # Add Last Session marker (append to end of file)
    echo "" >> "$LUKA_MD"
    echo "<!-- Last Session: $TIMESTAMP -->" >> "$LUKA_MD"
    ((LAYER2_UPDATED++))
fi

# Update AI context files (all at the same time)
AI_CONTEXT_FILES=(
    "$BASE_DIR/ai_context_entry.md"
    "$BASE_DIR/docs/ai_read.md"
    "$BASE_DIR/f/ai_context/01_current_work.json"
    "$BASE_DIR/f/ai_context/02_task_details.md"
    "$BASE_DIR/f/ai_context/mapping.json"
    "$BASE_DIR/ai_daily.json"
    "$BASE_DIR/run/system_status.v2.json"
)

for AI_FILE in "${AI_CONTEXT_FILES[@]}"; do
    if [[ -f "$AI_FILE" ]]; then
        # For JSON files, update timestamp field if it exists
        if [[ "$AI_FILE" == *.json ]]; then
            # Try to update last_session or timestamp field using jq if available
            if command -v jq >/dev/null 2>&1; then
                # Create temp file with updated timestamp
                TEMP_JSON=$(mktemp)
                # Try to update last_session and last_updated fields
                if jq --arg ts "$TIMESTAMP" '. + {last_session: $ts, last_updated: $ts}' "$AI_FILE" > "$TEMP_JSON" 2>/dev/null; then
                    mv "$TEMP_JSON" "$AI_FILE"
                    ((LAYER2_UPDATED++))
                else
                    # If jq update fails, try adding comment at end (for JSON with comments)
                    echo "" >> "$AI_FILE"
                    echo "// Last Session: $TIMESTAMP" >> "$AI_FILE"
                    ((LAYER2_UPDATED++))
                fi
                rm -f "$TEMP_JSON" 2>/dev/null || true
            else
                # Fallback: append comment
                echo "" >> "$AI_FILE"
                echo "// Last Session: $TIMESTAMP" >> "$AI_FILE"
                ((LAYER2_UPDATED++))
            fi
        else
            # For markdown files, add Last Session marker
            echo "" >> "$AI_FILE"
            echo "<!-- Last Session: $TIMESTAMP -->" >> "$AI_FILE"
            ((LAYER2_UPDATED++))
        fi
    fi
done

if [[ $LAYER2_UPDATED -gt 0 ]]; then
    echo "✅ Layer 2: Updated 02luka.md and $((LAYER2_UPDATED - 1)) AI context file(s)"
else
    echo "⚠️  Layer 2: No context files found to update" >&2
fi

# Layer 3: Append to CLAUDE_MEMORY_SYSTEM.md
cat >> "$MEMORY_FILE" <<EOF

## Session $TIMESTAMP
- Summary: $SESSION_SUMMARY
- Actions: $SESSION_ACTIONS
- Status: $SESSION_STATUS

EOF

echo "✅ Layer 3: Appended to CLAUDE_MEMORY_SYSTEM.md"

# Layer 4: Verification (NEW)
VERIFY_EXIT=0
VERIFY_STATUS="SKIPPED"
VERIFY_DURATION=0
VERIFY_TESTS=""

if [[ "$SKIP_VERIFY" != "true" ]]; then
    echo ""
    echo "→ Running verification..."
    VERIFY_START=$(date +%s)
    
    # Try to find and run verification command
    VERIFY_CMD=""
    if [[ -f "$BASE_DIR/tools/ci_check.zsh" ]]; then
        VERIFY_CMD="$BASE_DIR/tools/ci_check.zsh --view-mls"
        VERIFY_TESTS="ci_check.zsh --view-mls"
    elif [[ -f "$BASE_DIR/tools/auto_verify_template.sh" ]]; then
        VERIFY_CMD="$BASE_DIR/tools/auto_verify_template.sh system_health"
        VERIFY_TESTS="auto_verify_template.sh system_health"
    else
        # Lightweight verification: check if files were created
        VERIFY_TESTS="file_existence_check"
        if [[ ! -f "$SESSION_FILE" ]]; then
            echo "❌ Verification failed: Session file not created" >&2
            VERIFY_EXIT=1
        elif [[ ! -f "$LUKA_MD" ]]; then
            echo "⚠️  Verification warning: 02luka.md not found" >&2
        elif [[ ! -f "$MEMORY_FILE" ]]; then
            echo "⚠️  Verification warning: CLAUDE_MEMORY_SYSTEM.md not found" >&2
        else
            # Basic file checks passed
            VERIFY_EXIT=0
        fi
    fi
    
    # Run verification command if found
    if [[ -n "$VERIFY_CMD" ]]; then
        if eval "$VERIFY_CMD" >/dev/null 2>&1; then
            VERIFY_EXIT=0
            VERIFY_STATUS="PASS"
        else
            VERIFY_EXIT=$?
            VERIFY_STATUS="FAIL"
        fi
    else
        # Use file existence check result
        if [[ $VERIFY_EXIT -eq 0 ]]; then
            VERIFY_STATUS="PASS"
        else
            VERIFY_STATUS="FAIL"
        fi
    fi
    
    VERIFY_DURATION=$(($(date +%s) - VERIFY_START))
    
    # Emit verification summary (for dashboard scraping)
    echo ""
    echo "=== Verification Summary ==="
    echo "Status: $VERIFY_STATUS"
    echo "Duration: ${VERIFY_DURATION}s"
    echo "Tests: $VERIFY_TESTS"
    echo "Exit Code: $VERIFY_EXIT"
    echo "============================"
    
    if [[ $VERIFY_EXIT -ne 0 ]]; then
        echo "" >&2
        echo "❌ Verification failed - save may be incomplete or invalid" >&2
        echo "   Use --skip-verify to bypass (not recommended)" >&2
        exit $VERIFY_EXIT
    fi
    
    echo "✅ Verification passed"
fi

echo ""
echo "🎉 3-Layer save complete!"
echo "   Session: $SESSION_FILE"
if [[ "$VERIFY_STATUS" != "SKIPPED" ]]; then
    echo "   Verification: $VERIFY_STATUS (${VERIFY_DURATION}s)"
fi
