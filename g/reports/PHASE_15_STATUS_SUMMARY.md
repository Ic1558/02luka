⸻

🧩 02Luka Phase 15 – Operational Checklist Summary

📅 Generated: 2025-11-10 (ICT)

⸻

✅ Done

	•	CI: AJV deps + validator merged (PR #252)

	•	npm cache & maintenance guard active (PR #254 + #256)

	•	CLS ledger → JSONL + sanitize auto-commit working

	•	ICT timezone enabled for all workflows

	•	router-selftest input (node_version) fixed

	•	Reusable workflow refactor complete

⸻

🟢 Next Immediate (Run Now)

# 1. Disable maintenance mode & trigger full CI

gh variable set MAINTENANCE_MODE --body 0

~/02luka/tools/ci_check.zsh



# 2. Restart MCP services on Mac mini

launchctl kickstart -k system/com.02luka.mcp.fs

launchctl kickstart -k system/com.02luka.mcp.puppeteer

launchctl kickstart -k system/com.02luka.gg.mcp-bridge



# 3. Validate MCP telemetry

gh workflow run system-telemetry-v2.yml



# 4. Verify router / ops-gate selftests

gh workflow run router-selftest.yml

gh workflow run ops-gate.yml

⸻

🟡 Next 24 h Tasks

# Daily delegation routine

~/02luka/tools/delegation_enable_and_test.zsh



# Snapshot Phase 15 final state

mkdir -p ~/02luka/snapshots/phase15_final

cp -R ~/02luka/g/reports ~/02luka/snapshots/phase15_final/

⸻

🔵 Planned (Phase 16 Launch)

	•	Re-enable daily LaunchAgent for delegation (07:00 ICT)

	•	Web & Telegram export bridge → theedges.work

	•	Merge MCP telemetry and MLS report streams

	•	Draft PHASE_16_PLAN.md → g/reports/

⸻

⚙️ Verification Commands

# Confirm MCP health

~/02luka/tools/mls_view.zsh --grep 'MCP' --today



# Check 3 green streak in CLS (creates file if missing)

cat ~/02luka/mls/status/mls_validation_streak.json 2>/dev/null | jq . || echo "⚠️  File not found - will be created on first validation"



# Confirm ledger integrity

tail -n 5 ~/02luka/mls/ledger/$(TZ=Asia/Bangkok date +%Y-%m-%d).jsonl | jq .

⸻
