# ✅ PR Package Ready for CLS Implementation

**Created:** 2025-11-14 00:00  
**Status:** Ready for CLS to implement  
**Type:** Complete PR Package

---

## 📦 What Was Created

### 1. **SPEC Document**
**File:** `g/reports/feature_wo_pipeline_v2_rebuild_SPEC.md`

**Contains:**
- Complete problem statement
- Technical architecture
- File structure
- State JSON schema (default + TODO for CLS to inspect real schema)
- Component responsibilities
- Risk assessment
- Success metrics

### 2. **PLAN Document**
**File:** `g/reports/feature_wo_pipeline_v2_rebuild_PLAN.md`

**Contains:**
- ✅ **PR Title:** `feat(wo): rebuild WO processing pipeline v2 (CLS-only)`
- ✅ **PR Description:** Complete markdown ready to paste into GitHub PR body
- ✅ **Checklist:** 7 categories with detailed items
- ✅ **11 Implementation Tasks:** Step-by-step with time estimates
- ✅ **All 7 Script Skeletons:** Complete code with TODOs for CLS
- ✅ **5 LaunchAgent Templates:** XML plists ready
- ✅ **E2E Test Skeleton:** Complete test script
- ✅ **Documentation Template:** Structure for `WO_PIPELINE_V2.md`

---

## 🎯 PR Summary

### PR Title
```
feat(wo): rebuild WO processing pipeline v2 (CLS-only)
```

### PR One-Line Summary
```
Recreate the WO processing pipeline (processors + state writer + guardrail) so that WOs in bridge/inbox/CLC produce state files in followup/state and show up correctly in the followup dashboard.
```

### Files to Create (in Git repo root = `g/`)

```
tools/wo_pipeline/
  lib_wo_common.zsh              ✅ Skeleton provided
  apply_patch_processor.zsh       ✅ Skeleton provided
  json_wo_processor.zsh          ✅ Skeleton provided
  wo_executor.zsh                 ✅ Skeleton provided
  followup_tracker.zsh            ✅ Skeleton provided
  wo_pipeline_guardrail.zsh      ✅ Skeleton provided
  test_wo_pipeline_e2e.zsh       ✅ Skeleton provided

followup/state/
  .gitkeep                        ✅ Optional

launchd/
  com.02luka.apply_patch_processor.plist        ✅ Template provided
  com.02luka.json_wo_processor.plist             ✅ Template provided
  com.02luka.wo_executor.plist                  ✅ Template provided
  com.02luka.followup_tracker.plist             ✅ Template provided
  com.02luka.wo_pipeline_guardrail.plist        ✅ Template provided

docs/
  WO_PIPELINE_V2.md              ✅ Structure provided
```

---

## 🔧 What CLS Must Do

### Critical TODOs for CLS:

1. **Inspect State Schema** (Task 1, 15 min)
   - Search git history for `followup/state/*.json`
   - Check existing state files if any
   - Inspect `generate_followup_data.zsh` to see expected schema
   - Update `write_state_json()` in `lib_wo_common.zsh` to match

2. **Fill Execution Logic** (Task 5, 30 min)
   - Replace stub `ok=0` in `wo_executor.zsh`
   - Inspect real WO files to understand execution pattern
   - Route by category or executor field
   - Handle errors properly

3. **Match WO Schema** (Task 4, 25 min)
   - Inspect real WO files in `bridge/inbox/CLC/`
   - Adjust field extraction in `json_wo_processor.zsh`
   - Handle YAML parsing (ensure PyYAML or use minimal parser)

4. **Run Integration Tests** (Task 11, 30 min)
   - E2E test must pass
   - Real WO must process correctly
   - Dashboard must show WOs
   - Guardrail must work

---

## 📋 Implementation Checklist

### Before Starting:
- [ ] Read SPEC.md completely
- [ ] Read PLAN.md completely
- [ ] Understand the flow: inbox → processors → state → dashboard

### During Implementation:
- [ ] Task 1: Inspect schema (15 min)
- [ ] Task 2: Implement common library (20 min)
- [ ] Task 3: apply_patch_processor (15 min)
- [ ] Task 4: json_wo_processor (25 min)
- [ ] Task 5: wo_executor (30 min)
- [ ] Task 6: followup_tracker (15 min)
- [ ] Task 7: guardrail (15 min)
- [ ] Task 8: E2E test (20 min)
- [ ] Task 9: LaunchAgents (20 min)
- [ ] Task 10: Documentation (20 min)
- [ ] Task 11: Integration test (30 min)

### Before PR:
- [ ] All scripts executable (`chmod +x`)
- [ ] E2E test passes
- [ ] Guardrail works (exit 0 when healthy)
- [ ] Dashboard shows test WO
- [ ] All TODOs addressed
- [ ] Documentation complete

---

## 🚀 How to Use This Package

### For CLS (Implementation):

1. **Open PLAN.md:**
   ```bash
   open ~/02luka/g/reports/feature_wo_pipeline_v2_rebuild_PLAN.md
   ```

2. **Copy PR Description:**
   - Copy the PR description section from PLAN.md
   - Paste into GitHub PR body when creating PR

3. **Implement Tasks in Order:**
   - Follow Task 1 → Task 11 sequentially
   - Each task has skeleton code provided
   - Fill in TODOs based on repo inspection

4. **Test Before PR:**
   - Run E2E test
   - Test with real WO
   - Verify dashboard integration
   - Verify guardrail

5. **Create PR:**
   - Use PR title from PLAN.md
   - Use PR description from PLAN.md
   - Include all files
   - Mark checklist items complete

### For Boss (Review):

1. **Review SPEC.md:**
   - Understand architecture
   - Verify approach is correct

2. **Review PLAN.md:**
   - Check PR description
   - Verify checklist is complete
   - Review skeleton code quality

3. **Test PR Locally:**
   - Checkout PR branch
   - Run E2E test
   - Verify dashboard works

4. **Approve & Merge:**
   - If all tests pass
   - If checklist complete
   - If documentation adequate

---

## 📊 Timeline

**Total:** 2.5-3 hours (single CLS session)

**Breakdown:**
- Schema inspection: 15 min
- Script implementation: 2 hours
- Testing & docs: 30 min

---

## ✅ Acceptance Criteria

**Must Pass:**
- [ ] E2E test: `test_wo_pipeline_e2e.zsh` exits 0
- [ ] Real WO: Drop WO → State created → Dashboard shows it
- [ ] Guardrail: Healthy case exits 0, broken case exits non-zero
- [ ] All scripts: Executable, no hardcoded paths, use `resolve_repo_root()`

---

## 📝 Key Files

**SPEC:** `g/reports/feature_wo_pipeline_v2_rebuild_SPEC.md`  
**PLAN:** `g/reports/feature_wo_pipeline_v2_rebuild_PLAN.md`  
**This Summary:** `g/reports/PR_PACKAGE_READY.md`

---

## 🎯 Next Action

**For CLS:**
```
1. Read PLAN.md
2. Copy PR description
3. Implement tasks 1-11
4. Test everything
5. Create PR on GitHub
```

**For Boss:**
```
1. Review SPEC.md and PLAN.md
2. Approve approach
3. Wait for CLS PR
4. Review and merge
```

---

**Status:** ✅ **PR Package Complete - Ready for CLS Implementation**

**All skeletons provided, all TODOs documented, all templates ready.**

**CLS can start implementing immediately!** 🚀
