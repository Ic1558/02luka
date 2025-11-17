#!/usr/bin/env zsh
set -euo pipefail

setopt null_glob

ROOT="${LUKA_SOT:-${HOME}/02luka}"
INBOX="$ROOT/bridge/inbox/ENTRY"
OUTBOX="$ROOT/bridge/outbox/ENTRY"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/mary_dispatcher.log"
ROUTING_RULES="$ROOT/g/config/wo_routing_rules.yaml"
LPE_INBOX="$ROOT/bridge/inbox/LPE"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR" "$LPE_INBOX" "$ROOT/bridge/outbox/LPE" "$ROOT/bridge/processed/ENTRY"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
}

normalize_id() {
  local file="$1"
  local base="${${file:t}%.*}"
  if [[ -n "$base" ]]; then
    echo "$base"
  else
    echo "wo-$(date +%s)"
  fi
}

resolve_destination() {
  local file="$1"
  python3 - "$file" "$ROUTING_RULES" <<'PY'
import sys
import yaml
from pathlib import Path

wo_path = Path(sys.argv[1])
rules_path = Path(sys.argv[2])

VALID_TARGETS = {"CLC", "LPE", "shell", "Andy", "CLS"}

def load_yaml(path: Path):
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as handle:
            return yaml.safe_load(handle) or {}
    except Exception as e:
        print(f"Error loading YAML from {path}: {e}", file=sys.stderr)
        return {}

try:
    with wo_path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
except Exception as e:
    print(f"Error loading WO from {wo_path}: {e}", file=sys.stderr)
    data = {}

rules = load_yaml(rules_path).get("routes", [])

strict_target = data.get("strict_target")
target_candidates = data.get("target_candidates") or []
route_hints = data.get("route_hints") or {}
fallback_order = route_hints.get("fallback_order") or []
task_type = (data.get("task") or {}).get("type")

# Match rules: check if fallback_contains is a substring of any fallback_order element
for rule in rules:
    match = rule.get("match") or {}
    rule_task_type = match.get("task_type")
    fallback_contains = match.get("fallback_contains")
    
    # Check task_type match
    if rule_task_type and rule_task_type != task_type:
        continue
    
    # Check fallback_contains: substring matching (case-insensitive)
    if fallback_contains:
        fallback_contains_lower = str(fallback_contains).lower()
        fallback_matches = any(
            fallback_contains_lower in str(x).lower()
            for x in fallback_order
        )
        if not fallback_matches:
            continue
    
    # Rule matched - validate target before returning
    target = rule.get("target", "CLC")
    if target in VALID_TARGETS:
        print(target)
        sys.exit(0)
    else:
        print(f"Invalid target '{target}' in rule '{rule.get('name', 'unnamed')}', using default CLC", file=sys.stderr)

# Fallback: check strict_target for shell
if strict_target and any(str(c).lower() == "shell" for c in target_candidates):
    print("shell")
else:
    print("CLC")
PY
}

convert_to_lpe_json() {
  local yaml_file="$1" json_out="$2" wo_id="$3"
  python3 - "$yaml_file" "$json_out" "$wo_id" <<'PY'
import json, sys, yaml, pathlib
source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
wo_id = sys.argv[3]
with source.open("r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}
if "id" not in data:
    data["id"] = wo_id
target.write_text(json.dumps(data), encoding="utf-8")
PY
}

log "start mary_dispatcher"

for file in "$INBOX"/*.yaml "$INBOX"/*.yml; do
  [[ -f "$file" ]] || continue
  id="$(normalize_id "$file")"

  dest="$(resolve_destination "$file")"
  case "$dest" in
    LPE)
      mkdir -p "$LPE_INBOX"
      tmp_json="$LPE_INBOX/.mary_${id}.$$.json"
      convert_to_lpe_json "$file" "$tmp_json" "$id"
      mv "$tmp_json" "$LPE_INBOX/${id}.json"
      cp "$file" "$OUTBOX/${id}.yaml"
      mv "$file" "$ROOT/bridge/processed/ENTRY/${id}.yaml"
      log "$id -> LPE"
      ;;
    shell|CLC)
      mkdir -p "$ROOT/bridge/inbox/$dest" "$ROOT/bridge/outbox/$dest"
      tmp="$ROOT/bridge/inbox/$dest/.mary_${id}.$$"
      cp "$file" "$tmp"
      mv "$tmp" "$ROOT/bridge/inbox/$dest/${id}.yaml"
      mv "$file" "$OUTBOX/${id}.yaml"
      log "$id -> $dest"
      ;;
    *)
      log "unknown route for $file (dest=$dest)"
      ;;
  esac
done
