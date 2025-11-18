# PR #328 Conflict Analysis

**Date:** 2025-11-18  
**PR:** #328 - Add dashboard WO history timeline view  
**Status:** CONFLICTING  
**Files with conflicts:** 2
- `apps/dashboard/dashboard.js` (18 conflict markers)
- `apps/dashboard/index.html` (9 conflict markers)

## Summary

PR #328 adds a **History tab** to the dashboard showing a grouped timeline of work orders. This is a front-end only change that conflicts with recent changes in `main` (likely from PR #368 which added pipeline metrics and timeline features).

## Conflict Analysis

### Root Cause

1. **PR #368** merged pipeline metrics and timeline features into `main`
2. **PR #328** adds a separate "History" tab feature
3. Both PRs modify the same dashboard files (`dashboard.js` and `index.html`)
4. PR #328 was created before PR #368 merged, causing conflicts

### Files Affected

#### `apps/dashboard/dashboard.js`
- **18 conflict markers** across multiple sections:
  - Variable declarations (autorefresh, tabs)
  - Tab initialization
  - WO loading/fetching logic
  - Rendering functions
  - Event handlers

#### `apps/dashboard/index.html`
- **9 conflict markers** in:
  - Tab navigation structure
  - Tab panel definitions
  - CSS styles

## Resolution Strategy

### Approach: Merge Both Features

Since both features are **additive** and serve different purposes:
- **PR #368**: Pipeline metrics + timeline view (operational metrics)
- **PR #328**: History tab (historical WO timeline)

**Strategy:**
1. Accept `main`'s version as base (PR #368 features)
2. Add PR #328's History tab features on top
3. Ensure both features coexist without conflicts
4. Test that both tabs work independently

### Steps

1. **Resolve `dashboard.js`:**
   - Keep `main`'s autorefresh, tab initialization
   - Add PR #328's `loadWoHistory()`, `renderWoHistoryTimeline()` functions
   - Add PR #328's helper functions (`toLocalDateString`, `computeDurationMs`, etc.)
   - Merge tab switching logic to support both tabs

2. **Resolve `index.html`:**
   - Keep `main`'s tab structure
   - Add PR #328's History tab button and panel
   - Merge CSS styles (no conflicts expected, just additions)

3. **Verify:**
   - Both tabs render correctly
   - No JavaScript errors
   - Timeline and History tabs work independently

## Risk Assessment

- **Low Risk:** Both features are front-end only, no backend changes
- **Additive:** History tab is independent of pipeline metrics
- **Testing:** Manual QA required to verify both tabs work

## Next Steps

1. Resolve conflicts manually (accept main + add PR #328 features)
2. Test in dev environment
3. Create PR or update PR #328 branch
4. Verify CI passes

