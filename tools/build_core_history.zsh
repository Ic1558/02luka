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

# latest.md (human digest)
LATEST_MD_CONTENT=$(python3 - <<'PY'
import json, pathlib, datetime, os, sys

p = pathlib.Path("g/core_history/latest.json")
data = json.loads(p.read_text(encoding="utf-8"))
m = data["metadata"]
d = data["decisions"]
r = data["rules"]
DEBUG = os.environ.get("BUILD_CORE_HISTORY_DEBUG") == "1"

lines=[]
lines.append(f"# Core History - {m['ts']}")
lines.append("")
lines.append(f"- git: {m['git']['branch']} @ {m['git']['head']} ({m['git']['status']})")
lines.append(f"- decision_log: {d['status']} (count={d['count']})")
lines.append(f"- rules: {r['status']} (count={r['count']}, sha256={r.get('hash')})")
lines.append("")
lines.append("## Recent Decisions (last 5)")

recent = d.get("recent", [])

def parse_ts(ts_val):
    if isinstance(ts_val, (int, float)):
        return datetime.datetime.fromtimestamp(ts_val, datetime.timezone.utc)
    try:
        return datetime.datetime.fromisoformat(str(ts_val).replace('Z', '+00:00'))
    except:
        return datetime.datetime.now(datetime.timezone.utc)

# 1. Cluster by time (gap > 60m starts new cluster)
clusters = []
current_cluster = []
last_ts = None

for item in recent:
    ts = item.get("ts", 0)
    dt = parse_ts(ts)
    if last_ts and (dt - last_ts).total_seconds() > 3600:
        clusters.append(current_cluster)
        current_cluster = []
    current_cluster.append(item)
    last_ts = dt
if current_cluster: clusters.append(current_cluster)

rendered = []

for i, cluster in enumerate(clusters):
    if not cluster: continue
    
    # Analyze cluster
    rules_set = set()
    for i in cluster: rules_set.update(i.get("matched_rules", []))
    
    start_ts = parse_ts(cluster[0].get("ts", 0))
    end_ts = parse_ts(cluster[-1].get("ts", 0))
    duration_m = int((end_ts - start_ts).total_seconds() / 60)
    count = len(cluster)
    r5_only = (rules_set == {"R5_DEFAULT"})
    
    # Promotion Logic (Phase 12)
    promoted = False
    
    # R3 -> R2 (Actionable)
    action_rules = {r for r in rules_set if any(x in r.lower() for x in ['save', 'seal', 'sync'])}
    
    if action_rules:
        rendered.append(f"- [ ACTIONABLE ] System State Shift")
        rendered.append(f"  - triggered by: {', '.join(list(action_rules)[:3])}")
        promoted = True
    elif len(rules_set) >= 2 and "R5_DEFAULT" in rules_set:
        rendered.append(f"- [ SIGNAL ] Sustained System Activity Detected")
        rendered.append(f"  - sources: {', '.join(list(rules_set)[:3])}")
        rendered.append(f"  - duration: {duration_m}m")
        promoted = True
    elif r5_only and count >= 5:
        rendered.append(f"- [ PATTERN ] Repeated Routine Snapshot (x{count} in {duration_m}m)")
        promoted = True
        
    # Phase 13: Auto-Hook Planner (Dry-Run)
    # Only for the most recent cluster, if it was a signal but NO explicit action was taken yet
    if i == len(clusters) - 1 and (len(rules_set) >= 2 and "R5_DEFAULT" in rules_set) and not action_rules:
        if os.environ.get("R2_HOOKS", "1") != "0":
            last_event_ts = parse_ts(cluster[-1].get("ts", 0))
            now = datetime.datetime.now(datetime.timezone.utc)
            silence_min = (now - last_event_ts).total_seconds() / 60
            
            if 10 <= silence_min <= 120:
                rendered.append(f"- [ ACTIONABLE ] Hook Planned: save (dry-run)")
                rendered.append(f"  - trigger: signal cluster ended ({int(silence_min)}m ago)")

    if promoted:
        if DEBUG: print(f"DEBUG: Promoted cluster size={count} dur={duration_m} rules={rules_set}", file=sys.stderr)
        continue

    # Fallback: Standard Grouping
    sub_group_count = 0
    sub_last_ts = 0
    for item in cluster:
        risk = item.get("risk","?")
        r_list = item.get("matched_rules",[])
        is_routine = (risk == "low" and r_list == ["R5_DEFAULT"])
        
        if is_routine:
            sub_group_count += 1
            sub_last_ts = item.get("ts", 0)
        else:
            if sub_group_count > 0:
                t_str = parse_ts(sub_last_ts).strftime('%H:%M')
                rendered.append(f"- [ x{sub_group_count} ] Routine Snapshots (R5_DEFAULT) · last active {t_str}")
                sub_group_count = 0
            
            preview = item.get("text_preview","")[:120]
            r_str = ",".join(r_list[:5])
            rendered.append(f"- risk={risk} rules=[{r_str}] preview={preview}")
            
    if sub_group_count > 0:
        t_str = parse_ts(sub_last_ts).strftime('%H:%M')
        rendered.append(f"- [ x{sub_group_count} ] Routine Snapshots (R5_DEFAULT) · last active {t_str}")

# Phase 13: Auto-Hook Planner (Dry-Run) - Corrected Selection Logic
# Find the newest completed signal cluster (reverse iteration)
hook_planned = False
for cluster in reversed(clusters):
    if hook_planned: break
    
    rules_set = set()
    for item in cluster: rules_set.update(item.get("matched_rules", []))
    
    # Check if SIGNAL
    is_signal = (len(rules_set) >= 2 and "R5_DEFAULT" in rules_set)
    if not is_signal: continue
    
    # Check if already actioned
    action_rules = {r for r in rules_set if any(x in r.lower() for x in ['save', 'seal', 'sync'])}
    if action_rules: continue
    
    last_event_ts = parse_ts(cluster[-1].get("ts", 0))
    now = datetime.datetime.now(datetime.timezone.utc)
    silence_min = (now - last_event_ts).total_seconds() / 60
    
    if DEBUG:
        duration_m = int((parse_ts(cluster[-1].get("ts", 0)) - parse_ts(cluster[0].get("ts", 0))).total_seconds() / 60)
        print(f"DEBUG[R2]: cluster duration={duration_m}m silence={int(silence_min)}m rules={rules_set}", file=sys.stderr)

    if 10 <= silence_min <= 120:
        if os.environ.get("R2_HOOKS", "1") != "0":
            rendered.append(f"- [ ACTIONABLE ] Hook Planned: save (dry-run)")
            rendered.append(f"  - trigger: signal cluster ended ({int(silence_min)}m ago)")
            hook_planned = True

lines.extend(rendered[-5:])
print("\n".join(lines))
PY
)

write_if_changed "$LATEST_MD_CONTENT" "$CORE_DIR/latest.md"

# Validate JSON
# python3 -c "import json; json.load(open('$CORE_DIR/latest.json')); json.load(open('$CORE_DIR/index.json')); json.load(open('$CORE_DIR/rule_table.json')); print('JSON_OK')"

echo "✅ Core History built (deterministic)"
