#!/usr/bin/env zsh
set -euo pipefail

BASE="${HOME}/02luka"
RUN_SH="${BASE}/run/ops_atomic.sh"
PLIST_DIR="${HOME}/Library/LaunchAgents"
LABEL="com.02luka.ops-atomic.daily"
PLIST="${PLIST_DIR}/${LABEL}.plist"
LOG_DIR="${BASE}/g/reports"
OUT_LOG="${LOG_DIR}/ops_atomic.daily.out.log"
ERR_LOG="${LOG_DIR}/ops_atomic.daily.err.log"

if [[ ! -f "${RUN_SH}" ]]; then
  echo "❌ Missing ${RUN_SH} — abort."; exit 1
fi
chmod +x "${RUN_SH}"
mkdir -p "${PLIST_DIR}" "${LOG_DIR}"

cat > "${PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
 <dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>cd ${BASE} && ${RUN_SH}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OPS_BASE</key><string>${BASE}</string>
  </dict>
  <key>StandardOutPath</key><string>${OUT_LOG}</string>
  <key>StandardErrorPath</key><string>${ERR_LOG}</string>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>2</integer>
    <key>Minute</key><integer>30</integer>
  </dict>
  <key>RunAtLoad</key><true/>
 </dict>
</plist>
PLIST

launchctl unload "${PLIST}" >/dev/null 2>&1 || true
launchctl load -w "${PLIST}"

echo "— Running one-shot now for verification…"
( cd "${BASE}" && "${RUN_SH}" ) || true

echo "✅ Scheduled ${LABEL} for 02:30 daily (local time)."
echo "📄 Plist: ${PLIST}"
echo "🪵 Logs:  ${OUT_LOG}, ${ERR_LOG}"

echo
printf "🔎 launchctl check:\n"
launchctl list | grep -F "${LABEL}" || echo "(not shown yet? it will appear after a scheduled start)"

echo
printf "🧪 Tail last logs:\n"
test -f "${OUT_LOG}" && tail -n 20 "${OUT_LOG}" || echo "(no stdout yet)"
test -f "${ERR_LOG}" && tail -n 20 "${ERR_LOG}" || echo "(no stderr yet)"

echo
printf "Tips:\n"
echo "• Disable: launchctl unload -w '${PLIST}'"
echo "• Re-enable: launchctl load -w '${PLIST}'"
echo "• Manual run anytime: cd '${BASE}' && '${RUN_SH}'"
