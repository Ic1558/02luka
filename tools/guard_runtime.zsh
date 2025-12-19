#!/usr/bin/env zsh
# tools/guard_runtime.zsh
# Active Memory Runtime Guard - Pattern matching engine
# V2: Robust Python JSON handling + Multi-hit override check + Fail-safe lanes
set -u

REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
PATTERNS_FILE="${PATTERNS_FILE:-$REPO_ROOT/g/rules/runtime_patterns.yaml}"
TELEMETRY_FILE="${TELEMETRY_FILE:-$REPO_ROOT/g/telemetry/runtime_guard.jsonl}"
EMERGENCY_LOG="${EMERGENCY_LOG:-$REPO_ROOT/g/telemetry/gate_emergency.jsonl}"
ACTOR="${ACTOR:-${AGENT_ID:-${GG_AGENT_ID:-unknown}}}"
GUARD_LANE="${GUARD_LANE:-daemon}" # daemon (fail-closed) or interactive (fail-open warn)

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

export _CMD="$_cmd"
export PATTERNS_FILE
export TELEMETRY_FILE
export EMERGENCY_LOG
export ACTOR
export GUARD_LANE

# Single Python block for logic + JSON integrity
python3 - <<'PY'
import os, re, sys, json, time
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

# 2. Match Logic
level_rank = {"ALLOW": 0, "WARN": 1, "BLOCK": 2}
max_level = "ALLOW"
hits = []
active_overrides = set()

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
            hits.append({
                "id": pid, 
                "action": action, 
                "msg": msg, 
                "fix": fix,
                "override": override_env
            })
            if level_rank.get(action, 0) > level_rank.get(max_level, 0):
                max_level = action
            if action == "BLOCK" and override_env:
                active_overrides.add(override_env)
    except re.error:
        continue # Bad regex in pattern shouldn't crash guard

# 3. Decision & Override Check
final_decision = max_level
effective_override = None

if max_level == "BLOCK" and active_overrides:
    # Check if any valid override is present in current env
    for ov in active_overrides:
        if "=" in ov:
            k, v = ov.split("=", 1)
            env_val = os.environ.get(k)
            # print(f"DEBUG: Checking override {k}={v} (current env: {env_val})")
            if env_val == v:
                final_decision = "ALLOW" # downgrade to allow
                effective_override = ov
                break

# 4. Telemetry (Integrity critical)
telem_rec = {
    "ts": ts,
    "actor": actor,
    "level": max_level, # Original level
    "final": final_decision,
    "hits": len(hits),
    "cmd_preview": cmd[:500],
    "override_used": effective_override
}
log_telemetry(telem_rec, os.environ.get("TELEMETRY_FILE"))

if effective_override:
    emerg_rec = {
        "ts": ts,
        "actor": actor,
        "action": "emergency_bypass",
        "reason": f"Override {effective_override} used for pattern(s)",
        "cmd_preview": cmd[:500]
    }
    log_telemetry(emerg_rec, os.environ.get("EMERGENCY_LOG"))

# 5. User Output & Exit Code
if not hits:
    print("\033[0;32m✅ ALLOW\033[0m")
    sys.exit(0)

# Print Report
print(f"Guard Decision: {final_decision}")
print("----")
for h in hits:
    color = "\033[0;31m" if h['action'] == "BLOCK" else "\033[1;33m"
    rst = "\033[0m"
    print(f"{color}[{h['action']}] {h['id']}{rst}")
    if h['msg']: print(f"  {h['msg'].replace(chr(10), ' ')}")
    if h['fix']: print(f"  Fix: {h['fix']}")
    if h['override']: print(f"  Override: {h['override']}")
    print("")

if effective_override:
    print(f"\033[1;33m⚠️  Emergency Override Applied ({effective_override}) - Proceeding with caution.\033[0m")
    sys.exit(0)

if max_level == "BLOCK":
    print("\033[0;31m⛔ BLOCKED\033[0m")
    sys.exit(1)

# WARN or ALLOW
sys.exit(0)
PY
