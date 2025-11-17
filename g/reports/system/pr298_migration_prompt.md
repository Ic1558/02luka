# PR #298 Migration Prompt for Liam/Gemini

**Purpose:** Migrate useful features from PR #298 onto main's dashboard v2.2.0 (SOT)

**Date:** 2025-11-18  
**Status:** READY FOR USE

---

## Context

PR #298 (`codex/add-trading-journal-csv-importer`) has conflicts with `main` because:
- `main` has advanced dashboard v2.2.0 with bulletproof delegation, metrics, MLS, services, reality snapshot
- PR #298 was based on older dashboard version
- 8 files have conflicts (5 add/add, 3 content conflicts)

**Strategy:** Create new branch from `main`, extract only useful features from PR #298, merge into current SOT.

---

## Task: Migrate PR #298 Features to Main Dashboard

### Objective

Extract and integrate useful features from PR #298's branch into a new branch based on `main` (dashboard v2.2.0), without regressing existing functionality.

### Constraints

**CRITICAL RULES:**
1. **`g/apps/dashboard/dashboard.js` from `main` is the SOT** — DO NOT replace it
2. **DO NOT remove** existing features: metrics, reality snapshot, bulletproof delegation, services panel, MLS panel
3. **ADD features** from PR #298 on top of existing code, don't replace
4. **`docs/GG_ORCHESTRATOR_CONTRACT.md`** — Use `main` version (Protocol v3.2) as base, only merge non-conflicting additions

### Step-by-Step Instructions

#### Step 1: Setup New Branch

```bash
git checkout main
git pull origin main
git checkout -b feat/dashboard-followup-v2
```

#### Step 2: Analyze PR #298 Branch

```bash
git fetch origin codex/add-trading-journal-csv-importer
git diff main...origin/codex/add-trading-journal-csv-importer --name-only
```

**Identify:**
- What new features were added in PR #298?
- What dashboard functionality was added?
- What trading-related UI components exist?
- What followup panel features exist?

#### Step 3: Extract Dashboard Features from PR #298

**File:** `g/apps/dashboard/dashboard.js`

**Process:**
1. Read current `main` version (SOT) — this is the base
2. Read PR #298 version — identify additions
3. Extract ONLY new features (don't take old code that replaces new code)
4. Integrate new features into SOT version

**What to look for in PR #298:**
- Followup panel functionality
- Trading widget/panel (if any)
- New UI components
- New event handlers
- New data fetching logic

**What NOT to do:**
- ❌ Replace entire file
- ❌ Remove metrics/reality/services/MLS panels
- ❌ Remove bulletproof delegation
- ❌ Remove WO timeline features

**Integration pattern:**
```javascript
// Example: If PR #298 adds a followup panel
// 1. Find where it's added in PR #298 version
// 2. Add it to main version in appropriate location
// 3. Ensure it doesn't conflict with existing panels
```

#### Step 4: Merge followup.json Data Format

**File:** `g/apps/dashboard/data/followup.json`

**Current SOT (main):**
```json
{
  "updated_at": "2025-11-15T18:33:39Z",
  "owner": "Operations Command Center",
  "items": []
}
```

**Process:**
1. Use main's structure as base
2. If PR #298 has additional fields (status, link, wo_id, etc.), add them to `items` array structure
3. Preserve `updated_at` and `owner` metadata
4. Ensure valid JSON structure

**Example merge:**
```json
{
  "updated_at": "2025-11-15T18:33:39Z",
  "owner": "Operations Command Center",
  "items": [
    {
      "id": "...",
      "status": "...",
      "link": "...",
      "wo_id": "..."
    }
  ]
}
```

#### Step 5: Merge Governance Documentation

**File:** `docs/GG_ORCHESTRATOR_CONTRACT.md`

**Process:**
1. **Use `main` version as base** (Protocol v3.2 aligned — this is critical)
2. Compare with PR #298 version
3. Extract only:
   - Useful examples
   - Clarifications that don't conflict with Protocol v3.2
   - Additional notes
4. Append/merge into main version
5. **DO NOT** replace Protocol v3.2 sections

**Checklist:**
- [ ] Protocol v3.2 references preserved
- [ ] Locked zones list matches Protocol v3.2
- [ ] Agent capabilities match Protocol v3.2
- [ ] Only non-conflicting additions merged

#### Step 6: Merge Documentation Files

**Files:**
- `agents/README.md`
- `agents/andy/README.md`
- `agents/gg_orch/README.md`
- `agents/subagents/README.md`
- `reports/ci/CI_RELIABILITY_PACK.md`

**Process:**
1. Use `main` version as base
2. Compare with PR #298 version
3. Merge content from both versions
4. Remove duplicates
5. Ensure consistent formatting
6. Fix any whitespace issues

**Strategy:** "Combine content from both sides" — these are docs only, low risk.

#### Step 7: Verify Integration

**Testing Checklist:**
- [ ] Dashboard loads without errors
- [ ] WO filters work
- [ ] Services panel displays correctly
- [ ] MLS panel displays correctly
- [ ] Reality snapshot works
- [ ] Metrics display correctly
- [ ] Bulletproof delegation works
- [ ] New features from PR #298 work (if any)
- [ ] Followup panel reads `followup.json` correctly (if added)

**Manual QA:**
1. Open dashboard in browser
2. Test all existing features
3. Test new features (if any)
4. Check browser console for errors
5. Verify data loading

#### Step 8: Commit and Push

```bash
git add .
git commit -m "feat(dashboard): merge PR298 features onto v2.2.0 SOT

- Keep main/dashboard.js as SOT base
- Integrate followup panel and trading features from PR #298
- Merge followup.json data format
- Use Protocol v3.2 governance docs as base
- Combine documentation from both branches

Resolves conflicts from PR #298 by migrating to current SOT"
git push origin feat/dashboard-followup-v2
```

#### Step 9: Create New PR

**Title:**
```
feat(dashboard): merge PR298 features onto v2.2.0 SOT
```

**Description:**
```markdown
## feat(dashboard): merge PR298 features onto v2.2.0 SOT

### Summary

Consolidates the remaining useful pieces from PR #298 onto the current `main` dashboard (v2.2.0) without regressing the UI/metrics/Reality features.

### Changes

- Keep `g/apps/dashboard/dashboard.js` from `main` as SOT and layer PR #298 additions on top
- Align `g/apps/dashboard/data/followup.json` with the new data format while preserving `updated_at` and `owner` metadata
- Use `docs/GG_ORCHESTRATOR_CONTRACT.md` from `main` (Protocol v3.2) as base and merge in non-conflicting clarifications from PR #298
- Reconcile agent README docs and `reports/ci/CI_RELIABILITY_PACK.md` by combining content from both branches

### Rationale

- PR #298 was behind `main` and reported "conflicts resolved" while new conflicts still existed
- The dashboard in `main` (v2.2.0) is the SOT and must not be replaced by older variants
- This PR salvages the useful work from #298 without regressing the current system

### Testing

- [x] Dashboard manual QA (WO filters, logs, services, MLS, Reality snapshot)
- [x] Verified follow-up data flow using `g/apps/dashboard/data/followup.json`
- [x] CI workflow green on this branch

### Related

- Supersedes: PR #298
```

---

## Key Principles

1. **SOT Preservation:** `main` dashboard v2.2.0 is the source of truth
2. **Additive Only:** Add features, don't replace existing code
3. **Protocol Compliance:** Maintain Protocol v3.2 alignment
4. **Test Everything:** Verify no regressions
5. **Clean History:** New branch, clean commits

---

## Success Criteria

✅ Dashboard v2.2.0 features preserved  
✅ PR #298 features integrated  
✅ No conflicts with `main`  
✅ Protocol v3.2 compliance maintained  
✅ All tests pass  
✅ Manual QA successful

---

## Notes

- If unsure about a change, prefer keeping `main` version
- When in doubt, ask for clarification
- Document any decisions made during migration
- Keep commits atomic and well-described

---

**Ready to use:** Copy this entire prompt to Liam/Gemini in Cursor to execute the migration.
