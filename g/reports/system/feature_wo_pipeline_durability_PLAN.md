# Feature PLAN: WO Pipeline Durability & Persistence

**Created:** 2025-11-13 23:40  
**Priority:** P0 (Critical)  
**Owner:** CLS → CLC/Mary  
**Timeline:** 2-3 hours (phased execution)  
**Status:** Ready for Execution

---

## Executive Summary

**Problem:** WO pipeline components vanish silently, breaking the "fix once, stays fixed" guarantee.

**Solution:** 4-phase approach:
1. **Forensics** (10-15 min) - Understand what happened
2. **Rebuild** (60-90 min) - Restore pipeline durability
3. **Guardrail** (30-45 min) - Prevent future vanishing
4. **History-Aware** (30 min) - Enhance agent diagnostics

**Total Time:** 2.5-3 hours (can be split across days)

---

## Tasks Not Done (From session_20251113_145301.md)

### Critical (P0)
❌ **WO Pipeline Missing Components:**
- `agents/apply_patch_processor/apply_patch_processor.zsh` - MISSING
- `agents/json_wo_processor/json_wo_processor.zsh` - MISSING (or not running)
- `agents/wo_executor/wo_executor.zsh` - MISSING (or not running)
- `tools/followup_tracker_update.zsh` - MISSING
- `g/followup/state/` directory - MISSING
- All 5 LaunchAgents: loaded but not running (exit 127)

❌ **Forensic Analysis:**
- No investigation of Nov 13 01:50-22:43 gap
- No rollback log review
- No git history check for that timeframe

❌ **Persistence/Durability System:**
- No guardrail to detect missing components
- No rollback protection for critical files
- No snapshot before destructive operations

### High Priority (P1)
⚠️ **Pre-existing Health Issues:**
- Expense ledger missing
- Roadmap file missing  
- Dashboard data validation failing

⚠️ **Documentation:**
- GG WO generation approval (not documented in governance)
- WO creation pattern (0-1 vs 2+) not enforced systematically
- Cursor model setup (which models support slash commands)

### Medium Priority (P2)
⚠️ **Dead Code Cleanup:**
- Phase 6 proposal generator (lines 76-78) - fallback logic never triggers

⚠️ **LaunchAgent Optimization:**
- Proposal generator: RunAtLoad: false (won't run at boot)

---

## Tasks Not Deployed (But Were Developed)

### From CLC Session (Nov 13 01:50):
✅ **Developed but LOST:**
- `apply_patch_processor` (was working at 01:50, missing by 22:43)
- 9 WO state files created (all disappeared)
- PATH fixes in LaunchAgent
- Absolute path fixes in processor script

### From CLS Session (Nov 13):
✅ **Developed and DEPLOYED:**
- Phase 6 Week 1 (adaptive collector, dashboard generator, daily digest)
- Phase 6 Week 2 (proposal generator with bug fixes)
- MLS Cursor Watcher (auto-capture prompts)
- Session save system (`.md` + `.ai.json`)
- WO status checker with colors/progress bars

⚠️ **Partially Deployed:**
- WO creation pattern enforcement (documented but not automated)
- Dashboard improvements (some fixes not applied)

❌ **Not Yet Deployed:**
- Guardrail system (doesn't exist)
- Protected rollback (not implemented)
- History-aware diagnosis (not implemented)
- SSOT tree unification (not started)

---

## Implementation Phases

### Phase 1: Time-Boxed Forensics (10-15 min MAX)

**Goal:** Understand what killed CLC's work, not write a novel

#### Tasks

**Task 1.1: Git History Analysis**
- **Time:** 5 min
- **Owner:** CLS
- **Command:**
  ```bash
  cd ~/02luka
  git log --oneline --since="2025-11-13 01:50" --until="2025-11-13 22:43" > /tmp/git_forensic.txt
  git log -p --all --full-history -- agents/apply_patch_processor/ >> /tmp/git_forensic.txt
  git log -p --all --full-history -- g/followup/state/ >> /tmp/git_forensic.txt
  ```
- **Look for:**
  - Hard resets (`git reset --hard`)
  - Checkouts (`git checkout .`)
  - Pulls from clean remote
  - Large reversions

**Task 1.2: Rollback Script Analysis**
- **Time:** 5 min
- **Owner:** CLS
- **Command:**
  ```bash
  grep -l "agents/apply_patch_processor\|g/followup/state" ~/02luka/tools/rollback_*.zsh
  cat ~/02luka/tools/rollback_phase6_week1_20251113.zsh | grep -A10 -B10 "apply_patch\|followup/state"
  ```
- **Look for:**
  - Scripts that touch those directories
  - When they were run (check logs)

**Task 1.3: LaunchAgent Log Review**
- **Time:** 5 min
- **Owner:** CLS
- **Command:**
  ```bash
  ls -lht ~/Library/Logs/*apply_patch* ~/Library/Logs/*wo_executor* ~/Library/Logs/*json_wo*
  grep -h "exit 127\|command not found\|No such file" ~/Library/Logs/*.{log,err} 2>/dev/null | head -50
  ```
- **Look for:**
  - First occurrence of "file not found"
  - Timestamp when failures started

**Task 1.4: Document Findings**
- **Time:** 2 min
- **Owner:** CLS
- **Output:** `g/reports/forensic_wo_pipeline_20251113.json`
  ```json
  {
    "investigation_date": "2025-11-13T23:45:00Z",
    "time_window": "2025-11-13 01:50 - 22:43",
    "findings": {
      "git_events": ["..."],
      "rollback_scripts": ["..."],
      "launchagent_failures": ["..."],
      "likely_cause": "..."
    },
    "recommendation": "rebuild"
  }
  ```
- **MLS Entry:** Capture findings as "pattern" type

**Stop Criteria:**
- If smoking gun found in 10 min → Document and move to Phase 2
- If nothing clear in 15 min → Accept "cause: rollback/tree mismatch" and move to Phase 2
- **DO NOT** spend more than 15 minutes on this

---

### Phase 2: WO Pipeline Rebuild (60-90 min)

**Goal:** Restore pipeline using CLC's pattern as reference, but rebuild properly

#### Task 2.1: Create Rebuild WO (15 min)

**File:** `bridge/inbox/CLC/WO-20251113-WO-PIPELINE-REBUILD.yaml`

**Owner:** CLS → CLC processes

**Structure:**
```yaml
wo_id: WO-20251113-WO-PIPELINE-REBUILD
title: "WO Pipeline Complete Rebuild with Durability"
priority: P0
owner: mary
type: apply_patch
created_at: "2025-11-13T23:45:00Z"

description: |
  Rebuild WO processing pipeline with persistence guarantees.
  Based on CLC's Nov 13 01:50 successful deployment.
  Includes 4 processors + LaunchAgents + state directory + canary test.

files:
  # Processor 1: apply_patch_processor
  - path: agents/apply_patch_processor/apply_patch_processor.zsh
    mode: "0755"
    content: |
      #!/usr/bin/env zsh
      # Apply Patch Processor - Durable Version
      # Created: 2025-11-13 (rebuild)
      # Pattern from: CLC Nov 13 01:50
      set -euo pipefail
      
      # Use absolute paths (LaunchAgent compatibility)
      DATE=/usr/bin/date
      MV=/bin/mv
      MKDIR=/bin/mkdir
      BASENAME=/usr/bin/basename
      DIRNAME=/usr/bin/dirname
      CP=/bin/cp
      
      BASE="${LUKA_SOT:-$HOME/02luka}"
      STATE="$BASE/g/followup/state"
      TELE="$BASE/g/telemetry/unified.jsonl"
      INBOX="$BASE/bridge/inbox/CLC"
      
      $MKDIR -p "$STATE" "$BASE/backups/apply_patch"
      
      # [Rest of processor logic from CLC's pattern]
      # ... (full script)

  # Processor 2: json_wo_processor
  - path: agents/json_wo_processor/json_wo_processor.zsh
    mode: "0755"
    content: |
      #!/usr/bin/env zsh
      # JSON WO Processor
      set -euo pipefail
      # ... (full script)

  # Processor 3: wo_executor
  - path: agents/wo_executor/wo_executor.zsh
    mode: "0755"
    content: |
      #!/usr/bin/env zsh
      # WO Executor
      set -euo pipefail
      # ... (full script)

  # Tool: followup_tracker_update
  - path: tools/followup_tracker_update.zsh
    mode: "0755"
    content: |
      #!/usr/bin/env zsh
      # Followup Tracker
      set -euo pipefail
      # ... (full script)

  # LaunchAgent 1: apply_patch_processor
  - path: ../Library/LaunchAgents/com.02luka.apply_patch_processor.plist
    content: |
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
        <key>Label</key><string>com.02luka.apply_patch_processor</string>
        <key>ProgramArguments</key>
        <array>
          <string>/bin/zsh</string>
          <string>-l</string>
          <string>-c</string>
          <string>/Users/icmini/02luka/agents/apply_patch_processor/apply_patch_processor.zsh</string>
        </array>
        <key>StartInterval</key><integer>15</integer>
        <key>RunAtLoad</key><true/>
        <key>KeepAlive</key><true/>
        <key>StandardOutPath</key><string>/Users/icmini/Library/Logs/apply_patch_processor.out</string>
        <key>StandardErrorPath</key><string>/Users/icmini/Library/Logs/apply_patch_processor.err</string>
        <key>EnvironmentVariables</key>
        <dict>
          <key>PATH</key>
          <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
          <key>LUKA_SOT</key>
          <string>/Users/icmini/02luka</string>
        </dict>
      </dict></plist>

  # [LaunchAgents 2-4 similar structure]

post_verify:
  - launchctl load ~/Library/LaunchAgents/com.02luka.apply_patch_processor.plist
  - launchctl load ~/Library/LaunchAgents/com.02luka.json_wo_processor.plist
  - launchctl load ~/Library/LaunchAgents/com.02luka.wo_executor.plist
  - launchctl load ~/Library/LaunchAgents/com.02luka.followup_tracker.plist
  - mkdir -p ~/02luka/g/followup/state
  - sleep 20  # Let LaunchAgents start
  - launchctl list | grep "com.02luka.*processor\|wo_executor\|followup_tracker"

tests:
  - name: "All LaunchAgents running"
    command: "launchctl list | grep -c 'com.02luka.*processor\\|wo_executor\\|followup_tracker'"
    expected: "4"
  
  - name: "State directory exists"
    command: "test -d ~/02luka/g/followup/state && echo 'exists'"
    expected: "exists"
  
  - name: "Canary WO test"
    command: "test -f ~/02luka/g/followup/state/WO-CANARY-TEST.json && echo 'canary_ok'"
    expected: "canary_ok"
```

**Deliverable:** WO file ready for processing

---

#### Task 2.2: Create Canary WO (5 min)

**File:** `bridge/inbox/CLC/WO-CANARY-20251113-TEST.yaml`

**Purpose:** End-to-end pipeline test

```yaml
wo_id: WO-CANARY-20251113-TEST
title: "Pipeline Health Check - Canary"
priority: P2
owner: auto-test
type: apply_patch

files:
  - path: tmp/canary_test.txt
    content: |
      Pipeline test at $(date)
      If you see this file and a state file, pipeline is working.
```

**Expected Outcome:**
- File created: `~/02luka/tmp/canary_test.txt`
- State created: `~/02luka/g/followup/state/WO-CANARY-20251113-TEST.json`
- Telemetry entry: `wo_started` + `wo_completed`

---

#### Task 2.3: Monitor Rebuild (20-30 min)

**Wait for:**
1. LaunchAgents to process rebuild WO (15-30 sec)
2. All 4 processors installed and running
3. Canary WO to complete (15-30 sec)

**Verification Commands:**
```bash
# Check LaunchAgents
launchctl list | grep com.02luka | grep -E "processor|executor|tracker"

# Check state files
ls -lh ~/02luka/g/followup/state/

# Check telemetry
tail -20 ~/02luka/g/telemetry/unified.jsonl | grep -E "wo_started|wo_completed"

# Check dashboard
cd ~/02luka && ./tools/claude_tools/generate_followup_data.zsh
# Open http://localhost:8000/apps/dashboard/followup.html
```

**Success Criteria:**
- ✅ 4 LaunchAgents running (not exit 127)
- ✅ ≥2 state files (rebuild WO + canary WO)
- ✅ Telemetry shows successful completions
- ✅ Dashboard shows WOs

---

#### Task 2.4: Document Deployment (10 min)

**Create:** `g/reports/wo_pipeline_rebuild_deployment_20251113.md`

**Contents:**
- Deployment timestamp
- Components installed
- Verification results
- Known issues (if any)
- Rollback procedure
- MLS entry

---

### Phase 3: Persistence Guardrail (30-45 min)

**Goal:** Prevent silent vanishing of critical components

#### Task 3.1: Create Guardrail Script (20 min)

**File:** `tools/wo_pipeline_guardrail.zsh`

```zsh
#!/usr/bin/env zsh
# WO Pipeline Guardrail - Drift Detection
# Runs every 5 minutes, alerts if critical components missing
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
TELE="$BASE/g/telemetry/unified.jsonl"
ALERT_FILE="$BASE/logs/guardrail_alerts.log"

# Critical files that must exist
CRITICAL_FILES=(
  "agents/apply_patch_processor/apply_patch_processor.zsh"
  "agents/json_wo_processor/json_wo_processor.zsh"
  "agents/wo_executor/wo_executor.zsh"
  "tools/followup_tracker_update.zsh"
)

# Critical directories
CRITICAL_DIRS=(
  "g/followup/state"
  "bridge/inbox/CLC"
  "bridge/inbox/ENTRY"
)

# Check and alert
MISSING_COUNT=0
for file in "${CRITICAL_FILES[@]}"; do
  FULL_PATH="$BASE/$file"
  if [[ ! -f "$FULL_PATH" ]] || [[ ! -x "$FULL_PATH" ]]; then
    echo "[$(date -u +%FT%TZ)] ALERT: Missing or not executable: $file" >> "$ALERT_FILE"
    echo "{\"ts\":\"$(date -u +%FT%TZ)\",\"agent\":\"guardrail\",\"event\":\"wo_pipeline_drift\",\"ok\":false,\"missing\":\"$file\"}" >> "$TELE"
    ((MISSING_COUNT++))
  fi
done

for dir in "${CRITICAL_DIRS[@]}"; do
  FULL_PATH="$BASE/$dir"
  if [[ ! -d "$FULL_PATH" ]]; then
    echo "[$(date -u +%FT%TZ)] ALERT: Missing directory: $dir" >> "$ALERT_FILE"
    echo "{\"ts\":\"$(date -u +%FT%TZ)\",\"agent\":\"guardrail\",\"event\":\"wo_pipeline_drift\",\"ok\":false,\"missing\":\"$dir\"}" >> "$TELE"
    ((MISSING_COUNT++))
  fi
done

# Healthy heartbeat
if [[ $MISSING_COUNT -eq 0 ]]; then
  echo "{\"ts\":\"$(date -u +%FT%TZ)\",\"agent\":\"guardrail\",\"event\":\"wo_pipeline_healthy\",\"ok\":true}" >> "$TELE"
fi

exit 0
```

**Permissions:**
```bash
chmod +x ~/02luka/tools/wo_pipeline_guardrail.zsh
```

---

#### Task 3.2: Create Guardrail LaunchAgent (10 min)

**File:** `~/Library/LaunchAgents/com.02luka.wo_pipeline_guardrail.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.02luka.wo_pipeline_guardrail</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-l</string>
    <string>-c</string>
    <string>/Users/icmini/02luka/tools/wo_pipeline_guardrail.zsh</string>
  </array>
  <key>StartInterval</key><integer>300</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/Users/icmini/02luka/logs/guardrail.out.log</string>
  <key>StandardErrorPath</key><string>/Users/icmini/02luka/logs/guardrail.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>LUKA_SOT</key>
    <string>/Users/icmini/02luka</string>
  </dict>
</dict></plist>
```

**Install:**
```bash
launchctl load ~/Library/LaunchAgents/com.02luka.wo_pipeline_guardrail.plist
```

---

#### Task 3.3: Test Guardrail (10-15 min)

**Test 1: Healthy System**
```bash
# Should log heartbeat every 5 min
tail -f ~/02luka/g/telemetry/unified.jsonl | grep guardrail
# Expected: "wo_pipeline_healthy" every 300s
```

**Test 2: Simulate Drift**
```bash
# Temporarily rename a critical file
mv ~/02luka/agents/apply_patch_processor/apply_patch_processor.zsh{,.backup}

# Wait up to 5 minutes
# Should see alert

# Restore
mv ~/02luka/agents/apply_patch_processor/apply_patch_processor.zsh{.backup,}
```

**Success Criteria:**
- ✅ Healthy heartbeat logged every 5 min
- ✅ Alert within 5 min of simulated drift
- ✅ Heartbeat resumes after restoration

---

### Phase 4: History-Aware Diagnosis (30 min)

**Goal:** Enhance CLS diagnostic pattern to check history

#### Task 4.1: Create History Check Utility (15 min)

**File:** `tools/check_component_history.zsh`

```zsh
#!/usr/bin/env zsh
# Check recent history of a component
# Usage: ./check_component_history.zsh <component_path>

COMPONENT="$1"
HOURS="${2:-24}"

echo "=== History Check: $COMPONENT (last ${HOURS}h) ==="
echo ""

# Git history
echo "📝 Git History:"
git log --oneline --since="${HOURS} hours ago" -- "$COMPONENT" | head -10
echo ""

# MLS entries
echo "📚 MLS Entries:"
grep -h "$COMPONENT" ~/02luka/mls/ledger/*.jsonl 2>/dev/null | tail -5 | jq -r '.title' 2>/dev/null || echo "(none)"
echo ""

# Rollback logs
echo "🔄 Rollback Logs:"
grep -h "$COMPONENT" ~/02luka/logs/rollback_*.log 2>/dev/null | tail -5 || echo "(none)"
echo ""

# LaunchAgent logs
echo "🤖 LaunchAgent Status:"
COMPONENT_NAME=$(basename "$COMPONENT" .zsh)
launchctl list | grep "$COMPONENT_NAME" || echo "(not found)"
```

**Permissions:**
```bash
chmod +x ~/02luka/tools/check_component_history.zsh
```

---

#### Task 4.2: Update CLS Diagnostic Pattern (15 min)

**Pattern:**

**Before diagnosing "X is missing/broken":**

1. Check current state (filesystem)
2. **NEW:** Check history:
   ```bash
   ./tools/check_component_history.zsh "agents/apply_patch_processor"
   ```
3. Determine:
   - Never existed → Create from scratch
   - Existed, then vanished → Investigate when/why → Restore/rebuild
   - Exists but broken → Fix in place
4. Report: "Current state + Recent history"
5. Propose fix (informed by history)

**Implementation:** Add to CLS prompts/context

---

## Test Strategy

### Unit Tests

**Test 1: Guardrail Detection**
- Create: Missing file scenario
- Verify: Alert logged within 5 min
- Cleanup: Restore file

**Test 2: Guardrail Heartbeat**
- Wait: 10 minutes
- Verify: 2 heartbeat entries in telemetry

**Test 3: History Check**
- Run: `check_component_history.zsh` on known component
- Verify: Output includes git/MLS/logs

### Integration Tests

**Test 4: End-to-End WO Processing**
- Drop: Canary WO
- Wait: 30 seconds
- Verify:
  - State file created
  - Telemetry entry exists
  - Dashboard shows WO

**Test 5: Pipeline Rebuild**
- Execute: WO-PIPELINE-REBUILD
- Wait: 2 minutes
- Verify:
  - All 4 LaunchAgents running
  - All critical files exist
  - Canary test passes

### Acceptance Tests

**Test 6: Durability Guarantee**
- Deploy: Phase 2 rebuild
- Wait: 24 hours
- Verify: All components still present
- Check: Guardrail logged 288 heartbeats (1 every 5 min)

**Test 7: History-Aware Diagnosis**
- Scenario: Component vanishes
- CLS check: Should report "Was working at [timestamp], vanished at [timestamp]"
- Not: "Never worked"

---

## Timeline

### Day 1 (Nov 13, Evening)
- **23:00-23:15** - Phase 1: Forensics
- **23:15-00:45** - Phase 2: Rebuild
- **00:45-01:00** - Verification & Documentation

### Day 2 (Nov 14, Morning)
- **08:00-08:45** - Phase 3: Guardrail
- **08:45-09:15** - Phase 4: History-Aware
- **09:15-09:30** - Final testing & MLS capture

### Total Time: ~3 hours (split over 2 sessions)

---

## Success Metrics

### Phase 1 Success:
- ✅ Forensic report generated
- ✅ Likely cause identified (or "unknown" documented)
- ✅ MLS entry captured

### Phase 2 Success:
- ✅ All 4 processors installed & running
- ✅ Canary WO completes successfully
- ✅ Dashboard shows WOs
- ✅ 0 LaunchAgent exit 127 errors

### Phase 3 Success:
- ✅ Guardrail runs every 5 min
- ✅ Healthy heartbeats logged
- ✅ Alert test successful
- ✅ No false positives in 24h

### Phase 4 Success:
- ✅ History check utility works
- ✅ CLS uses history in next diagnosis
- ✅ Reports "worked, then broke" when appropriate

---

## Rollback Plan

### If Phase 2 Rebuild Fails:
```bash
# Unload LaunchAgents
launchctl unload ~/Library/LaunchAgents/com.02luka.apply_patch_processor.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.json_wo_processor.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.wo_executor.plist
launchctl unload ~/Library/LaunchAgents/com.02luka.followup_tracker.plist

# Remove processors
rm -rf ~/02luka/agents/{apply_patch_processor,json_wo_processor,wo_executor}

# Clear state
rm -rf ~/02luka/g/followup/state/*.json
```

### If Phase 3 Guardrail Causes Issues:
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.wo_pipeline_guardrail.plist
rm ~/Library/LaunchAgents/com.02luka.wo_pipeline_guardrail.plist
```

---

## Next Steps

1. **Approve SPEC & PLAN** ✅
2. **Create WO for Phase 1-4** (use WO creation pattern: 4 tasks = create WO)
3. **Execute Phase 1** (time-boxed 15 min)
4. **Execute Phase 2** (rebuild)
5. **Execute Phase 3** (guardrail)
6. **Execute Phase 4** (history-aware)
7. **Monitor for 48 hours**
8. **Capture MLS lessons**
9. **Plan Phase 5: Tree Unification** (future)

---

**Ready for Execution:** ✅  
**Approval Required:** Boss  
**Estimated Completion:** Nov 14, 09:30
