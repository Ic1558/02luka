# Performance Monitoring Setup - 2025-12-09

**Status:** ✅ Automated Setup Complete

---

## 📋 What Was Created

### 1. Collection Script
**File:** `tools/perf_collect_daily.zsh`
- Collects RAM usage for Cursor and Antigravity
- Auto-appends to observation log
- Detects which day (1, 2, or 3) based on start date
- Handles processes not running gracefully

### 2. Validation Script
**File:** `tools/perf_validate_3day.zsh`
- Analyzes 3 days of collected data
- Generates summary report
- Calculates trends and validates against targets
- Only runs after 3 days have passed

### 3. LaunchAgent
**File:** `Library/LaunchAgents/com.02luka.perf-collect-daily.plist`
- Runs automatically twice daily:
  - 10:00 AM
  - 2:00 PM
- Logs to `logs/perf_collect_daily.stdout.log`

### 4. Setup Script
**File:** `tools/setup_perf_monitoring.zsh`
- One-command installation
- Loads LaunchAgent
- Validates setup

---

## 🚀 Usage

### Initial Setup (Already Done)
```bash
~/02luka/tools/setup_perf_monitoring.zsh
```

### Manual Collection (If Needed)
```bash
~/02luka/tools/perf_collect_daily.zsh
```

### Validation (After 3 Days)
```bash
~/02luka/tools/perf_validate_3day.zsh
```

---

## 📊 What Gets Collected

**Automated (Twice Daily):**
- RAM usage for Cursor (GB)
- RAM usage for Antigravity (GB)
- Total RAM usage
- Process status (running/not running)
- Timestamp

**Manual (You Fill In):**
- Feel rating (1-10)
- Context (what you're doing)
- Day summary checkboxes (freezes, crashes, etc.)
- Notes

---

## 📅 Schedule

**Start Date:** 2025-12-09  
**End Date:** 2025-12-11 (3 days)

**Collection Times:**
- Day 1: 2025-12-09 (10:00 AM, 2:00 PM)
- Day 2: 2025-12-10 (10:00 AM, 2:00 PM)
- Day 3: 2025-12-11 (10:00 AM, 2:00 PM)

**Validation:**
- Run `perf_validate_3day.zsh` after Day 3 completes

---

## 📁 Files

**Data:**
- `g/logs/perf_observation_log.md` - Main observation log

**Logs:**
- `logs/perf_collect_daily.stdout.log` - Collection output
- `logs/perf_collect_daily.stderr.log` - Errors

**Reports:**
- `g/reports/system/perf_validation_summary_YYYYMMDD.md` - Generated after validation

---

## 🔍 Monitoring

**Check LaunchAgent Status:**
```bash
launchctl list | grep perf-collect
```

**View Recent Collections:**
```bash
tail -20 ~/02luka/logs/perf_collect_daily.stdout.log
```

**View Observation Log:**
```bash
cat ~/02luka/g/logs/perf_observation_log.md
```

---

## 🛑 Management

**Stop Monitoring:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.perf-collect-daily.plist
```

**Restart Monitoring:**
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.perf-collect-daily.plist && \
launchctl load ~/Library/LaunchAgents/com.02luka.perf-collect-daily.plist
```

---

## ✅ Verification

**Test Collection (Just Run):**
```bash
~/02luka/tools/perf_collect_daily.zsh
```

**Expected Output:**
```
✅ Performance data collected:
   Time: HH:MM
   Cursor: X.XX GB ✅/❌
   Antigravity: X.XX GB ✅/❌
   Total: X.XX GB
   → Appended to Day N
```

---

## 📝 Next Steps

1. **Let it run automatically** - No action needed, data will be collected twice daily
2. **Fill in manual fields** - When you have time, add "Feel" ratings and context notes
3. **After Day 3** - Run validation script to generate summary
4. **Review summary** - Decide if workspace tuning was successful
5. **Proceed to P1** - If validation passes, move to HOWTO_TWO_WORLDS.md

---

**Setup Complete!** The system will now automatically collect performance data twice daily for 3 days.
