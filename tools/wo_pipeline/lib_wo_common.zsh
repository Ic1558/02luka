#!/usr/bin/env zsh
# Shared helpers for the WO pipeline scripts

set -euo pipefail

: "${PATH:=/usr/bin:/bin}"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Emit ISO-8601 timestamp in UTC
iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Resolve repo root from this library location
resolve_repo_root() {
  local source_path
  source_path="${(%):-%x}"
  [[ -z "$source_path" ]] && source_path="$0"
  local script_dir
  script_dir="$(cd "$(dirname "$source_path")" && pwd)"
  local repo_root
  repo_root="$(cd "$script_dir/../.." && pwd)"
  echo "$repo_root"
}

# Basic logging helpers
tag_log() {
  local level="$1"; shift
  printf '[%s] [%s] %s\n' "$(iso_now)" "$level" "$*" >&2
}

log_info()  { tag_log INFO  "$*"; }
log_warn()  { tag_log WARN  "$*"; }
log_error() { tag_log ERROR "$*"; }

if [[ -z "${WO_PIPELINE_PYTHON_BIN:-}" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    WO_PIPELINE_PYTHON_BIN="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    WO_PIPELINE_PYTHON_BIN="$(command -v python)"
  else
    log_error "python3 not found in PATH"
    return 1
  fi
fi

ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

normalize_wo_id() {
  local input="$1"
  local base="$input"
  if [[ -f "$input" ]]; then
    base="${input:t}"
  else
    base="${base##*/}"
  fi
  # Strip trailing extensions (once)
  if [[ "$base" == *.* ]]; then
    base="${base%.*}"
  fi
  base="${base// /_}"
  base="${base//[^A-Za-z0-9._-]/-}"
  base="${base##-}"
  base="${base%%-}"
  [[ -z "$base" ]] && base="wo-$(date +%s)"
  echo "$base"
}

write_state_json() {
  local state_file="$1"
  local wo_id="$2"
  local wo_status="$3"
  local title="${4:-$wo_id}"
  local owner="${5:-}" 
  ensure_dir "${state_file:h}"
  "$WO_PIPELINE_PYTHON_BIN" - "$state_file" "$wo_id" "$wo_status" "$title" "$owner" <<'PY'
import json, sys, pathlib, datetime
state_file = pathlib.Path(sys.argv[1])
wo_id, status, title, owner = sys.argv[2:6]
now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
data = {
    'id': wo_id,
    'title': title or wo_id,
    'summary': title or wo_id,
    'description': '',
    'owner': owner,
    'category': '',
    'priority': 'Medium',
    'status': status,
    'created_at': now,
    'updated_at': now,
    'due_date': '',
    'goal': '',
    'progress': 0,
    'tags': [],
    'notes': '',
    'last_error': '',
    'source': 'work_order',
    'meta': {
        'state_schema_version': 1
    }
}
state_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
PY
}

# Update a dot-delimited field inside the JSON state file
update_state_field() {
  local state_file="$1"
  local field_path="$2"
  local value="$3"
  local raw_type="${4:-auto}"
  "$WO_PIPELINE_PYTHON_BIN" - "$state_file" "$field_path" "$value" "$raw_type" <<'PY'
import json, sys, pathlib, datetime, re
state_path = pathlib.Path(sys.argv[1])
field_path = sys.argv[2]
raw_value = sys.argv[3]
raw_type = sys.argv[4]
if not state_path.exists():
    raise SystemExit(f"State file {state_path} missing")
data = json.loads(state_path.read_text(encoding='utf-8'))
if raw_type == 'json':
    value = json.loads(raw_value)
elif raw_type == 'int':
    value = int(float(raw_value))
elif raw_type == 'float':
    value = float(raw_value)
else:
    lowered = raw_value.strip().lower()
    number_pattern = re.compile(r'^-?\d+(\.\d+)?$')
    if lowered in {'true', 'false'}:
        value = lowered == 'true'
    elif lowered == 'null':
        value = None
    elif number_pattern.match(raw_value.strip()):
        value = float(raw_value)
        value = int(value) if value.is_integer() else value
    elif raw_value.strip().startswith('{') or raw_value.strip().startswith('['):
        try:
            value = json.loads(raw_value)
        except json.JSONDecodeError:
            value = raw_value
    else:
        value = raw_value
segments = [seg for seg in field_path.split('.') if seg]
current = data
for segment in segments[:-1]:
    node = current.get(segment)
    if not isinstance(node, dict):
        node = {}
        current[segment] = node
    current = node
current[segments[-1]] = value
data['updated_at'] = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
state_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
PY
}

mark_status() {
  local state_file="$1"
  local new_status="$2"
  update_state_field "$state_file" "status" "$new_status"
}

# Optional helper to force followup.json regeneration after mutations
trigger_followup_regen() {
  local repo_root
  repo_root="$(resolve_repo_root)"
  local workspace
  workspace="$(cd "$repo_root/.." && pwd)"
  local helper="$workspace/tools/regenerate_followup_after_state.zsh"
  local generator="$workspace/tools/claude_tools/generate_followup_data.zsh"
  if [[ -x "$helper" ]]; then
    "$helper" >/dev/null 2>&1 || log_warn "regenerate_followup_after_state.zsh exited non-zero"
  elif [[ -x "$generator" ]]; then
    "$generator" >/dev/null 2>&1 || log_warn "generate_followup_data.zsh exited non-zero"
  fi
}

# Parse WO file (YAML or JSON) and emit normalized JSON
parse_wo_file() {
  local wo_file="$1"
  "$WO_PIPELINE_PYTHON_BIN" - "$wo_file" <<'PY'
import json, sys, pathlib, datetime
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
if not text.strip():
    raise SystemExit('Empty WO file')
if text.lstrip().startswith('{'):
    data = json.loads(text)
else:
    try:
        import yaml  # PyYAML
    except ImportError as exc:
        raise SystemExit(f"PyYAML missing for {path}: {exc}")
    data = yaml.safe_load(text)
if data is None:
    data = {}
if isinstance(data, list):
    data = data[0] if data else {}
if not isinstance(data, dict):
    data = {}

def pick(*keys, default=""):
    for key in keys:
        value = data.get(key)
        if value is None:
            continue
        if isinstance(value, str) and value.strip():
            return value.strip()
        if isinstance(value, (int, float)):
            return str(value)
    return default

def normalize_priority(value):
    if value is None:
        return 'Medium'
    val = str(value).strip().lower()
    if val in {'p0', 'urgent', 'critical', 'high'}:
        return 'High'
    if val in {'p2', 'medium', 'normal'}:
        return 'Medium'
    if val in {'p3', 'low'}:
        return 'Low'
    return 'Medium'

def normalize_progress(value):
    if value is None:
        return 0
    try:
        num = float(value)
    except Exception:
        return 0
    if num < 0:
        num = 0
    if num > 100:
        num = 100
    return int(round(num))

def coerce_list(value):
    if value is None:
        return []
    if isinstance(value, (list, tuple, set)):
        return [str(item) for item in value if item is not None]
    return [str(value)]

objectives = data.get('objectives')
if isinstance(objectives, (list, tuple)):
    goal_text = '; '.join(str(item) for item in objectives if item is not None)
else:
    goal_text = pick('goal', 'objective')

tags = coerce_list(data.get('tags') or data.get('labels'))
category = pick('category', 'classification', 'type', 'intent', 'phase')
if category and category not in tags:
    tags.append(category)
priority = normalize_priority(data.get('priority') or data.get('urgency') or data.get('severity'))
due_date = pick('due_date', 'due', 'deadline', 'target_date')
description = pick('description', 'summary', 'notes')
summary = pick('summary', 'title', 'description')
owner = pick('owner', 'assignee', 'maintainer', 'requested_by', 'created_by')
if not owner and isinstance(data.get('route_hints'), dict):
    owner = data['route_hints'].get('preferred_executor') or ''
progress = normalize_progress(data.get('progress') or data.get('completion'))
executor = pick('executor', 'handler', default='')
if not executor and isinstance(data.get('route_hints'), dict):
    preferred = data['route_hints'].get('preferred_executor')
    if preferred:
        executor = preferred

result = {
    'id': pick('id', 'wo_id', 'work_order_id', default=path.stem),
    'title': pick('title', 'summary', default=path.stem),
    'summary': summary or pick('title', default=path.stem),
    'owner': owner,
    'category': category,
    'priority': priority,
    'status': pick('status', 'state', default='pending'),
    'due_date': due_date,
    'goal': goal_text,
    'progress': progress,
    'tags': tags,
    'notes': pick('notes', default=''),
    'description': description,
    'source': data.get('source') or 'work_order',
    'executor': executor,
    'raw_priority': data.get('priority'),
    'raw_path': str(path)
}
print(json.dumps(result, ensure_ascii=False, separators=(',', ':')))
PY
}
