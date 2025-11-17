# PR #336 Conflict Analysis

**Date:** 2025-11-18  
**PR:** #336 - Link WO timeline and MLS lessons to detail view  
**Status:** CONFLICTING  
**Files with conflicts:** 2
- `apps/dashboard/dashboard.js` (9 conflict markers)
- `apps/dashboard/index.html` (9 conflict markers)

## Summary

PR #336 adds linking functionality to connect WO timeline and MLS lessons to a detail view. This is a front-end only change that conflicts with recent changes in `main` (likely from PR #368 which added pipeline metrics and timeline features, and possibly PR #328 which adds History tab).

## Conflict Analysis

### Root Cause

1. **PR #368** merged pipeline metrics and timeline features into `main`
2. **PR #328** adds History tab (currently being resolved)
3. **PR #336** adds linking functionality for WO timeline and MLS lessons
4. All three PRs modify the same dashboard files (`dashboard.js` and `index.html`)
5. PR #336 was created before PR #368 merged, causing conflicts

### Files Affected

#### `apps/dashboard/dashboard.js`
- **9 conflict markers** in:
  - `openWoDetail` function implementation
  - MLS card rendering with linking
  - WO timeline rendering with click handlers
  - Event handlers

#### `apps/dashboard/index.html`
- **9 conflict markers** in:
  - CSS styles for clickable elements
  - HTML structure for detail views

## Resolution Strategy

### Approach: Merge All Features

Since all features are **additive** and serve different purposes:
- **PR #368**: Pipeline metrics + timeline view (operational metrics)
- **PR #328**: History tab (historical WO timeline)
- **PR #336**: Linking functionality (navigation between views)

**Strategy:**
1. Accept `main`'s version as base (PR #368 features)
2. Add PR #336's linking functionality on top
3. Ensure all features coexist without conflicts
4. Test that linking works across all views

### Steps

1. **Resolve `dashboard.js`:**
   - Keep `main`'s existing functions
   - Add PR #336's `openWoDetail()` helper function
   - Add click handlers to WO timeline items
   - Add click handlers to MLS lesson cards
   - Wire up `wo:select` event dispatching

2. **Resolve `index.html`:**
   - Keep `main`'s HTML structure
   - Add PR #336's CSS for clickable elements (cursor: pointer, hover states)
   - Ensure detail view panel exists

3. **Verify:**
   - WO timeline items are clickable
   - MLS lesson cards are clickable
   - Clicking opens detail view
   - All existing features still work

## Risk Assessment

- **Low Risk:** All features are front-end only, no backend changes
- **Additive:** Linking functionality is independent of other features
- **Testing:** Manual QA required to verify linking works across all views

## Dependencies

- **PR #328** should be resolved first (if not already)
- **PR #368** already merged to main (base)

## Next Steps

1. Wait for PR #328 resolution (if in progress)
2. Resolve PR #336 conflicts (add linking on top of main)
3. Test in dev environment
4. Update PR #336 branch or create new PR
5. Verify CI passes

