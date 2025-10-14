---
project: system-stabilization
tags: [ops,tasks,pending,user-action]
---

# Outstanding Tasks & Next Steps

**Date:** 2025-10-10 00:52
**Session Review:** Post-ops menu implementation

## ✅ Completed This Session

### Critical Work Done
1. ✅ **MCP Configuration Fixed** (all 8 servers operational)
2. ✅ **Excel File Recovered** (25Q_08SOL_02.xlsx with AutoRecovered versions)
3. ✅ **PR #58 Merged** (Batch #2: Option C v2.0)
4. ✅ **CI Fixed** (bash compatibility in Makefile)
5. ✅ **All 5 Ops Menu Options Implemented**

### Ops Menu Completed
- ✅ Option 1: Project backfill
- ✅ Option 2: CI alerts (already active)
- ✅ Option 3: Retention & hygiene
- ✅ Option 4: Agents spine
- ✅ Option 5: Boss daily HTML

**Total:** 6 commits pushed, 22+ files created, 3 workflows active

---

## 📋 Outstanding Tasks (User Action Required)

### 🔴 High Priority

**1. Configure Alert Webhooks** (5 minutes)
- **Why:** Enable Slack/Teams notifications for CI failures
- **Status:** Workflows ready, secrets missing
- **Action:**
  ```bash
  # Option A: Slack
  gh secret set SLACK_WEBHOOK_URL
  # Paste: https://hooks.slack.com/services/YOUR/WEBHOOK/URL

  # Option B: Teams
  gh secret set TEAMS_WEBHOOK_URL
  # Paste: https://YOUR.webhook.office.com/...
  ```
- **Verification:**
  ```bash
  gh secret list | grep WEBHOOK
  ```
- **Benefit:** Instant notifications when Daily Proof fails

---

### 🟡 Medium Priority

**2. Customize Agent READMEs** (15-30 minutes)
- **Why:** Document actual agent responsibilities
- **Status:** Template structure created, needs customization
- **Files:** `agents/{clc,gg,gc,mary,paula,codex,boss}/README.md`
- **Action:** Replace `(fill key responsibilities)` with actual scope
- **Example for CLC:**
  ```markdown
  ## Scope
  - Execute user requests via Claude Code
  - Generate reports and documentation
  - Manage system operations and maintenance
  - Coordinate with other agents
  - Handle ops menu implementations
  ```

**3. Add More Project Keywords** (5-10 minutes)
- **Why:** Improve project grouping in boss catalogs
- **Status:** 3 projects defined, can add more
- **File:** `config/project_keywords.tsv`
- **Action:** Add rows for new projects
  ```
  project-name	keyword1|keyword2|keyword3
  ```
- **Then run:**
  ```bash
  ./scripts/backfill_project_by_keywords.sh
  ```

**4. Review and Merge/Close Old PRs** (30-60 minutes)
- **Why:** 29 open PRs from previous work
- **Status:** Created by codex agent, need review
- **Action:**
  ```bash
  gh pr list --state open
  # Review each PR and either:
  # - Merge if still relevant: gh pr merge <number>
  # - Close if outdated: gh pr close <number>
  ```
- **Note:** These are NOT from this session

---

### 🟢 Low Priority (Optional)

**5. Enhance Daily HTML Dashboard**
- Add dark mode toggle
- Add search/filter functionality
- Add project grouping
- Add date range selector
- Auto-refresh capability

**6. Integrate boss-daily into Workflows**
- Add to GitHub Actions
- Deploy to GitHub Pages
- Schedule automatic updates

**7. Create boss_refresh.sh Script**
- Currently missing (Makefile references it)
- Should run boss-daily automatically
- Regenerate catalogs

**8. Add More Retention Targets**
- Clean old proof MOVEPLAN files
- Clean old test artifacts
- Clean old deployment logs

---

## ⚠️ Known Issues (None Critical)

### Missing Scripts
**Issue:** `boss_refresh.sh` referenced but doesn't exist
- **Impact:** Low (boss-daily works independently)
- **Workaround:** Run `make boss-daily` directly
- **Fix:** Create script or remove Makefile reference

**Status:** Non-blocking, system fully functional

---

## 🎯 Recommended Immediate Actions

**Do this now (5 minutes):**
```bash
# 1. Add webhook for alerts
gh secret set SLACK_WEBHOOK_URL

# 2. Test daily dashboard
make boss-daily && open views/ops/daily/index.html

# 3. Verify all workflows active
gh workflow list --all
```

**Do this soon (30 minutes):**
```bash
# 1. Customize CLC agent README
vim agents/clc/README.md

# 2. Add 2-3 more project keywords
vim config/project_keywords.tsv
./scripts/backfill_project_by_keywords.sh

# 3. Review top 5 oldest PRs
gh pr list --state open | tail -5
```

**Do this later (as needed):**
- Review and close old PRs
- Enhance daily HTML dashboard
- Create boss_refresh.sh
- Add more retention targets

---

## 📊 System Health

**Current Status:**
```
✅ Git: Clean (no uncommitted changes)
✅ Main branch: Up to date with origin
✅ CI: All recent runs passing
✅ Workflows: 3 active (Daily Proof, Alerting, Retention)
✅ Files: 1311 total, 7 out-of-zone (0.5%)
✅ Latest proof: 251009_0653_proof.md
```

**Open PRs:** 29 (all pre-existing, not from this session)
**Uncommitted:** None
**Pending workflows:** None

---

## 🔄 Maintenance Schedule

**Daily (automated):**
- 08:12 ICT - Daily Proof validation
- 09:05 ICT - Retention cleanup

**Weekly (manual):**
- Run `make boss-daily` for fresh dashboard
- Check `gh run list` for workflow health
- Review new reports in `g/reports/`

**Monthly (manual):**
- Review and update project keywords
- Clean up old branches
- Review agent READMEs for updates

---

## 📝 Quick Reference

**Generate dashboard:**
```bash
make boss-daily && open views/ops/daily/index.html
```

**Check status:**
```bash
make status
```

**Clean old files:**
```bash
make tidy-retention
```

**Backfill projects:**
```bash
./scripts/backfill_project_by_keywords.sh
```

**List secrets:**
```bash
gh secret list
```

**View workflows:**
```bash
gh workflow list --all
gh run list --limit 5
```

---

## Summary

**Critical tasks:** 0
**High priority:** 1 (webhook configuration)
**Medium priority:** 3 (customization tasks)
**Low priority:** 4 (enhancements)

**Blocker:** None
**System status:** Fully operational ✅
**Ready for:** Production use

**Recommended:** Configure webhooks (5 min), then system is 100% complete.
