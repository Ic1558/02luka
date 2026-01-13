#!/usr/bin/env zsh
# tools/telemetry_rotate.zsh - Rotate telemetry JSONL files
#
# Usage:
#   zsh tools/telemetry_rotate.zsh [--dry-run] [--verbose]
#
# Policy:
#   - Trigger: Files > 10,000 lines
#   - Retention: Keep last 30 rotations
#   - Compression: gzip files > 7 days old
#   - Telemetry: Log rotation events

set -euo pipefail

# Configuration
REPO_ROOT="${LUKA_BASE:-$HOME/02luka}"
TELEMETRY_DIR="$REPO_ROOT/g/telemetry"
ROTATION_LOG="$REPO_ROOT/g/telemetry/ops/rotation.jsonl"
MAX_ROTATIONS=30
LINE_THRESHOLD=10000
COMPRESS_AGE_DAYS=7

DRY_RUN=false
VERBOSE=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --verbose) VERBOSE=true ;;
    --help|-h)
      cat <<'EOF'
Telemetry Log Rotation

Usage: zsh tools/telemetry_rotate.zsh [OPTIONS]

Options:
  --dry-run    Show what would be done without making changes
  --verbose    Show detailed output
  --help       Show this help

Policy:
  - Rotate when file exceeds 10,000 lines
  - Keep last 30 rotations
  - Compress files older than 7 days
  - Log all rotation events

Examples:
  zsh tools/telemetry_rotate.zsh --dry-run
  zsh tools/telemetry_rotate.zsh --verbose
EOF
      exit 0
      ;;
  esac
done

# Ensure directories exist
mkdir -p "$TELEMETRY_DIR/ops"

# Logging function
log_event() {
  local event="$1"
  local file="$2"
  local details="${3:-}"
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local record=$(cat <<EOF
{"ts":"$timestamp","event":"$event","file":"$file","details":"$details","dry_run":$DRY_RUN}
EOF
)
  
  if [[ "$DRY_RUN" == "false" ]]; then
    echo "$record" >> "$ROTATION_LOG"
  fi
  
  if [[ "$VERBOSE" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
    echo "$record"
  fi
}

# Rotate a single file
rotate_file() {
  local file="$1"
  local basename=$(basename "$file")
  local dirname=$(dirname "$file")
  
  # Shift existing rotations
  for i in $(seq $((MAX_ROTATIONS - 1)) -1 1); do
    local old="${dirname}/${basename}.${i}"
    local new="${dirname}/${basename}.$((i + 1))"
    
    # Check both compressed and uncompressed
    for ext in "" ".gz"; do
      if [[ -f "${old}${ext}" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "Would move: ${old}${ext} -> ${new}${ext}"
        else
          mv "${old}${ext}" "${new}${ext}"
        fi
      fi
    done
  done
  
  # Delete oldest rotation
  for ext in "" ".gz"; do
    local oldest="${dirname}/${basename}.$((MAX_ROTATIONS + 1))${ext}"
    if [[ -f "$oldest" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would delete: $oldest"
      else
        rm "$oldest"
        log_event "deleted" "$oldest" "exceeded retention (${MAX_ROTATIONS} rotations)"
      fi
    fi
  done
  
  # Rotate current file
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would rotate: $file -> ${file}.1"
  else
    cp "$file" "${file}.1"  # Copy first (safer)
    > "$file"               # Truncate original
    log_event "rotated" "$file" "lines exceeded threshold"
  fi
}

# Compress old files
compress_old_files() {
  local file="$1"
  local basename=$(basename "$file")
  local dirname=$(dirname "$file")
  local cutoff_date=$(date -v-${COMPRESS_AGE_DAYS}d +%s 2>/dev/null || date -d "${COMPRESS_AGE_DAYS} days ago" +%s)
  
  for i in $(seq 1 $MAX_ROTATIONS); do
    local rotated="${dirname}/${basename}.${i}"
    
    if [[ -f "$rotated" ]] && [[ ! -f "${rotated}.gz" ]]; then
      local file_date=$(stat -f %m "$rotated" 2>/dev/null || stat -c %Y "$rotated")
      
      if [[ "$file_date" -lt "$cutoff_date" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "Would compress: $rotated"
        else
          gzip "$rotated"
          log_event "compressed" "$rotated" "older than ${COMPRESS_AGE_DAYS} days"
        fi
      fi
    fi
  done
}

# Main rotation logic
main() {
  local rotated_count=0
  local compressed_count=0
  
  # Find all JSONL files in telemetry directory
  if [[ ! -d "$TELEMETRY_DIR" ]]; then
    echo "❌ Telemetry directory not found: $TELEMETRY_DIR"
    exit 1
  fi
  
  # Exclude the rotation log itself
  for file in "$TELEMETRY_DIR"/*.jsonl; do
    [[ "$file" == "$ROTATION_LOG" ]] && continue
    [[ ! -f "$file" ]] && continue
    
    local line_count=$(wc -l < "$file" 2>/dev/null || echo 0)
    
    if [[ "$VERBOSE" == "true" ]]; then
      echo "Checking: $(basename "$file") ($line_count lines)"
    fi
    
    # Check if rotation needed
    if [[ "$line_count" -gt "$LINE_THRESHOLD" ]]; then
      if [[ "$VERBOSE" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        echo "⚠️  Rotating: $(basename "$file") ($line_count > $LINE_THRESHOLD lines)"
      fi
      
      rotate_file "$file"
      ((rotated_count++))
    fi
    
    # Compress old rotations
    compress_old_files "$file"
  done
  
  # Summary
  if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "📊 Dry run summary:"
    echo "   Would rotate: $rotated_count files"
  elif [[ "$VERBOSE" == "true" ]]; then
    echo ""
    echo "✅ Rotation complete:"
    echo "   Rotated: $rotated_count files"
    echo "   Log: $ROTATION_LOG"
  fi
}

main
