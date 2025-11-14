#!/usr/bin/env zsh
# Track stale WOs and enrich metadata derived from state files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib_wo_common.zsh"

STATE_DIR="$REPO_ROOT/followup/state"
STALE_AFTER_HOURS="${STALE_AFTER_HOURS:-6}"

main() {
  ensure_dir "$STATE_DIR"
  setopt null_glob

  local count=0
  local file
  for file in "$STATE_DIR"/*.json(.N); do
    "$WO_PIPELINE_PYTHON_BIN" - "$file" "$STALE_AFTER_HOURS" <<'PY'
import json, sys, pathlib, datetime
path = pathlib.Path(sys.argv[1])
threshold = float(sys.argv[2])
try:
    data = json.loads(path.read_text(encoding='utf-8'))
except Exception:
    sys.exit(0)
now = datetime.datetime.now(datetime.timezone.utc)
fmt = '%Y-%m-%dT%H:%M:%SZ'

def parse_ts(value):
    if not value:
        return None
    for candidate in (value, value.replace('Z', '+00:00')):
        try:
            return datetime.datetime.fromisoformat(candidate.replace('Z', '+00:00'))
        except Exception:
            continue
    try:
        return datetime.datetime.strptime(value, fmt).replace(tzinfo=datetime.timezone.utc)
    except Exception:
        return None

created = parse_ts(data.get('created_at')) or parse_ts(data.get('updated_at')) or now
age_hours = max(0.0, (now - created).total_seconds() / 3600.0)
status = (data.get('status') or '').lower()
priority = (data.get('priority') or 'Medium').lower()
progress = data.get('progress') or 0

is_active = status in {'pending', 'running'} and progress < 100
is_stale = is_active and age_hours >= threshold

meta = data.get('meta')
if not isinstance(meta, dict):
    meta = {}
meta['age_hours'] = round(age_hours, 2)
meta['age_days'] = round(age_hours / 24.0, 2)
meta['is_stale'] = bool(is_stale)
meta['last_tracker_run'] = now.strftime(fmt)
meta['priority_score'] = {'high': 3, 'medium': 2, 'low': 1}.get(priority, 2)
meta['status_bucket'] = status or 'pending'
data['meta'] = meta

# Maintain tags
existing_tags = [tag for tag in data.get('tags', []) if isinstance(tag, str)]
if is_stale:
    if 'Stale' not in existing_tags:
        existing_tags.append('Stale')
else:
    existing_tags = [tag for tag in existing_tags if tag != 'Stale']
data['tags'] = existing_tags

data['updated_at'] = now.strftime(fmt)
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
PY
    (( ++count ))
  done

  log_info "followup_tracker: refreshed metadata for $count state file(s)"
}

main "$@"
