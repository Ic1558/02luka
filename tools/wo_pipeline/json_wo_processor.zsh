#!/usr/bin/env zsh
# Parse WO definitions into normalized state files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

INBOX_DIR="$REPO_ROOT/bridge/inbox/CLC"
STATE_DIR="$REPO_ROOT/followup/state"

json_field() {
  local payload="$1" key="$2"
  echo "$payload" | jq -r --arg key "$key" '.[$key] // ""' 2>/dev/null || printf ''
}

main() {
  ensure_dir "$INBOX_DIR"
  ensure_dir "$STATE_DIR"
  setopt null_glob

  local file processed=0
  for file in "$INBOX_DIR"/*(.N); do
    case "$file" in
      *.yaml|*.yml|*.json) ;;
      *) continue ;;
    esac

    (( ++processed ))

    local meta_json
    if ! meta_json="$(parse_wo_file "$file" 2>/dev/null)"; then
      log_warn "json_wo_processor: unable to parse $file"
      continue
    fi

    local declared_id
    declared_id="$(json_field "$meta_json" "id")"
    local fallthrough_id="$(normalize_wo_id "$file")"
    local wo_id="$fallthrough_id"
    [[ -n "$declared_id" ]] && wo_id="$(normalize_wo_id "$declared_id")"

    local state_file="$STATE_DIR/$wo_id.json"
    local fallback_state="$STATE_DIR/$fallthrough_id.json"

    if [[ "$state_file" != "$fallback_state" && -f "$fallback_state" && ! -f "$state_file" ]]; then
      log_info "json_wo_processor: renaming state $fallback_state -> $state_file"
      mv "$fallback_state" "$state_file"
    fi

    if [[ ! -f "$state_file" ]]; then
      log_info "json_wo_processor: state missing for $wo_id, creating baseline"
      local title owner
      title="$(json_field "$meta_json" "title")"
      [[ -z "$title" ]] && title="$wo_id"
      owner="$(json_field "$meta_json" "owner")"
      write_state_json "$state_file" "$wo_id" "pending" "$title" "$owner"
    fi

    WO_META="$meta_json" "$WO_PIPELINE_PYTHON_BIN" - "$state_file" "$file" <<'PY'
import json, sys, pathlib, datetime, os
state_path = pathlib.Path(sys.argv[1])
inbox_file = pathlib.Path(sys.argv[2])
meta = json.loads(os.environ.get('WO_META', '{}'))
now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
state = {}
if state_path.exists():
    try:
        state = json.loads(state_path.read_text(encoding='utf-8'))
    except json.JSONDecodeError:
        state = {}

fields = ['id', 'title', 'summary', 'description', 'owner', 'category', 'priority',
          'due_date', 'goal', 'progress', 'notes', 'source']
for key in fields:
    value = meta.get(key)
    if value is None:
        continue
    state[key] = value

# Tags: merge & dedupe
existing_tags = set()
for tag in state.get('tags', []):
    if isinstance(tag, str) and tag.strip():
        existing_tags.add(tag.strip())
for tag in meta.get('tags', []) or []:
    if isinstance(tag, str) and tag.strip():
        existing_tags.add(tag.strip())
state['tags'] = sorted(existing_tags)

meta_block = state.get('meta', {})
if not isinstance(meta_block, dict):
    meta_block = {}
meta_block['inbox_path'] = str(inbox_file)
meta_block['raw_priority'] = meta.get('raw_priority')
meta_block['executor'] = meta.get('executor') or meta_block.get('executor')
meta_block['category'] = meta.get('category') or meta_block.get('category')
meta_block['last_parsed'] = now
state['meta'] = meta_block

# Ensure numeric progress/int values are valid
try:
    progress = int(state.get('progress', 0))
except Exception:
    progress = 0
state['progress'] = max(0, min(100, progress))

state.setdefault('status', 'pending')
state.setdefault('title', state.get('id', ''))
state.setdefault('owner', '')
state['updated_at'] = now
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
PY
  done

  if (( processed == 0 )); then
    log_info "json_wo_processor: no WO files found"
  else
    log_info "json_wo_processor: parsed $processed file(s)"
  fi
}

main "$@"
