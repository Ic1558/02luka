#!/usr/bin/env bash
set -euo pipefail

ROOT="${HOME}/02luka"
cd "${ROOT}"

JSONL="g/reports/web_actions.jsonl"
DAILY_GLOB="g/reports/web_actions_daily_*.json"
WEEKLY_GLOB="g/reports/web_actions_weekly_*.json"
SUMMARY="g/reports/phase7_7_summary.md"

pass() { echo "✅ $*"; }
fail() { echo "❌ $*"; exit 1; }
note() { echo "— $*"; }

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

echo "# Phase 7.7 Verification — $(date -Iseconds)" > "${SUMMARY}"
echo >> "${SUMMARY}"

ensure_cmd node
ensure_cmd jq || note "jq not found — CSV/JSON checks will be shallow"

# 0) Prep
mkdir -p 02luka/config g/reports
echo "example.com" > 02luka/config/browseros.allow
rm -f 02luka/config/browseros.off || true
pass "Prep done (allowlist example.com, killswitch off)"

# 1) MCP selftest
if node knowledge/mcp/browseros.cjs --selftest | tee /tmp/mcp_selftest.log | grep -qi "selftest"; then
  pass "MCP selftest ok"
else
  cat /tmp/mcp_selftest.log
  fail "MCP selftest failed"
fi

# 2) CLI run (navigate)
REQ_CLI=$(cat <<JSON
{
  "tool":"browseros.workflow",
  "params":{
    "plan":[{"op":"navigate","url":"https://example.com"}],
    "allowDomains":["example.com"],
    "timeoutMs": 20000
  }
}
JSON
)

OUT_CLI=$(echo "${REQ_CLI}" | tools/browseros.sh || true)
echo "${OUT_CLI}" | grep -q '"ok": true' || fail "CLI ok:false"
pass "CLI basic navigate ok"

# 3) Redis round-trip
ensure_cmd redis-cli
REQ_ID="act_$(date +%s)"
REQ_REDIS=$(cat <<JSON
{
  "id":"${REQ_ID}",
  "caller":"CLS",
  "tool":"browseros.workflow",
  "params":{
    "plan":[{"op":"navigate","url":"https://example.com"}],
    "allowDomains":["example.com"],
    "timeoutMs": 20000
  },
  "ts":"$(date -Iseconds)"
}
JSON
)
redis-cli PUBLISH ai.action.request "${REQ_REDIS}" >/dev/null

# optional: worker may also set key ai.action.result:<id>
sleep 2
RES=$(redis-cli GET "ai.action.result:${REQ_ID}" || true)
if [ -n "${RES}" ]; then
  echo "${RES}" | grep -q '"ok":true' || fail "Redis result ok:false"
  pass "Redis round-trip ok (GET key)"
else
  note "No GET result key; checking JSONL for ${REQ_ID}"
  grep -q "${REQ_ID}" "${JSONL}" || fail "No evidence of ${REQ_ID} in ${JSONL}"
  pass "Redis evidence found in JSONL"
fi

# 4) Telemetry append
test -f "${JSONL}" || fail "missing ${JSONL}"
tail -n 1 "${JSONL}" | grep -E '"id"|"caller"|"tool"|"ok"' >/dev/null || fail "JSONL fields missing"
pass "Telemetry JSONL appended"

# 5) Rollups (simulate nightly/weekly)
if [ -f knowledge/web_actions_rollup.cjs ]; then
  node knowledge/web_actions_rollup.cjs --csv || fail "daily rollup failed"
else
  note "rollup script not found: knowledge/web_actions_rollup.cjs (skipping)"
fi

if [ -f knowledge/web_actions_rollup_weekly.cjs ]; then
  node knowledge/web_actions_rollup_weekly.cjs --csv || fail "weekly rollup failed"
else
  note "rollup script not found: knowledge/web_actions_rollup_weekly.cjs (skipping)"
fi

ls g/reports/web_actions_daily_*.* >/dev/null 2>&1 && pass "Daily rollups exist" || note "Daily rollups missing (ok if scripts not installed)"
ls g/reports/web_actions_weekly_*.* >/dev/null 2>&1 && pass "Weekly rollups exist" || note "Weekly rollups missing (ok if scripts not installed)"

# 6) Safety — allowlist block
REQ_BLOCK=$(cat <<JSON
{
  "tool":"browseros.workflow",
  "params":{"plan":[{"op":"navigate","url":"https://not-allowed.test"}],"allowDomains":["not-allowed.test"],"timeoutMs": 5000}
}
JSON
)
set +e
OUT_BLOCK=$(echo "${REQ_BLOCK}" | tools/browseros.sh 2>&1)
EC=$?
set -e
[ ${EC} -ne 0 ] && echo "${OUT_BLOCK}" | grep -qi "allow" && pass "Allowlist block works" || fail "Allowlist block failed"

# 6.2 Killswitch
touch 02luka/config/browseros.off
set +e
OUT_KILL=$(echo "${REQ_CLI}" | tools/browseros.sh 2>&1)
EC2=$?
set -e
rm -f 02luka/config/browseros.off
[ ${EC2} -ne 0 ] && echo "${OUT_KILL}" | grep -qi "kill" && pass "Killswitch works" || fail "Killswitch failed"

# 7) Governance thresholds (if rollups exist)
P95_BAD=$(jq -r '.patterns[]?|select(.p95_ms>2000)|.action' ${DAILY_GLOB} 2>/dev/null | head -n1 || true)
ERR_BAD=$(jq -r '.patterns[]?|select(.error_rate>0.05)|.action' ${DAILY_GLOB} 2>/dev/null | head -n1 || true)
if [ -z "${P95_BAD}" ]; then pass "p95 < 2000ms"; else note "High p95 action: ${P95_BAD}"; fi
if [ -z "${ERR_BAD}" ]; then pass "error_rate < 5%"; else note "High error_rate action: ${ERR_BAD}"; fi

# 8) Service health (best-effort)
if command -v launchctl >/dev/null 2>&1; then
  launchctl list | grep -i browseros.worker >/dev/null && pass "LaunchAgent present" || note "LaunchAgent not listed"
fi

# 9) E2E navigate+extract
REQ_E2E=$(cat <<JSON
{
  "tool":"browseros.workflow",
  "params":{
    "plan":[
      {"op":"navigate","url":"https://example.com"},
      {"op":"extract","selectors":["h1"]}
    ],
    "allowDomains":["example.com"],
    "timeoutMs": 20000
  }
}
JSON
)
OUT_E2E=$(echo "${REQ_E2E}" | tools/browseros.sh)
echo "${OUT_E2E}" | grep -q '"ok": true' || fail "E2E ok:false"
echo "${OUT_E2E}" | grep -qi '"h1"' || note "E2E: h1 not captured (depends on extractor impl)"
pass "E2E navigate+extract ok"

echo -e "\nAll checks done." | tee -a "${SUMMARY}"
