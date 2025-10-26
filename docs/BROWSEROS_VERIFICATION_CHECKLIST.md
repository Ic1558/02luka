# Phase 7.7 — BrowserOS Verification Checklist

## Pre-flight Checks
- [ ] MCP selftest runs (if file exists)
- [ ] CLI path returns ok:true and appends telemetry JSONL
- [ ] Redis round-trip works (if redis-cli + worker available)
- [ ] Daily/weekly rollups generated (if scripts present)
- [ ] Allowlist + killswitch behaviour verified (real or simulated)

## Artifacts Verification
- [ ] Artifacts present: g/reports/phase7_7_summary.md
- [ ] Artifacts present: g/reports/web_actions.jsonl
- [ ] Daily rollups exist (if available): g/reports/web_actions_daily_*.json
- [ ] Weekly rollups exist (if available): g/reports/web_actions_weekly_*.json

## Safety Checks
- [ ] Allowlist blocking works (prevents navigation to non-allowed domains)
- [ ] Killswitch works (prevents execution when browseros.off is present)
- [ ] Telemetry logging functions correctly
- [ ] Error handling graceful (continues on failures)

## CI Integration
- [ ] Script runs in GitHub Actions environment
- [ ] Uses GITHUB_WORKSPACE correctly
- [ ] Generates required artifacts for upload
- [ ] Exit codes appropriate for CI success/failure

## Notes
- Script is designed to be robust without external dependencies (jq, redis)
- Falls back gracefully when components are missing
- Creates stub implementations when needed for CI testing
- All checks are best-effort to avoid CI failures
