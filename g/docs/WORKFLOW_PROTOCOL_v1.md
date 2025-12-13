# Workflow Protocol v1
**Status:** Active - **FUNDAMENTAL WORKING METHOD**  
**Last Updated:** 2025-12-14  
**Purpose:** Standard development workflow for all code changes and system modifications

---

## Overview

**⚠️ CRITICAL: This is the BASIC, FUNDAMENTAL way to work. Not optional. Not a suggestion.**

This protocol defines the mandatory workflow for all development tasks, ensuring quality, safety, and systematic problem-solving.

**Core Principle:** Never run changes directly. Always plan, dry-run, verify, and only execute after validation.

---

## 🚨 Before You Start - READ THIS FIRST

**Before suggesting, proposing, or executing ANY change, complete:**

**Pre-Action Checklist:** `g/docs/WORKFLOW_PRE_ACTION_CHECKLIST.md`

**Quick Check:**
- [ ] Have I created a plan?
- [ ] Have I defined the spec/goal?
- [ ] Have I done a dry-run?
- [ ] Have I verified the dry-run results?
- [ ] Do I have evidence/logs to support my claim?

**If ANY checkbox is unchecked → STOP and complete it first.**

**Remember:** Verification is proof. Without proof, there is no claim.

**Why This Matters:**
- **Safety:** Prevents destructive mistakes
- **Accuracy:** Avoids overclaiming without verification
- **Reliability:** Ensures changes work before claiming success
- **Trust:** Builds confidence through demonstrated validation

**Default Mode:** This workflow is the default operating mode. Any deviation requires explicit justification.

---

## Workflow Phases

### Phase 1: Planning & Specification

**1.1 Make Plan**
- Break down the task into clear, actionable steps
- Identify dependencies and prerequisites
- Estimate complexity and risks
- Document assumptions and constraints

**1.2 Make Spec**
- Define detailed requirements and acceptance criteria
- Specify inputs, outputs, and expected behavior
- Document edge cases and error handling
- Create test cases (if applicable)

**1.3 Define Goal**
- State the clear, measurable objective
- Define success criteria
- Identify what "done" looks like
- Set validation checkpoints

**Deliverables:**
- Plan document (`.md` file in `g/reports/` or `g/docs/`)
- Specification document (if complex)
- Goal statement with success criteria

---

### Phase 2: Dry-Run & Verification

**2.1 Dry-Run**
- Execute the plan in a non-destructive mode
- Use `-n`, `--dry-run`, or simulation flags
- Test with sample data or test environments
- Verify logic and flow without making real changes

**2.2 Verify**
- Check dry-run output against expected results
- Validate that all steps would execute correctly
- Confirm no unintended side effects
- Review logs and intermediate states

**Verification Checklist:**
- [ ] All commands/scripts execute without errors
- [ ] Output matches expected format and content
- [ ] No destructive operations would occur
- [ ] Edge cases are handled correctly
- [ ] Error paths are tested

---

### Phase 3: Decision Branch

#### Branch A: Dry-Run Passes ✅

**3A.1 Run (Execute)**
- Execute the actual changes
- Monitor execution closely
- Capture logs and outputs
- Verify final state matches expectations

**3A.2 Post-Execution Verification**
- Confirm all changes applied correctly
- Run validation checks
- Test functionality (if applicable)
- Document results

**Success Criteria:**
- All changes applied as expected
- System state matches specification
- No errors or warnings
- Tests pass (if applicable)

---

#### Branch B: Dry-Run Fails ❌

**3B.1 Debug**
- Analyze failure points
- Review logs and error messages
- Identify root causes
- Document findings

**3B.2 Optimize**
- Fix identified issues
- Improve error handling
- Refine logic or approach
- Update plan/spec if needed

**3B.3 Re-Verify**
- Run dry-run again with fixes
- Check if issues are resolved
- Validate improvements

**Iteration Rule:**
- **Minimum 3 optimization cycles** before declaring failure
- Each cycle must address different aspects or root causes
- Document each attempt and its outcome

**3B.4 Final Decision**

**If Passes After Optimization:**
- Proceed to **3A.1 Run (Execute)**

**If Still Fails After 3+ Cycles:**
- **Report Failure**
  - Document all attempts and findings
  - Explain why the approach didn't work
  - Identify blockers or limitations
  - Suggest alternative approaches (if any)
  - Create failure report in `g/reports/system/`

---

## Workflow Diagram

```
┌─────────────────────────────────┐
│ Phase 1: Planning & Specification│
│ 1. Make Plan                     │
│ 2. Make Spec                     │
│ 3. Define Goal                   │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ Phase 2: Dry-Run & Verification │
│ 4. Dry-Run                      │
│ 5. Verify                       │
└────────────┬────────────────────┘
             │
        ┌────┴────┐
        │         │
        ▼         ▼
    ┌───────┐  ┌──────────────┐
    │ PASS  │  │  NOT PASS    │
    └───┬───┘  └───┬──────────┘
        │          │
        │          ▼
        │    ┌─────────────────┐
        │    │ 6. Debug        │
        │    │ 7. Optimize     │
        │    │ 8. Re-Verify    │
        │    └───┬─────────────┘
        │        │
        │    ┌───┴───┐
        │    │       │
        │    ▼       ▼
        │  PASS   FAIL (3+ cycles)
        │    │       │
        │    │       └──► Report Failure
        │    │
        └────┘
           │
           ▼
    ┌──────────────┐
    │ 9. Run       │
    │ (Execute)    │
    └──────────────┘
```

---

## Examples

### Example 1: Script Modification

**Phase 1:**
- **Plan:** Add PATH-safe helpers to `bootstrap_workspace.zsh`
- **Spec:** Replace all `mkdir`, `rm`, `ln` calls with `/bin/mkdir`, `/bin/rm`, `/bin/ln`
- **Goal:** Script works in restricted PATH environments

**Phase 2:**
- **Dry-Run:** Test script with `set -n` or in test directory
- **Verify:** Check that all commands use absolute paths

**Phase 3:**
- **If Pass:** Apply changes to actual script
- **If Fail:** Debug PATH issues, optimize 3+ times, report if still failing

### Example 2: Git Operation

**Phase 1:**
- **Plan:** Untrack workspace paths from Git
- **Spec:** Use `git rm --cached` for `g/data`, `g/telemetry`, etc.
- **Goal:** Paths removed from Git index but data preserved

**Phase 2:**
- **Dry-Run:** `git rm --cached -n g/data` (check what would happen)
- **Verify:** Confirm it shows removal without `--force` deletion

**Phase 3:**
- **If Pass:** Execute `git rm --cached` commands
- **If Fail:** Debug Git state, optimize approach, report blockers

---

## Enforcement

### Pre-Execution Checklist

Before running any changes, verify:
- [ ] Plan documented
- [ ] Spec defined (if complex)
- [ ] Goal clear and measurable
- [ ] Dry-run completed
- [ ] Dry-run verified and passed
- [ ] OR: 3+ optimization cycles completed (if dry-run failed)

### Documentation Requirements

**For All Tasks:**
- Plan document in `g/reports/` or `g/docs/`
- Dry-run results logged
- Execution results documented

**For Failures:**
- Failure report in `g/reports/system/`
- All optimization attempts documented
- Root cause analysis included
- Alternative approaches suggested

---

## Integration with Other Protocols

This workflow protocol integrates with:
- **CONTEXT_ENGINEERING_PROTOCOL_v4.md** - For context loading and persona management
- **AI_OP_001_v4.md** - For AI operation guidelines
- **ADR_001_workspace_split.md** - For architectural decisions

---

## Version History

- **v1 (2025-12-14):** Initial protocol definition
  - Based on Phase C testing experience
  - Emphasizes dry-run → verify → optimize cycle
  - Mandates minimum 3 optimization attempts before failure

---

## Quick Reference

**For Simple Tasks:**
1. Plan (brief)
2. Dry-run
3. Verify → Pass → Run
4. Verify → Fail → Debug/Optimize (3x) → Report if still failing

**For Complex Tasks:**
1. Plan (detailed)
2. Spec (comprehensive)
3. Goal (measurable)
4. Dry-run (thorough)
5. Verify → Pass → Run
6. Verify → Fail → Debug/Optimize (3x) → Report if still failing

---

## Enforcement & Mindset

**This is NOT optional. This is HOW you work.**

**Before claiming ANY success:**
- ✅ Must have completed dry-run
- ✅ Must have verified results
- ✅ Must have evidence/logs
- ❌ Never claim success without verification
- ❌ Never skip dry-run "to save time"
- ❌ Never assume it will work

**The Safety Rule:**
> "If I haven't dry-run and verified it, I don't know if it works. Therefore, I cannot claim it works."

**The Overclaim Prevention:**
> "Verification is proof. Without proof, there is no claim."

---

**Remember:** Quality over speed. A well-verified dry-run prevents costly mistakes. **This is your fundamental working method.**

---

## 📊 End-of-Task: Telemetry & Report

**After completing any task, ALWAYS:**

1. **Check Telemetry:**
   ```bash
   # Save sessions
   tail -3 g/telemetry/save_sessions.jsonl
   
   # Other telemetry
   ls -lt g/telemetry/*.jsonl | head -5
   ```

2. **Create Completion Report:**
   - Use template: `g/docs/TASK_COMPLETION_REPORT_TEMPLATE.md`
   - Document all tasks, commits, telemetry
   - Include verification evidence
   - Save to: `g/reports/system/task_completion_report_YYYYMMDD.md`

3. **Verify Tracking:**
   - All commits logged
   - Telemetry entries present
   - Session files created
   - Report complete

**Why:** Enables tracking back all work, auditability, and rollback capability.
