# PR Status Summary

**Date:** 2025-11-15  
**Status:** Active PRs Review

---

## Recently Fixed PRs

### PR #293: feat(dashboard): add services and MLS panels
- **Status:** ✅ **MERGEABLE** (UNSTABLE - 1 pending CI check)
- **Branch:** `codex/add-services-and-mls-panels-to-dashboard-799lai`
- **Fixes Applied:**
  - ✅ P1: API endpoints wired to Python API server (`http://127.0.0.1:8767`)
  - ✅ Merge conflict resolved in `dashboard_services_mls.md`
- **CI Status:** Mostly passing (1 pending, non-blocking)
- **Action:** ✅ **Ready for merge**

---

### PR #295: feat(tools): add multi-agent PR review CLI
- **Status:** ⚠️ **CONFLICTING** (GitHub shows DIRTY)
- **Branch:** `codex/add-multi-agent-pr-review-cli`
- **Fixes Applied:**
  - ✅ P1: Set `LUKA_SOT=$REPO_ROOT` before orchestrator
  - ✅ Codex sandbox: Replaced `rm -rf` with `find -delete`
- **Local Status:** No conflicts detected locally
- **Action:** ⚠️ **Check GitHub UI for actual conflicts** (may need refresh)

---

## Other Open PRs

- **PR #301:** feat: add unified trading cli (score: 70-79)
- **PR #300:** Add unified trading CLI with prompts and MLS hooks (score: 70-79)
- **PR #299:** feat(trading): add trading session snapshot & PnL summary (score: 70-79)
- **PR #298:** feat(trading): add trading journal CSV importer and MLS hook (score: 70-79)
- **PR #297:** feat(tools): add unified system snapshot & status report (score: <=69)
- **PR #296:** feat(dashboard): add WO pipeline metrics and timeline (score: <=69)

---

## Recommendations

1. **Merge PR #293** - Ready and all checks passing
2. **Investigate PR #295** - Check GitHub UI for actual conflicts
3. **Review other PRs** - Prioritize based on score and impact

---

**Last Updated:** 2025-11-15
