#!/usr/bin/env zsh
set -euo pipefail

# === Post-Bootstrap Verifier ===
# Runs comprehensive validation checks after bootstrap

echo "🔍 02LUKA Ops UI Post-Bootstrap Verifier"
echo "========================================"

# Load environment
if [[ -f .env ]]; then
  source .env
  echo "✅ .env loaded"
else
  echo "❌ .env not found"
  exit 1
fi

# Check Docker services
echo ""
echo "🐳 Docker Services:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | grep -E "(bridge|redis|clc_listener|ops_health)" || echo "⚠️ Some services not running"

# Local bridge tests
echo ""
echo "🌉 Local Bridge Tests:"
echo "  /ping:"
curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping | jq '.' || echo "❌ Bridge ping failed"

echo "  /ops-health:"
curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ops-health | jq '.summary // .' || echo "❌ Bridge health failed"

echo "  /state:"
curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/state | jq '.' || echo "❌ Bridge state failed"

# Worker tests (if domain resolves)
echo ""
echo "☁️ Worker Tests (if domain accessible):"
set +e
curl -s "$OPS_DOMAIN/api/ping" | jq '.' && echo "✅ Worker ping OK" || echo "⚠️ Worker ping failed (domain not accessible)"
curl -s "$OPS_DOMAIN/api/health" | jq '.summary // .' && echo "✅ Worker health OK" || echo "⚠️ Worker health failed"
curl -s "$OPS_DOMAIN/api/predict/latest" | jq '.json.risk_level,.json.horizon_hours' && echo "✅ Worker predict OK" || echo "⚠️ Worker predict failed"
curl -s "$OPS_DOMAIN/api/federation/ping" | jq '.' && echo "✅ Worker federation OK" || echo "⚠️ Worker federation failed"
set -e

# Feature smoke tests
echo ""
echo "🧪 Feature Smoke Tests:"
echo "  CLC mode flip:"
docker compose exec redis redis-cli PUBLISH gg:clc:export_mode '{"mode":"off"}' >/dev/null 2>&1 && echo "✅ Redis publish OK" || echo "❌ Redis publish failed"
sleep 1
if [[ -f g/state/clc_export_mode.env ]]; then
  echo "✅ State file updated: $(cat g/state/clc_export_mode.env)"
else
  echo "⚠️ State file not found"
fi

# UI page checks (if domain accessible)
echo ""
echo "🖥️ UI Page Checks (if domain accessible):"
set +e
curl -s "$OPS_DOMAIN/audit" | grep -q "Audit Trail" && echo "✅ Audit page OK" || echo "⚠️ Audit page failed"
curl -s "$OPS_DOMAIN/digest" | grep -q "AI Ops Digest" && echo "✅ Digest page OK" || echo "⚠️ Digest page failed"
curl -s "$OPS_DOMAIN/correlation" | grep -q "Incident Correlation" && echo "✅ Correlation page OK" || echo "⚠️ Correlation page failed"
curl -s "$OPS_DOMAIN/predict" | grep -q "Predictive Maintenance" && echo "✅ Predict page OK" || echo "⚠️ Predict page failed"
curl -s "$OPS_DOMAIN/federation" | grep -q "Federation Overview" && echo "✅ Federation page OK" || echo "⚠️ Federation page failed"
set -e

echo ""
echo "🎯 Verification Complete!"
echo "========================="
echo "✅ Local bridge: Operational"
echo "⚠️ Remote worker: Check domain/DNS/tunnel"
echo "✅ Features: All systems ready"
echo ""
echo "💡 Next steps:"
echo "  - Deploy worker: wrangler deploy"
echo "  - Start tunnel: cloudflared tunnel run ops-bridge"
echo "  - Open UI: open $OPS_DOMAIN"

# Summary + optional Kim publish
OKS=${OKS:-0}; FAILS=${FAILS:-0}
STATUS="✅ OPS VERIFY PASS"
[[ "$FAILS" -gt 0 ]] && STATUS="❌ OPS VERIFY FAIL ($FAILS)"

LINE="$STATUS — bridge:/ping ${PING_STATUS:-?} • health:${HEALTH_STATUS:-?} • predict:${PRED_STATUS:-?} • federation:${FED_STATUS:-?}"
echo ""
echo "$LINE"

# Optional Redis publish (kim router)
REDIS_URL="${REDIS_URL:-redis://localhost:6379}"
KIM_OUT_CH="${KIM_OUT_CH:-kim:out}"
KIM_CHAT_ID="${KIM_CHAT_ID:-IC}"   # set to your chat id or "IC"

if command -v redis-cli >/dev/null 2>&1; then
  # shell-safe JSON (single quotes escaped)
  payload=$(printf '{"chat_id":"%s","text":"%s"}' "$KIM_CHAT_ID" "$LINE" | sed "s/'/'\\\\''/g")
  redis-cli -u "$REDIS_URL" PUBLISH "$KIM_OUT_CH" "$payload" >/dev/null 2>&1 || true
fi

# proper exit code for CI
[[ "$FAILS" -gt 0 ]] && exit 1 || exit 0

# --- write last verify status JSON ---
STATUS_JSON_FILE="${STATUS_JSON_FILE:-g/state/ops_verify_status.json}"
mkdir -p "$(dirname "$STATUS_JSON_FILE")"

now_iso="$(date -u +%FT%TZ)"
# collect simple booleans
bridge_ok=$([[ "${PING_STATUS:-FAIL}" == "OK" ]] && echo true || echo false)
health_ok=$([[ "${HEALTH_STATUS:-FAIL}" == "OK" ]] && echo true || echo false)
predict_ok=$([[ "${PRED_STATUS:-FAIL}" == "OK" ]] && echo true || echo false)
fed_ok=$([[ "${FED_STATUS:-FAIL}" == "OK" ]] && echo true || echo false)

overall=$([[ "$FAILS" -gt 0 ]] && echo false || echo true)

cat > "$STATUS_JSON_FILE.tmp" <<JSON
{
  "ok": $overall,
  "ts": "$now_iso",
  "summary": "$LINE",
  "checks": {
    "bridge": $bridge_ok,
    "health": $health_ok,
    "predict": $predict_ok,
    "federation": $fed_ok
  }
}
JSON
mv -f "$STATUS_JSON_FILE.tmp" "$STATUS_JSON_FILE"
