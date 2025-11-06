#!/usr/bin/env zsh
# telemetry_validate.zsh – Validator for telemetry JSONL files (Phase 14.2)
# Validates schema conformance, required fields, RFC3339 timestamps, and duplicate detection
set -euo pipefail

# Default values
path=""
strict=0
report=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      path="$2"
      shift 2
      ;;
    --strict)
      strict=1
      shift 1
      ;;
    --report)
      report="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: telemetry_validate.zsh --path <file> [--strict] [--report <file>]" >&2
      echo "Options:" >&2
      echo "  --path <file>    JSONL file to validate (required)" >&2
      echo "  --strict         Enforce strict mode: disallow unknown fields" >&2
      echo "  --report <file>  Write validation report to file" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$path" ]]; then
  echo "ERROR: --path is required" >&2
  exit 1
fi

if [[ ! -f "$path" ]]; then
  echo "ERROR: File not found: $path" >&2
  exit 1
fi

# Counters
fails=0
dups=0
warnings=0
total_lines=0
valid_events=0

# Temporary file for tracking event_ids
tmp_ids=$(mktemp)
trap "rm -f $tmp_ids" EXIT

# Known valid fields for strict mode
known_fields=("ts" "event" "component" "level" "data" "duration_ms" "batch_id" "event_id" "source" "__normalized")

echo "Validating: $path"
[[ $strict -eq 1 ]] && echo "Mode: STRICT (unknown fields will fail)"

lineno=0
while IFS= read -r line; do
  lineno=$((lineno+1))
  total_lines=$((total_lines+1))

  # Skip blank lines
  if [[ -z "${line// }" ]]; then
    continue
  fi

  # Check if valid JSON
  if ! echo "$line" | jq -e . >/dev/null 2>&1; then
    echo "ERROR [line $lineno]: Invalid JSON" >&2
    fails=$((fails+1))
    continue
  fi

  # Check required fields
  req_check=$(echo "$line" | jq -e '.ts and .event and .component and .event_id' 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "ERROR [line $lineno]: Missing required fields (ts, event, component, event_id)" >&2
    fails=$((fails+1))
    continue
  fi

  # Validate RFC3339 timestamp format (strict Z suffix)
  ts_value=$(echo "$line" | jq -r '.ts')
  if ! echo "$ts_value" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
    echo "ERROR [line $lineno]: Invalid timestamp format (expected RFC3339 with Z suffix): $ts_value" >&2
    fails=$((fails+1))
  fi

  # Validate component enum
  component_value=$(echo "$line" | jq -r '.component')
  valid_components=("gg" "cls" "cdc" "gm" "bridge" "rag" "router")
  if [[ ! " ${valid_components[@]} " =~ " ${component_value} " ]]; then
    echo "ERROR [line $lineno]: Invalid component: $component_value (must be one of: ${valid_components[*]})" >&2
    fails=$((fails+1))
  fi

  # Validate level enum (if present)
  if echo "$line" | jq -e '.level' >/dev/null 2>&1; then
    level_value=$(echo "$line" | jq -r '.level')
    valid_levels=("debug" "info" "warn" "error")
    if [[ ! " ${valid_levels[@]} " =~ " ${level_value} " ]]; then
      echo "ERROR [line $lineno]: Invalid level: $level_value (must be one of: ${valid_levels[*]})" >&2
      fails=$((fails+1))
    fi
  fi

  # Validate event_id format (64-char hex)
  event_id=$(echo "$line" | jq -r '.event_id')
  if ! echo "$event_id" | grep -qE '^[a-f0-9]{64}$'; then
    echo "ERROR [line $lineno]: Invalid event_id format (expected 64-char hex): $event_id" >&2
    fails=$((fails+1))
  fi

  # Strict mode: check for unknown fields
  if [[ $strict -eq 1 ]]; then
    all_keys=$(echo "$line" | jq -r 'keys | .[]')
    while IFS= read -r key; do
      if [[ ! " ${known_fields[@]} " =~ " ${key} " ]]; then
        echo "ERROR [line $lineno]: Unknown field in strict mode: $key" >&2
        fails=$((fails+1))
      fi
    done <<< "$all_keys"
  fi

  # Check for duplicate event_id
  if grep -qxF "$event_id" "$tmp_ids"; then
    echo "ERROR [line $lineno]: Duplicate event_id: $event_id" >&2
    dups=$((dups+1))
    fails=$((fails+1))
  else
    echo "$event_id" >> "$tmp_ids"
  fi

  # Count valid events
  if [[ $fails -eq 0 ]] || [[ $lineno -gt 1 ]]; then
    valid_events=$((valid_events+1))
  fi
done < "$path"

# Generate report if requested
if [[ -n "$report" ]]; then
  mkdir -p "$(dirname "$report")"
  cat > "$report" <<EOF
# Telemetry Validation Report

**File**: \`$path\`
**Date**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Mode**: $([ $strict -eq 1 ] && echo "STRICT" || echo "NORMAL")

## Summary

- Total lines: $total_lines
- Valid events: $valid_events
- Errors: $fails
- Duplicates: $dups
- Warnings: $warnings

## Result

$([ $fails -eq 0 ] && echo "✅ **PASS** - All validations passed" || echo "❌ **FAIL** - $fails error(s) detected")

## Schema Version

Validated against: **Telemetry Unified Schema v1.1**

## Validation Rules Applied

- Required fields: ts, event, component, event_id
- Timestamp format: RFC3339 with Z suffix
- Component enum validation
- Level enum validation (if present)
- Event ID format: 64-char SHA256 hex
- Duplicate event_id detection
$([ $strict -eq 1 ] && echo "- Strict mode: No unknown fields allowed")

---
Generated by \`tools/telemetry_validate.zsh\`
EOF
  echo "Report written to: $report"
fi

# Exit with appropriate code
if [[ $fails -gt 0 ]]; then
  echo ""
  echo "❌ VALIDATION FAILED"
  echo "   Errors: $fails"
  echo "   Duplicates: $dups"
  exit 1
else
  echo ""
  echo "✅ VALIDATION PASSED"
  echo "   Total events: $valid_events"
  echo "   Mode: $([ $strict -eq 1 ] && echo 'STRICT' || echo 'NORMAL')"
  exit 0
fi
