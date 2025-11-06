#!/usr/bin/env zsh
# telemetry_emit.zsh – Telemetry event emitter for Phase 14.2
# Generates compliant events with SHA256 event_id and writes to JSONL sink
set -euo pipefail

# Default values
sink="g/telemetry_unified/unified.jsonl"
event=""
component=""
level="info"
data="{}"
ts=""
batch_id=""
source=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sink)
      sink="$2"
      shift 2
      ;;
    --event)
      event="$2"
      shift 2
      ;;
    --component)
      component="$2"
      shift 2
      ;;
    --level)
      level="$2"
      shift 2
      ;;
    --data)
      data="$2"
      shift 2
      ;;
    --ts)
      ts="$2"
      shift 2
      ;;
    --batch-id)
      batch_id="$2"
      shift 2
      ;;
    --source)
      source="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: telemetry_emit.zsh --event <name> --component <component> [options]" >&2
      echo "Options:" >&2
      echo "  --sink <path>       Output JSONL file (default: g/telemetry_unified/unified.jsonl)" >&2
      echo "  --event <name>      Event name (required, e.g., rag.ctx.hit)" >&2
      echo "  --component <name>  Component (required: gg|cls|cdc|gm|bridge|rag|router)" >&2
      echo "  --level <level>     Log level (default: info, options: debug|info|warn|error)" >&2
      echo "  --data <json>       Event payload as JSON object (default: {})" >&2
      echo "  --ts <timestamp>    RFC3339 timestamp (default: auto-generated UTC)" >&2
      echo "  --batch-id <id>     Batch identifier (optional)" >&2
      echo "  --source <path>     Source path or agent name (optional)" >&2
      exit 1
      ;;
  esac
done

# Validate required fields
if [[ -z "$event" || -z "$component" ]]; then
  echo "ERROR: --event and --component are required" >&2
  exit 1
fi

# Validate component enum
valid_components=("gg" "cls" "cdc" "gm" "bridge" "rag" "router")
if [[ ! " ${valid_components[@]} " =~ " ${component} " ]]; then
  echo "ERROR: component must be one of: ${valid_components[*]}" >&2
  exit 1
fi

# Validate level enum
valid_levels=("debug" "info" "warn" "error")
if [[ ! " ${valid_levels[@]} " =~ " ${level} " ]]; then
  echo "ERROR: level must be one of: ${valid_levels[*]}" >&2
  exit 1
fi

# Validate data is valid JSON
if ! echo "$data" | jq -e . >/dev/null 2>&1; then
  echo "ERROR: --data must be valid JSON" >&2
  exit 1
fi

# Auto-generate timestamp if not provided
if [[ -z "$ts" ]]; then
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
fi

# Ensure sink directory exists
mkdir -p "$(dirname "$sink")"

# Build canonical JSON payload (sorted keys, no event_id yet)
payload=$(jq -cn \
  --arg ts "$ts" \
  --arg event "$event" \
  --arg component "$component" \
  --arg level "$level" \
  --argjson data "$data" \
  --arg batch_id "$batch_id" \
  --arg source "$source" \
  '{
    ts: $ts,
    event: $event,
    component: $component,
    level: $level,
    data: $data,
    __normalized: true
  }
  + (if ($batch_id | length) > 0 then {batch_id: $batch_id} else {} end)
  + (if ($source | length) > 0 then {source: $source} else {} end)
' | jq -S -c .)

# Compute SHA256 event_id
# macOS uses 'shasum -a 256', Linux uses 'sha256sum'
if command -v sha256sum >/dev/null 2>&1; then
  event_id=$(printf "%s" "$payload" | sha256sum | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  event_id=$(printf "%s" "$payload" | shasum -a 256 | awk '{print $1}')
else
  echo "ERROR: Neither sha256sum nor shasum found" >&2
  exit 1
fi

# Add event_id to payload
final=$(printf '%s' "$payload" | jq -c --arg eid "$event_id" '. + {event_id: $eid}')

# Append to sink file (JSONL format)
printf '%s\n' "$final" >> "$sink"

# Success output
echo "✓ Event emitted"
echo "  sink: $sink"
echo "  event: $event"
echo "  event_id: $event_id"
