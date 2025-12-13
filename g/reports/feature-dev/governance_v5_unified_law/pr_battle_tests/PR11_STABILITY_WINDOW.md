# PR-11: 7-Day Stability Window

**Start Date:** 2025-12-12  
**Status:** ⏳ **IN PROGRESS** — Day 0/7

---

## Objective

Verify system stability over 7 consecutive days:
- No legacy routing fallback
- No gateway process duplication
- Stable error rates
- Consistent v5 stack usage

---

## Success Criteria

✅ **7 consecutive days with:**
- All WOs processed via `process_v5` (no `"action":"route"`)
- Gateway process count: 1 (no duplicates)
- Mary-COO process count: 1 (no duplicates)
- Error rate: No spikes from gateway fallback/exception loops

---

## Daily Monitoring

**Command:**
```bash
zsh ~/02luka/tools/monitor_v5_production.zsh json > \
  g/reports/feature-dev/governance_v5_unified_law/pr_battle_tests/monitoring/monitor_YYYYMMDD.json
```

**Evidence Files:**
- `monitoring/monitor_20251212.json` (Day 0)
- `monitoring/monitor_20251213.json` (Day 1)
- `monitoring/monitor_20251214.json` (Day 2)
- `monitoring/monitor_20251215.json` (Day 3)
- `monitoring/monitor_20251216.json` (Day 4)
- `monitoring/monitor_20251217.json` (Day 5)
- `monitoring/monitor_20251218.json` (Day 6)

---

## Daily Checklist

| Day | Date | Monitoring | Legacy Fallback | Process Count | Error Rate | Status |
|-----|------|------------|-----------------|---------------|------------|--------|
| 0 | 2025-12-12 | ✅ | ✅ No | ✅ 1+1 | ✅ Stable | ✅ |
| 1 | 2025-12-13 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 2 | 2025-12-14 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 3 | 2025-12-15 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 4 | 2025-12-16 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 5 | 2025-12-17 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 6 | 2025-12-18 | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |

---

## Verification Commands

**Check for legacy routing:**
```bash
tail -n 200 ~/02luka/g/telemetry/gateway_v3_router.log | \
  grep -E '"action":"route"|falling back' | wc -l
# Expected: 0
```

**Check process count:**
```bash
pgrep -fl "gateway_v3_router.py" | wc -l
pgrep -fl "agents/mary/mary.py" | wc -l
# Expected: 1 each
```

**Check error rate:**
```bash
tail -n 200 ~/02luka/g/telemetry/gateway_v3_router.log | \
  grep -E '"status":"error"' | wc -l
# Monitor for spikes
```

---

## Day 0 Status (2025-12-12)

**Baseline:**
- ✅ Gateway: 1 process
- ✅ Mary-COO: 1 process
- ✅ All recent WOs: `process_v5`
- ✅ No legacy fallback detected
- ✅ Error rate: Stable

**Evidence:**
- `monitoring/monitor_20251212.json`

---

## Notes

- Monitoring should be done daily at approximately the same time
- If any day fails criteria, reset the 7-day window
- Keep all evidence files for PR-12 post-mortem

---

**Last Updated:** 2025-12-12 (Day 0)

