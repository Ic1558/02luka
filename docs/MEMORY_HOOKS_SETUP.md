# 🪝 Memory Hooks Setup Guide

**Purpose:** Automate memory recording for significant commits and events

---

## Post-Commit Hook (Automatic Memory Recording)

### What It Does

Automatically records significant commits to the vector memory system:
- **Feat commits** → Recorded as `plan` memories
- **Fix commits** → Recorded as `solution` memories
- **Perf/optimize commits** → Recorded as `insight` memories

**Criteria for Recording:**
- ✅ Commit affects ≥3 files (skip trivial changes)
- ✅ Commit message follows conventional format (`feat:`, `fix:`, etc.)
- ❌ Skip: docs-only, style, chore, minor refactors

### Installation

**Option 1: Symbolic Link (Recommended)**
```bash
cd /path/to/02luka-repo
ln -sf ../../scripts/post-commit-memory-hook.sh .git/hooks/post-commit
```

**Option 2: Copy Hook**
```bash
cd /path/to/02luka-repo
cp scripts/post-commit-memory-hook.sh .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

**Verify Installation:**
```bash
ls -la .git/hooks/post-commit
# Should show: post-commit -> ../../scripts/post-commit-memory-hook.sh
```

### Testing

**Test 1: Make a significant commit**
```bash
# Create test changes (3+ files)
touch test1.txt test2.txt test3.txt
git add test1.txt test2.txt test3.txt
git commit -m "feat: test automatic memory recording"

# Check memory
node memory/index.cjs --stats
# Should show: totalMemories increased by 1

# View the recorded memory
node memory/index.cjs --recall "test automatic memory"
# Should return: the commit we just made
```

**Test 2: Verify skipped commits**
```bash
# Docs-only commit (should be skipped)
echo "test" > README.md
git add README.md
git commit -m "docs: update readme"

# Check memory (should NOT increase)
node memory/index.cjs --stats
```

### Customization

**Adjust Significance Threshold:**

Edit `scripts/post-commit-memory-hook.sh`:
```bash
# Change from 3 to your preferred minimum
if [ "$COMMIT_FILES" -lt 5 ]; then  # Now requires 5+ files
  exit 0
fi
```

**Add Custom Skip Patterns:**
```bash
# Skip additional patterns
if echo "$COMMIT_MSG" | grep -qE "^(test:|ci:|build:)"; then
  exit 0
fi
```

**Add Custom Memory Kinds:**
```bash
# Add more specific categorization
elif echo "$COMMIT_MSG" | grep -qE "^refactor:"; then
  KIND="insight"  # Refactors often provide insights
elif echo "$COMMIT_MSG" | grep -qE "^test:"; then
  KIND="solution"  # Tests often solve validation problems
fi
```

### Troubleshooting

**Hook not running:**
```bash
# Check if hook is executable
ls -la .git/hooks/post-commit

# Make it executable if needed
chmod +x .git/hooks/post-commit

# Check if symlink is correct
readlink .git/hooks/post-commit
# Should show: ../../scripts/post-commit-memory-hook.sh
```

**Hook runs but no memory recorded:**
```bash
# Check if memory module exists
ls -la memory/index.cjs

# Check if node is available
which node

# Manually test memory recording
node memory/index.cjs --remember plan "Test manual recording"

# Check git commit message format
git log -1 --pretty=%B
# Should start with: feat:, fix:, etc.
```

**Too many memories being recorded:**
```bash
# Increase file threshold (edit hook script)
# Or add more skip patterns
```

### Uninstallation

```bash
cd /path/to/02luka-repo
rm .git/hooks/post-commit
```

---

## Other Hooks (Future Enhancements)

### Pre-Push Hook (Validate Before Push)

**Planned Features:**
- Check memory consistency before push
- Validate recent commits have memory entries
- Suggest recording if significant work not captured

**Status:** Planned for Phase 6.5

### Post-Merge Hook (Record Merges)

**Planned Features:**
- Record successful merges as insights
- Track integration patterns
- Note conflict resolutions

**Status:** Planned for Phase 6.5

---

## Best Practices

**DO:**
- ✅ Use conventional commit messages (`feat:`, `fix:`, etc.)
- ✅ Make meaningful commits (not "WIP" or "temp")
- ✅ Review memory periodically: `node memory/index.cjs --stats`
- ✅ Clean up memory occasionally: `node memory/index.cjs --clear` (with backup)

**DON'T:**
- ❌ Commit secrets/tokens (they'll be recorded in memory)
- ❌ Make tiny commits just to trigger recording
- ❌ Rely solely on auto-recording (manual recording still valuable)

---

## Integration with Workflow

### Standard Workflow
```bash
# 1. Make changes
vim memory/index.cjs

# 2. Test changes
node memory/index.cjs --stats

# 3. Commit (hook auto-records if significant)
git add memory/index.cjs
git commit -m "feat: add importance scoring to memory system"

# 4. Verify recording (optional)
node memory/index.cjs --recall "importance scoring"

# 5. Push to remote
git push
```

### Manual Override

If you want to record something the hook skipped:
```bash
# After commit
node memory/index.cjs --remember solution \
  "Detailed explanation of what was done and why"
```

---

## Metrics

**Tracking Hook Effectiveness:**
```bash
# Check memory growth over time
node memory/index.cjs --stats

# Review recent auto-recorded memories
node memory/index.cjs --recall "Commit" | head -20

# Identify patterns
git log --oneline --since="1 week ago" | wc -l  # Total commits
# Compare to:
node memory/index.cjs --stats  # Total memories
# Ratio should be ~30-50% (not all commits should be recorded)
```

---

## Automatic Cleanup and Importance Scoring (Phase 6.5-A)

### What Is It?

**Importance Scoring**: Every memory now gets an automatic importance score (0.0-1.0) based on:
- **Memory kind**: `error` memories get +0.2, `insight` memories get +0.15
- **Success rate**: High success rate (>0.9) gets +0.1
- **Reuse count**: Frequently reused (>5 times) gets +0.1
- **Base score**: Default 0.5, can be overridden

**Smart Cleanup**: Removes old or low-importance memories while preserving:
- Recent memories (within `maxAgeDays`, default: 90 days)
- Important memories (importance >= `minImportance`, default: 0.3)

### Usage

**Store memory with metadata (automatic importance calculation):**
```bash
node memory/index.cjs --remember plan "Deploy fix for ops-gate" --meta '{"successRate":0.95}'
# Importance: 0.5 (base) + 0.1 (high success rate) = 0.6
```

**Store error with high importance:**
```bash
node memory/index.cjs --remember error "Critical database connection timeout" --meta '{"reuseCount":10}'
# Importance: 0.5 (base) + 0.2 (error) + 0.1 (high reuse) = 0.8
```

**Manual cleanup:**
```bash
# Cleanup memories older than 90 days OR with importance < 0.3
node memory/index.cjs --cleanup --maxAge 90 --minImportance 0.3

# More aggressive cleanup
node memory/index.cjs --cleanup --maxAge 30 --minImportance 0.5
```

**Automated cleanup script:**
```bash
# Run manual cleanup
bash scripts/cleanup_memory.sh

# With custom parameters (via environment variables)
MEMORY_CLEANUP_MAX_AGE=60 MEMORY_CLEANUP_MIN_IMPORTANCE=0.4 bash scripts/cleanup_memory.sh
```

**Schedule automated cleanup (macOS LaunchAgent):**
```bash
# Create weekly cleanup schedule
# Add to: ~/Library/LaunchAgents/com.02luka.memory.cleanup.plist

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.memory.cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/scripts/cleanup_memory.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/icmini/Library/02luka/logs/memory_cleanup.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/icmini/Library/02luka/logs/memory_cleanup_error.log</string>
</dict>
</plist>

# Load the agent
launchctl load ~/Library/LaunchAgents/com.02luka.memory.cleanup.plist
```

### Importance Scoring Logic

```javascript
function calculateImportance(kind, meta = {}, userImportance = 0.5) {
  let score = userImportance;

  // Kind-based importance
  if (kind === 'error') score += 0.2;
  if (kind === 'insight') score += 0.15;

  // Metadata-based importance
  if (meta.successRate && meta.successRate > 0.9) score += 0.1;
  if (meta.reuseCount && meta.reuseCount > 5) score += 0.1;

  return Math.min(1.0, score); // Cap at 1.0
}
```

**Example Scores:**
- `plan` memory with default meta: **0.5**
- `error` memory: **0.7** (0.5 + 0.2)
- `insight` memory with high success rate: **0.75** (0.5 + 0.15 + 0.1)
- `error` memory with high reuse: **0.8** (0.5 + 0.2 + 0.1)
- `insight` with both: **0.85** (0.5 + 0.15 + 0.1 + 0.1)

### Cleanup Strategy

**Preserved Memories:**
- ✅ Recent (< 90 days old by default)
- ✅ Important (importance >= 0.3 by default)
- ✅ Both recent AND important

**Removed Memories:**
- ❌ Old (>90 days) AND low importance (<0.3)

**Example:**
```
Memory A: 120 days old, importance 0.8 → KEPT (important)
Memory B: 30 days old, importance 0.2 → KEPT (recent)
Memory C: 120 days old, importance 0.2 → REMOVED (old + low importance)
```

### Monitoring

**Check memory health:**
```bash
# View stats
node memory/index.cjs --stats

# Check oldest memories (via direct file inspection)
cat g/memory/vector_index.json | jq '.memories | sort_by(.timestamp) | .[0:5] | .[] | {id, kind, importance, timestamp}'

# Check lowest importance memories
cat g/memory/vector_index.json | jq '.memories | sort_by(.importance) | .[0:5] | .[] | {id, kind, importance, text}'
```

**Cleanup logs:**
```bash
# If using automated cleanup
tail -f ~/Library/02luka/logs/memory_cleanup.log
```

---

## Related Documentation

- **Memory System**: `docs/CONTEXT_ENGINEERING.md` (Vector Memory section)
- **Memory Sharing**: `docs/MEMORY_SHARING_GUIDE.md`
- **Setup Script**: `scripts/setup_cursor_memory_bridge.sh`
- **Cognitive Model**: `g/concepts/PHASE6_COGNITIVE_MODEL.md`
- **Cleanup Script**: `scripts/cleanup_memory.sh`

---

**Last Updated:** 2025-10-20
**Status:** Active (Phase 6 + 6.5-A)
