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
  RECENT_JSON=$(python3 - <<'PY'
import sys, json, pathlib
try:
    lines = pathlib.Path("g/telemetry/decision_log.jsonl").read_text().strip().splitlines()
    rows = []
    for line in lines[-50:]:  # Last 50 lines for pattern detection (Phase 12)
        if line.strip():
            rows.append(json.loads(line))
    print(json.dumps(rows, ensure_ascii=False))
except Exception:
    print("[]")
PY
)
fi

# Git metadata (best-effort)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
STATUS=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$STATUS" == "0" ]]; then STATUS="clean"; else STATUS="dirty"; fi

# Build latest.json content (Memory)
# Deterministic TS: Use last decision TS or fallback to file mtime, NOT current time.
TS_ISO=$(python3 - <<'PY'
import sys, json, pathlib, datetime

dec_path = pathlib.Path("g/telemetry/decision_log.jsonl")
ts = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00","Z")

try:
    if dec_path.exists():
        lines = dec_path.read_text().strip().splitlines()
        if lines:
            last = json.loads(lines[-1])
            # Trust the log's timestamp if present
            if "ts" in last:
                 # Ensure it's treated as string
                 ts = last["ts"]
except Exception:
    pass

print(ts)
PY
)

# Function to write only if changed
write_if_changed() {
  local new_content="$1"
  local target="$2"
  
  if [[ -f "$target" ]]; then
    # effective sha256 comparison
    local old_sha=$(shasum -a 256 "$target" | awk '{print $1}')
    local new_sha=$(echo "$new_content" | shasum -a 256 | awk '{print $1}')
    if [[ "$old_sha" == "$new_sha" ]]; then
      # No change, skip write
      return 0
    fi
  fi
  # Write
  echo "$new_content" > "$target"
}

# Generate latest.json content
LATEST_JSON_CONTENT=$(python3 - <<PY
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
    "ids": json.loads(r'''$(python3 - <<'P2'
import json
ids = '''${(j:,:)RULE_IDS[@]}'''.split(',') if '''${(j:,:)RULE_IDS[@]}''' else []
print(json.dumps([i for i in ids if i], ensure_ascii=False))
P2
)''')
  }
}
print(json.dumps(data, ensure_ascii=False, indent=2))
PY
)

# Atomic write latest.json
write_if_changed "$LATEST_JSON_CONTENT" "$CORE_DIR/latest.json"

# rule_table.json (minimal, hash-locked by file hash)
RULE_TABLE_CONTENT=$(python3 - <<PY
import json
print(json.dumps({
  "source": "$RULE_SRC",
  "sha256": "$RULE_HASH",
  "rule_count": int("$RULE_COUNT"),
  "rule_ids": json.loads(r'''$(python3 - <<'P3'
import json
ids = '''${(j:,:)RULE_IDS[@]}'''.split(',') if '''${(j:,:)RULE_IDS[@]}''' else []
print(json.dumps([i for i in ids if i], ensure_ascii=False))
P3
)''')
}, ensure_ascii=False, indent=2))
PY
)

write_if_changed "$RULE_TABLE_CONTENT" "$CORE_DIR/rule_table.json"

# index.json checksums
LATEST_SHA=$(shasum -a 256 "$CORE_DIR/latest.json" | awk '{print $1}')
RULET_SHA=$(shasum -a 256 "$CORE_DIR/rule_table.json" | awk '{print $1}')

INDEX_CONTENT=$(python3 - <<PY
import json
print(json.dumps({
  "ts": "$TS_ISO",
  "files": {
    "latest.json": {"sha256": "$LATEST_SHA"},
    "rule_table.json": {"sha256": "$RULET_SHA"}
  }
}, ensure_ascii=False, indent=2))
PY
)
write_if_changed "$INDEX_CONTENT" "$CORE_DIR/index.json"

# latest.md (human digest) - Phase 12/13 Signal Promotion + Auto-Hook Planner
LATEST_MD_CONTENT=$(python3 tools/build_core_history_engine.py)

write_if_changed "$LATEST_MD_CONTENT" "$CORE_DIR/latest.md"

# Validate JSON
# python3 -c "import json; json.load(open('$CORE_DIR/latest.json')); json.load(open('$CORE_DIR/index.json')); json.load(open('$CORE_DIR/rule_table.json')); print('JSON_OK')"

echo "✅ Core History built (deterministic)"
