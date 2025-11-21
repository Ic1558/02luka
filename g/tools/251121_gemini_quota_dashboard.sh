#!/usr/bin/env bash
# Gemini Quota Dashboard
# Created: 2025-11-21
# Purpose: Pretty-print Gemini API quota status

set -e

REPO_ROOT="/Users/icmini/02luka"
JSON_FILE="$REPO_ROOT/g/telemetry/251121_gemini_quota.json"

cd "$REPO_ROOT"
source venv/bin/activate

# Run quota check with JSON output
python g/tools/check_quota.py --json-out "$JSON_FILE"

echo ""
echo "=== Gemini Quota Dashboard ==="
echo ""

# Check if jq is available
if command -v jq &> /dev/null; then
    # Pretty-print with jq
    echo "Status:    $(jq -r '.status' "$JSON_FILE")"
    echo "Model:     $(jq -r '.model' "$JSON_FILE")"
    echo "Message:   $(jq -r '.message' "$JSON_FILE")"
    echo "Test OK:   $(jq -r '.test_call_ok' "$JSON_FILE")"
    echo "Timestamp: $(jq -r '.timestamp' "$JSON_FILE")"
    
    ERROR_CODE=$(jq -r '.error_code' "$JSON_FILE")
    if [[ "$ERROR_CODE" != "null" ]]; then
        echo "Error:     $ERROR_CODE"
    fi
else
    # Fallback: cat the JSON
    echo "JSON Output:"
    cat "$JSON_FILE"
    echo ""
    echo "💡 Tip: Install jq for prettier output: brew install jq"
fi

echo ""
echo "JSON file: $JSON_FILE"
