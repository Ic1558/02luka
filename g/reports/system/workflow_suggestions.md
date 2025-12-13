# Workflow Protocol Implementation Suggestions
**Date:** 2025-12-14  
**Context:** Phase C Complete, Workflow Protocol v1 Active

---

## 🎯 Current Status

✅ Phase A-C: Complete  
✅ Workflow Protocol v1: Documented and integrated into `.cursorrules`  
✅ All changes: Committed and pushed  
✅ System: Production-ready

---

## 💡 Suggestions (Prioritized)

### 1. **Workflow Compliance Validator** (High Priority)

**Purpose:** Automatically check if workflow protocol was followed before commits

**Implementation:**
- Create `tools/validate_workflow_compliance.zsh`
- Check for:
  - Plan document exists (for complex changes)
  - Dry-run logs present
  - Verification evidence
- Integrate into pre-commit hook (optional, warn-only)

**Benefits:**
- Enforces workflow protocol
- Catches missing dry-runs
- Prevents overclaiming

**Workflow:**
1. Plan: Create validator script
2. Spec: Check for plan/docs, dry-run logs, verification evidence
3. Goal: Warn if workflow steps missing
4. Dry-run: Test with sample commits
5. Verify: Check warnings appear correctly
6. Run: Add to pre-commit hook (warn mode)

---

### 2. **Quick Reference Card** (Medium Priority)

**Purpose:** One-page visual reference for workflow protocol

**Implementation:**
- Create `g/docs/WORKFLOW_QUICK_REF.md`
- Include:
  - Visual flowchart
  - Decision tree
  - Common commands (dry-run flags)
  - Checklist format

**Benefits:**
- Fast lookup during work
- Easy to share/reference
- Reduces cognitive load

**Workflow:**
1. Plan: Design quick ref structure
2. Spec: Define content sections
3. Goal: Single-page reference
4. Dry-run: Review format
5. Verify: Check completeness
6. Run: Create document

---

### 3. **Lessons Learned Documentation** (Medium Priority)

**Purpose:** Capture Phase C debugging insights for future reference

**Implementation:**
- Create `g/reports/system/phase_c_lessons_learned.md`
- Document:
  - PATH-safe scripting patterns
  - Array iteration gotchas (zsh)
  - Command substitution hanging issues
  - Bootstrap restoration process

**Benefits:**
- Prevents repeating mistakes
- Knowledge preservation
- Reference for similar issues

**Workflow:**
1. Plan: Identify key lessons
2. Spec: Structure lessons document
3. Goal: Comprehensive lessons doc
4. Dry-run: Review content
5. Verify: Check accuracy
6. Run: Create document

---

### 4. **Workflow Template Generator** (Low Priority)

**Purpose:** Generate plan/spec templates for new tasks

**Implementation:**
- Create `tools/generate_workflow_template.zsh`
- Generates:
  - Plan template
  - Spec template
  - Goal template
  - Checklist

**Benefits:**
- Consistency
- Time-saving
- Ensures completeness

**Workflow:**
1. Plan: Design template structure
2. Spec: Define template sections
3. Goal: Reusable templates
4. Dry-run: Test generation
5. Verify: Check output quality
6. Run: Create script

---

### 5. **PR-11 Monitoring Setup** (High Priority - Next Step)

**Purpose:** Begin 7-day stability window monitoring

**Implementation:**
- Review PR-11 requirements
- Set up monitoring scripts
- Create daily check-in process

**Benefits:**
- Validates production readiness
- Catches regressions early
- Builds confidence

**Workflow:**
1. Plan: Review PR-11 spec
2. Spec: Define monitoring metrics
3. Goal: 7-day stability window
4. Dry-run: Test monitoring scripts
5. Verify: Check data collection
6. Run: Start monitoring

---

### 6. **Cleanup Temporary Files** (Low Priority)

**Purpose:** Remove any remaining test/debug files

**Implementation:**
- Scan for temporary files:
  - `tools/debug_*.zsh`
  - `tools/test_*.zsh`
  - `/tmp/phase_c_*.log`
- Document cleanup in MLS

**Benefits:**
- Clean repository
- Reduces confusion
- Better organization

**Workflow:**
1. Plan: Identify temp files
2. Spec: Define cleanup scope
3. Goal: Clean repo state
4. Dry-run: List files to remove
5. Verify: Check no important files
6. Run: Remove files

---

## 🎯 Recommended Priority Order

1. **PR-11 Monitoring Setup** (Immediate - Next Step)
2. **Workflow Compliance Validator** (High Value)
3. **Lessons Learned Documentation** (Knowledge Preservation)
4. **Quick Reference Card** (Convenience)
5. **Workflow Template Generator** (Nice to Have)
6. **Cleanup Temporary Files** (Maintenance)

---

## 📋 Implementation Notes

**For Each Suggestion:**
- Follow workflow protocol (plan → spec → goal → dry-run → verify → run)
- Document in appropriate location
- Update `.cursorrules` if needed
- Capture learnings in MLS

**Success Criteria:**
- Each suggestion improves workflow compliance
- No shortcuts or skipping steps
- All changes verified before claiming success

---

**Status:** Suggestions ready for prioritization and implementation
