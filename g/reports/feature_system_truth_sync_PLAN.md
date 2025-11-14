# Feature Implementation Plan: System Truth Sync

**Feature ID:** `system_truth_sync`  
**Date:** 2025-11-13  
**Status:** ✅ APPROVED - Ready for Implementation  
**Owner:** CLC  
**Estimated Time:** 3.5 hours

---

## 🎯 Objective

Create automated system to ensure 02luka.md always reflects actual system state by:
1. Scanning runtime reality (LaunchAgents, scripts, pipelines)
2. Generating truth map (JSON)
3. Auto-updating 02luka.md sections
4. Adding simple AI session summaries

**Goal:** "02luka.md must not lie - it shows what's actually running"

---

## 📋 Approved Specifications

### Core Architecture
```
Runtime Reality → system_map.v1.json → 02luka.md (auto-sections)
MLS Ledger → session_YYYYMMDD.ai.json → Quick summaries
```

### Key Constraints
1. **Safe Updates:** ONLY modify AUTO_RUNTIME blocks in 02luka.md
2. **Idempotent:** Running N times = same result
3. **Fresh Data:** Map age >48h = health failure
4. **Simple Format:** No TTL, no complex versioning

---

## 📁 Deliverables

### 1. system_map.v1.json Schema
```json
{
  "version": 1,
  "scanned_at": "2025-11-13T15:40:00+0700",
  "host": "macmini-02luka",
  "launchagents": [
    {
      "name": "com.02luka.apply_patch_processor",
      "status": "loaded|unloaded",
      "pid": 12345,
      "script": "agents/apply_patch_processor/apply_patch_processor.zsh",
      "inbox": "bridge/inbox/CLC",
      "state_dir": "g/followup/state"
    }
  ],
  "agents": [
    {
      "name": "apply_patch_processor",
      "type": "processor|collector|generator|watcher",
      "entry_point": "agents/apply_patch_processor/apply_patch_processor.zsh",
      "launchagent": "com.02luka.apply_patch_processor"
    }
  ],
  "pipelines": [
    {
      "name": "WO Pipeline",
      "steps": ["ENTRY inbox", "mary_dispatcher", "CLC inbox", "apply_patch_processor"],
      "active": true,
      "inbox_paths": ["bridge/inbox/ENTRY", "bridge/inbox/CLC"]
    }
  ],
  "stats": {
    "total_launchagents": 10,
    "active_launchagents": 8,
    "total_scripts": 45,
    "active_pipelines": 3
  }
}
```

### 2. Session AI Summary Schema
```json
{
  "date": "2025-11-13",
  "ts_local": "2025-11-13T15:34:05+0700",
  "agent": "CLS",
  "summary": {
    "total_entries": 289,
    "top_activities": [
      "Phase 6 Week 1 deployed (7/7 tests passed)",
      "MLS cursor watcher stdin bug fixed",
      "System truth sync implemented"
    ],
    "stats": {
      "solutions": 276,
      "improvements": 12,
      "failures": 1,
      "files_modified": 15
    }
  },
  "links": {
    "mls_ledger": "mls/ledger/2025-11-13.jsonl",
    "full_session": "g/reports/sessions/session_20251113_150700.md",
    "system_map": "g/system_map/system_map.v1.json"
  }
}
```

### 3. 02luka.md Auto-Section Format
```markdown
# 02LUKA System Documentation

_Last Reality Scan: 2025-11-13 15:40 ICT_  
_Verified Against: launchctl, agents/, tools/, bridge/inbox/, g/followup/state/_

<!-- AUTO_RUNTIME_START -->
## Current Runtime Agents

### ✅ apply_patch_processor (Running - PID: 12345)
- **LaunchAgent:** com.02luka.apply_patch_processor
- **Script:** agents/apply_patch_processor/apply_patch_processor.zsh
- **Inbox:** bridge/inbox/CLC
- **State:** g/followup/state/*.json
- **Type:** WO Processor

### ✅ Adaptive Collector (Scheduled - Daily 06:30)
- **LaunchAgent:** com.02luka.adaptive.collector.daily
- **Script:** tools/adaptive_collector.zsh
- **Output:** mls/adaptive/insights_YYYYMMDD.json
- **Type:** Metrics Collector

## Active Pipelines

### WO Pipeline (Active)
**Flow:** ENTRY inbox → mary_dispatcher → CLC inbox → apply_patch_processor
**Inbox Paths:**
- bridge/inbox/ENTRY (monitored)
- bridge/inbox/CLC (monitored)

**Status:** ✅ Operational

### Phase 6 Adaptive Governance (Active)
**Flow:** adaptive_collector → dashboard_generator → proposal_gen
**Schedule:** Daily 06:30, 07:00
**Status:** ✅ Operational

<!-- AUTO_RUNTIME_END -->

## System Philosophy (Human Written)
... Boss's manual content here ...
```

---

## 🛠️ Implementation Tasks

### Task 1: Create system_map_scan.zsh (1 hour)

**File:** `tools/system_map_scan.zsh`

**Requirements:**
1. Scan LaunchAgents:
   ```bash
   launchctl list | grep 'com.02luka' | while read pid status name; do
     # Extract info, check if loaded
   done
   ```

2. Scan Agent Scripts:
   ```bash
   find agents/ tools/ -type f -executable -name "*.zsh" -o -name "*.sh"
   # Detect which have LaunchAgents
   ```

3. Detect Pipelines:
   ```bash
   # Check inbox directories
   find bridge/inbox/ -type d -maxdepth 1
   # Check state directories
   find g/followup/state/ -name "*.json" | wc -l
   ```

4. Generate JSON:
   ```bash
   jq -n \
     --arg version "1" \
     --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S%z)" \
     --arg host "$(hostname)" \
     --argjson agents "$agents_json" \
     --argjson launchagents "$launchagents_json" \
     --argjson pipelines "$pipelines_json" \
     '{version: ($version | tonumber), scanned_at: $ts, host: $host, launchagents: $launchagents, agents: $agents, pipelines: $pipelines}'
   ```

5. Write Output:
   ```bash
   mkdir -p g/system_map
   echo "$output" > g/system_map/system_map.v1.json
   echo "$(date -u +%Y-%m-%dT%H:%M:%S%z)" > g/system_map/last_scan.txt
   date >> g/system_map/scan_log_$(date +%Y%m%d).txt
   ```

**Error Handling:**
- If launchctl fails → log error, continue with partial data
- If jq fails → abort, don't overwrite existing good JSON
- Always create scan log entry

---

### Task 2: Create system_map_render.zsh (1 hour)

**File:** `tools/system_map_render.zsh`

**Requirements:**
1. Safety Checks:
   ```bash
   # Check if 02luka.md exists
   [[ -f ~/02luka/02luka.md ]] || exit 1
   
   # Check if markers exist
   grep -q "AUTO_RUNTIME_START" ~/02luka/02luka.md || exit 1
   grep -q "AUTO_RUNTIME_END" ~/02luka/02luka.md || exit 1
   
   # Check if system_map.v1.json exists and is valid
   [[ -f g/system_map/system_map.v1.json ]] || exit 1
   jq empty g/system_map/system_map.v1.json 2>/dev/null || exit 1
   ```

2. Extract Block (Before):
   ```bash
   # Save content before AUTO_RUNTIME_START
   sed -n '1,/AUTO_RUNTIME_START/p' ~/02luka/02luka.md > /tmp/before.txt
   
   # Save content after AUTO_RUNTIME_END
   sed -n '/AUTO_RUNTIME_END/,$p' ~/02luka/02luka.md > /tmp/after.txt
   ```

3. Generate New Section:
   ```bash
   # Read system_map.v1.json
   MAP=$(cat g/system_map/system_map.v1.json)
   
   # Generate markdown from JSON
   echo "<!-- AUTO_RUNTIME_START -->" > /tmp/new_section.md
   echo "## Current Runtime Agents" >> /tmp/new_section.md
   echo "" >> /tmp/new_section.md
   
   # For each LaunchAgent
   echo "$MAP" | jq -r '.launchagents[] | ...' | while read ...; do
     # Generate markdown section
   done
   
   echo "<!-- AUTO_RUNTIME_END -->" >> /tmp/new_section.md
   ```

4. Rebuild File:
   ```bash
   # Combine: before + new_section + after
   cat /tmp/before.txt /tmp/new_section.md /tmp/after.txt > /tmp/02luka.md.new
   
   # Verify new file is valid (has markers, non-empty)
   grep -q "AUTO_RUNTIME_START" /tmp/02luka.md.new || exit 1
   
   # Atomic replace
   TMP_FILE="/tmp/02luka.md.new"
   TARGET_FILE="$HOME/02luka/02luka.md"
   mv "$TMP_FILE" "$TARGET_FILE"
   ```

**Critical Safety:**
- NEVER use `>` directly on 02luka.md (atomic replace only)
- If ANY step fails → abort, don't touch 02luka.md
- Create backup before replace: `cp 02luka.md 02luka.md.bak.$(date +%s)`

---

### Task 3: Update session_save.zsh (30 minutes)

**File:** `tools/session_save.zsh` (existing)

**Changes:**
1. After generating session_YYYYMMDD_HHMMSS.md
2. Generate session_YYYYMMDD.ai.json

**New Function:**
```bash
generate_ai_summary() {
  local today=$(date +%Y-%m-%d)
  local ts_local=$(date +"%Y-%m-%dT%H:%M:%S%z")
  local mls_ledger="mls/ledger/$(date +%Y-%m-%d).jsonl"
  
  # Extract top 10 activities from MLS
  local top_activities=$(cat "$mls_ledger" | jq -s 'sort_by(.ts) | reverse | .[0:10] | map(.title)')
  
  # Count by type
  local solutions=$(cat "$mls_ledger" | jq -s '[.[] | select(.type == "solution")] | length')
  local improvements=$(cat "$mls_ledger" | jq -s '[.[] | select(.type == "improvement")] | length')
  local failures=$(cat "$mls_ledger" | jq -s '[.[] | select(.type == "failure")] | length')
  local total=$(cat "$mls_ledger" | jq -s 'length')
  
  # Find latest full session for today
  local full_session=$(ls -t g/reports/sessions/session_${today//-/}_*.md 2>/dev/null | head -1)
  
  # Generate JSON
  jq -n \
    --arg date "$today" \
    --arg ts_local "$ts_local" \
    --arg agent "${SESSION_AGENT:-CLS}" \
    --argjson top "$top_activities" \
    --arg solutions "$solutions" \
    --arg improvements "$improvements" \
    --arg failures "$failures" \
    --arg total "$total" \
    --arg mls_ledger "$mls_ledger" \
    --arg full_session "${full_session#$HOME/02luka/}" \
    --arg system_map "g/system_map/system_map.v1.json" \
    '{
      date: $date,
      ts_local: $ts_local,
      agent: $agent,
      summary: {
        total_entries: ($total | tonumber),
        top_activities: $top,
        stats: {
          solutions: ($solutions | tonumber),
          improvements: ($improvements | tonumber),
          failures: ($failures | tonumber)
        }
      },
      links: {
        mls_ledger: $mls_ledger,
        full_session: $full_session,
        system_map: $system_map
      }
    }' > "g/reports/sessions/session_${today//-/}.ai.json"
  
  echo "✅ AI summary: g/reports/sessions/session_${today//-/}.ai.json"
}
```

**Integration:**
```bash
# In main save flow (after session .md created):
echo ""
echo "📝 Generating AI summary..."
generate_ai_summary

# Commit both files
git add "g/reports/sessions/session_${today//-/}.ai.json"
```

---

### Task 4: Create Acceptance Tests (30 minutes)

**File:** `tools/system_truth_sync_acceptance.zsh`

```bash
#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
cd "$REPO"

echo "🧪 System Truth Sync - Acceptance Tests"
echo "========================================"

PASS=0
FAIL=0

# Test 1: System map freshness
echo ""
echo "Test 1: System map freshness (<48h)"
if [[ -f g/system_map/system_map.v1.json ]]; then
  AGE=$(( $(date +%s) - $(stat -f %m g/system_map/system_map.v1.json) ))
  if [[ $AGE -lt 172800 ]]; then
    echo "✅ PASS: Map age = $((AGE / 3600))h"
    ((PASS++))
  else
    echo "❌ FAIL: Map age = $((AGE / 3600))h (>48h)"
    ((FAIL++))
  fi
else
  echo "❌ FAIL: system_map.v1.json not found"
  ((FAIL++))
fi

# Test 2: 02luka.md has auto-sections
echo ""
echo "Test 2: 02luka.md has AUTO_RUNTIME markers"
if grep -q "AUTO_RUNTIME_START" 02luka.md && grep -q "AUTO_RUNTIME_END" 02luka.md; then
  echo "✅ PASS: Auto-section markers present"
  ((PASS++))
else
  echo "❌ FAIL: Missing AUTO_RUNTIME markers"
  ((FAIL++))
fi

# Test 3: LaunchAgents match reality
echo ""
echo "Test 3: LaunchAgents in JSON match launchctl"
if [[ -f g/system_map/system_map.v1.json ]]; then
  MISMATCH=0
  jq -r '.launchagents[].name' g/system_map/system_map.v1.json 2>/dev/null | while read agent; do
    if ! launchctl list | grep -q "$agent"; then
      echo "⚠️  Mismatch: $agent in JSON but not loaded"
      MISMATCH=1
    fi
  done
  
  if [[ $MISMATCH -eq 0 ]]; then
    echo "✅ PASS: All agents match"
    ((PASS++))
  else
    echo "❌ FAIL: Some agents don't match"
    ((FAIL++))
  fi
else
  echo "⏭️  SKIP: No system_map.v1.json"
fi

# Test 4: Session AI summary exists
echo ""
echo "Test 4: Today's session AI summary exists"
TODAY=$(date +%Y%m%d)
if [[ -f "g/reports/sessions/session_${TODAY}.ai.json" ]]; then
  # Verify it's valid JSON
  if jq empty "g/reports/sessions/session_${TODAY}.ai.json" 2>/dev/null; then
    echo "✅ PASS: AI summary exists and is valid JSON"
    ((PASS++))
  else
    echo "❌ FAIL: AI summary exists but invalid JSON"
    ((FAIL++))
  fi
else
  echo "⚠️  SKIP: No AI summary for today (run 'save' first)"
fi

# Summary
echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "❌ Some tests failed"
  exit 1
fi
```

---

### Task 5: Create LaunchAgent for Daily Scan (15 minutes)

**File:** `LaunchAgents/com.02luka.system_map_scan.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.02luka.system_map_scan</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/Users/icmini/02luka/tools/system_map_scan.zsh</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>7</integer>
        <key>Minute</key>
        <integer>30</integer>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/Users/icmini/02luka/logs/system_map_scan.out</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/icmini/02luka/logs/system_map_scan.err</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>WorkingDirectory</key>
    <string>/Users/icmini/02luka</string>
</dict>
</plist>
```

**Install:**
```bash
cp LaunchAgents/com.02luka.system_map_scan.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.02luka.system_map_scan.plist
launchctl start com.02luka.system_map_scan
```

---

### Task 6: Update 02luka.md with Markers (15 minutes)

**File:** `02luka.md` (manual edit)

**Add markers in appropriate location:**
```markdown
# 02LUKA System Documentation

... existing content ...

---

_Last Reality Scan: (will be auto-updated)_  
_Verified Against: launchctl, agents/, tools/, bridge/inbox/_

<!-- AUTO_RUNTIME_START -->
<!-- This section is auto-generated by tools/system_map_render.zsh -->
<!-- DO NOT EDIT MANUALLY - Changes will be overwritten -->

## Current Runtime Agents

(Initial placeholder - will be replaced on first render)

<!-- AUTO_RUNTIME_END -->

---

## System Philosophy
... Boss's manual content ...
```

---

## 📊 Acceptance Criteria

| Test | Expected | Verification |
|------|----------|--------------|
| **Map Freshness** | <48h | `stat g/system_map/system_map.v1.json` |
| **02luka.md Markers** | Present | `grep AUTO_RUNTIME 02luka.md` |
| **LaunchAgent Match** | 100% | Compare JSON vs `launchctl list` |
| **AI Summary Exists** | Every save | `ls session_YYYYMMDD.ai.json` |
| **No Manual Content Loss** | 100% preserved | Diff before/after render |
| **Idempotent Render** | Same result N times | Run 3x, compare output |

---

## 🔄 Rollback Plan

**If implementation fails:**

1. **system_map_scan.zsh** - Remove LaunchAgent:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.system_map_scan.plist
   rm ~/Library/LaunchAgents/com.02luka.system_map_scan.plist
   ```

2. **02luka.md** - Restore backup:
   ```bash
   cp 02luka.md.bak.TIMESTAMP 02luka.md
   ```

3. **session_save.zsh** - Git revert:
   ```bash
   git checkout HEAD -- tools/session_save.zsh
   ```

**Backup locations:**
- `02luka.md.bak.*` (timestamped)
- Git history
- `g/deploy_backups/system_truth_sync_YYYYMMDD/`

---

## 📝 Testing Strategy

### Unit Tests (per script)
```bash
# Test system_map_scan.zsh
./tools/system_map_scan.zsh
jq empty g/system_map/system_map.v1.json # Verify valid JSON
jq '.version' g/system_map/system_map.v1.json # Should be 1

# Test system_map_render.zsh (dry run)
cp 02luka.md 02luka.md.test
./tools/system_map_render.zsh
diff 02luka.md.test 02luka.md # Should only differ in AUTO_RUNTIME block

# Test session_save.zsh
./tools/session_save.zsh
ls g/reports/sessions/session_$(date +%Y%m%d).ai.json # Should exist
jq empty g/reports/sessions/session_$(date +%Y%m%d).ai.json # Valid JSON
```

### Integration Tests
```bash
# Full cycle test
./tools/system_map_scan.zsh
./tools/system_map_render.zsh
./tools/session_save.zsh
./tools/system_truth_sync_acceptance.zsh # Should pass all
```

### Regression Tests
```bash
# Ensure nothing broke
~/02luka/tools/phase6_1_acceptance.zsh # Should still pass
~/02luka/tools/phase6_2_acceptance.zsh # Should still pass
~/02luka/tools/system_health_check.zsh # Should maintain score
```

---

## 🚀 Deployment Checklist

- [ ] Create `tools/system_map_scan.zsh`
- [ ] Create `tools/system_map_render.zsh`
- [ ] Update `tools/session_save.zsh`
- [ ] Create `tools/system_truth_sync_acceptance.zsh`
- [ ] Create LaunchAgent plist
- [ ] Update `02luka.md` with markers
- [ ] Test all scripts individually
- [ ] Run integration test
- [ ] Install LaunchAgent
- [ ] Run acceptance tests
- [ ] Verify health score maintained
- [ ] Create deployment backup
- [ ] Record to MLS

---

## 📅 Timeline

| Day | Tasks | Deliverables |
|-----|-------|--------------|
| **Day 1 AM** | Tasks 1-2 | system_map_scan.zsh, system_map_render.zsh |
| **Day 1 PM** | Tasks 3-4 | session_save.zsh update, acceptance tests |
| **Day 2 AM** | Tasks 5-6 | LaunchAgent, 02luka.md markers |
| **Day 2 PM** | Testing | All tests pass, deployment complete |

**Total Duration:** 1.5 days (3.5 hours active work + testing)

---

## ✅ Definition of Done

1. ✅ All 6 tasks completed
2. ✅ All 4 acceptance tests pass
3. ✅ LaunchAgent installed and running
4. ✅ 02luka.md has auto-sections with real data
5. ✅ Today's session has .ai.json summary
6. ✅ No regression (Phase 6 tests still pass)
7. ✅ Health score maintained or improved
8. ✅ MLS entry recorded
9. ✅ Deployment backup created
10. ✅ Boss approves: "02luka.md doesn't lie anymore"

---

**Plan Status:** ✅ APPROVED - Ready for WO Creation  
**Next Step:** Create WO for CLC to execute

<!-- Sanitized for Codex Sandbox Mode (2025-11) -->
