# Git Commands for WO-QA-003

**Branch:** `feat/hybrid-router-clean`  
**Date:** 2025-12-03

---

## Quick Copy-Paste Commands

```bash
# ============================================================
# 1. Add WO-QA-003 files only
# ============================================================

git add agents/qa_v4/__init__.py
git add agents/qa_v4/factory.py
git add agents/qa_v4/guardrails.py
git add agents/qa_v4/mode_selector.py
git add agents/qa_v4/workers/
git add agents/qa_v4/tests/
git add agents/qa_v4/actions.py
git add agents/qa_v4/checklist_engine.py
git add agents/qa_v4/rnd_integration.py
git add agents/dev_common/qa_handoff.py
git add g/docs/qa_mode_guide.md
git add g/docs/qa_mode_configuration.md
git add g/reports/feature-dev/lac_v4/251203_qa_3mode_*.md
git add g/reports/feature-dev/lac_v4/251203_completion_report_review.md
git add g/reports/feature-dev/lac_v4/251203_gmx_edit_review.md
git add g/reports/feature-dev/lac_v4/251203_qa_3mode_implementation_runbook.md

# Remove deleted file
git rm agents/qa_v4/qa_worker.py

# ============================================================
# 2. Commit
# ============================================================

git commit -m "feat(qa): add 3-mode QA system with auto-selection (WO-QA-003)

- Implement Basic/Enhanced/Full QA modes
- Add intelligent mode selection based on risk/complexity/history
- Add guardrails (budget limits, performance monitoring)
- Integrate with qa_handoff.py
- Add comprehensive tests (29 unit + 6 integration)
- Add documentation (881 lines)
- Maintain backward compatibility (QAWorkerV4 alias)

All 9 phases complete and verified.
See: g/reports/feature-dev/lac_v4/251203_qa_3mode_comprehensive_verification_final.md"

# ============================================================
# 3. Push
# ============================================================

git push origin feat/hybrid-router-clean
```

---

## Files Included

### Code Files
- `agents/qa_v4/__init__.py` - Package init with backward compat
- `agents/qa_v4/factory.py` - Factory for mode selection
- `agents/qa_v4/guardrails.py` - Budget and performance guardrails
- `agents/qa_v4/mode_selector.py` - Mode selection logic
- `agents/qa_v4/workers/` - All 3 worker classes (basic/enhanced/full)
- `agents/qa_v4/tests/` - All test files
- `agents/qa_v4/actions.py` - Modified (shared actions)
- `agents/qa_v4/checklist_engine.py` - Modified (shared engine)
- `agents/qa_v4/rnd_integration.py` - Modified (shared R&D integration)
- `agents/dev_common/qa_handoff.py` - Integration with dev lane

### Documentation
- `g/docs/qa_mode_guide.md` - User guide (404 lines)
- `g/docs/qa_mode_configuration.md` - Configuration reference (477 lines)

### Reports
- `g/reports/feature-dev/lac_v4/251203_qa_3mode_*.md` - All phase reports
- `g/reports/feature-dev/lac_v4/251203_completion_report_review.md`
- `g/reports/feature-dev/lac_v4/251203_gmx_edit_review.md`
- `g/reports/feature-dev/lac_v4/251203_qa_3mode_implementation_runbook.md`

### Deleted
- `agents/qa_v4/qa_worker.py` - Replaced by workers/basic.py

---

## Verification

✅ All tests passing (97.5%)  
✅ Backward compatible  
✅ Documentation complete  
✅ All 9 phases verified

---

**Ready to commit and push!**
