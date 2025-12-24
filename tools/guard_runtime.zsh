#!/usr/bin/env zsh
# tools/guard_runtime.zsh
# Active Memory Runtime Guard - Pattern matching engine
# V4: Hardening (Fail-fast, Audit Telemetry, Better Lane Detect)
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
PATTERNS_FILE="${PATTERNS_FILE:-$REPO_ROOT/g/rules/runtime_patterns.yaml}"
TELEMETRY_FILE="${TELEMETRY_FILE:-$REPO_ROOT/g/telemetry/runtime_guard.jsonl}"
EMERGENCY_LOG="${EMERGENCY_LOG:-$REPO_ROOT/g/telemetry/gate_emergency.jsonl}"
ACTOR="${ACTOR:-${AGENT_ID:-${GG_AGENT_ID:-unknown}}}"

mkdir -p "$(dirname "$TELEMETRY_FILE")"

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

# Auto-detect lane (default) AFTER command is known.
# Prefer explicit GUARD_LANE if set.
# Treat piped/STDIN command mode (`--cmd -`) as interactive by default.
if [[ -z "${GUARD_LANE:-}" ]]; then
  if [[ "${_cmd:-}" == "-" ]]; then
    GUARD_LANE="interactive"
  elif [[ -t 0 || -t 1 || -t 2 ]]; then
    GUARD_LANE="interactive"
  else
    GUARD_LANE="daemon"
  fi
fi

export _CMD="$_cmd"
export PATTERNS_FILE
export TELEMETRY_FILE
export EMERGENCY_LOG
export ACTOR
export GUARD_LANE

# Single Python block for logic
python3 - <<'PY'
import os, re, sys, json, hashlib
from datetime import datetime, timezone

def log_telemetry(data, file_path):
    try:
        if not file_path: return
        with open(file_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(data) + "\n")
    except Exception as e:
        sys.stderr.write(f"Telemetry error: {e}\n")

def fail(msg, code=1):
    print(f"\033[0;31m⛔ SYSTEM ERROR: {msg}\033[0m")
    sys.exit(code)

cmd = os.environ.get("_CMD", "")
pat_file = os.environ.get("PATTERNS_FILE", "")
actor = os.environ.get("ACTOR", "unknown")
lane = os.environ.get("GUARD_LANE", "daemon")
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# 1. Load Patterns
patterns = []
try:
    if not pat_file or not os.path.exists(pat_file):
        raise FileNotFoundError(f"Missing patterns file: {pat_file}")
    
    import yaml
    data = yaml.safe_load(open(pat_file, "r", encoding="utf-8")) or {}
    patterns = data.get("patterns", [])
except ImportError:
    msg = "PyYAML missing"
    if lane == "interactive":
        print(f"\033[1;33m⚠️  Guard Skipped ({msg}) - Interactive Mode Allow\033[0m")
        sys.exit(0)
    else:
        fail(f"Guard Failed ({msg}) - Daemon Mode Block")
except Exception as e:
    msg = str(e)
    if lane == "interactive":
        print(f"\033[1;33m⚠️  Guard Skipped ({msg}) - Interactive Mode Allow\033[0m")
        sys.exit(0)
    else:
        fail(f"Guard Failed ({msg}) - Daemon Mode Block")

# 2. Match Logic & Security Check
hits = []
invalid_patterns = []
highest_effective = "ALLOW"
raw_highest = "ALLOW"
level_rank = {"ALLOW": 0, "WARN": 1, "BLOCK": 2}

blocked_hits_effective = [] # Blocks that stayed blocked
bypassed_block_ids = []     # Blocks that were overridden
overrides_used = []

for p in patterns:
    pid = p.get("id", "unknown")
    trig = p.get("trigger", "")
    action = (p.get("action", "ALLOW") or "ALLOW").upper()
    msg = (p.get("message", "") or "").strip()
    fix = (p.get("fix", "") or "").strip()
    override_env = (p.get("override_env", "") or "").strip()

    if not trig: continue
    
    try:
        if re.search(trig, cmd, flags=re.IGNORECASE | re.MULTILINE):
            # Calculate raw highest (before overrides)
            if level_rank.get(action, 0) > level_rank.get(raw_highest, 0):
                raw_highest = action

            hit_info = {
                "id": pid, 
                "action": action, 
                "msg": msg, 
                "fix": fix,
                "override": override_env,
                "bypassed": False
            }
            
            if action == "BLOCK":
                is_overridden = False
                if override_env and "=" in override_env:
                    k, v = override_env.split("=", 1)
                    if os.environ.get(k) == v:
                        is_overridden = True
                        if override_env not in overrides_used:
                            overrides_used.append(override_env)
                
                if is_overridden:
                    hit_info["bypassed"] = True
                    bypassed_block_ids.append(pid)
                else:
                    blocked_hits_effective.append(pid)
                    # Update effective highest
                    if level_rank.get(action, 0) > level_rank.get(highest_effective, 0):
                        highest_effective = action
            else:
                 # WARN or ALLOW
                 if level_rank.get(action, 0) > level_rank.get(highest_effective, 0):
                        highest_effective = action
            
            hits.append(hit_info)

    except re.error as e:
        invalid_patterns.append({"id": pid, "error": str(e), "trigger": trig[:200]})
        continue

cmd_sha256 = hashlib.sha256(cmd.encode("utf-8", errors="replace")).hexdigest() if cmd else ""

final_decision = highest_effective
if blocked_hits_effective:
    final_decision = "BLOCK"

# 3. Telemetry
telem_rec = {
    "ts": ts,
    "actor": actor,
    "level": highest_effective,   # Effective level
    "raw_highest": raw_highest,   # Raw severity before override
    "final": final_decision,
    "hits": len(hits),
    "invalid_patterns": invalid_patterns,
    "cmd_preview": cmd[:500],
    "cmd_sha256": cmd_sha256,
    "overrides": overrides_used,
    "bypassed_block_ids": bypassed_block_ids
}
log_telemetry(telem_rec, os.environ.get("TELEMETRY_FILE"))

if overrides_used:
    emerg_rec = {
        "ts": ts,
        "actor": actor,
        "action": "emergency_bypass",
        "reason": f"Overrides used: {overrides_used}",
        "cmd_preview": cmd[:500],
        "bypassed_ids": bypassed_block_ids
    }
    log_telemetry(emerg_rec, os.environ.get("EMERGENCY_LOG"))

# 4. Reporting
if not hits:
    print("\033[0;32m✅ ALLOW\033[0m")
    sys.exit(0)

print(f"Guard Decision: {final_decision}")
print("----")
for h in hits:
    color = "\033[0;31m" # Default Red/Block
    if h['bypassed']: color = "\033[0;32m" # Green if bypassed
    elif h['action'] == "WARN": color = "\033[1;33m" # Yellow
    rst = "\033[0m"
    
    status_tag = h['action']
    if h['bypassed']: status_tag += " (BYPASSED)"
    
    print(f"{color}[{status_tag}] {h['id']}{rst}")
    if h['msg']: print(f"  {h['msg'].replace(chr(10), ' ')}")
    if h['fix']: print(f"  Fix: {h['fix']}")
    if h['override']: print(f"  Override: {h['override']}")
    print("")

if final_decision == "BLOCK":
    print("\033[0;31m⛔ BLOCKED\033[0m")
    sys.exit(1)

# Allow or Warn
sys.exit(0)
PY
