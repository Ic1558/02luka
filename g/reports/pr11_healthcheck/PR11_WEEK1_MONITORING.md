# PR-11 Week 1 Stability Window Monitoring
**Start Date:** 2025-12-14 (Day 4)  
**End Date:** 2025-12-20 (Day 10)  
**Duration:** 7 days  
**Status:** 🟢 Active

---

## 📋 Daily Checklist

### Each Day (Day 4 → Day 10)

**Command:**
```bash
cd ~/02luka
zsh tools/pr11_snapshot_daily.zsh
```

**Expected Result:**
- ✅ Guard check passes
- ✅ Snapshot created (valid JSON)
- ✅ Process counts: gateway=1, mary=1
- ✅ Committed with `pr11(dayN): monitoring snapshot evidence`
- ✅ Pushed to remote

**If duplicate detected:**
- Script will exit with error (sanity check working)
- Use `--force` only for incidents/reruns

---

## 🔍 Monitoring Signals (Minimum)

### 1. Process Health
- **gateway_v3_router.py:** Must be 1 process
- **mary.py:** Must be 1 process
- **Action if different:** Investigate immediately

### 2. JSON Integrity
- **Check:** `python3 -m json.tool g/reports/pr11_healthcheck/*.json`
- **Action if invalid:** Use `--force` to rerun

### 3. Workspace Guard
- **Check:** `zsh tools/guard_workspace_inside_repo.zsh`
- **Must pass:** All paths are symlinks
- **Action if fails:** Run `zsh tools/bootstrap_workspace.zsh`

### 4. Duplicate Prevention
- **Check:** Script blocks duplicates automatically
- **Action if needed:** Use `--force` for reruns (adds `[rerun]` marker)

---

## 📊 Daily Log

| Day | Date | Snapshot | Commit | Status | Notes |
|-----|------|----------|--------|--------|-------|
| 4 | 2025-12-14 | - | fb5b5401 | ✅ | Baseline (before monitoring) |
| 5 | 2025-12-15 | - | - | ⏳ | - |
| 6 | 2025-12-16 | - | - | ⏳ | - |
| 7 | 2025-12-17 | - | - | ⏳ | - |
| 8 | 2025-12-18 | - | - | ⏳ | - |
| 9 | 2025-12-19 | - | - | ⏳ | - |
| 10 | 2025-12-20 | - | - | ⏳ | - |

**Status Legend:**
- ✅ Complete
- ⏳ Pending
- ⚠️ Incident (rerun)
- ❌ Failed

---

## 🚨 Incident Log

**If rerun needed:**
```bash
cd ~/02luka
zsh tools/pr11_snapshot_daily.zsh --force
```

**Document incidents here:**
- Date: [YYYY-MM-DD]
- Reason: [Why rerun was needed]
- Commit: [hash]
- Resolution: [What was fixed]

---

## 📈 Week 1 Summary (After Day 10)

**To be completed after Day 10:**

### Results
- [ ] **Pass/Fail:** [Pass / Fail]
- [ ] **Total Snapshots:** [count]
- [ ] **Incidents:** [count]
- [ ] **Reruns:** [count]

### Key Metrics
- Process stability: [gateway/mary counts consistent?]
- JSON validity: [all snapshots valid?]
- Guard checks: [all passed?]
- Duplicate prevention: [sanity check worked?]

### Issues Found
- [List any issues encountered]

### Next Steps
- [ ] If clean → Freeze subsystem, move to next production lane
- [ ] If issues → Document and address before proceeding

---

**Last Updated:** 2025-12-14  
**Next Snapshot:** Day 5 (2025-12-15)
