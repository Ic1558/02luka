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

⸻

🔍 Quick Health Check Commands

MCP Bridge: com.02luka.gg.mcp-bridge

# สถานะ + PID
launchctl list | grep com.02luka.gg.mcp-bridge

# รายละเอียดบริการ (ตรวจ Program, KeepAlive, RunAtLoad, LastExitStatus)
launchctl print gui/$(id -u)/com.02luka.gg.mcp-bridge

# รีสตาร์ตอย่างปลอดภัย
launchctl bootout gui/$(id -u)/com.02luka.gg.mcp-bridge 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/com.02luka.gg.mcp-bridge.plist"
launchctl kickstart -k gui/$(id -u)/com.02luka.gg.mcp-bridge

# ดู log สด (ถ้าใช้ stdout/stderr ของ plist)
log stream --predicate 'subsystem CONTAINS "02luka" OR process == "mcp-bridge"' --info

# ตรวจ plist ให้ชัวร์
plutil -lint "$HOME/Library/LaunchAgents/com.02luka.gg.mcp-bridge.plist"
grep -A 1 "Label" "$HOME/Library/LaunchAgents/com.02luka.gg.mcp-bridge.plist" | grep "com.02luka.gg.mcp-bridge"

MLS Streak & Ledger (ชุดดูเร็ว)

# ดู streak (ปลอดภัยแม้ไฟล์ยังไม่ถูกสร้าง)
cat "$HOME/02luka/mls/status/mls_validation_streak.json" 2>/dev/null | jq . \
  || echo "⚠️  streak file not found (จะถูกสร้างเมื่อ validate ครั้งแรก)"

# ดู entry วันนี้ (ICT)
"$HOME/02luka/tools/mls_view.zsh" --today

# ยืนยันไฟล์ ledger วันนี้เป็น JSONL และมี newline ปิดท้าย
LEDGER="$HOME/02luka/mls/ledger/$(TZ=Asia/Bangkok date +%Y-%m-%d).jsonl"
[ -f "$LEDGER" ] && tail -n 3 "$LEDGER" | jq -c . >/dev/null && echo "JSONL ✅" || echo "ยังไม่พบ/ไม่ใช่ JSONL"

⸻
