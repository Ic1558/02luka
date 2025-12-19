#!/usr/bin/env zsh
set -euo pipefail

REPO="${REPO:-$HOME/02luka}"
cd "$REPO"

mkdir -p tools g/rules g/knowledge g/telemetry g/state

# ---------------------------
# NEW: g/rules/runtime_patterns.yaml
# ---------------------------
cat > g/rules/runtime_patterns.yaml <<'YAML'
patterns:
  - id: atg_extensions_trap
    trigger: "(~/.vscode/extensions|Application Support/Code|~/.vscode-server/extensions)"
    action: WARN
    message: |
      ATG extension trap:
      - Antigravity uses: ~/.antigravity/extensions/
      - Copying ~/.vscode/extensions alone is not enough
      - Must also update Antigravity extensions.json (registry) if required by ATG
    fix: "Copy into ~/.antigravity/extensions/ AND update ATG extensions.json, then restart ATG"

  - id: git_push_main_trap
    trigger: "(git\\s+push\\s+origin\\s+main|ALLOW_PUSH_MAIN=)"
    action: BLOCK
    message: |
      PR management is law:
      - Never push origin/main directly
      - Use: branch → push → PR → squash merge
    override_env: "SAVE_EMERGENCY=1"
    fix: "Create branch + PR. Use SAVE_EMERGENCY=1 only for true emergency and log evidence."

  - id: fix_to_pass_trap
    trigger: "(EXCLUDE.*\\*\\*|broad\\s+exclusion|exclude\\s+tools/\\*\\*|skip\\s+sandbox)"
    action: WARN
    message: |
      Fix-to-pass anti-pattern detected:
      - Avoid broad exclusions to make CI pass
      - Prefer root-cause fixes + narrow allowlist with rationale
    fix: "Explain root cause, add narrow allowlist or safe-guard rm -rf with path checks"
YAML

# ---------------------------
# NEW: tools/guard_runtime.zsh
# ---------------------------
cat > tools/guard_runtime.zsh <<'ZSH2'
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

# python yaml loader (expects PyYAML; repo likely has it already)
_decision_json="$(python3 - <<'PY'
import os, re, json, sys
pat_file = os.environ.get("PATTERNS_FILE")
cmd = os.environ.get("_CMD","")
if not pat_file or not os.path.exists(pat_file):
    print(json.dumps({"level":"ALLOW","hits":[], "error": f"patterns file missing: {pat_file}"}))
    sys.exit(0)

try:
    import yaml
except Exception as e:
    print(json.dumps({"level":"ALLOW","hits":[], "error":"PyYAML not available; install pyyaml or convert patterns to json"}))
    sys.exit(0)

data = yaml.safe_load(open(pat_file, "r", encoding="utf-8")) or {}
patterns = data.get("patterns", [])

level_rank = {"ALLOW":0, "WARN":1, "BLOCK":2}
best = "ALLOW"
hits = []

for p in patterns:
    pid = p.get("id","unknown")
    trig = p.get("trigger","")
    action = (p.get("action","ALLOW") or "ALLOW").upper()
    msg = p.get("message","")
    fix = p.get("fix","")
    override_env = p.get("override_env","")
    if not trig:
        continue
    try:
        if re.search(trig, cmd, flags=re.IGNORECASE|re.MULTILINE):
            hits.append({
                "id": pid,
                "action": action,
                "message": msg.strip(),
                "fix": fix.strip(),
                "override_env": override_env.strip(),
            })
            if level_rank.get(action,0) > level_rank.get(best,0):
                best = action
    except re.error:
        continue

print(json.dumps({"level": best, "hits": hits}))
PY
)"

# export cmd into python
export _CMD="$_cmd"
export PATTERNS_FILE

level="$(echo "$_decision_json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("level","ALLOW"))')"
hits_count="$(echo "$_decision_json" | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("hits",[])))')"

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# log telemetry
echo "{\"ts\":\"$ts\",\"actor\":\"$ACTOR\",\"level\":\"$level\",\"hits\":$hits_count,\"cmd_preview\":$(python3 - <<PY
import json,os
s=os.environ.get("_CMD","")
p=s[:200].replace("\\n","\\\\n")
print(json.dumps(p))
PY
)}" >> "$TELEMETRY_FILE"

if [[ "$level" == "ALLOW" ]]; then
  echo "ALLOW"
  exit 0
fi

# pretty print hits
echo "$level"
echo "----"
python3 - <<'PY'
import sys, json
d=json.load(sys.stdin)
for h in d.get("hits",[]):
    print(f"[{h.get('action')}] {h.get('id')}")
    if h.get("message"):
        print(h["message"])
    if h.get("fix"):
        print(f"Fix: {h['fix']}")
    if h.get("override_env"):
        print(f"Override: {h['override_env']}")
    print("")
PY <<<"$_decision_json"

if [[ "$level" == "WARN" ]]; then
  exit 0
fi

# BLOCK with optional emergency override
override_key="$(echo "$_decision_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); 
hits=d.get("hits",[]); 
print((hits[0].get("override_env","") if hits else ""))')"

if [[ -n "$override_key" ]]; then
  key="${override_key%%=*}"
  val="${override_key#*=}"
  if [[ "${(P)key:-}" == "$val" ]]; then
    echo "⚠️ Emergency override detected ($override_key) → allowing but logging."
    echo "{\"ts\":\"$ts\",\"actor\":\"$ACTOR\",\"override\":\"$override_key\",\"cmd_preview\":$(python3 - <<PY
import json,os
s=os.environ.get("_CMD","")
p=s[:200].replace("\\n","\\\\n")
print(json.dumps(p))
PY
)}" >> "$REPO_ROOT/g/telemetry/gate_emergency.jsonl"
    exit 0
  fi
fi

exit 1
ZSH2
chmod +x tools/guard_runtime.zsh

# ---------------------------
# NEW: g/knowledge/solution_ledger.jsonl (create if missing)
# ---------------------------
touch g/knowledge/solution_ledger.jsonl

# ---------------------------
# NEW: tools/solution_collector.zsh (minimal v1: collects obvious guard blocks/warns)
# ---------------------------
cat > tools/solution_collector.zsh <<'ZSH3'
#!/usr/bin/env zsh
set -euo pipefail

REPO="${REPO:-$HOME/02luka}"
cd "$REPO"

LEDGER="g/knowledge/solution_ledger.jsonl"
TELE_GUARD="g/telemetry/runtime_guard.jsonl"
DRY="${1:-}"

mkdir -p g/knowledge

if [[ ! -f "$TELE_GUARD" ]]; then
  echo "No runtime guard telemetry yet: $TELE_GUARD"
  exit 0
fi

# take last 200 lines, extract WARN/BLOCK, append as lessons (simple v1)
python3 - <<'PY'
import json, os, hashlib, time
from datetime import datetime, timezone

repo=os.environ.get("REPO","")
ledger=os.path.join(repo,"g/knowledge/solution_ledger.jsonl")
tele=os.path.join(repo,"g/telemetry/runtime_guard.jsonl")
dry=os.environ.get("DRY","")

def sha(s): 
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]

existing=set()
if os.path.exists(ledger):
    with open(ledger,"r",encoding="utf-8") as f:
        for line in f:
            try:
                existing.add(json.loads(line).get("id",""))
            except:
                pass

new=[]
lines=open(tele,"r",encoding="utf-8").read().splitlines()[-200:]
for ln in lines:
    try:
        d=json.loads(ln)
    except:
        continue
    lvl=d.get("level","ALLOW")
    if lvl not in ("WARN","BLOCK"):
        continue
    cmd=d.get("cmd_preview","")
    rid=sha(f"{lvl}|{cmd}")
    if rid in existing:
        continue
    rec={
        "id": rid,
        "ts": d.get("ts"),
        "actor": d.get("actor","unknown"),
        "context": "runtime_guard",
        "symptom": f"Runtime guard {lvl} triggered",
        "root_cause": "Known risky pattern matched (see runtime_patterns.yaml)",
        "fix": "Follow guard message + fix guidance; refine pattern if false positive",
        "prevent": "Pattern captured in g/rules/runtime_patterns.yaml",
        "evidence": {"cmd_preview": cmd, "telemetry": "g/telemetry/runtime_guard.jsonl"},
        "tags": ["guard", lvl.lower()]
    }
    new.append(rec)

if not new:
    print("No new lessons found.")
    raise SystemExit(0)

if dry == "--dry-run":
    print(f"Would append {len(new)} lessons to {ledger}")
    for r in new[:5]:
        print(r["id"], r["symptom"], r["evidence"]["cmd_preview"])
    raise SystemExit(0)

with open(ledger,"a",encoding="utf-8") as f:
    for r in new:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")

print(f"Appended {len(new)} lessons → {ledger}")
PY
ZSH3
chmod +x tools/solution_collector.zsh

# ---------------------------
# PATCH: tools/save.sh → call solution_collector after save (idempotent)
# ---------------------------
python3 - <<'PY'
import pathlib, re
p=pathlib.Path("tools/save.sh")
if not p.exists():
    print("skip: tools/save.sh not found")
    raise SystemExit(0)
s=p.read_text(encoding="utf-8")

marker="## ACTIVE_MEMORY: solution_collector hook"
if marker in s:
    print("ok: save.sh already patched")
    raise SystemExit(0)

# append near end (before final exit if possible); fallback: append at end
insert = f'\n{marker}\n' \
         'if [[ -x "$SCRIPT_DIR/solution_collector.zsh" ]]; then\n' \
         '  (REPO="$REPO_ROOT" zsh "$SCRIPT_DIR/solution_collector.zsh" >/dev/null 2>&1) || true\n' \
         'fi\n'
# try to insert before last "exit"
m=re.search(r"\nexit\s+[01]\s*\n?$", s, flags=re.M)
if m:
    s = s[:m.start()] + insert + s[m.start():]
else:
    s = s + insert

p.write_text(s, encoding="utf-8")
print("patched: tools/save.sh")
PY

# ---------------------------
# PATCH: tools/pre_action_gate.zsh → show top lessons during read-now (best-effort, idempotent)
# ---------------------------
python3 - <<'PY'
import pathlib, re
p=pathlib.Path("tools/pre_action_gate.zsh")
if not p.exists():
    print("skip: tools/pre_action_gate.zsh not found")
    raise SystemExit(0)

s=p.read_text(encoding="utf-8")
marker="## ACTIVE_MEMORY: show_top_lessons"
if marker in s:
    print("ok: pre_action_gate already patched")
    raise SystemExit(0)

# add helper function at end
addon = f'''
{marker}
show_top_lessons() {{
  local ledger="$REPO_ROOT/g/knowledge/solution_ledger.jsonl"
  [[ -f "$ledger" ]] || return 0
  echo ""
  echo "🧠 Active Memory (latest lessons):"
  tail -n 3 "$ledger" | sed 's/^/  - /'
}}
'''
s = s + "\n" + addon

# try to call it inside create/read-now flow: if function "create" exists, we just call at bottom when script invoked with create
# non-invasive: only call if env READ_NOW=1 or arg create
call_snip = r'''
# ACTIVE_MEMORY_CALL
if [[ "${1:-}" == "create" ]] || [[ "${1:-}" == "read-now" ]] || [[ "${READ_NOW:-}" == "1" ]]; then
  show_top_lessons || true
fi
'''
if "# ACTIVE_MEMORY_CALL" not in s:
    s = s + "\n" + call_snip

p.write_text(s, encoding="utf-8")
print("patched: tools/pre_action_gate.zsh")
PY

# ---------------------------
# PATCH: tools/atg_runner_daemon.zsh (if exists) → guard before executing batch
# ---------------------------
python3 - <<'PY'
import pathlib, re
p=pathlib.Path("tools/atg_runner_daemon.zsh")
if not p.exists():
    print("skip: tools/atg_runner_daemon.zsh not found")
    raise SystemExit(0)
s=p.read_text(encoding="utf-8")
marker="## ACTIVE_MEMORY: runtime_guard"
if marker in s:
    print("ok: atg_runner_daemon already patched")
    raise SystemExit(0)

# naive injection: before any "zsh $batch" style execution, guard it
# We'll just add a helper function; you can wire exact call site later if daemon differs.
addon=f'''
{marker}
guard_batch_or_block() {{
  local batch_file="$1"
  if [[ -x "$REPO_ROOT/tools/guard_runtime.zsh" ]]; then
    if ! ACTOR="atg_daemon" zsh "$REPO_ROOT/tools/guard_runtime.zsh" --batch "$batch_file" >/dev/null; then
      echo "❌ BLOCKED by runtime guard: $batch_file"
      return 1
    fi
  fi
  return 0
}}
'''
s = s + "\n" + addon
p.write_text(s, encoding="utf-8")
print("patched: tools/atg_runner_daemon.zsh (helper added; wire call site as needed)")
PY

echo "✅ Active Memory Runtime Guard installed."
echo "Next: run verification commands below."
