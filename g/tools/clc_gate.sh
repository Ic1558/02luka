#!/usr/bin/env bash
# CLC gate: soft by default (WARN passes), block on FAIL; set CLC_STRICT=1 to block WARN too
set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCOPE="${1:-prepush}"
STRICT="${CLC_STRICT:-0}"
ok=0; warn=0; fail=0

run_check () {
  local name="$1"; shift
  echo "[CLC] check: $name"
  if output=$("$@" 2>&1); then
    echo "  ✓ $name: OK"
    ok=$((ok+1))
  else
    if echo "$output" | grep -qiE 'fatal|FAIL|error (critical)'; then
      echo "  ✗ $name: FAIL"
      echo "$output" | sed 's/^/    /'
      fail=$((fail+1))
    else
      echo "  ! $name: WARN"
      echo "$output" | sed 's/^/    /'
      warn=$((warn+1))
    fi
  fi
}

[ -x "$ROOT/.codex/preflight.sh" ] && run_check preflight bash "$ROOT/.codex/preflight.sh"
[ -x "$ROOT/g/tools/mapping_drift_guard.sh" ] && run_check mapping_drift_guard bash "$ROOT/g/tools/mapping_drift_guard.sh" --validate
[ -x "$ROOT/run/smoke_api_ui.sh" ] && run_check smoke_api_ui bash "$ROOT/run/smoke_api_ui.sh" </dev/null || true

echo "[CLC] summary: OK=$ok WARN=$warn FAIL=$fail (scope=$SCOPE strict=$STRICT)"
if [ "$fail" -gt 0 ]; then
  echo "[CLC] blocking push due to FAIL."
  exit 1
fi
if [ "$STRICT" = 1 ] && [ "$warn" -gt 0 ]; then
  echo "[CLC] strict mode: WARN treated as FAIL."
  exit 1
fi
echo "[CLC] gate passed."
exit 0
