# Machine Learning System (MLS) - Complete Guide

**Status:** ✅ OPERATIONAL
**Version:** 1.0
**Created:** 2025-11-05

---

## 🎯 Overview

The **Machine Learning System (MLS)** is your system's self-learning component that automatically captures, organizes, and retrieves lessons learned from successes, failures, and patterns discovered during R&D work.

### What It Does

✅ **Auto-Captures Lessons** from WO executions
✅ **Organizes Knowledge** by type (solutions/failures/patterns)
✅ **Provides Search** across all captured lessons
✅ **Generates Reports** (HTML dashboards)
✅ **Integrates with R&D Autopilot** for decision-making

---

## 🚀 Quick Start

### Capture a Lesson

```bash
# Manual capture
~/02luka/tools/mls_capture.zsh solution \
  "Title of what worked" \
  "Description of the solution" \
  "Additional context or details"
```

### Search Lessons

```bash
# Search all lessons
~/02luka/tools/mls_search.zsh "keyword"

# Filter by type
~/02luka/tools/mls_search.zsh "sync" solution
~/02luka/tools/mls_search.zsh "conflict" failure

# List all of a type
~/02luka/tools/mls_search.zsh "" pattern
```

### Generate Report

```bash
# Create HTML report
~/02luka/tools/mls_report.zsh

# Open in browser
open ~/02luka/g/reports/mls_report_$(date +%Y%m%d).html
```

---

## 📚 Lesson Types

### 1. Solution
**When:** Something worked well and should be repeated

**Example:**
```bash
mls_capture.zsh solution \
  "Two-Phase GD Sync Deployment" \
  "Breaking deployment into phases reduces risk and allows rollback" \
  "Phase 1: baseline, Phase 2: enhancements"
```

### 2. Failure
**When:** Something didn't work (learn from it!)

**Example:**
```bash
mls_capture.zsh failure \
  "Direct Complex Merge" \
  "Merging 89GB + 6.5GB with different structures was too risky" \
  "Chose fresh start instead"
```

### 3. Pattern
**When:** Discovered a reusable approach

**Example:**
```bash
mls_capture.zsh pattern \
  "Archive with README Pattern" \
  "Always include README when archiving large files" \
  "Explains what, why, options, and review date"
```

### 4. Anti-Pattern
**When:** Found something to avoid

**Example:**
```bash
mls_capture.zsh antipattern \
  "Manual Conflict Resolution Only" \
  "Requiring manual review of every conflict doesn't scale" \
  "Use auto-resolve with manual review option instead"
```

### 5. Improvement
**When:** Enhanced existing system capability

**Example:**
```bash
mls_capture.zsh improvement \
  "Real-Time Monitoring Dashboard" \
  "Added live HTML dashboard for 41 services" \
  "http://127.0.0.1:8766 with 30s auto-refresh"
```

---

## 🔄 Auto-Capture Integration

### R&D Autopilot Hook

The MLS automatically captures lessons when WOs complete:

**Auto-captured events:**
- ✅ WO success → captures as `solution`
- ❌ WO failure → captures as `failure`
- 🔍 Novel patterns → captures as `pattern`
- ⚠️ Errors → captures as `antipattern`

**Hook location:**
```
~/02luka/tools/mls_auto_capture_hook.zsh
```

**Called by:**
- R&D autopilot after each WO execution
- Manual via: `mls_auto_capture_hook.zsh <wo_file> <result> [log]`

### Manual Trigger

Per your CLAUDE.md:
> "Always trigger and save to MLS when trigger learning, solutions that proved, failures"

Use `mls_capture.zsh` manually for:
- Insights not tied to WOs
- External lessons learned
- User observations
- System improvements

---

## 📂 File Structure

```
~/02luka/g/knowledge/
├── mls_lessons.jsonl       # All lessons (append-only)
└── mls_index.json          # Summary stats

~/02luka/g/reports/
└── mls_report_YYYYMMDD.html  # Daily reports

~/02luka/tools/
├── mls_capture.zsh          # Capture new lesson
├── mls_search.zsh           # Search lessons
├── mls_report.zsh           # Generate HTML report
└── mls_auto_capture_hook.zsh  # Auto-capture from WOs
```

---

## 🔍 Search Examples

### By Keyword
```bash
# Find all lessons mentioning "sync"
mls_search.zsh sync

# Find all lessons about "conflict"
mls_search.zsh conflict

# Find all lessons with "dashboard"
mls_search.zsh dashboard
```

### By Type
```bash
# All solutions
mls_search.zsh "" solution

# All failures (learn what didn't work)
mls_search.zsh "" failure

# All patterns (reusable approaches)
mls_search.zsh "" pattern
```

### Combined
```bash
# Solutions about "sync"
mls_search.zsh sync solution

# Failures involving "merge"
mls_search.zsh merge failure
```

---

## 📊 Reporting

### HTML Dashboard

**Generate:**
```bash
~/02luka/tools/mls_report.zsh
```

**Features:**
- Beautiful gradient UI
- Stats cards (total, by type)
- Color-coded lessons
- Grouped by type
- Responsive design

**Auto-generated includes:**
- Total lesson count
- Breakdown by type
- All lessons with full details
- Timestamps and IDs
- Related WOs and sessions

### Export Options

**JSON export:**
```bash
cat ~/02luka/g/knowledge/mls_lessons.jsonl | jq
```

**CSV export (custom):**
```bash
cat ~/02luka/g/knowledge/mls_lessons.jsonl | \
  jq -r '[.id, .type, .title, .timestamp] | @csv'
```

---

## 🤖 R&D Integration

### How Autopilot Uses MLS

1. **Before executing WO:** Check MLS for similar failures
2. **After WO success:** Auto-capture solution
3. **After WO failure:** Auto-capture failure + context
4. **Decision making:** Query MLS for patterns

### Notification Flow

```
WO Execution
    ↓
mls_auto_capture_hook.zsh
    ↓
Lesson captured in MLS
    ↓
Notification → R&D autopilot inbox
    ↓
R&D reviews lesson (future: auto-suggest improvements)
```

---

## 🎓 Best Practices

### When to Capture

✅ **DO capture:**
- New approaches that worked
- Failures with clear cause
- Discovered patterns
- System improvements
- Time-saving techniques

❌ **DON'T capture:**
- Routine operations (not lessons)
- Duplicate of existing lesson
- Obvious best practices

### Writing Good Lessons

**Title:** Clear, concise (5-10 words)
```
✅ "Two-Phase Deployment Reduces Risk"
❌ "We did a thing with phases and it worked"
```

**Description:** What/Why/How (1-3 sentences)
```
✅ "Breaking GD sync into 2 phases allowed Phase 1 to establish baseline while Phase 2 added features without risk. Enables rollback if Phase 2 fails."
❌ "It worked"
```

**Context:** Relevant details for reuse
```
✅ "Phase 1: fresh sync (21MB), Phase 2: two-way upgrade + conflict resolution"
❌ "stuff"
```

### Organizing Lessons

**Tag similar lessons:** (future enhancement)
- Add tags to group related lessons
- Example: `#sync`, `#mobile`, `#conflict-resolution`

**Verify lessons:** (future enhancement)
- Mark lessons as verified after reuse
- Increment usefulness score

**Archive old lessons:** (future enhancement)
- Move outdated lessons to archive
- Keep MLS database focused

---

## 📈 Current Stats (as of 2025-11-05)

```
Total Lessons: 5

By Type:
  - Solutions: 2
  - Failures: 1
  - Patterns: 1
  - Improvements: 1
  - Anti-patterns: 0
```

**Recent lessons:**
1. Two-Phase GD Sync Deployment (solution)
2. Archive with README Pattern (pattern)
3. Direct Complex Merge Approach (failure)
4. Automatic Conflict Resolution (solution)
5. Real-Time Monitoring Dashboard (improvement)

---

## 🛠️ Advanced Usage

### Batch Import

Import lessons from file:
```bash
while IFS= read -r line; do
  # Parse and capture
  echo "$line" | jq -r '. |
    mls_capture.zsh \(.type) "\(.title)" "\(.desc)" "\(.ctx)"'
done < lessons_export.jsonl
```

### API Integration (future)

Query MLS via API:
```bash
# Not yet implemented
curl http://localhost:3000/api/mls/search?q=sync&type=solution
```

### Scheduled Reports

Add to crontab:
```bash
# Generate MLS report daily at 9 AM
0 9 * * * ~/02luka/tools/mls_report.zsh
```

---

## 🔐 Data Management

### Backup

MLS database is in:
```
~/02luka/g/knowledge/mls_lessons.jsonl
```

**Backed up by:**
- GD sync (every 4h) ✅
- Safety snapshots ✅
- Git (if committed) ✅

### Privacy

**MLS contains:**
- Technical lessons (safe)
- System approaches (safe)
- WO titles (may contain project names)

**Does NOT contain:**
- Passwords or secrets
- Personal information
- Sensitive business data

---

## 🚀 Future Enhancements

Planned features:

- [ ] **Auto-suggest improvements** based on patterns
- [ ] **Usefulness scoring** (track which lessons help most)
- [ ] **Tag system** for better organization
- [ ] **Lesson verification** workflow
- [ ] **Integration with knowledge base** (RAG)
- [ ] **API endpoint** for programmatic access
- [ ] **Slack/Telegram notifications** for new lessons
- [ ] **Lesson aging** (archive old/outdated)
- [ ] **Collaborative lessons** (team annotations)
- [ ] **Export to Notion/Obsidian**

---

## 📞 Quick Commands

```bash
# Capture lesson
~/02luka/tools/mls_capture.zsh <type> "Title" "Description" "Context"

# Search
~/02luka/tools/mls_search.zsh <keyword> [type]

# Generate report
~/02luka/tools/mls_report.zsh

# View raw data
cat ~/02luka/g/knowledge/mls_lessons.jsonl | jq

# Stats
cat ~/02luka/g/knowledge/mls_index.json | jq
```

---

## 🎯 Example Workflow

### After Successful Deployment

```bash
# 1. WO completes successfully
# (auto-captured by autopilot hook)

# 2. Manual review and enhancement
~/02luka/tools/mls_search.zsh "deployment"

# 3. Add related pattern if discovered
~/02luka/tools/mls_capture.zsh pattern \
  "Dry-Run Before Production" \
  "Always test with dry-run script before real execution" \
  "Prevents mistakes, validates approach"

# 4. Generate daily report
~/02luka/tools/mls_report.zsh

# 5. Open and review
open ~/02luka/g/reports/mls_report_$(date +%Y%m%d).html
```

### Before Starting New Project

```bash
# 1. Search for related lessons
~/02luka/tools/mls_search.zsh "sync" solution

# 2. Check for known failures
~/02luka/tools/mls_search.zsh "sync" failure

# 3. Review patterns
~/02luka/tools/mls_search.zsh "" pattern

# 4. Apply lessons to new project
```

---

## 📖 See Also

- **R&D Autopilot:** `~/02luka/CLAUDE_MEMORY_SYSTEM.md`
- **Dashboard:** `~/02luka/g/manuals/SYSTEM_DASHBOARD_GUIDE.md`
- **GD Sync:** `~/02luka/GDRIVE_MOBILE_DEPLOYMENT_PLAN.md`

---

**Created:** 2025-11-05
**Status:** Production Ready
**Database:** ~/02luka/g/knowledge/mls_lessons.jsonl
**Reports:** ~/02luka/g/reports/mls_report_*.html
