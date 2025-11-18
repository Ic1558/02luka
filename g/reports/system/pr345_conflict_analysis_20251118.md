# PR #345 Conflict Analysis

**Date:** 2025-11-18  
**PR:** #345 - Dashboard Global Health Summary Bar  
**Status:** CONFLICTING  
**Files with conflicts:** 2
- `apps/dashboard/dashboard.js` (conflict markers)
- `apps/dashboard/index.html` (conflict markers)

## Summary

PR #345 adds a **global "System Health" bar** at the top of the dashboard that summarizes:
- Work Orders: total / active / failed
- Services: total / running / failed

The bar changes visual state (green/yellow/red) based on failures or stopped services. This is a front-end only change that conflicts with recent changes in `main` (likely from PR #368, PR #328, and PR #336).

## Conflict Analysis

### Root Cause

1. **PR #368** merged pipeline metrics and timeline features into `main`
2. **PR #328** adds History tab (currently being resolved)
3. **PR #336** adds linking functionality (currently being resolved)
4. **PR #345** adds global health summary bar
5. All PRs modify the same dashboard files (`dashboard.js` and `index.html`)
6. PR #345 was created before other PRs merged, causing conflicts

### Files Affected

#### `apps/dashboard/dashboard.js`
- **Conflicts in:**
  - `updateSystemHealthBar()` function implementation
  - Calls to `updateSystemHealthBar()` in `loadWos()` and `loadServices()`
  - Summary refresh functions

#### `apps/dashboard/index.html`
- **Conflicts in:**
  - HTML structure for `#system-health-bar` section
  - CSS styles for health bar states (`.health-ok`, `.health-warn`, `.health-bad`)

## Resolution Strategy

### Approach: Merge All Features

Since all features are **additive** and serve different purposes:
- **PR #368**: Pipeline metrics + timeline view (operational metrics)
- **PR #328**: History tab (historical WO timeline)
- **PR #336**: Linking functionality (navigation between views)
- **PR #345**: Global health summary bar (system status overview)

**Strategy:**
1. Accept `main`'s version as base (PR #368 features)
2. Add PR #345's health bar functionality on top
3. Ensure all features coexist without conflicts
4. Test that health bar updates correctly

### Steps

1. **Resolve `dashboard.js`:**
   - Keep `main`'s existing functions
   - Add PR #345's `updateSystemHealthBar()` function
   - Add calls to `updateSystemHealthBar()` in:
     - `loadWos()` (after setting WOs)
     - `loadServices()` (after updating services)
     - `refreshSummaryWos()` (to fix Codex review feedback)
     - `refreshSummaryServices()` (if exists)
   - Ensure health bar reads from `allWos` and `serviceData`

2. **Resolve `index.html`:**
   - Keep `main`'s HTML structure
   - Add PR #345's `#system-health-bar` section at the top of `<main>`
   - Add CSS styles for:
     - `.health-pill` (WO and Services count pills)
     - `.health-ok` (green state)
     - `.health-warn` (yellow state)
     - `.health-bad` (red state)

3. **Verify:**
   - Health bar appears at top of dashboard
   - Updates when WOs or services change
   - Shows correct counts and states
   - All existing features still work

## Codex Review Feedback

PR #345 received Codex review feedback:
- **P1 Badge:** Refresh health bar when WO summary poll updates
- Issue: `refreshSummaryWos` doesn't update `allWos` or call `updateSystemHealthBar()`
- Fix: Mirror `refreshSummaryServices` behavior by storing fetched list and triggering bar update

This should be addressed during conflict resolution.

## Risk Assessment

- **Low Risk:** All features are front-end only, no backend changes
- **Additive:** Health bar is independent of other features
- **Testing:** Manual QA required to verify health bar updates correctly

## Dependencies

- **PR #328** should be resolved first (if not already)
- **PR #336** should be resolved first (if not already)
- **PR #368** already merged to main (base)

## Next Steps

1. Wait for PR #328 and PR #336 resolution (if in progress)
2. Resolve PR #345 conflicts (add health bar on top of main)
3. Address Codex review feedback (refresh health bar from summary WOs)
4. Test in dev environment
5. Update PR #345 branch or create new PR
6. Verify CI passes

