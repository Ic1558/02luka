#!/usr/bin/env bash
set -euo pipefail
echo "== ci/validate =="
# actionlint (ถ้ามี)
if command -v actionlint >/dev/null 2>&1; then
  actionlint
else
  echo "(i) actionlint not found, skipping"
fi
# yamllint (ถ้ามี) + fallback ตรวจเบื้องต้น
if command -v yamllint >/dev/null 2>&1; then
  yamllint -s .github/workflows || exit 1
else
  echo "(i) yamllint not found, basic YAML check"
  python3 - <<'PY'
import sys, yaml, glob
for f in glob.glob(".github/workflows/*.yml")+glob.glob(".github/workflows/*.yaml"):
    with open(f) as fh: yaml.safe_load(fh)
print("YAML OK")
PY
fi
# JSON quick check (ถ้ามีไฟล์)
if command -v jq >/dev/null 2>&1; then
  find . -name "*.json" -maxdepth 2 -print0 | xargs -0 -I{} sh -c 'jq -e . "{}" >/dev/null || (echo "Bad JSON: {}" && exit 1)'
else
  echo "(i) jq not found, skipping JSON strict check"
fi
echo "VALIDATE OK"
