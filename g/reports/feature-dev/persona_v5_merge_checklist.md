# Persona v5 Merge Checklist

**Date:** 2025-12-18  
**PRs:** #407 (persona), #408 (governance)

---

## Merge Order (Recommended)

### 1. Merge PR #408 First ✅
**Reason:** PERSONA_MODEL_v5.md is the "law/capability model" that persona references → governance foundation should be in main first.

**PR:** https://github.com/Ic1558/02luka/pull/408  
**Files:**
- `g/docs/PERSONA_MODEL_v5.md` (new)
- `g/docs/HOWTO_TWO_WORLDS_v2.md` (reference update)

### 2. Merge PR #407 Next ✅
**Reason:** After #408 is in main, reference chain will be complete and readable.

**PR:** https://github.com/Ic1558/02luka/pull/407  
**Files:**
- `personas/GEMINI_PERSONA_v5.md` (new)

---

## Post-Merge Steps

### 3. Sync Local Main
```bash
cd ~/02luka
git checkout main
git fetch origin
git pull origin main
```

### 4. Cleanup Branches (Optional)
```bash
# Delete local branches (after merge confirmed)
git branch -d docs/gemini-persona-v5
git branch -d docs/governance-restore-persona-model-v5

# Delete remote branches (if auto-delete not enabled)
git push origin --delete docs/gemini-persona-v5
git push origin --delete docs/governance-restore-persona-model-v5
```

### 5. Verify Gemini CLI Can Read Documents
```bash
# Test in Gemini CLI
cd ~/02luka
zsh tools/gemini_full_feature.zsh

# In Gemini CLI, try:
# @personas/GEMINI_PERSONA_v5.md
# @g/docs/PERSONA_MODEL_v5.md
```

**Expected:** Gemini should be able to read and reference both documents.

---

## Status Report File Decision

**File:** `g/reports/feature-dev/persona_model_v5_status.md`

**Options:**
1. **Keep local-only** (don't commit) - If it's just working notes
2. **Create reports branch** - If you want audit trail but not in main
3. **Commit to separate PR** - If it's official status documentation

**Recommendation:** Keep local-only for now (can always commit later if needed).

---

## Verification Checklist

After both PRs merged:
- [ ] `personas/GEMINI_PERSONA_v5.md` exists in main
- [ ] `g/docs/PERSONA_MODEL_v5.md` exists in main
- [ ] `g/docs/HOWTO_TWO_WORLDS_v2.md` shows ✅ for PERSONA_MODEL_v5.md
- [ ] Gemini CLI can read both documents via @ references
- [ ] Local main is synced with origin/main
- [ ] Branches cleaned up (optional)

---

**Status:** Ready for merge (waiting for PR approval/merge)
