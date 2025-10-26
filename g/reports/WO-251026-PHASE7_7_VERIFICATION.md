# WO-251026 — Phase 7.7 BrowserOS Integration Verification

**Owner:** CLC  
**Date:** 2025-10-26  
**Purpose:** Verify BrowserOS integration paths and governance telemetry

## Scope
- MCP selftest
- CLI direct run
- Redis request/result round-trip
- Telemetry append (JSONL) + daily/weekly rollups (JSON/CSV)
- Safety (allowlist, killswitch, quota)
- Governance thresholds (p95 < 2000ms, error_rate < 5%)

## Files
- docs/BROWSEROS_VERIFICATION_CHECKLIST.md
- tools/test_browseros_phase77.sh

## Acceptance Criteria
- All tests in checklist = PASS
- Daily/weekly rollups created with CSV
- Alerts generated only if thresholds breached
- Report summary appended to g/reports/phase7_7_summary.md

## Run
```bash
bash tools/test_browseros_phase77.sh
```

Artifacts
- g/reports/web_actions.jsonl
- g/reports/web_actions_daily_YYYYMMDD.{json,csv}
- g/reports/web_actions_weekly_YYYYWW.{json,csv}
- g/reports/phase7_7_summary.md
