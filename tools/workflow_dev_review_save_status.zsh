#!/usr/bin/env zsh
# tools/workflow_dev_review_save_status.zsh
# Status viewer for the dev review save workflow telemetry.
# Usage: workflow_dev_review_save_status.zsh [--last N] [--summary]

set -euo pipefail

TELEMETRY_FILE="${HOME}/02luka/g/telemetry/workflow_dev_review_save.jsonl"

if [[ ! -f "$TELEMETRY_FILE" ]]; then
    echo "No telemetry found yet for workflow_dev_review_save."
    exit 0
fi

# Default settings
LAST_N=5
MODE="list"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --last) 
            if [[ $# -lt 2 ]]; then
                echo "Error: --last requires a number" >&2
                exit 1
            fi
            LAST_N="$2"
            shift 2
            ;; 
        --summary)
            MODE="summary"
            shift
            ;; 
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;; 
    esac
done

# Ensure jq is available for robust parsing, otherwise warn and try fallback or exit
if ! command -v jq >/dev/null 2>&1; then
    echo "⚠️  jq not found. Basic text processing will be used (less robust)." >&2
fi

parse_line() {
    local line="$1"
    # Extract fields using jq if available, else grep/sed/awk fallback (brittle for JSON)
    if command -v jq >/dev/null 2>&1; then
        echo "$line" | jq -r '[.ts, .review_exit, .snapshot_exit, .save_exit] | @tsv' 2>/dev/null || echo ""
    else
        # Fallback: extract simplistic pattern. Assumes specific order or naming.
        # This is a risk if JSON structure changes.
        local ts=$(echo "$line" | grep -o '"ts": *"[^"]*"' | cut -d'"' -f4)
        local rev=$(echo "$line" | grep -o '"review_exit": *[0-9-]*' | cut -d':' -f2 | tr -d ' ')
        local snap=$(echo "$line" | grep -o '"snapshot_exit": *[0-9-]*' | cut -d':' -f2 | tr -d ' ')
        local save=$(echo "$line" | grep -o '"save_exit": *[0-9-]*' | cut -d':' -f2 | tr -d ' ')
        if [[ -n "$ts" && -n "$rev" && -n "$snap" && -n "$save" ]]; then
            echo "$ts\t$rev\t$snap\t$save"
        else
            echo ""
        fi
    fi
}

calculate_status() {
    local rev="$1"
    local snap="$2"
    local save="$3"
    
    # Sanitize inputs (remove quotes if any)
    rev=$(echo "$rev" | tr -d '"')
    snap=$(echo "$snap" | tr -d '"')
    save=$(echo "$save" | tr -d '"')

    if [[ "$rev" == "0" && "$snap" == "0" && "$save" == "0" ]]; then
        echo "OK"
    elif [[ "$rev" != "0" ]]; then
        echo "FAIL"
    else
        echo "WARN"
    fi
}

if [[ "$MODE" == "summary" ]]; then
    TOTAL=0
    OK=0
    WARN=0
    FAIL=0
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then continue; fi
        PARSED=$(parse_line "$line")
        if [[ -z "$PARSED" ]]; then continue; fi
        
        read -r ts rev snap save <<< "$PARSED"
        STATUS=$(calculate_status "$rev" "$snap" "$save")
        
        TOTAL=$((TOTAL + 1))
        case "$STATUS" in
            OK) OK=$((OK + 1)) ;; 
            WARN) WARN=$((WARN + 1)) ;; 
            FAIL) FAIL=$((FAIL + 1)) ;; 
        esac
    done < "$TELEMETRY_FILE"
    
    echo "=== Workflow Status Summary ==="
    echo "Total Runs: $TOTAL"
    echo "✅ OK:      $OK"
    echo "⚠️  WARN:    $WARN"
    echo "❌ FAIL:    $FAIL"

else
    # List Mode
    echo "TIMESTAMP            REV SNAP SAVE STATUS"
    echo "-------------------- --- ---- ---- ------"
    
    tail -n "$LAST_N" "$TELEMETRY_FILE" | while IFS= read -r line; do
        if [[ -z "$line" ]]; then continue; fi
        PARSED=$(parse_line "$line")
        if [[ -z "$PARSED" ]]; then continue; fi
        
        read -r ts rev snap save <<< "$PARSED"
        STATUS=$(calculate_status "$rev" "$snap" "$save")
        
        # Format timestamp
        ts_short=$(echo "$ts" | cut -d'.' -f1 | tr 'T' ' ')
        
        printf "% -20s %3s %4s %4s %s\n" "$ts_short" "$rev" "$snap" "$save" "$STATUS"
    done
fi
