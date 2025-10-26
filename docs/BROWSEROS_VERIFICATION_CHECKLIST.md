# Phase 7.7 — BrowserOS Verification Checklist

## 0) Prep
- [ ] example.com in `02luka/config/browseros.allow`
- [ ] `02luka/config/browseros.off` not present

## 1) MCP
- [ ] `node knowledge/mcp/browseros.cjs --selftest` exit 0, contains "selftest ok"

## 2) CLI
- [ ] `tools/browseros.sh` navigate https://example.com → ok:true, perf.totalMs present

## 3) Redis
- [ ] Publish `ai.action.request` → receive matching `ai.action.result` for id
- [ ] Result ok:true with perf.totalMs

## 4) Telemetry
- [ ] `g/reports/web_actions.jsonl` appended with id/caller/tool/ok/perf/domain

## 5) Rollups
- [ ] Nightly: `web_actions_daily_YYYYMMDD.json/csv` created
- [ ] Weekly: `web_actions_weekly_YYYYWW.json/csv` created

## 6) Safety
- [ ] Allowlist blocks non-allowed domain with reason
- [ ] Killswitch blocks any command
- [ ] Quota over-limit is rejected and logged

## 7) Governance
- [ ] p95_ms < 2000 for primary actions (navigate/click/type/extract)
- [ ] error_rate < 5%

## 8) Services
- [ ] BrowserOS worker running (LaunchAgent/systemd), no crash-loop

## 9) E2E
- [ ] workflow: navigate → extract h1 from example.com, logs + rollups reflect run
