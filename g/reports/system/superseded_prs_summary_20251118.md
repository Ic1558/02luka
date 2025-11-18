# Superseded PRs Summary

**Date:** 2025-11-18  
**Status:** Reviewing open PRs for duplicates/superseded

---

## Summary

Found **1 likely superseded PR**: #310

---

## Superseded PRs

### ✅ PR #349 - CLOSED
- **Title:** Add WO timeline/history view to dashboard
- **Status:** CLOSED (2025-11-18T19:55:40Z)
- **Reason:** Superseded by PR #328
- **Action:** ✅ Already closed

### ⚠️ PR #310 - LIKELY SUPERSEDED
- **Title:** Add WO timeline/history view in dashboard
- **Status:** OPEN, CONFLICTING
- **Created:** 2025-11-15T22:36:58Z
- **Head Branch:** `codex/add-wo-timeline-and-history-view`

**Analysis:**
- PR #310 description matches functionality already in main:
  - `_build_wo_timeline()` function exists in `g/apps/dashboard/api_server.py`
  - Timeline rendering in dashboard.js
  - `timeline=1` query parameter support

**Merged PRs with similar functionality:**
1. **PR #326** (merged 2025-11-17): "feat(dashboard): add WO timeline/history view"
2. **PR #328** (merged 2025-11-18): "Add dashboard WO history timeline view"

**Git history shows:**
- Commits from PR #310 were merged via PR #326:
  - `419049474 merge: Resolve conflicts with main for PR #310`
  - `987b97647 docs(pr310): Add cleanup completion documentation`
  - `b0cc5d7d0 feat(pr310): Restore and improve timeline functionality`

**Recommendation:**
- PR #310's functionality was already merged via PR #326
- PR #310 is now CONFLICTING and duplicates existing features
- **Action:** Close PR #310 as superseded by PR #326 and #328

---

## Other Open PRs Checked

### PR #306 - Include filters in trading snapshot filenames
- **Status:** OPEN, mergeable UNKNOWN
- **Analysis:** Different feature (trading snapshot naming), not superseded

### PR #368 - feat(dashboard): integrate PR #298 features
- **Status:** OPEN, mergeable UNKNOWN
- **Analysis:** Different feature (PR #298 migration), not superseded

---

## Action Items

1. ✅ PR #349 - Already closed
2. ⏳ PR #310 - **Needs closure** (superseded by PR #326/#328)
3. ✅ Other PRs - Not superseded

---

## Next Steps

1. Review PR #310 to confirm duplicate functionality
2. Close PR #310 with message referencing PR #326 and #328
3. Document closure in code review report

---

**Status:** 1 PR needs closure (PR #310)  
**Confidence:** High (PR #310's commits were merged via PR #326)

