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
