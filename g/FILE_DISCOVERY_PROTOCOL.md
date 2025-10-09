# File Discovery Protocol - Delegation Pattern

**Created:** 2025-10-08T02:00:00Z
**Purpose:** Standard pattern for finding files (avoids expensive searches)
**Principle:** Check local resources FIRST, never burn tokens on searchable info

---

## 🚦 Standard Pattern (Use This Every Time)

### When looking for any file:

```bash
# Step 1: Check librarian index (0 tokens, instant)
cat "$SOT/run/file_index.json" | jq -r '.important_files[] | select(contains("KEYWORD"))'

# If found → Use that path ✅
# If not found → File likely missing from working directory, proceed to Step 2

# Step 2: Check git history (100 tokens, fast)
cd 02luka-repo
git ls-tree -r HEAD --name-only | grep FILENAME

# If found → Restore from git ✅
# If not found → File never existed, proceed to Step 3

# Step 3: Search codebase (if still needed)
git log --all --full-history --source --oneline -- "*FILENAME*"

# If found in history → May have been deleted, investigate commit
# If not found → File never existed in project
```

**NEVER use `find ~` or `find $HOME` - expensive, slow, often timeout**

---

## 📋 Librarian Index Reference

### What It Tracks

**Location:** `$SOT/run/file_index.json`
**Updated:** Every 30 minutes (by librarian_v2.py LaunchAgent)
**Covers:** Zones: a, c, f, g, tools, gateway

### Structure

```json
{
  "updated_at": "ISO timestamp",
  "total_files": 59105,
  "by_type": {
    ".md": 2280,
    ".sh": 133,
    ".py": 568,
    ...
  },
  "by_zone": {
    "a": 1302,
    "g": 1367,
    ...
  },
  "important_files": [
    "a/section/clc/INDEX.md",
    "a/memory_center/core/CLAUDE_MEMORY_SYSTEM.md",
    "f/ai_daily.json",
    ...
  ]
}
```

### Important File Patterns

Librarian automatically tracks files matching:
- `**/CLAUDE*.md`
- `**/*protocol*.md`
- `**/INDEX.md`
- `**/*context*.json`
- `**/02luka.md`
- `**/ai_daily.json`

---

## 🎯 Examples

### Example 1: Finding save.sh (What CLC Should Have Done)

```bash
# Step 1: Check librarian (0 tokens, instant)
$ cat run/file_index.json | jq -r '.important_files[] | select(contains("save"))'
c/centralized/protocol/sub/gc/save_protocol_checklist.md

# Result: save.sh NOT in index
# Interpretation: File doesn't exist in working directory
# Action: Check git history

# Step 2: Check git (100 tokens, fast)
$ git ls-tree -r HEAD --name-only | grep save.sh
a/section/clc/commands/save.sh

# Result: File exists in git HEAD
# Action: Restore it

# Step 3: Restore
$ git checkout HEAD -- a/section/clc/commands/save.sh
$ ls -lh a/section/clc/commands/save.sh
-rwxr-xr-x  1.8K Oct  8 01:40

# Total time: <10 seconds
# Total tokens: ~100
```

**vs What CLC Actually Did:**
```bash
$ find ~ -name "save.sh"
# ... timeout after 2 minutes
# Total tokens: 1,500+
# User frustration: High
```

### Example 2: Finding protocol files

```bash
# Step 1: Librarian index
$ cat run/file_index.json | jq -r '.important_files[] | select(contains("protocol"))'
c/centralized/protocol/sub/clc_protocol.md
c/centralized/protocol/sub/gc/gc_protocol.md
c/centralized/protocol/main/communication_protocols.md
...

# Result: Instant list of all protocol files
# No filesystem search needed
```

### Example 3: Finding INDEX.md files

```bash
# Step 1: Librarian index
$ cat run/file_index.json | jq -r '.important_files[] | select(contains("INDEX"))'
a/section/learning/INDEX.md
a/section/clc/INDEX.md
a/memory_analysis/learning/INDEX.md

# Result: All INDEX files instantly
# No glob or find needed
```

### Example 4: File doesn't exist anywhere

```bash
# Step 1: Librarian
$ cat run/file_index.json | jq -r '.important_files[] | select(contains("nonexistent"))'
# (no output)

# Step 2: Git history
$ git ls-tree -r HEAD --name-only | grep nonexistent
# (no output)

# Step 3: Full history search
$ git log --all --oneline -- "*nonexistent*"
# (no output)

# Conclusion: File never existed
# Total time: <30 seconds
# Total tokens: ~200 (vs 1,500+ for find ~)
```

---

## 🔄 When Librarian Index Is Stale

### Check Index Age

```bash
$ cat run/file_index.json | jq -r '.updated_at'
2025-10-02T17:54:07.241088Z

# If > 1 day old, librarian may not be running
```

### Verify Librarian Agent

```bash
$ launchctl list | grep librarian
-       0       com.02luka.intelligent_librarian

# Exit code 0 = healthy
# If not listed, librarian not running
```

### Trigger Manual Index Update

```bash
# Run librarian manually (if needed)
$ python3 /path/to/librarian_v2.py
# Or wait for next automatic run (every 30min)
```

---

## 💰 Cost Comparison

### Finding Missing File (save.sh Example)

| Method | Tokens | Time | Result |
|--------|--------|------|--------|
| **find ~ (wrong)** | 1,500 | 2min timeout | ❌ Failed |
| **Librarian → git (right)** | 100 | <10 sec | ✅ Found |
| **Savings** | **93%** | **92%** | **Success** |

### Finding Existing File (protocol file)

| Method | Tokens | Time | Result |
|--------|--------|------|--------|
| **Glob + grep** | 500 | 20 sec | ✅ Found |
| **Librarian index** | 0 | <1 sec | ✅ Found |
| **Savings** | **100%** | **95%** | **Same** |

---

## 📝 Checklist for File Discovery

**Before ANY file search:**

- [ ] Check librarian index first (`cat run/file_index.json | jq ...`)
- [ ] If not found, check git history (`git ls-tree | grep`)
- [ ] If still not found, search git log (`git log --all -- "*file*"`)
- [ ] NEVER use `find ~` or `find $HOME` (expensive, timeout prone)
- [ ] Document the working path once found (update CLAUDE.md)
- [ ] Update delegation docs if this becomes a pattern

**After finding file:**

- [ ] Add to CLAUDE.md if it's a frequently-used command/file
- [ ] Consider if librarian patterns need updating
- [ ] Document for future reference (avoid repeated searches)

---

## 🎓 Learning Integration

### From save.sh Incident

**Problem:** CLC created delegation docs but didn't follow them when searching for save.sh

**What happened:**
- Oct 7: Documented "check librarian first" in delegation system
- Oct 8: Searched for save.sh using `find ~` (timeout, 1,500 tokens)
- Oct 8: Boss asked "why don't use librarian in the system?"
- Oct 8: Fixed with this protocol

**Lesson:**
> Documentation without application = useless
> Must practice delegation principles, not just write them

**See:**
- `g/reports/SAVE_COMMAND_FIX_251008_0141.md` - Full incident analysis
- `g/reports/DELEGATION_SYSTEM_MAP_251007_2200.md` - Delegation framework
- `g/DELEGATION_QUICK_REF.md` - Quick reference (includes save.sh case study)

---

## 🚀 Future Enhancements

### 1. Smart Search Function

Create wrapper function in tools:

```bash
# smart_find.sh
#!/bin/bash
# Searches librarian → git → logs automatically

KEYWORD="$1"

echo "Checking librarian index..."
RESULT=$(cat run/file_index.json | jq -r ".important_files[] | select(contains(\"$KEYWORD\"))")

if [ -n "$RESULT" ]; then
  echo "Found in librarian index:"
  echo "$RESULT"
  exit 0
fi

echo "Not in index, checking git..."
git ls-tree -r HEAD --name-only | grep "$KEYWORD"
```

### 2. Librarian Health Check

Add to health_proxy endpoints:

```
GET /librarian/status
Response: {
  "last_updated": "2025-10-08T02:00:00Z",
  "age_hours": 0.5,
  "total_files": 59105,
  "status": "healthy"
}
```

### 3. Update CLAUDE.md Template

For any new critical file/command:

```markdown
## COMMAND_NAME

**Working Path:** [exact path]

**If missing:**
1. Check librarian: `cat run/file_index.json | jq '...'`
2. Check git: `git ls-tree -r HEAD | grep ...`
3. Never use `find ~`
```

---

## 🏁 Summary

### Core Principle

**Before any file search:**
1. Check librarian index (0 tokens, instant)
2. Check git history (100 tokens, fast)
3. NEVER use find ~ (1,500 tokens, timeout)

### Key Benefits

- **Cost:** 93% token savings
- **Speed:** 90%+ faster
- **Reliability:** No timeouts
- **Boss satisfaction:** High

### When to Use

**Always.** No exceptions.

**Even if you think you know where the file is:**
- Verify with librarian first (instant confirmation)
- Avoids blind path attempts
- Builds habit of delegation

---

**Created:** 2025-10-08T02:00:00Z
**Status:** Active Protocol
**Updates:** When new patterns discovered or tools added
**Related:** Delegation System, Save Command Protocol, Agent Capabilities
