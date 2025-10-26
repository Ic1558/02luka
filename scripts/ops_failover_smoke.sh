#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
#  02LUKA • Ops Failover Smoke
#  Validates: detection (MTTD), recovery (MTTR), cooldown dedupe & governance UI
# ──────────────────────────────────────────────────────────────────────────────
# Prereqs:
#   - curl, awk, date
#   - cloudflared/bridge processes present if you test process restarts
# Configure via env:
#   OPS_URL                # e.g. https://ops-02luka.ittipong-c.workers.dev
#   HEALTH_PATH=/ops/health            # worker health endpoint
#   ALERT_PATH=/ops/alert              # alert bridge endpoint
#   AUTOHEAL_INTERVAL=30               # seconds between health checks (daemon)
#   COOLDOWN_SEC=300                   # dedupe cooldown (server side)
#   TESTS="process:cloudflared,process:bridge,alert_cooldown,governance"
#
# Example:
#   OPS_URL="https://ops-02luka.ittipong-c.workers.dev" bash scripts/ops_failover_smoke.sh
#
# Notes:
#  - We DO NOT edit worker config. For "worker health fail" you can add your own
#    temporary flag/endpoint; this script focuses on process & alert paths.
# ──────────────────────────────────────────────────────────────────────────────

OPS_URL="${OPS_URL:-}"
HEALTH_PATH="${HEALTH_PATH:-/ops/health}"
ALERT_PATH="${ALERT_PATH:-/ops/alert}"
AUTOHEAL_INTERVAL="${AUTOHEAL_INTERVAL:-30}"
COOLDOWN_SEC="${COOLDOWN_SEC:-300}"
TESTS="${TESTS:-process:cloudflared,process:bridge,alert_cooldown,governance}"

if [[ -z "$OPS_URL" ]]; then
  echo "ERROR: OPS_URL not set"; exit 2
fi

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }

now_ms(){ date +%s%3N 2>/dev/null || echo $(( $(date +%s) * 1000 )); }

curl_json () {
  # $1: url
  curl -fsS --max-time 5 "$1" 2>/dev/null || return 1
}

health_check () {
  curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${OPS_URL}${HEALTH_PATH}" || echo 000
}

await_first_failure () {
  local start_ms="$1" deadline_ms=$(( start_ms + 120000 ))
  while :; do
    local code; code="$(health_check)"
    if [[ "$code" != "200" ]]; then
      echo "$(now_ms)"
      return 0
    fi
    [[ "$(now_ms)" -gt "$deadline_ms" ]] && echo 0 && return 1
    sleep 2
  done
}

await_recovery () {
  local start_ms="$1" deadline_ms=$(( start_ms + 180000 ))
  while :; do
    local code; code="$(health_check)"
    if [[ "$code" == "200" ]]; then
      echo "$(now_ms)"
      return 0
    fi
    [[ "$(now_ms)" -gt "$deadline_ms" ]] && echo 0 && return 1
    sleep 2
  done
}

print_metric_row () {
  # $1 name, $2 mttd_ms, $3 mttr_ms, $4 pass|fail, $5 note
  local n="$1" d="$2" r="$3" s="$4" note="$5"
  printf "%-22s | MTTD: %6sms | MTTR: %6sms | %s | %s\n" "$n" "${d:-n/a}" "${r:-n/a}" "$s" "$note"
}

test_process () {
  local proc="$1"
  bold "▶ Chaos: restart process [$proc]"
  local code_before; code_before="$(health_check)"
  [[ "$code_before" == "200" ]] || yellow "Health before kill is not 200 (${code_before}). Proceeding."

  # Kill target (non-destructive; supervised by auto-heal)
  if pgrep -f "$proc" >/dev/null; then
    pkill -f "$proc" || true
  else
    yellow "Process '$proc' not running — this test will measure that nothing breaks."
  fi

  local t0="$(now_ms)"
  local tf; tf="$(await_first_failure "$t0")" || tf=0
  local tr; tr="$(await_recovery "${tf:-$t0}")" || tr=0

  local mttd=$(( tf>0 ? tf - t0 : 0 ))
  local mttr=$(( tr>0 && tf>0 ? tr - tf : 0 ))

  # Evaluate
  local status="PASS" note=""
  if (( tf == 0 )); then
    # Possibly masked by fast restart within poll interval; treat as pass if health stayed 200
    if [[ "$(health_check)" == "200" ]]; then
      note="no visible outage (restart faster than probe)"
      status="PASS"
    else
      status="FAIL"; note="no failure observed but health not 200"
    fi
  else
    # We saw failure; enforce SLOs
    (( mttd <= 30000 )) || { status="FAIL"; note+="MTTD>${30000}ms "; }
    (( mttr > 0 && mttr <= 20000 )) || { status="FAIL"; note+="MTTR>${20000}ms "; }
  fi

  print_metric_row "proc:${proc}" "$mttd" "$mttr" "$status" "${note:-ok}"
}

test_alert_cooldown () {
  bold "▶ Alert dedupe/cooldown"
  local payload='{"severity":"warn","source":"smoke","title":"cooldown check","dedupeKey":"smoke:cooldown:1","details":{"t":"'"$(date -Iseconds)"'"}}'
  local url="${OPS_URL}${ALERT_PATH}"

  local a1; a1="$(curl -s -X POST -H 'content-type: application/json' --data "$payload" "$url" || true)"
  sleep 2
  local a2; a2="$(curl -s -X POST -H 'content-type: application/json' --data "$payload" "$url" || true)"

  # very light checks
  local sent1 skipped2
  grep -q '"sent":true' <<<"$a1"   && sent1=1  || sent1=0
  grep -q 'cooldown'  <<<"$a2"    && skipped2=1|| skipped2=0

  if (( sent1==1 && skipped2==1 )); then
    print_metric_row "alert:cooldown" "-" "-" "PASS" "first sent, second skipped (cooldown)"
  else
    print_metric_row "alert:cooldown" "-" "-" "FAIL" "resp1=$a1 resp2=$a2"
  fi
}

test_governance_ui () {
  bold "▶ Governance UI snapshot"
  local gov_url="${OPS_URL}/ops/governance"
  if curl -fsS --max-time 5 "$gov_url" >/dev/null; then
    print_metric_row "governance" "-" "-" "PASS" "renders"
  else
    print_metric_row "governance" "-" "-" "FAIL" "cannot render"
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────
bold "OPS Failover Smoke against: $OPS_URL"
echo "Tests: $TESTS"
echo "Auto-heal poll ~${AUTOHEAL_INTERVAL}s • Cooldown ~${COOLDOWN_SEC}s"
echo

IFS=',' read -r -a items <<< "$TESTS"
for t in "${items[@]}"; do
  case "$t" in
    process:cloudflared)  test_process "cloudflared" ;;
    process:bridge)       test_process "bridge" ;;
    process:redis)        test_process "redis-server" ;;
    alert_cooldown)       test_alert_cooldown ;;
    governance)           test_governance_ui ;;
    *) yellow "Skip unknown test token: $t" ;;
  esac
  echo
done

bold "Done."
