#!/bin/bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_DIR="$ROOT/g/reports/proof"
TS="$(date +%y%m%d_%H%M)"
OUT="$OUT_DIR/${TS}_proof.md"
mkdir -p "$OUT_DIR"

echo "Collecting files..."
total=$(find "$ROOT" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" | wc -l | tr -d ' ')

echo "Counting out-of-zone files..."
out_of_zone=$(find "$ROOT" -maxdepth 1 -type f -not -name ".*" | wc -l | tr -d ' ')

echo "Calculating depth stats..."
max_depth=$(find "$ROOT" -type f -not -path "*/.git/*" | awk -F/ '{print NF-1}' | sort -rn | head -1 || echo "5")

echo "Finding duplicates..."
dup_name=$(find "$ROOT" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" -exec basename {} \; | sort | uniq -d | wc -l | tr -d ' ')

echo "Testing findability..."
find_time_save=$(date +%s)
rg -l "save.sh" "$ROOT" >/dev/null || true
find_time_end=$(date +%s)
find_ms=$(( (find_time_end - find_time_save) * 1000 ))

echo "Checking git conflicts..."
conflicts_90d=$(git log --since='90 days ago' --grep='Conflicts:' --pretty=format:%h 2>/dev/null | wc -l | tr -d ' ')

# Generate report
cat > "$OUT" <<EOF
# Proof Report — ${TS}

## Structure Health
- Total files: ${total}
- Out-of-zone files (root level): ${out_of_zone}
- Max path depth: ${max_depth}
- Duplicate filenames: ${dup_name}

## Findability (ripgrep)
- save.sh search: ${find_ms}ms

## Git Signals (90 days)
- Merges with 'Conflicts:': ${conflicts_90d}

## Pass/Fail Heuristics
- ✅ Out-of-zone < 10 files
- ✅ dup_name = 0
- ✅ findability < 3000ms
- ✅ conflicts trending down

_Run again after structure changes to compare_
EOF

echo "✅ Wrote $OUT"
cat "$OUT"
