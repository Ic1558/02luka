# Task Completion Report Template
**Purpose:** Standard end-of-task audit trail with telemetry tracking  
**Usage:** Create report after completing each major task

---

## 📋 Task Summary

**Task Name:** [Task Name]  
**Date:** [YYYY-MM-DD]  
**Agent:** [CLS/CLC/Gemini/etc.]  
**Status:** [✅ Complete / ⚠️ Partial / ❌ Failed]

---

## 📊 Tasks Completed

### Task 1: [Task Name]
**Status:** ✅ Complete  
**Commits:** [commit hashes]
**Key Achievements:**
- [Achievement 1]
- [Achievement 2]

---

## 📊 Telemetry & Tracking

### Git Commits
```
[Use: git log --oneline --since="YYYY-MM-DD 00:00:00"]
```

### Telemetry Auto-Tracking

**Check telemetry files:**
```bash
# Save sessions
tail -3 g/telemetry/save_sessions.jsonl

# Other telemetry
ls -lt g/telemetry/*.jsonl | head -5
```

**Telemetry Sources:**
- `g/telemetry/save_sessions.jsonl` - Save session logs
- `g/telemetry/cls_*.jsonl` - CLS-specific logs
- `g/telemetry/gateway_v3_router.log` - Gateway logs
- `g/reports/pr11_healthcheck/*.json` - PR-11 monitoring snapshots

**Session Files:**
- `g/reports/sessions/session_YYYYMMDD_*.md` - Full session logs
- `g/reports/sessions/session_YYYYMMDD.ai.json` - AI summaries

---

## 🔍 Verification Evidence

### Tests/Checks
- [ ] Test 1: [Result]
- [ ] Test 2: [Result]
- [ ] Guard checks: [Result]

### System Health
- [ ] Processes: [Status]
- [ ] Errors: [Count]
- [ ] Monitoring: [Status]

---

## 📁 Files Modified/Created

### Created
- [File 1]
- [File 2]

### Modified
- [File 1]
- [File 2]

---

## 🎯 Key Learnings

1. [Learning 1]
2. [Learning 2]

---

## ✅ Completion Checklist

- [ ] All tasks completed
- [ ] All commits pushed
- [ ] Tags created (if applicable)
- [ ] Telemetry checked
- [ ] Report created
- [ ] Documentation updated

---

## 🔄 Next Steps

1. [Next step 1]
2. [Next step 2]

---

**Report Generated:** [Timestamp]  
**Telemetry Verified:** [Yes/No]
