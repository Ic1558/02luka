#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
cd "$REPO"

CORE_DIR="g/core_history"
DEC="g/telemetry/decision_log.jsonl"
RULE_SRC="decision_summarizer.py"

mkdir -p "$CORE_DIR"

# Basic inputs
DEC_EXISTS="missing"
DEC_COUNT=0
if [[ -f "$DEC" ]]; then
  DEC_EXISTS="present"
  DEC_COUNT=$(wc -l < "$DEC" | tr -d ' ')
fi

# Extract rule ids (best-effort, no execution of untrusted code)
RULE_COUNT=0
RULE_IDS=()
if [[ -f "$RULE_SRC" ]]; then
  # heuristics: capture R1_... style tokens
  RULE_IDS=("${(@f)$(grep -oE 'R[0-9]+_[A-Z0-9_]+' "$RULE_SRC" | sort -u || true)}")
  RULE_COUNT=${#RULE_IDS[@]}
fi

# Rule table hash (file hash)
RULE_HASH="missing"
if [[ -f "$RULE_SRC" ]]; then
  RULE_HASH=$(shasum -a 256 "$RULE_SRC" | awk '{print $1}')
fi

# Recent decisions (last 5 json lines)
RECENT_JSON="[]"
if [[ -f "$DEC" ]]; then
  RECENT_JSON=$(tail -n 5 "$DEC" | python3 - <<'PY'
import sys, json
rows=[]
for line in sys.stdin.read().splitlines():
    line=line.strip()
    if not line: 
        continue
    try:
        rows.append(json.loads(line))
    except Exception:
        pass
print(json.dumps(rows, ensure_ascii=False))
PY
)
fi

# Git metadata (best-effort)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
STATUS=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$STATUS" == "0" ]]; then STATUS="clean"; else STATUS="dirty"; fi

# Build latest.json
TS_ISO=$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).isoformat().replace("+00:00","Z"))
PY
)

python3 - <<PY > "$CORE_DIR/latest.json"
import json
data = {
  "metadata": {
    "ts": "$TS_ISO",
    "git": {"branch": "$BRANCH", "head": "$HEAD", "status": "$STATUS"},
    "generated_by": "build_core_history.zsh"
  },
  "snapshot": {
    "status": "unknown",
    "md_path": None,
    "summary_path": None
  },
  "decisions": {
    "status": "$DEC_EXISTS",
    "count": int("$DEC_COUNT"),
    "recent": json.loads(r'''$RECENT_JSON''')
  },
  "rules": {
    "status": "ok" if "$RULE_HASH" != "missing" else "missing",
    "hash": "$RULE_HASH",
    "count": int("$RULE_COUNT"),
    "ids": ${RULE_IDS:+json.loads(r'''$(python3 - <<'P2'
import json,sys
ids = sys.argv[1:]
print(json.dumps(ids, ensure_ascii=False))
P2
${RULE_IDS[@]})''')}
  }
}
print(json.dumps(data, ensure_ascii=False, indent=2))
PY

# rule_table.json (minimal, hash-locked by file hash)
python3 - <<PY > "$CORE_DIR/rule_table.json"
import json
print(json.dumps({
  "source": "$RULE_SRC",
  "sha256": "$RULE_HASH",
  "rule_count": int("$RULE_COUNT"),
  "rule_ids": ${RULE_IDS:+json.loads(r'''$(python3 - <<'P3'
import json,sys
ids = sys.argv[1:]
print(json.dumps(ids, ensure_ascii=False))
P3
${RULE_IDS[@]})''')}
}, ensure_ascii=False, indent=2))
PY

# index.json checksums
LATEST_SHA=$(shasum -a 256 "$CORE_DIR/latest.json" | awk '{print $1}')
RULET_SHA=$(shasum -a 256 "$CORE_DIR/rule_table.json" | awk '{print $1}')

python3 - <<PY > "$CORE_DIR/index.json"
import json
print(json.dumps({
  "ts": "$TS_ISO",
  "files": {
    "latest.json": {"sha256": "$LATEST_SHA"},
    "rule_table.json": {"sha256": "$RULET_SHA"}
  }
}, ensure_ascii=False, indent=2))
PY

# latest.md (human digest)
python3 - <<'PY' > "$CORE_DIR/latest.md"
import json, pathlib
p = pathlib.Path("g/core_history/latest.json")
data = json.loads(p.read_text(encoding="utf-8"))
m = data["metadata"]
d = data["decisions"]
r = data["rules"]

lines=[]
lines.append(f"# Core History — {m['ts']}")
lines.append("")
lines.append(f"- git: {m['git']['branch']} @ {m['git']['head']} ({m['git']['status']})")
lines.append(f"- decision_log: {d['status']} (count={d['count']})")
lines.append(f"- rules: {r['status']} (count={r['count']}, sha256={r.get('hash')})")
lines.append("")
lines.append("## Recent Decisions (last 5)")
for item in d.get("recent", []):
  risk = item.get("risk","?")
  preview = item.get("text_preview","")[:120]
  rules = ",".join(item.get("matched_rules",[])[:5])
  lines.append(f"- risk={risk} rules=[{rules}] preview={preview}")
print("\n".join(lines))
PY

# Validate JSON
python3 -c "import json; json.load(open('$CORE_DIR/latest.json')); json.load(open('$CORE_DIR/index.json')); json.load(open('$CORE_DIR/rule_table.json')); print('JSON_OK')"

echo "✅ Core History built:"
ls -la "$CORE_DIR"
