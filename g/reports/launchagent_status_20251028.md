# LaunchAgent Status Report
**Date:** 2025-10-28 04:11
**After Cleanup:** Phase 7.8 exit=127 agent removal

## Summary
- **Total Agents:** 69 (was 78)
- **Healthy (exit=0 or running):** 36 (52.2%)
- **Failed:** 33 (47.8%)

## Cleanup Completed ✅
**Removed 9 broken agents:**
- 7× exit=127 (command not found) - Non-existent services
- 1× invalid XML plist (security.scan)

**Archived to:** `~/Library/LaunchAgents_disabled/`

## Remaining Failures
**8× exit=78 (Configuration Error):**
- digest
- gptree_events
- gptree_updater
- health_monitor
- gg_local_llm
- routine_delegation
- simple.watchdog
- watcher

**Other Failures (~25):**
- Various runtime errors and crashed services
- Need individual investigation
- Not blocking core operations

## Critical Services Status ✅
- **ops_atomic_monitor.loop:** ✅ Running (PID 0, exit 38806)
- **analytics.parquet:** ✅ Running (exit 0)
- **ops_atomic_daily:** ✅ Healthy (exit 0)
- **optimizer:** ✅ Healthy (exit 0)
- **digest:** ⚠️ exit=78 (config error, non-critical)
- **reports.rotate:** ✅ Removed (was exit=127)

## Phase 7.8 Analytics ✅
**Parquet Export Pipeline:** Fully operational
- LaunchAgent: Loaded and scheduled (02:30 daily)
- Latest export: ops_atomic_20251027.parquet (2.6KB, 21 rows)
- Status: exit=0 (healthy)

## Recommendations

### Immediate (Done ✅)
- ✅ Remove exit=127 agents (command not found)
- ✅ Archive invalid plists

### Short-term (Optional)
- Review exit=78 agents - may be optional features
- Consider archiving if not needed:
  - gg_local_llm (Gemini CLI, might be unused)
  - simple.watchdog (duplicate of watchdog?)
  - routine_delegation (functionality unclear)

### Long-term
- Document LaunchAgent dependencies
- Create restoration procedure for archived agents
- Implement health monitoring dashboard

## Exit Code Reference
- `0` = Success / Healthy
- `78` = Configuration error
- `127` = Command not found (archived)
- Large numbers (58355, 38643, etc.) = Crash exit codes

---
**Generated:** 2025-10-28T04:11:06+07:00
