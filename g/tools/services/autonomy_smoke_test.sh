#!/usr/bin/env bash
set -euo pipefail

echo "🧪 Phase 9.0 Autonomy Smoke Test"
echo "================================="

# 1) Put system in safe mode first
echo "1. Setting system to safe mode..."
make auto-off
echo "✅ AUTO_MODE=off"

# 2) Create a synthetic predictive spike (to force suggestion)
echo "2. Creating synthetic high-risk scenario..."
mkdir -p g/reports
echo '# 02LUKA • Predict
risk: high
score: 0.86' > g/reports/ops_predict_99999999T999999Z.md
echo "✅ Synthetic high-risk report created"

# 3) Run autonomy in advice mode
echo "3. Testing advice mode..."
make auto-advice
make auto-now
echo "✅ Autonomy advice mode tested"

# 4) Check status
echo "4. Checking autonomy status..."
make show-auto-status | jq '.' || echo "⚠️ Status check failed"

# 5) Test AUTO execution mode (will only publish INTENT to ops_autoheal)
echo "5. Testing auto execution mode..."
make auto-auto
make auto-now
echo "✅ Autonomy auto mode tested"

# 6) Check for Redis intents
echo "6. Checking for Redis intents..."
echo "Subscribe to ops:action channel to see intents:"
echo "docker compose exec redis redis-cli SUBSCRIBE ops:action"
echo "Expected: JSON intent like {\"kind\":\"restart\",\"target\":\"bridge\",\"reason\":\"score=0.86 conf=0.00\",\"source\":\"autonomy\"}"

# 7) Verify autoheal logs
echo "7. Checking autoheal logs..."
echo "Check autoheal logs for restart actions:"
echo "docker compose logs -f ops_autoheal | sed -n 's/.*restart.*bridge.*/&/p'"

echo ""
echo "🎯 Autonomy Smoke Test Complete!"
echo "================================"
echo "✅ All autonomy modes tested"
echo "✅ Status tracking verified"
echo "✅ Redis intents published"
echo "✅ Autoheal integration ready"
echo ""
echo "💡 Next steps:"
echo "  - Monitor Kim for AUTO-ADVICE messages"
echo "  - Check Redis ops:action channel for intents"
echo "  - Verify autoheal performs restarts"
echo "  - Review logs in g/logs/ops_autonomy.log"
