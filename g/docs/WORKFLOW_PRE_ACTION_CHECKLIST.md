# Pre-Action Checklist
**CRITICAL: Complete this checklist BEFORE suggesting any action**

---

## ⚠️ Mandatory Checklist

**Before suggesting, proposing, or executing ANY change, verify:**

- [ ] **Plan Created**
  - Task broken down into clear steps
  - Dependencies identified
  - Risks assessed

- [ ] **Spec Defined**
  - Requirements clear
  - Acceptance criteria set
  - Expected behavior documented

- [ ] **Goal Stated**
  - Objective is measurable
  - Success criteria defined
  - "Done" condition clear

- [ ] **Dry-Run Completed**
  - Tested without making real changes
  - Used `-n`, `--dry-run`, or simulation
  - Verified logic and flow

- [ ] **Dry-Run Verified**
  - Output matches expectations
  - No unintended side effects
  - Edge cases handled

- [ ] **Evidence Available**
  - Logs/outputs captured
  - Results documented
  - Proof of verification

- [ ] **Ready to Execute** (if dry-run passed)
  - All checks passed
  - Safe to proceed
  - Rollback plan (if needed)

---

## 🚨 Stop Conditions

**STOP and complete missing steps if:**
- Any checkbox above is unchecked
- No dry-run was performed
- No verification evidence exists
- Claiming success without proof

---

## ✅ Example: Correct Workflow

**Task:** Modify a script

1. ✅ **Plan:** "I'll add PATH-safe helpers to script X"
2. ✅ **Spec:** "Replace all `mkdir` with `/bin/mkdir`, test in restricted PATH"
3. ✅ **Goal:** "Script works in restricted PATH environments"
4. ✅ **Dry-Run:** Test script with `set -n` or in test directory
5. ✅ **Verify:** Check all commands use absolute paths
6. ✅ **Evidence:** Show dry-run output/logs
7. ✅ **Execute:** Apply changes (only after all above complete)

---

## ❌ Example: Incorrect Workflow

**Task:** Modify a script

1. ❌ **Skip Plan:** "I'll just modify it"
2. ❌ **Skip Dry-Run:** "It should work"
3. ❌ **Claim Success:** "Done! Script is fixed"
4. ❌ **No Evidence:** No logs or verification

**Result:** Overclaiming, no proof, potential issues

---

## 📝 Quick Reference

**Before ANY action:**
1. Plan it
2. Spec it
3. Goal it
4. Dry-run it
5. Verify it
6. Evidence it
7. Then execute (if all pass)

**Remember:** Verification is proof. Without proof, there is no claim.

---

**Print this checklist and reference it for every task.**
