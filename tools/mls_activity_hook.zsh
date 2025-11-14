#!/usr/bin/env zsh
# MLS Activity Hook - Auto-record common activities
# Source this file in other scripts to enable auto-recording
set -euo pipefail

# Function to record activity to MLS
mls_record() {
  local activity_type="$1"
  local title="$2"
  local summary="$3"
  local tags="${4:-}"
  local wo_id="${5:-}"
  
  if [[ -f "$HOME/02luka/tools/mls_auto_record.zsh" ]]; then
    "$HOME/02luka/tools/mls_auto_record.zsh" \
      "$activity_type" \
      "$title" \
      "$summary" \
      "$tags" \
      "$wo_id" 2>/dev/null || true
  fi
}

# Auto-record on script exit (capture what was done)
mls_record_on_exit() {
  local script_name=$(basename "$0")
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    mls_record "work" \
      "Script completed: $script_name" \
      "Script $script_name completed successfully" \
      "script,completed" \
      ""
  else
    mls_record "failure" \
      "Script failed: $script_name" \
      "Script $script_name failed with exit code $exit_code" \
      "script,failure" \
      ""
  fi
}

# Register exit trap
trap mls_record_on_exit EXIT

# Export function for use in other scripts
export -f mls_record
