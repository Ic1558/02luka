#!/usr/bin/env bash
set -euo pipefail
API="http://127.0.0.1:4000"
UI="http://127.0.0.1:5173"
pass(){ echo "PASS $1"; }
fail(){ echo "FAIL $1"; exit 1; }

# Ensure up
bash ./run/dev_up_simple.sh >/dev/null 2>&1 || true
sleep 1

# API checks
curl -fsS "$API/api/capabilities" >/dev/null || fail "capabilities"
curl -fsS -X POST "$API/api/optimize" -H 'Content-Type: application/json' -d '{"prompt":"hello"}' >/dev/null || fail "optimize"
curl -fsS -X POST "$API/api/chat-with-nlu-router" -H 'Content-Type: application/json' -d '{"message":"hi"}' >/dev/null || fail "nlu-router"
pass "api"

# UI checks
curl -fsSI "$UI/luka.html" >/dev/null || fail "luka.html"
curl -fsS "$UI/js/chatbot_actions.js" >/dev/null || fail "chatbot_actions.js"
pass "ui"

# MCP FS connectivity (8765)
curl -fsS http://127.0.0.1:8765/health >/dev/null && pass "mcp_fs" || echo "WARN mcp_fs offline"
