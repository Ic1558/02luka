#!/usr/bin/env zsh
# Create initial state files for any WO assets dropped into bridge/inbox/CLC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

REPO_ROOT="$(resolve_repo_root)"
DATA_ROOT="$(resolve_data_root "$REPO_ROOT")"
STATE_DIR="$DATA_ROOT/followup/state"
INBOX_DIRS=("$DATA_ROOT/bridge/inbox/CLC")
if [[ "$DATA_ROOT" != "$REPO_ROOT" && -d "$REPO_ROOT/bridge/inbox/CLC" ]]; then
  INBOX_DIRS+=("$REPO_ROOT/bridge/inbox/CLC")
fi

extract_field() {
  local payload="$1" key="$2"
  echo "$payload" | jq -r --arg key "$key" '.[$key] // ""' 2>/dev/null || printf ''
}

main() {
  local inbox_dir
  for inbox_dir in "${INBOX_DIRS[@]}"; do
    ensure_dir "$inbox_dir"
  done
  ensure_dir "$STATE_DIR"
  setopt null_glob

  local processed=0
  local file
  for inbox_dir in "${INBOX_DIRS[@]}"; do
    log_info "apply_patch_processor: scanning $inbox_dir"
    for file in "$inbox_dir"/*(.N); do
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
  done

  if (( processed == 0 )); then
    log_info "apply_patch_processor: no WO files found in configured inboxes"
  else
    log_info "apply_patch_processor: processed $processed file(s)"
  fi
}

main "$@"
