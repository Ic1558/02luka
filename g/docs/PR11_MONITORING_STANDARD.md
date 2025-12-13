# PR-11 Monitoring Standard
**Status:** Active  
**Date:** 2025-12-14  
**Purpose:** Standardized daily monitoring workflow for PR-11 stability window

---

## 📋 Standard Rules

### Rule 1: Snapshot Storage
- **Location:** `g/reports/pr11_healthcheck/` (evidence/audit trail)
- **Naming:** `YYYY-MM-DDTHHMMSS.json` (ISO timestamp)
- **Frequency:** 1 snapshot per day (committed to git)
- **Purpose:** Audit trail and evidence for stability tracking

### Rule 2: Runtime State vs Evidence
- **Evidence (Tracked):** Daily snapshots in `g/reports/pr11_healthcheck/*.json`
- **Runtime State (Ignored):** Cache files like `.seen_runs` (already in `.gitignore`)

**Clear Separation:**
- Evidence = Tracked in git (audit trail)
- Runtime = Ignored (temporary state)

---

## 🔄 Daily Workflow (Day 1+)

### Manual Workflow (3 Commands)

```bash
cd ~/02luka

# 1. Generate snapshot
zsh tools/monitor_v5_production.zsh json | tee "g/reports/pr11_healthcheck/$(date +%F)T$(date +%H%M%S).json"

# 2. Commit evidence
git add g/reports/pr11_healthcheck/*.json
git commit -m "pr11(dayN): monitoring snapshot evidence"

# 3. Push
git pull --rebase && git push
```

### Automated Workflow (Atomic Command)

**Script:** `tools/pr11_snapshot_daily.zsh`

**Usage:**
```bash
cd ~/02luka
zsh tools/pr11_snapshot_daily.zsh
```

**What it does:**
1. Runs guard check (must pass)
2. Generates snapshot
3. Adds to git
4. Commits with standardized message
5. Pulls and pushes (with guard check)

---

## 📁 Directory Structure

**Current (Day 0):**
```
g/reports/pr11_healthcheck/
  ├── 2025-12-14T03:47:55.json
  ├── 2025-12-14T042256.json
  └── 2025-12-14T043010.json
```

**Standard (Day 1+):**
- 1 snapshot per day (committed)
- All snapshots tracked in git (evidence)
- Runtime state files ignored

---

## ✅ Verification

**After each snapshot:**
- [ ] Snapshot file created
- [ ] Guard checks passed
- [ ] Committed to git
- [ ] Pushed to remote
- [ ] Process counts verified (gateway_v3_router.py: 1, mary.py: 1)

---

## 🎯 Success Criteria

**PR-11 Monitoring is working when:**
- Daily snapshots are created
- All snapshots are committed (evidence trail)
- No runtime state files are tracked
- Guard checks pass before each commit
- Process health is verified

---

**Last Updated:** 2025-12-14
