#!/usr/bin/env bash
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Validation Script - Phase 4/5/6 Smoke Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ ${cmd} not found"
    exit 1
  fi
}

echo "✅ Checking base dependencies..."
check_cmd jq
check_cmd yq
check_cmd redis-cli
echo "✅ Base dependencies present"

echo ""
echo "🧹 Running workflow linters..."
if command -v actionlint >/dev/null 2>&1; then
  actionlint
  echo "✅ actionlint passed"
else
  echo "⚠️  actionlint not found, skipping"
fi

if command -v yamllint >/dev/null 2>&1; then
  yamllint -s .github/workflows
  echo "✅ yamllint passed"
else
  echo "⚠️  yamllint not found, falling back to python yaml check"
  python3 - <<'PY'
import glob

try:
    import yaml
except ImportError:
    print('⚠️  PyYAML not installed; skipping YAML fallback')
else:
    for path in glob.glob('.github/workflows/*.yml') + glob.glob('.github/workflows/*.yaml'):
        with open(path, 'r', encoding='utf-8') as handle:
            yaml.safe_load(handle)
    print('✅ YAML syntax ok (fallback)')
PY
fi

echo ""
echo "🧾 Verifying JSON syntax..."
json_files=()
while IFS= read -r -d '' file; do
  json_files+=("$file")
done < <(find . -maxdepth 2 -name '*.json' \
  -not -path './node_modules/*' \
  -not -path './run/*' \
  -not -path './test-results/*' \
  -print0)

if command -v jq >/dev/null 2>&1; then
  for file in "${json_files[@]}"; do
    jq -e . "$file" >/dev/null
  done
  echo "✅ JSON syntax ok"
else
  echo "⚠️  jq missing for JSON linting, using python fallback"
  if ((${#json_files[@]})); then
    printf '%s\n' "${json_files[@]}" | python3 - <<'PY'
import json, sys
for line in sys.stdin:
    path = line.strip()
    if not path:
        continue
    with open(path, 'r', encoding='utf-8') as handle:
        json.load(handle)
print('✅ JSON syntax ok (fallback)')
PY
  else
    echo "ℹ️  No JSON files to validate"
  fi
fi

echo ""
echo "🔥 Running smoke tests..."
bash scripts/smoke.sh

echo ""
echo "✅ Validation complete"
