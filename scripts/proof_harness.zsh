#!/usr/bin/env zsh
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_DIR="$ROOT/reports/proof"
TS="$(date +%y%m%d_%H%M)"
OUT="$OUT_DIR/${TS}_proof.md"
mkdir -p "$OUT_DIR"

# --- config ---
ZONES_FILE="$ROOT/config/zones.txt"
QUERIES_FILE="$ROOT/config/findability_queries.txt"
EXCLUDES='(\.git/|node_modules/|__pycache__/|\.venv/|\.cursor/\.mcp\.json$)'

# --- collect files ---
FILES=()
while IFS= read -r line; do
  FILES+=("$line")
done < <(cd "$ROOT" && find . -type f -not -path "*/.git/*" -print | sed 's#^\./##')

# 1) Count files per top-level + out-of-zone
typeset -A zone_set; while read -r z; do [[ -n "$z" ]] && zone_set[$z]=1; done < "$ZONES_FILE"
total=${#FILES[@]}
typeset -A by_top
out_of_zone=0
for p in "${FILES[@]}"; do
  [[ "$p" =~ $~EXCLUDES ]] && continue
  t="${p%%/*}"
  (( by_top[$t]++ ))
  [[ -z "${zone_set[$t]-}" ]] && (( out_of_zone++ ))
done

# 2) Depth stats
depth_sum=0 max_depth=0
for p in "${FILES[@]}"; do
  [[ "$p" =~ $~EXCLUDES ]] && continue
  d=$(( $(grep -o "/" <<<"$p" | wc -l | tr -d ' ') + 1 ))
  (( depth_sum+=d ))
  (( d>max_depth )) && max_depth=$d
done
avg_depth=$(( depth_sum>0 ? depth_sum/ (total>0?total:1) : 0 ))

# 3) Duplicate filenames (skip content hashing for speed)
typeset -A by_name
dup_name=0
for p in "${FILES[@]}"; do
  [[ "$p" =~ $~EXCLUDES ]] && continue
  name="${p##*/}"
  (( by_name[$name]++ ))
done
for k v in ${(kv)by_name}; do (( v>1 )) && (( dup_name++ )); done
dup_hash=0  # Skip expensive sha1 hashing

# 4) Findability (time-to-locate) with ripgrep
find_rows=()
while read -r q || [[ -n "${q-}" ]]; do
  [[ -z "$q" ]] && continue
  t_start=$(python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
)
  rg -n --hidden --no-messages -S "$q" "$ROOT" >/dev/null || true
  t_end=$(python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
)
  ms=$(( t_end - t_start ))
  find_rows+=("$q\t${ms}ms")
done < "$QUERIES_FILE"

# 5) Git conflict trend (last 90 days)
conflicts_90d=$(git log --since='90 days ago' --grep='Conflicts:' --pretty=format:%h 2>/dev/null | wc -l | tr -d ' ')
mcp_churn_pre=$(git log --since='90 days ago' --name-only --pretty=format: 2>/dev/null | grep -x ".cursor/mcp.json" | wc -l | tr -d ' ')
mcp_churn_post=$(git log --since='90 days ago' --name-only --pretty=format: 2>/dev/null | grep -x ".cursor/mcp.example.json" | wc -l | tr -d ' ')

# --- Render Markdown ---
{
  echo "# Proof Report — ${TS}"
  echo
  echo "## Structure Health"
  echo "- Total files: ${total}"
  echo "- Out-of-zone files: ${out_of_zone}"
  echo "- Avg path depth: ${avg_depth}"
  echo "- Max path depth: ${max_depth}"
  echo "- Duplicate *filenames* (count of names that appear >1): ${dup_name}"
  echo "- Duplicate *contents*: ${dup_hash} (skipped for speed)"
  echo
  echo "### Files by top-level"
  for k v in ${(kv)by_top}; do
    printf "- %s: %s\n" "$k" "$v"
  done | sort
  echo
  echo "## Findability (ripgrep elapsed)"
  for row in "${find_rows[@]}"; do
    printf "- %s\n" "$row"
  done
  echo
  echo "## Git Signals (90 days)"
  echo "- Merges with 'Conflicts:' in message: ${conflicts_90d}"
  echo "- Churn on .cursor/mcp.json (old, should trend ↓): ${mcp_churn_pre}"
  echo "- Churn on .cursor/mcp.example.json (tracked SOT, should trend ↑): ${mcp_churn_post}"
  echo
  echo "## Pass/Fail Heuristics (suggested)"
  echo "- ✅ Out-of-zone = 0 (หรือ <1% ของไฟล์ทั้งหมด)"
  echo "- ✅ dup_name = 0, dup_hash = 0"
  echo "- ✅ median findability < 3s ต่อคีย์เวิร์ด (ระวังไดเรกทอรีใหญ่)"
  echo "- ✅ conflicts_90d ลดลงเมื่อเทียบก่อนปรับ"
  echo
  echo "_Run again หลังปรับโครงสร้าง แล้วเทียบสองไฟล์รายงานเพื่อสรุปว่า \"ดีขึ้น/แย่ลง\" ด้วยตัวเลข._"
} > "$OUT"

echo "✅ Wrote $OUT"
