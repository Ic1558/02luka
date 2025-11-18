# Remaining TODOs Status

**Date:** 2025-11-18  
**Last Updated:** 2025-11-18

## Completed TODOs ✅

1. ✅ **PR #345 conflicts** - Resolved and pushed
2. ✅ **PR #368 conflicts** - Resolved and merged
3. ✅ **Sandbox check false positive** - Fixed
4. ✅ **LPE ACL security verification** - Verified
5. ✅ **Mary dispatcher dependency verification** - Verified

## Pending TODOs ⏳

### High Priority (Conflicts/Blocking)

1. ⏳ **PR #328 conflicts** - History tab feature
   - Status: CONFLICTING
   - Files: `apps/dashboard/dashboard.js`, `apps/dashboard/index.html`
   - Action: Resolve conflicts with main (PR #368 features)

2. ⏳ **PR #336 conflicts** - Linking functionality
   - Status: CONFLICTING
   - Files: `apps/dashboard/dashboard.js`, `apps/dashboard/index.html`
   - Action: Resolve conflicts with main

3. ⏳ **PR #358 conflicts** - Phase 3 Completion
   - Status: Check required
   - Action: Rebase, remove noise, resolve conflicts

4. ⏳ **PR #360 conflicts** - LPE Worker & Filesystem Bridge
   - Status: Check required
   - Action: Restore LPE path ACL security (CRITICAL)

5. ⏳ **PR #361 conflicts** - LPE CLI & SIP Helper
   - Status: Check required
   - Action: Sync CLI/worker interface after #360

6. ⏳ **PR #363 conflicts** - LPE Wiring & Smoke Tests
   - Status: Check required
   - Action: Fix ACL, PyYAML guard, MLS schema (3 critical issues)

### Medium Priority (SOT Definitions)

7. ⏳ **Define SOT for LPE worker** - Path ACL + allow list on main
   - Action: Document current implementation as SOT

8. ⏳ **Define SOT for Mary dispatcher** - Dependency guards on main
   - Action: Document current implementation as SOT

9. ⏳ **Define SOT for MLS ledger schema** - Match existing JSONL
   - Action: Document current schema as SOT

### Low Priority (Cleanup)

10. ⏳ **Legacy branch cleanup** - Close/archive `launchagent-fix-from-main`
    - Action: Check if still needed, close if obsolete

## Recommended Order

1. **PR #328** - Dashboard conflicts (similar to #345, should be quick)
2. **PR #336** - Dashboard conflicts (similar to #345, should be quick)
3. **PR #360** - LPE ACL security (CRITICAL)
4. **PR #363** - Three critical issues (ACL, PyYAML, MLS)
5. **PR #361** - After #360 (depends on it)
6. **PR #358** - After others (remove noise, rebase)
7. **SOT Definitions** - Document current state
8. **Legacy cleanup** - Final cleanup

## Notes

- PR #328 and #336 are similar to #345 (dashboard conflicts) - should be straightforward
- PR #360, #361, #363 are related to LPE security - need careful handling
- SOT definitions are documentation tasks - lower priority but important for future work

