#!/usr/bin/env zsh
# Create initial state files for any WO assets dropped into bridge/inbox/CLC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

INBOX_DIR="$REPO_ROOT/bridge/inbox/CLC"
STATE_DIR="$REPO_ROOT/followup/state"

extract_field() {
  local payload="$1" key="$2"
  echo "$payload" | jq -r --arg key "$key" '.[$key] // ""' 2>/dev/null || printf ''
}

main() {
  ensure_dir "$INBOX_DIR"
  ensure_dir "$STATE_DIR"
  setopt null_glob

  local processed=0
  local file
  for file in "$INBOX_DIR"/*(.N); do
    case "$file" in
      *.yaml|*.yml|*.json) ;;
      *) continue ;;
    esac

    (( ++processed ))

    local meta_json=""
    if ! meta_json="$(parse_wo_file "$file" 2>/dev/null)"; then
      log_warn "apply_patch_processor: unable to parse $file, using filename-derived metadata"
    fi

    local wo_id title owner
    wo_id="$(normalize_wo_id "$file")"
    if [[ -n "$meta_json" ]]; then
      local declared_id
      declared_id="$(extract_field "$meta_json" "id")"
      [[ -n "$declared_id" ]] && wo_id="$(normalize_wo_id "$declared_id")"
      title="$(extract_field "$meta_json" "title")"
      [[ -z "$title" ]] && title="$(extract_field "$meta_json" "summary")"
      owner="$(extract_field "$meta_json" "owner")"
    fi

    local state_file="$STATE_DIR/$wo_id.json"

    if [[ ! -f "$state_file" ]]; then
      log_info "apply_patch_processor: creating state for $wo_id"
      write_state_json "$state_file" "$wo_id" "pending" "${title:-$wo_id}" "${owner:-}" 
    else
      log_info "apply_patch_processor: state exists for $wo_id (refreshing metadata)"
    fi

    update_state_field "$state_file" "meta.inbox_path" "$file"
    update_state_field "$state_file" "meta.raw_filename" "${file:t}"
    update_state_field "$state_file" "meta.last_seen" "$(iso_now)"
    [[ -n "$title" ]] && update_state_field "$state_file" "title" "$title"
    [[ -n "$owner" ]] && update_state_field "$state_file" "owner" "$owner"
  done

  if (( processed == 0 )); then
    log_info "apply_patch_processor: no WO files found in $INBOX_DIR"
  else
    log_info "apply_patch_processor: processed $processed file(s)"
  fi
}

main "$@"
