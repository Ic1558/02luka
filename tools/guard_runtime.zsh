#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
PATTERNS_FILE="${PATTERNS_FILE:-$REPO_ROOT/g/rules/runtime_patterns.yaml}"
TELEMETRY_FILE="${TELEMETRY_FILE:-$REPO_ROOT/g/telemetry/runtime_guard.jsonl}"
ACTOR="${ACTOR:-${AGENT_ID:-${GG_AGENT_ID:-unknown}}}"

mkdir -p "$REPO_ROOT/g/telemetry"

usage() {
  echo "Usage:"
  echo "  zsh tools/guard_runtime.zsh --cmd \"<command>\""
  echo "  echo \"<command>\" | zsh tools/guard_runtime.zsh --cmd -"
  echo "  zsh tools/guard_runtime.zsh --batch <file.zsh>"
}

_cmd=""
_batch=""

while (( $# > 0 )); do
  case "$1" in
    --cmd)
      _cmd="${2:-}"
      shift 2
      ;;
    --batch)
      _batch="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -n "$_batch" ]]; then
  if [[ ! -f "$_batch" ]]; then
    echo "❌ batch file not found: $_batch"
    exit 2
  fi
  _cmd="$(cat "$_batch")"
elif [[ "$_cmd" == "-" ]]; then
  _cmd="$(cat)"
elif [[ -z "$_cmd" ]]; then
  usage
  exit 2
fi

# Export for Python subprocess
export _CMD="$_cmd"
export PATTERNS_FILE

# Run Python pattern matcher - outputs: LEVEL on line 1, then hit details
_result="$(python3 - <<'PY'
import os, re, sys

pat_file = os.environ.get("PATTERNS_FILE", "")
cmd = os.environ.get("_CMD", "")

if not pat_file or not os.path.exists(pat_file):
    print("ALLOW")
    print("0")
    sys.exit(0)

try:
    import yaml
except:
    print("ALLOW")
    print("0")
    sys.exit(0)

data = yaml.safe_load(open(pat_file, "r", encoding="utf-8")) or {}
patterns = data.get("patterns", [])

level_rank = {"ALLOW": 0, "WARN": 1, "BLOCK": 2}
best = "ALLOW"
hits = []

for p in patterns:
    pid = p.get("id", "unknown")
    trig = p.get("trigger", "")
    action = (p.get("action", "ALLOW") or "ALLOW").upper()
    msg = (p.get("message", "") or "").replace("\n", " ").strip()
    fix = (p.get("fix", "") or "").strip()
    override_env = (p.get("override_env", "") or "").strip()
    
    if not trig:
        continue
    try:
        if re.search(trig, cmd, flags=re.IGNORECASE | re.MULTILINE):
            hits.append((pid, action, msg, fix, override_env))
            if level_rank.get(action, 0) > level_rank.get(best, 0):
                best = action
    except re.error:
        continue

# Output format: line 1 = level, line 2 = hit_count, rest = hit details
print(best)
print(len(hits))
for pid, action, msg, fix, override_env in hits:
    print(f"{action}|{pid}|{msg}|{fix}|{override_env}")
PY
)"

# Parse result
level="$(echo "$_result" | sed -n '1p')"
hits_count="$(echo "$_result" | sed -n '2p')"

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# log telemetry
cmd_escaped="$(printf '%s' "$_cmd" | head -c 200 | tr '\n' ' ')"
echo "{\"ts\":\"$ts\",\"actor\":\"$ACTOR\",\"level\":\"$level\",\"hits\":$hits_count,\"cmd_preview\":\"$cmd_escaped\"}" >> "$TELEMETRY_FILE"

if [[ "$level" == "ALLOW" ]]; then
  echo "ALLOW"
  exit 0
fi

# pretty print hits
echo "$level"
echo "----"
echo "$_result" | tail -n +3 | while IFS='|' read -r action pid msg fix override_env; do
  echo "[$action] $pid"
  [[ -n "$msg" ]] && echo "  $msg"
  [[ -n "$fix" ]] && echo "  Fix: $fix"
  [[ -n "$override_env" ]] && echo "  Override: $override_env"
  echo ""
done

if [[ "$level" == "WARN" ]]; then
  exit 0
fi

# BLOCK with optional emergency override
# Get override_env from first hit
override_key="$(echo "$_result" | sed -n '3p' | cut -d'|' -f5)"

if [[ -n "$override_key" && "$override_key" != "" ]]; then
  key="${override_key%%=*}"
  val="${override_key#*=}"
  if [[ "${(P)key:-}" == "$val" ]]; then
    echo "⚠️ Emergency override detected ($override_key) → allowing but logging."
    echo "{\"ts\":\"$ts\",\"actor\":\"$ACTOR\",\"override\":\"$override_key\",\"cmd_preview\":\"$cmd_escaped\"}" >> "$REPO_ROOT/g/telemetry/gate_emergency.jsonl"
    exit 0
  fi
fi

exit 1
