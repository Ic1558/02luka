# Feature SPEC: WO Pipeline Durability & Persistence

**Created:** 2025-11-13 23:30  
**Priority:** P0 (Critical - System Reliability)  
**Owner:** CLS → CLC/Mary  
**Status:** Planning

---

## Problem Statement

### The Root Issue

**Pattern Observed:**
```
Agent A (CLC): "Fixed apply_patch_processor ✅" (Nov 13 01:50)
→ 21 hours later →
Agent B (CLS): "Everything is missing ❌" (Nov 13 22:43)
```

**Why This Happens:**

1. **No Durability Guarantee**
   - Critical agent installs are not protected from rollback
   - No snapshot/checkpoint before destructive operations
   - No verification that fixes persist

2. **Multiple Trees / No SSOT**
   - Multiple working copies (`~/02luka`, `~/LocalProjects/02luka-memory`, etc.)
   - Rollback scripts don't know which tree is "the real one"
   - rsync/sync operations can overwrite recent work

3. **Agent Diagnostic Blindness**
   - CLS only looked at current filesystem state
   - Didn't check git history
   - Didn't check MLS entries
   - Didn't check recent rollback logs
   - Assumed "never worked" instead of "worked, then broke"

### The Brutal Truth

**Current Guarantee:** NONE

"CLC fixed and verified → I expect that to stay true unless I explicitly undo it."

**This does NOT exist today.**

Things can be silently rolled back by:
- Rollback scripts (`tools/rollback_*.zsh`)
- rsync operations
- Git operations (`git reset --hard`, `git checkout .`)
- Different working copy activation
- LaunchAgent failures (exit 127 → script missing)

**Result:**
```
"Agent A: fixed ✅" 
→ some hours/tools later → 
"Agent B: but it's broken now ❌"
```

---

## Objectives

### Primary Goal

**Create a durability guarantee for critical WO pipeline components:**

1. Critical processors survive rollbacks
2. Agents check history before diagnosing
3. System alerts when critical components vanish
4. One SSOT for all agents

### Success Criteria

✅ **Durability:**
- Critical agent installs persist across rollbacks
- Rollback scripts protect critical components
- Snapshot taken before destructive operations

✅ **Observability:**
- Agents check git history before diagnosing
- Agents check MLS entries for recent changes
- Agents check rollback logs
- Clear audit trail: "What changed and when?"

✅ **Monitoring:**
- Guardrail detects missing critical files within 5 minutes
- Auto-alert to telemetry
- Optional: Auto-repair WO

✅ **SSOT:**
- One canonical working tree
- All agents use same SOT path
- Clear documentation: "This is the production tree"

---

## Scope

### In Scope

**Phase 1: Forensics (Time-boxed 10-15 min)**
- Git history analysis (Nov 13 01:50 - 22:43)
- Rollback script analysis
- LaunchAgent log review
- Identify: What killed CLC's work?

**Phase 2: WO Pipeline Rebuild**
- Restore critical processors:
  - `agents/apply_patch_processor/apply_patch_processor.zsh`
  - `agents/json_wo_processor/json_wo_processor.zsh`
  - `agents/wo_executor/wo_executor.zsh`
  - `tools/followup_tracker_update.zsh`
- Create proper LaunchAgents
- Create `g/followup/state/` structure
- Deploy "canary WO" for end-to-end test
- **Use CLC's work as reference, not blind copy**

**Phase 3: Persistence Layer**
- Guardrail script:
  - Checks critical files exist & executable
  - Runs every 5 minutes (LaunchAgent)
  - Logs drift events to telemetry
  - Optional: Auto-repair WO
- Protected component list (do not rollback):
  - `agents/apply_patch_processor/`
  - `agents/json_wo_processor/`
  - `agents/wo_executor/`
  - `g/followup/state/`
  - `tools/followup_tracker_update.zsh`
- Rollback script updates:
  - Check protected components
  - Require `--force` flag to rollback protected items
  - Log all rollback operations

**Phase 4: Agent Diagnostic Enhancement**
- CLS history check before diagnosis:
  - Git log (last 24 hours)
  - MLS entries (relevant tags)
  - Rollback logs (recent operations)
- New diagnosis pattern:
  ```
  1. Check current state
  2. Check history (git/MLS/logs)
  3. Determine: "Never worked" vs "Worked, then broke"
  4. If broke: Identify when and why
  5. Then propose fix
  ```

### Out of Scope

- Multi-tree unification (future work)
- Complete rollback system redesign
- Backup/restore infrastructure
- Git workflow changes

---

## Technical Design

### Component 1: Forensic Script

**File:** `tools/forensic_wo_pipeline_check.zsh`

**Purpose:** Time-boxed investigation (10-15 min max)

**Checks:**
1. Git history:
   ```bash
   git log --oneline --since="2025-11-13 01:50" --until="2025-11-13 22:43"
   git diff HEAD~20..HEAD -- agents/ g/followup/
   git log -p --all --full-history -- agents/apply_patch_processor/
   ```

2. Rollback scripts:
   ```bash
   grep -l "agents/apply_patch_processor" tools/rollback_*.zsh
   grep -l "g/followup/state" tools/rollback_*.zsh
   cat tools/rollback_phase6_week1_20251113.zsh
   ```

3. LaunchAgent logs:
   ```bash
   ls -lht ~/Library/Logs/*apply_patch*
   grep "exit 127\|command not found" ~/Library/Logs/*.log
   ```

**Output:**
- JSON summary: `g/reports/forensic_wo_pipeline_20251113.json`
- MLS entry with findings

---

### Component 2: WO Pipeline Rebuild

**Approach:** Create WO that rebuilds from scratch (using CLC's pattern)

**WO File:** `bridge/inbox/CLC/WO-20251113-WO-PIPELINE-REBUILD.yaml`

**Components to Create:**

1. **apply_patch_processor:**
   ```yaml
   files:
     - path: agents/apply_patch_processor/apply_patch_processor.zsh
       content: |
         #!/usr/bin/env zsh
         # [Full processor script from CLC's pattern]
         # With absolute paths: /usr/bin/date, /bin/mv, etc.
   ```

2. **json_wo_processor:**
   ```yaml
   files:
     - path: agents/json_wo_processor/json_wo_processor.zsh
       content: |
         #!/usr/bin/env zsh
         # [Processor for JSON WOs]
   ```

3. **wo_executor:**
   ```yaml
   files:
     - path: agents/wo_executor/wo_executor.zsh
       content: |
         #!/usr/bin/env zsh
         # [Main WO execution engine]
   ```

4. **followup_tracker:**
   ```yaml
   files:
     - path: tools/followup_tracker_update.zsh
       content: |
         #!/usr/bin/env zsh
         # [State file tracker]
   ```

5. **LaunchAgents:**
   - `~/Library/LaunchAgents/com.02luka.apply_patch_processor.plist`
   - `~/Library/LaunchAgents/com.02luka.json_wo_processor.plist`
   - `~/Library/LaunchAgents/com.02luka.wo_executor.plist`
   - `~/Library/LaunchAgents/com.02luka.followup_tracker.plist`

6. **State directory:**
   ```bash
   mkdir -p ~/02luka/g/followup/state
   ```

7. **Canary WO:**
   ```yaml
   # Tiny test WO to verify end-to-end
   wo_id: WO-CANARY-20251113
   title: "Pipeline Test"
   type: apply_patch
   files:
     - path: tmp/canary_test.txt
       content: "Pipeline working at $(date)"
   ```

**Verification:**
- All 5 LaunchAgents running (not exit 127)
- Canary WO creates state file
- Telemetry entry written
- Dashboard shows canary WO

---

### Component 3: Guardrail System

**File:** `tools/wo_pipeline_guardrail.zsh`

**Purpose:** Detect drift/deletion of critical components

**Logic:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

CRITICAL_FILES=(
  "agents/apply_patch_processor/apply_patch_processor.zsh"
  "agents/json_wo_processor/json_wo_processor.zsh"
  "agents/wo_executor/wo_executor.zsh"
  "tools/followup_tracker_update.zsh"
)

CRITICAL_DIRS=(
  "g/followup/state"
)

for file in "${CRITICAL_FILES[@]}"; do
  if [[ ! -f ~/02luka/$file ]]; then
    # Log to telemetry
    echo "{\"ts\":\"$(date -u +%FT%TZ)\",\"agent\":\"guardrail\",\"event\":\"wo_pipeline_drift\",\"missing\":\"$file\"}" >> ~/02luka/g/telemetry/unified.jsonl
    
    # Optional: Auto-repair
    # cat > ~/02luka/bridge/inbox/CLC/WO-AUTOREPAIR-$(date +%s).yaml <<EOF
    # ...
    # EOF
  fi
done

for dir in "${CRITICAL_DIRS[@]}"; do
  if [[ ! -d ~/02luka/$dir ]]; then
    echo "{\"ts\":\"$(date -u +%FT%TZ)\",\"agent\":\"guardrail\",\"event\":\"wo_pipeline_drift\",\"missing\":\"$dir\"}" >> ~/02luka/g/telemetry/unified.jsonl
  fi
done
```

**LaunchAgent:** `com.02luka.wo_pipeline_guardrail.plist`
- Runs every 5 minutes
- KeepAlive: false (one-shot per interval)
- Logs to: `~/02luka/logs/guardrail.log`

---

### Component 4: Protected Rollback

**Modify ALL rollback scripts:**

**Pattern:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

# Protected components (do not rollback unless --force)
PROTECTED=(
  "agents/apply_patch_processor"
  "agents/json_wo_processor"
  "agents/wo_executor"
  "g/followup/state"
)

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

if [[ "$FORCE" == "false" ]]; then
  echo "⚠️  Protected components will NOT be rolled back:"
  for item in "${PROTECTED[@]}"; do
    echo "  - $item"
  done
  echo ""
  echo "Add --force to rollback everything (including protected)"
  echo ""
fi

# Rollback logic...
for item in "${PROTECTED[@]}"; do
  if [[ "$FORCE" == "false" ]]; then
    echo "SKIP: $item (protected)"
    continue
  fi
  # ... actual rollback
done
```

---

### Component 5: History-Aware Diagnosis

**Pattern for CLS:**

**Before:**
```
1. Check filesystem
2. Report current state
3. Propose fix
```

**After:**
```
1. Check filesystem (current state)
2. Check git log (last 24h)
3. Check MLS entries (relevant tags: wo, pipeline, processor)
4. Check rollback logs (~/02luka/logs/rollback_*.log)
5. Determine:
   a. Never worked → Create from scratch
   b. Worked, then broke → Identify when/why → Restore/rebuild
6. Report: "Current state + Recent history"
7. Propose fix (informed by history)
```

**Implementation:**
```zsh
# In any diagnostic script
check_recent_history() {
  local component="$1"
  
  # Git
  git log --oneline --since="24 hours ago" -- "$component" | head -10
  
  # MLS
  grep "$component" ~/02luka/mls/ledger/$(date +%Y-%m-%d).jsonl 2>/dev/null | tail -5
  
  # Rollback logs
  grep "$component" ~/02luka/logs/rollback_*.log 2>/dev/null | tail -5
}
```

---

## Dependencies

### Required for Phase 1 (Forensics):
- Git repository exists
- Access to git log
- Access to rollback scripts
- Access to LaunchAgent logs

### Required for Phase 2 (Rebuild):
- CLC's original script pattern (from Nov 13 01:50)
- Access to `bridge/inbox/CLC/`
- Ability to create LaunchAgents
- Ability to load LaunchAgents

### Required for Phase 3 (Guardrail):
- Telemetry system working
- LaunchAgent system working
- MLS capture working

### Required for Phase 4 (History-Aware):
- Git history accessible
- MLS ledger accessible
- Rollback logs exist

---

## Risk Assessment

### High Risk

**R1: Rebuild may not match current system**
- Mitigation: Use CLC's pattern as reference, adapt to current state
- Mitigation: Test with canary WO first

**R2: Guardrail creates alert fatigue**
- Mitigation: Start with logging only (no auto-repair)
- Mitigation: Monitor for 48 hours before enabling auto-repair

**R3: Protected rollback breaks emergency recovery**
- Mitigation: `--force` flag available
- Mitigation: Document when to use --force

### Medium Risk

**R4: Multiple trees still exist**
- Mitigation: Document canonical path in SPEC
- Mitigation: Phase 2 of this project: Unify trees

**R5: History-aware diagnosis too slow**
- Mitigation: Time-box history checks to 30 seconds max
- Mitigation: Cache recent git/MLS lookups

### Low Risk

**R6: Canary WO pollutes real WO queue**
- Mitigation: Use special prefix: `WO-CANARY-`
- Mitigation: Auto-cleanup canary state files after 24h

---

## Success Metrics

### Quantitative

1. **Pipeline Uptime:** ≥99% (measured every 5 min by guardrail)
2. **Detection Time:** Missing component detected within 5 minutes
3. **Recovery Time:** Auto-repair completes within 15 minutes
4. **False Positives:** <1% (guardrail doesn't fire when system is healthy)

### Qualitative

1. **Agent Confidence:** "CLC fixed it → stays fixed"
2. **No Silent Failures:** If pipeline breaks, telemetry shows exactly when/why
3. **Clear Audit Trail:** Git + MLS + Logs tell complete story
4. **Reproducible Rebuilds:** WO-PIPELINE-REBUILD works consistently

---

## Rollback Plan

### If Guardrail Causes Issues:
```bash
launchctl unload ~/Library/LaunchAgents/com.02luka.wo_pipeline_guardrail.plist
```

### If Rebuild Breaks System:
- Use existing rollback script with `--force`
- Clear `g/followup/state/`
- Remove new LaunchAgents

### If Protected Rollback Blocks Recovery:
- All rollback scripts support `--force` flag
- Document: "When to use --force" in runbook

---

## Future Work

### Phase 2: Tree Unification
- Identify all working trees
- Choose canonical SOT
- Archive/remove non-canonical trees
- Update all agents to use canonical path

### Phase 3: Backup/Restore
- Snapshot critical components before rollback
- Restore from snapshot if drift detected
- Integrate with Time Machine or git stash

### Phase 4: Test Coverage
- Unit tests for each processor
- Integration tests for full pipeline
- CI tests run before any rollback

---

## References

- CLC Chat Archive: `02luka-memory/Boss/Chat archive/clc_251112.txt`
- CLS Analysis: `02luka/g/reports/ANALYSIS_CLS_vs_CLC_20251113.md`
- Session Log: `02luka-memory/g/reports/sessions/session_20251113_145301.md`
- MLS Entry: `MLS-1763048919` (CLC Work Lost pattern)
- MLS Entry: `MLS-1763049946` (CLS vs CLC Analysis)

---

**Next:** Create detailed PLAN document with task breakdown and timeline.
