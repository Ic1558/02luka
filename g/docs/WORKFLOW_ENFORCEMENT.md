# Workflow Protocol Enforcement Strategy
**Date:** 2025-12-14  
**Purpose:** Ensure workflow protocol is always followed

---

## 🎯 Problem

AI assistants may forget to follow workflow protocol (plan → dry-run → verify → run), leading to:
- Overclaiming without verification
- Skipping dry-runs
- Suggesting actions without evidence

---

## 🛡️ Enforcement Layers

### Layer 1: Pre-Action Checklist (CRITICAL)

**Before suggesting ANY action, AI must:**

```
✅ Pre-Action Checklist:
[ ] Have I created a plan?
[ ] Have I defined the spec/goal?
[ ] Have I done a dry-run?
[ ] Have I verified the dry-run results?
[ ] Do I have evidence/logs to support my claim?
[ ] Am I ready to execute (if dry-run passed)?
```

**If ANY checkbox is unchecked → STOP and complete it first.**

---

### Layer 2: Prominent Reminders

**Location 1: `.cursorrules` Header**
- Already added: "⚠️ FUNDAMENTAL WORKING METHOD" at top
- **Enhancement:** Add reminder before every major section

**Location 2: Workflow Protocol Document**
- Already marked as "FUNDAMENTAL WORKING METHOD"
- **Enhancement:** Add "Before You Start" section

**Location 3: System Architecture Docs**
- Reference workflow protocol in key decision points

---

### Layer 3: Validation Scripts

**Create:** `tools/validate_workflow_compliance.zsh`

**Checks:**
- Plan document exists (for complex changes)
- Dry-run logs present
- Verification evidence available
- No claims without proof

**Integration:**
- Pre-commit hook (warn mode)
- Manual validation before major changes

---

### Layer 4: Template System

**Create:** `g/docs/WORKFLOW_TEMPLATE.md`

**Purpose:**
- Standard format for plans
- Required sections checklist
- Verification evidence template

**Usage:**
- Copy template for each task
- Fill in required sections
- Reference during execution

---

### Layer 5: Reminder Prompts

**Add to `.cursorrules`:**

```markdown
## ⚠️ CRITICAL REMINDER - READ BEFORE EVERY ACTION

Before suggesting, proposing, or executing ANY change:

1. **Have I planned it?** (Break down steps)
2. **Have I specified it?** (Define requirements)
3. **Have I dry-run it?** (Test without changes)
4. **Have I verified it?** (Check results match expectations)
5. **Do I have proof?** (Logs, outputs, evidence)

**If NO to any question → Complete that step first.**

**Never suggest actions without dry-run and verification.**
```

---

## 📋 Implementation Plan

### Step 1: Create Pre-Action Checklist Template

**File:** `g/docs/WORKFLOW_PRE_ACTION_CHECKLIST.md`

**Content:**
- Copy-paste checklist
- Examples of each step
- Common mistakes to avoid

### Step 2: Enhance `.cursorrules`

**Add:**
- Prominent reminder section
- Pre-action checklist reference
- Examples of correct workflow

### Step 3: Create Workflow Template

**File:** `g/docs/WORKFLOW_TEMPLATE.md`

**Content:**
- Plan template
- Spec template
- Goal template
- Verification checklist

### Step 4: Create Validation Script

**File:** `tools/validate_workflow_compliance.zsh`

**Function:**
- Check for plan documents
- Verify dry-run logs exist
- Validate evidence present
- Warn if workflow not followed

### Step 5: Add Reminder to Workflow Protocol

**Enhance:** `g/docs/WORKFLOW_PROTOCOL_v1.md`

**Add:**
- "Before You Start" section
- Pre-action checklist
- Common failure patterns

---

## 🎯 Success Criteria

**Enforcement is working when:**
- AI always mentions dry-run before suggesting actions
- AI provides evidence/logs with claims
- AI asks "should I dry-run this first?" for new tasks
- No overclaiming without verification

---

## 🔄 Continuous Improvement

**Review monthly:**
- Are reminders effective?
- Are checklists being used?
- Are validation scripts catching issues?
- Update based on patterns

---

**Status:** Ready for implementation
