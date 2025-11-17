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

def load_yaml(path: Path):
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}

with wo_path.open("r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}

rules = load_yaml(rules_path).get("routes", [])

strict_target = data.get("strict_target")
target_candidates = data.get("target_candidates") or []
route_hints = data.get("route_hints") or {}
fallback_order = route_hints.get("fallback_order") or []
task_type = (data.get("task") or {}).get("type")

for rule in rules:
    match = rule.get("match") or {}
    if match.get("task_type") == task_type and str(match.get("fallback_contains")).lower() in [str(x).lower() for x in fallback_order]:
        print(rule.get("target", "CLC"))
        sys.exit(0)

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
