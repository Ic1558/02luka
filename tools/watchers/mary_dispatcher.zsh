#!/usr/bin/env zsh
set -euo pipefail

setopt null_glob

ROOT="${HOME}/02luka"
INBOX="$ROOT/bridge/inbox/ENTRY"
OUTBOX="$ROOT/bridge/outbox/ENTRY"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/mary_dispatcher.log"
ROUTING_RULES="$ROOT/g/config/wo_routing_rules.yaml"

mkdir -p "$INBOX" "$OUTBOX" "$LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOG_FILE"
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

log "start mary_dispatcher"

for file in "$INBOX"/*.yaml; do
  [[ -f "$file" ]] || continue
  id="${${file:t}%.*}"

  dest="$(resolve_destination "$file")"
  mkdir -p "$ROOT/bridge/inbox/$dest" "$ROOT/bridge/outbox/$dest"
  tmp="$ROOT/bridge/inbox/$dest/.mary_${id}.$$"
  cp "$file" "$tmp"
  mv "$tmp" "$ROOT/bridge/inbox/$dest/${id}.yaml"
  mv "$file" "$OUTBOX/${id}.yaml"
  log "$id -> $dest"
done
