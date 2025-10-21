#!/usr/bin/env zsh
set -euo pipefail

# Repo & report
CANDIDATES=(
  "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
  "/workspaces/02luka-repo"
)
ROOT=""
for d in "${CANDIDATES[@]}"; do [[ -d "$d" ]] && ROOT="$d" && break; done
[[ -z "$ROOT" ]] && { echo "Repo root not found"; exit 1; }

LOG_DIR="$ROOT/g/logs"; REP_DIR="$ROOT/g/reports"
mkdir -p "$LOG_DIR" "$REP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$REP_DIR/251021_verification_precise_${STAMP}.md"

# 0) sqlite3 sanity
pushd "$ROOT" >/dev/null
SQLITE_STATUS="OK"
if [ -d node_modules/sqlite3 ]; then
  if ! node -e "require('sqlite3')" >/dev/null 2>&1; then
    (npm rebuild sqlite3 --silent || true)
  fi
  node -e "require('sqlite3')" >/dev/null 2>&1 || SQLITE_STATUS="FAIL"
else
  SQLITE_STATUS="SKIP(no node_modules/sqlite3)"
fi
popd >/dev/null

# Helper to time commands
run_time () {
  local t0 t1 dur
  t0=$(python3 - <<'PY'
import time;print(time.time())
PY
)
  if eval "$@" >/dev/null 2>&1; then
    t1=$(python3 - <<'PY'
import time;print(time.time())
PY
)
    dur=$(python3 - <<PY
print(round($t1-$t0,3))
PY
)
    echo "OK:$dur"
  else
    echo "FAIL:NA"
  fi
}

cd "$ROOT"

# 1) Timed functional tests (same as before)
R1=$(run_time "node knowledge/sync.cjs --export")
R2=$(run_time "bash g/tools/emit_codex_truth.sh")
R3=$(run_time "bash scripts/generate_telemetry_report.sh")

# 2) Regression scans
# JS scan identical (robust already)
JS_HITS=$(grep -RIn "fs\.writeFileSync\(" knowledge agents memory g 2>/dev/null \
  | grep -vE "node_modules|atomicExport|writeArtifacts|\.backup" || true)

# Shell scan (precision): only real shell/executables under g/ and scripts/
SHELL_FILES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && SHELL_FILES+=("$line")
done < <(find g scripts -type f \
  \( -name '*.sh' -o -perm -0100 -o -perm -0010 -o -perm -0001 \) \
  ! -path "*/.backup/*" ! -path "*/proof/*" \
  ! -name "*.md" ! -name "*.txt" ! -name "*.plist" ! -name "*.json" ! -name "*.log" 2>/dev/null)

SH_HITS=""
if (( ${#SHELL_FILES[@]} > 0 )); then
  SH_HITS=$(grep -RInE "(^|[^>])>\s*(\.codex|g/reports|knowledge/exports|Library/CloudStorage/GoogleDrive[^ ]*)" \
            "${SHELL_FILES[@]}" 2>/dev/null \
            | grep -vE "mktemp|mv " || true)
fi

# 3) Report
{
  echo "# 251021 — Freeze-Proofing Verification (Precise)"
  echo "**Generated (UTC):** ${STAMP}"
  echo
  echo "## sqlite3 Native Module"
  echo "- Status: \`${SQLITE_STATUS}\`"
  echo
  echo "## Timed Functional Tests"
  awk -v r="$R1" 'BEGIN{split(r,a,":");print "- Phase 1 (knowledge/sync.cjs --export):",(a[1]=="OK"?"✅ PASS":"❌ FAIL"),(a[2]!=""?a[2]"s":"")}'
  awk -v r="$R2" 'BEGIN{split(r,a,":");print "- Phase 3 (emit_codex_truth.sh):     ",(a[1]=="OK"?"✅ PASS":"❌ FAIL"),(a[2]!=""?a[2]"s":"")}'
  awk -v r="$R3" 'BEGIN{split(r,a,":");print "- Phase 3 (generate_telemetry_report):",(a[1]=="OK"?"✅ PASS":"❌ FAIL"),(a[2]!=""?a[2]"s":"")}'
  echo
  echo "## Regression Scan"
  if [ -n "$JS_HITS" ]; then
    echo "### ❌ Raw \`fs.writeFileSync\` occurrences"
    echo '```'; echo "$JS_HITS" | sed -e 's/^/  /'; echo '```'
  else
    echo "- JS scan: ✅ No raw \`fs.writeFileSync\` in sensitive paths"
  fi
  if [ -n "$SH_HITS" ]; then
    echo "### ❌ Risky shell redirections to synced paths"
    echo '```'; echo "$SH_HITS" | sed -e 's/^/  /'; echo '```'
  else
    echo "- Shell scan: ✅ No risky direct redirections (mktemp+mv in place)"
  fi
  echo
  echo "## Pass Criteria"
  echo "- sqlite3: \`OK\` or \`SKIP\`"
  echo "- All timed tests: \`PASS\` and < 5s each"
  echo "- No regression hits in JS/SH scans"
} > "$OUT"

echo "==> Report: $OUT"
[ "${R1%%:*}" = "OK" ] && [ "${R2%%:*}" = "OK" ] && [ "${R3%%:*}" = "OK" ] && [ -z "$JS_HITS" ] && [ -z "$SH_HITS" ] && [ "$SQLITE_STATUS" != "FAIL" ] \
  && echo "✅ OVERALL: PASS" || { echo "❌ OVERALL: CHECK REPORT"; exit 2; }
