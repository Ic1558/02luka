# MLS Ledger - Primary Memory Layer
**Date:** 2025-11-13  
**Status:** ✅ CLARIFIED  
**Priority:** 🔴 CRITICAL - This is the ACTUAL working memory

---

## Key Understanding

### The Reality

**MLS Lessons** (`g/knowledge/mls_lessons.jsonl`):
- ❌ **Wasn't being used in reality**
- Concept was good, but not practical
- Not the actual working memory

**MLS Ledger** (`mls/ledger/YYYY-MM-DD.jsonl`):
- ✅ **This is the 2nd memory layer that was created**
- ✅ **This is what's ACTUALLY being used**
- ✅ **This is the REAL core brain and memory**
- ✅ **Everything must be recorded HERE**

**MLS Status** (`mls/status/`):
- ✅ Part of the working layer
- Status summaries and tracking files
- Also actively used

---

## Why Ledger Was Created

The user created the **Ledger as a 2nd memory layer** because:
1. MLS Lessons concept was good but **wasn't being used**
2. Needed a **practical, working memory system**
3. Ledger provides **daily append-only audit trail**
4. Ledger is **actually being used** by CI/CD and systems
5. Ledger is **the real core brain**

---

## Recording Strategy

### ✅ PRIMARY TARGET: MLS Ledger
- **Always record to:** `mls/ledger/YYYY-MM-DD.jsonl`
- **Use:** `mls_add.zsh` or `mls_auto_record.zsh`
- **This is the working memory**

### ⚠️ SECONDARY: MLS Lessons (Optional)
- **Only if needed:** `g/knowledge/mls_lessons.jsonl`
- **Use:** `mls_capture.zsh`
- **Not the primary target**

### ✅ ALSO RECORD: MLS Status
- **Status summaries:** `mls/status/YYYYMMDD_ci_cls_codex_summary.*`
- **Tracking files:** `mls/status/mls_validation_streak.json`
- **Part of working layer**

---

## Tools

### Primary Tool: `mls_auto_record.zsh`
**Records to LEDGER (the actual working memory):**
```bash
~/02luka/tools/mls_auto_record.zsh <type> <title> <summary> [tags] [wo_id]
```

**Examples:**
```bash
# Record todo to LEDGER
mls_auto_record.zsh todo "Fix bug" "Fixed CI pipeline" "ci,bug"

# Record deployment to LEDGER
mls_auto_record.zsh deployment "Deploy v1.2.3" "Deployed features" "deploy"

# Record debugging to LEDGER
mls_auto_record.zsh debug "Debug Redis" "Fixed timeout" "redis,debug"
```

### Direct Tool: `mls_add.zsh`
**Records directly to LEDGER:**
```bash
~/02luka/tools/mls_add.zsh \
  --type solution \
  --title "Title" \
  --summary "Summary" \
  --producer clc \
  --context local \
  --tags "tag1,tag2" \
  --author gg \
  --confidence 0.9
```

---

## What Gets Recorded to Ledger

### All Activities:
- ✅ todos
- ✅ pendings
- ✅ followups
- ✅ reminders
- ✅ failures
- ✅ learning
- ✅ lessons
- ✅ deployments
- ✅ debugging
- ✅ work activities
- ✅ solutions
- ✅ improvements
- ✅ patterns
- ✅ antipatterns

### Everything goes to LEDGER because:
- **Ledger is the actual working memory**
- **Ledger is what's being used**
- **Ledger is the core brain**
- **Nothing should be lost**

---

## Verification

### Check Ledger (the actual memory):
```bash
# View today's ledger entries
cat ~/02luka/mls/ledger/$(date +%Y-%m-%d).jsonl | jq -r '.title, .type, .tags'

# Count entries
wc -l ~/02luka/mls/ledger/$(date +%Y-%m-%d).jsonl

# Search ledger
cat ~/02luka/mls/ledger/$(date +%Y-%m-%d).jsonl | jq -r 'select(.tags[] | contains("todo")) | .title'
```

### Check Status Files:
```bash
# View status summary
cat ~/02luka/mls/status/$(date +%Y%m%d)_ci_cls_codex_summary.json | jq .

# View validation streak
cat ~/02luka/mls/status/mls_validation_streak.json | jq .
```

---

## Best Practices

### 1. Always Record to Ledger
- ✅ Use `mls_auto_record.zsh` for all activities
- ✅ Record todos, deployments, debugging, etc.
- ✅ Ledger is the primary target

### 2. Don't Rely on Lessons
- ⚠️ Lessons weren't being used
- ⚠️ Ledger is what matters
- ✅ Focus on Ledger recording

### 3. Include Context
- ✅ Add tags for categorization
- ✅ Include WO ID if applicable
- ✅ Include component/system names

### 4. Regular Recording
- ✅ Record activities immediately
- ✅ Don't wait - record as you work
- ✅ Ensure nothing is missed

---

## Summary

**The Reality:**
- MLS Lessons: Concept good, **wasn't used in reality**
- MLS Ledger: **2nd layer created, THIS IS WHAT'S USED**
- MLS Status: **Part of working layer**

**The Strategy:**
- ✅ **Record everything to LEDGER** (the actual working memory)
- ✅ **Ledger is the core brain**
- ✅ **Nothing should be lost**
- ✅ **Ledger is what matters**

---

**Status:** ✅ CLARIFIED  
**Last Updated:** 2025-11-13  
**Critical:** LEDGER is the actual working memory - record everything there!
