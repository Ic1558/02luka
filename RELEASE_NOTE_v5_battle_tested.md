# Release: Governance v5 — Battle-Tested Hardening (Gateway + Sandbox + Router)

## Highlights

- ✅ **Stable v5 routing in production** (no legacy fallback on valid v5 REJECTED/FAILED outcomes)
- ✅ **Single gateway process enforcement** (routing consistency restored)
- ✅ **Security hardening**: blocks null-byte, newline, traversal variants, empty/hostile paths
- ✅ **Monitoring accuracy**: v5 activity and lane distribution computed from telemetry

## Security

- Closed critical injection gaps uncovered by fuzz/stress testing.

## Operational Impact

- Routing becomes deterministic: PR-10 auto-approve stays FAST lane when eligible.
- Safer defaults: unknown triggers no longer silently route into permissive lanes.

## How to Verify After Deploy

- `zsh tools/monitor_v5_production.zsh json` → expect `legacy:0`, `action=process_v5`
- `tail -n 200 g/telemetry/gateway_v3_router.log` → no `"action":"route"` or "falling back"

## Breaking / Operational Changes

**LaunchAgent Configuration:**
- `com.02luka.mary-coo` must run `agents/mary/mary.py` ONLY
- `com.02luka.mary-gateway-v3` is the ONLY gateway runner
- Do not configure Mary-COO to run gateway_v3_router.py (causes duplicate processes)

**Router v5:**
- CLS auto-approve now supports OPEN zone + whitelist paths (not just LOCKED)
- DANGER zone patterns fixed (removed non-functional patterns)

**Monitor:**
- 24h activity window now correctly filters by timestamp

## Known Limitations

- "Battle-tested" production confidence still benefits from continued PR-7 accumulation + PR-11 stability window evidence (7 days).
