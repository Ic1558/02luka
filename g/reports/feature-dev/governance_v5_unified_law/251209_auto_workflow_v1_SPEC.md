# Auto Workflow v1 — Fully Automatic Execution

**Date:** 2025-12-10  
**Status:** 📋 SPEC  
**Authority:** Boss Directive

---

## 🎯 Core Principle

**Fully Automatic from Beginning to End:**
- No Boss approval required at any step
- Auto-redesign if quality not met
- Final report generated automatically
- Boss only reviews final result

---

## 🔄 Workflow Stages

### Stage 1: Design Phase (Auto)
```
PLAN → SPEC → REVIEW → [Quality Gate] → Continue or REDESIGN
```

### Stage 2: Implementation Phase (Auto)
```
DRYRUN → CODE-REVIEW (Gate 2.5) → VERIFY → [Quality Gate] → Continue or REDESIGN
```

### Stage 3: Execution Phase (Auto)
```
IMPLEMENT → TEST → [Gate 3] → Continue or REDESIGN
```

### Stage 4: Finalization (Auto)
```
VALIDATE → SCORE → [Gate 4: Production Readiness ≥90%] → DONE or REDESIGN
```

**Tool:** `zsh tools/run_tool.zsh feature-dev-validate <feature-slug>`
**Auto Executor:** `zsh tools/run_tool.zsh auto-workflow <feature-slug>` (includes validation automatically)

---

## 🎯 Quality Gates

### Gate 1: Design Quality
**Check:** PLAN + SPEC completeness
- ✅ All required sections present
- ✅ Integration points defined
- ✅ Test strategy defined
- ✅ Success criteria measurable

**If FAIL:** → REDESIGN (improve PLAN/SPEC)

---

### Gate 2.5: Code Review (Fast Gate)
**Check:** Code review gate (style, history, bugs)
- ✅ Style check passed
- ✅ No obvious bugs
- ✅ No critical security issues
- ✅ Diff hotspots identified

**Tool:** `zsh tools/code_review_gate.zsh <target>`
**Cache:** Uses `g/.cache/code_review_cache.json` for fast lookup
**Catalog:** Uses `catalog_lookup.zsh` for tool discovery (single source of truth)

**If FAIL:** → REDESIGN (fix issues) or continue with warnings

---

### Gate 2: Code Quality
**Check:** DRYRUN code quality
- ✅ All functions implemented
- ✅ Integration points correct
- ✅ Error handling present
- ✅ Documentation complete
- ✅ Code review passed (Gate 2.5)

**If FAIL:** → REDESIGN (improve code)

---

### Gate 3: Verification Quality
**Check:** VERIFY results
- ✅ Score >= 90/100
- ✅ No critical blockers
- ✅ All test cases pass

**If FAIL:** → REDESIGN (fix issues)

---

### Gate 4: Implementation Quality
**Check:** IMPLEMENT results
- ✅ Files created successfully
- ✅ No linter errors
- ✅ Integration tests pass

**If FAIL:** → REDESIGN (fix implementation)

---

### Gate 5: Final Report Quality
**Check:** REPORT completeness
- ✅ All stages documented
- ✅ Results summarized
- ✅ Next steps clear

**If FAIL:** → REDESIGN (improve report)

---

## 🔄 Auto-Redesign Logic

### Redesign Triggers
1. Quality gate fails
2. Score < 90/100
3. Critical blockers found
4. Integration failures

### Redesign Process
```
1. Analyze failure reason
2. Identify root cause
3. Redesign affected component
4. Retry from appropriate stage
5. Max retries: 3
```

### Redesign Strategy
- **Design failures:** Improve PLAN/SPEC
- **Code failures:** Fix implementation
- **Integration failures:** Fix integration points
- **Quality failures:** Enhance quality

---

## 📊 Final Report Format

### Automatic Report Generation
```markdown
# [Feature Name] — Auto Execution Report

**Date:** YYYY-MM-DD
**Status:** ✅ COMPLETE / ⚠️ PARTIAL / ❌ FAILED
**Score:** X/100

## Execution Summary
- Stages completed: X/Y
- Redesigns: N
- Final status: [Status]

## Results
- [Stage 1]: ✅ PASS
- [Stage 2]: ✅ PASS
- [Stage 3]: ✅ PASS

## Files Created
- [List of files]

## Next Steps
- [Auto-generated recommendations]
```

---

## 🎯 Implementation Rules

### Rule 1: No Boss Approval Required
- ✅ All stages execute automatically
- ✅ No "ASK BOSS" steps
- ✅ Final report only

### Rule 2: Auto-Redesign on Failure
- ✅ Quality gate fails → Auto-redesign
- ✅ Max 3 retries per stage
- ✅ If still fails → Report failure with analysis

### Rule 3: Quality Threshold
- ✅ Minimum score: 90/100
- ✅ No critical blockers
- ✅ All integrations working

### Rule 4: Final Report Always Generated
- ✅ Report created regardless of success/failure
- ✅ Includes full execution history
- ✅ Includes redesign attempts
- ✅ Includes recommendations

---

## 🔧 Execution Flow

```
START
  ↓
PLAN (auto)
  ↓
SPEC (auto)
  ↓
REVIEW (auto)
  ↓
[Quality Gate 1]
  ├─ PASS → Continue
  └─ FAIL → REDESIGN → Retry from PLAN
  ↓
DRYRUN (auto)
  ↓
VERIFY (auto)
  ↓
[Quality Gate 2]
  ├─ PASS → Continue
  └─ FAIL → REDESIGN → Retry from DRYRUN
  ↓
IMPLEMENT (auto)
  ↓
TEST (auto)
  ↓
[Quality Gate 3]
  ├─ PASS → Continue
  └─ FAIL → REDESIGN → Retry from IMPLEMENT
  ↓
REPORT (auto)
  ↓
[Quality Gate 4]
  ├─ PASS → DONE
  └─ FAIL → REDESIGN → Retry from REPORT
  ↓
FINAL REPORT
```

---

## 📝 Quality Gate Implementation

### Quality Gate Function
```python
def check_quality_gate(stage: str, result: Dict) -> Tuple[bool, List[str]]:
    """
    Check quality gate for stage.
    
    Returns:
        (passed, issues)
    """
    issues = []
    
    if stage == "DESIGN":
        # Check PLAN + SPEC completeness
        if not result.get("plan_complete"):
            issues.append("PLAN incomplete")
        if not result.get("spec_complete"):
            issues.append("SPEC incomplete")
        if result.get("score", 0) < 80:
            issues.append(f"Design score too low: {result.get('score')}")
    
    elif stage == "CODE":
        # Check DRYRUN code quality
        if not result.get("all_functions_implemented"):
            issues.append("Missing functions")
        if result.get("linter_errors"):
            issues.append(f"Linter errors: {len(result['linter_errors'])}")
        if result.get("score", 0) < 90:
            issues.append(f"Code score too low: {result.get('score')}")
    
    elif stage == "VERIFY":
        # Check verification results
        if result.get("score", 0) < 90:
            issues.append(f"Verification score too low: {result.get('score')}")
        if result.get("critical_blockers"):
            issues.append(f"Critical blockers: {len(result['critical_blockers'])}")
    
    elif stage == "IMPLEMENT":
        # Check implementation results
        if not result.get("files_created"):
            issues.append("No files created")
        if result.get("errors"):
            issues.append(f"Implementation errors: {len(result['errors'])}")
    
    passed = len(issues) == 0
    return (passed, issues)
```

---

## 🔄 Auto-Redesign Implementation

### Redesign Function
```python
def auto_redesign(stage: str, failure_reason: List[str]) -> Dict:
    """
    Auto-redesign based on failure reason.
    
    Returns:
        Redesign plan
    """
    redesign_plan = {
        "stage": stage,
        "failure_reasons": failure_reason,
        "redesign_strategy": [],
        "retry_count": 0
    }
    
    # Analyze failure and create redesign strategy
    for reason in failure_reason:
        if "incomplete" in reason.lower():
            redesign_plan["redesign_strategy"].append("Enhance completeness")
        elif "score" in reason.lower():
            redesign_plan["redesign_strategy"].append("Improve quality")
        elif "error" in reason.lower():
            redesign_plan["redesign_strategy"].append("Fix errors")
        elif "blocker" in reason.lower():
            redesign_plan["redesign_strategy"].append("Resolve blockers")
    
    return redesign_plan
```

---

## 📊 Final Report Template

```markdown
# [Feature Name] — Auto Execution Report

**Date:** YYYY-MM-DD HH:MM:SS
**Status:** ✅ COMPLETE / ⚠️ PARTIAL / ❌ FAILED
**Final Score:** X/100
**Total Time:** X hours Y minutes
**Redesigns:** N

---

## Execution Summary

### Stages Completed
- ✅ PLAN: Complete (Score: X/100)
- ✅ SPEC: Complete (Score: X/100)
- ✅ REVIEW: Complete (Score: X/100)
- ✅ DRYRUN: Complete (Score: X/100)
- ✅ VERIFY: Complete (Score: X/100)
- ✅ IMPLEMENT: Complete
- ✅ REPORT: Complete

### Redesign History
- Redesign #1: [Stage] - [Reason] - [Result]
- Redesign #2: [Stage] - [Reason] - [Result]

---

## Results

### Files Created
- `path/to/file1.py` (X lines)
- `path/to/file2.zsh` (X lines)
- `path/to/file3.md` (X lines)

### Quality Scores
- Design: X/100
- Code: X/100
- Verification: X/100
- Overall: X/100

### Test Results
- Unit Tests: X/Y passed
- Integration Tests: X/Y passed
- Performance Tests: X/Y passed

---

## Issues & Resolutions

### Issues Found
1. [Issue description] → [Resolution]

### Resolutions Applied
1. [Resolution description] → [Result]

---

## Next Steps

### Immediate
- [Auto-generated next steps]

### Recommendations
- [Auto-generated recommendations]

---

## Execution Log

```
[Timestamp] PLAN: Started
[Timestamp] PLAN: Complete (Score: X/100)
[Timestamp] SPEC: Started
[Timestamp] SPEC: Complete (Score: X/100)
[Timestamp] REVIEW: Started
[Timestamp] REVIEW: Complete (Score: X/100)
[Timestamp] DRYRUN: Started
[Timestamp] DRYRUN: Complete (Score: X/100)
[Timestamp] VERIFY: Started
[Timestamp] VERIFY: Complete (Score: X/100)
[Timestamp] IMPLEMENT: Started
[Timestamp] IMPLEMENT: Complete
[Timestamp] REPORT: Generated
```

---

**Status:** ✅ COMPLETE

**Last Updated:** YYYY-MM-DD HH:MM:SS
```

---

## 🎯 Implementation Status

**Workflow:** Fully Automatic  
**Boss Approval:** Not Required  
**Auto-Redesign:** Enabled  
**Final Report:** Always Generated

---

**Status:** ✅ SPEC Complete — Ready for Implementation

