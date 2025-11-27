# LAC Realignment V2 — Deployment Checklist
**Date:** 2025-11-28  
**Feature:** LAC Realignment V2 (P1-P3) + Dev Lane Backends + CLS Cursor Wrapper  
**Status:** ✅ **READY FOR DEPLOYMENT**

---

## Pre-Deployment Verification

### ✅ Test Results
- ✅ **22/22 tests passing** (100%)
- ✅ Policy tests: 9/9
- ✅ Agent direct-write: 5/5
- ✅ Self-complete pipeline: 4/4
- ✅ Dev lane backends: 4/4

### ✅ Code Review Status
- ✅ All critical issues fixed
- ✅ Response parsing implemented
- ✅ Error handling comprehensive
- ✅ No linting errors
- ✅ Contract compliance: 100%

### ✅ Implementation Status
- ✅ P1: Shared Policy Module — Complete
- ✅ P2: Agent Direct-Write — Complete
- ✅ P3: Self-Complete Pipeline — Complete
- ✅ Dev Lane Backends — Complete
- ✅ CLS Cursor Wrapper — Complete

---

## Deployment Checklist

### Phase 1: Pre-Deployment

- [x] All tests passing (22/22)
- [x] Code review approved
- [x] Contract compliance verified
- [x] No linting errors
- [x] Documentation complete
- [ ] **Backup current state** (create git branch)
- [ ] **Verify git status** (review changes)

### Phase 2: File Commit

**New Files to Commit:**
- [ ] `shared/policy.py` + `shared/__init__.py`
- [ ] `agents/dev_oss/dev_worker.py`
- [ ] `agents/dev_gmxcli/dev_worker.py`
- [ ] `agents/dev_common/reasoner_backend.py`
- [ ] `agents/dev_codex/dev_worker.py`
- [ ] `agents/qa_v4/qa_worker.py`
- [ ] `agents/docs_v4/docs_worker.py`
- [ ] `agents/ai_manager/ai_manager.py`
- [ ] `agents/ai_manager/actions/direct_merge.py`
- [ ] `schemas/work_order.schema.json`
- [ ] `config/dev_oss_backend.yaml`
- [ ] `config/dev_gmxcli_backend.yaml`
- [ ] `tools/cursor_cls_wrapper.py`
- [ ] `tools/cursor_cls_bridge/*.py`
- [ ] `.cursor/commands/cls-apply.md`
- [ ] `tests/shared/test_policy.py`
- [ ] `tests/test_agent_direct_write.py`
- [ ] `tests/test_self_complete_pipeline.py`
- [ ] `tests/test_dev_lane_backends.py`

**Documentation Files:**
- [ ] All spec/plan/review documents in `g/reports/feature-dev/lac_realignment/`

### Phase 3: Git Operations

```bash
# 1. Create backup branch
git checkout -b backup/pre-lac-realignment-v2-$(date +%Y%m%d)

# 2. Return to main/feature branch
git checkout main  # or your feature branch

# 3. Stage all new files
git add shared/ agents/dev_oss/ agents/dev_gmxcli/ agents/dev_common/ \
        agents/qa_v4/ agents/docs_v4/ agents/ai_manager/ \
        agents/dev_codex/ schemas/work_order.schema.json \
        config/dev_oss_backend.yaml config/dev_gmxcli_backend.yaml \
        tools/cursor_cls_wrapper.py tools/cursor_cls_bridge/ \
        .cursor/commands/cls-apply.md \
        tests/shared/ tests/test_agent_direct_write.py \
        tests/test_self_complete_pipeline.py tests/test_dev_lane_backends.py

# 4. Commit with conventional commit message
git commit -m "feat(lac): LAC Realignment V2 - Local-first autonomous dev team

- P1: Shared policy module (shared/policy.py)
- P2: Agent direct-write capability (all dev/qa/docs workers)
- P3: Self-complete pipeline (DEV→QA→DOCS→DIRECT_MERGE)
- Dev lane backends: Pluggable OSS/GMX CLI reasoners
- CLS Cursor wrapper: Optional tool for Cursor integration

All tests passing (22/22). Contract compliant (LAC Contract V2).
Non-breaking: Optional features, doesn't touch core LAC."

# 5. Push to remote
git push origin <branch-name>
```

### Phase 4: Post-Deployment Verification

- [ ] **Run smoke tests:**
  ```bash
  pytest tests/shared/test_policy.py tests/test_agent_direct_write.py \
         tests/test_self_complete_pipeline.py tests/test_dev_lane_backends.py -v
  ```

- [ ] **Verify imports:**
  ```bash
  python3 -c "from shared.policy import check_write_allowed; print('✅ Policy OK')"
  python3 -c "from agents.dev_oss.dev_worker import DevOSSWorker; print('✅ Dev OSS OK')"
  python3 -c "from agents.ai_manager.ai_manager import AIManager; print('✅ AI Manager OK')"
  ```

- [ ] **Test CLS wrapper (dry-run):**
  ```bash
  python3 tools/cursor_cls_wrapper.py --command-text "test" --dry-run
  ```

- [ ] **Check health:**
  ```bash
  # Run system health check
  ~/02luka/bin/luka-h
  ```

### Phase 5: Integration Testing (Optional)

- [ ] **Test with real CLS pipeline:**
  - Create test WO via wrapper
  - Verify CLS processes it
  - Check result in outbox

- [ ] **Test agent direct-write:**
  - Create simple task
  - Verify agent writes file
  - Verify policy enforcement

- [ ] **Test self-complete pipeline:**
  - Create simple WO
  - Verify DEV→QA→DOCS→DIRECT_MERGE flow

---

## Rollback Plan

### If Deployment Fails

**Rollback Steps:**
```bash
# 1. Restore from backup branch
git checkout backup/pre-lac-realignment-v2-YYYYMMDD

# 2. Copy files back to main
git checkout main
git checkout backup/pre-lac-realignment-v2-YYYYMMDD -- <files>

# 3. Or simply revert commit
git revert <commit-hash>
```

**Files to Remove (if rollback needed):**
- `shared/` directory
- `agents/dev_oss/`, `agents/dev_gmxcli/`, `agents/dev_common/`
- `agents/qa_v4/`, `agents/docs_v4/`
- `agents/ai_manager/actions/direct_merge.py`
- `tools/cursor_cls_wrapper.py`, `tools/cursor_cls_bridge/`
- `.cursor/commands/cls-apply.md`
- New test files

**Estimated Rollback Time:** 5-10 minutes

---

## Deployment Impact

### ✅ Non-Breaking Changes

- **Core LAC:** No changes to core contracts
- **Existing Agents:** Backward compatible
- **Existing WOs:** Still work as before
- **Policy:** New shared module, doesn't replace existing

### ⚠️ New Dependencies

- **Python:** `json`, `subprocess`, `pathlib` (standard library)
- **Optional:** `yaml` (PyYAML) for config loading
- **No external APIs:** All local-first

### 📊 System Impact

| Component | Impact | Risk |
|-----------|--------|------|
| Core LAC | None | ✅ None |
| Existing Agents | None | ✅ None |
| New Agents | New features | ⚠️ Low (optional) |
| Tests | New tests | ✅ None |
| Config | New YAML files | ✅ None |

---

## Success Criteria

Deployment is successful when:

1. ✅ All files committed to git
2. ✅ All tests pass (22/22)
3. ✅ All imports work
4. ✅ CLS wrapper can create WOs (dry-run)
5. ✅ Health check passes
6. ✅ No breaking changes to existing functionality

---

## Post-Deployment Monitoring

### First 24 Hours

- [ ] Monitor system health checks
- [ ] Check for any error logs
- [ ] Verify agent workers can be instantiated
- [ ] Test CLS wrapper with real WO (if possible)

### First Week

- [ ] Monitor self-complete success rate
- [ ] Track CLC usage (should drop if self-complete works)
- [ ] Check telemetry for errors
- [ ] Review any user feedback

---

## Deployment Commands

### Quick Deploy (All-in-One)

```bash
cd /Users/icmini/LocalProjects/02luka_local_g

# 1. Backup
git checkout -b backup/pre-lac-realignment-v2-$(date +%Y%m%d)
git checkout main  # or your feature branch

# 2. Stage all files
git add shared/ agents/dev_oss/ agents/dev_gmxcli/ agents/dev_common/ \
        agents/qa_v4/ agents/docs_v4/ agents/ai_manager/ agents/dev_codex/ \
        schemas/work_order.schema.json config/dev_oss_backend.yaml \
        config/dev_gmxcli_backend.yaml tools/cursor_cls_wrapper.py \
        tools/cursor_cls_bridge/ .cursor/commands/cls-apply.md \
        tests/shared/ tests/test_agent_direct_write.py \
        tests/test_self_complete_pipeline.py tests/test_dev_lane_backends.py \
        g/reports/feature-dev/lac_realignment/

# 3. Commit
git commit -m "feat(lac): LAC Realignment V2 - Local-first autonomous dev team

- P1: Shared policy module
- P2: Agent direct-write capability  
- P3: Self-complete pipeline
- Dev lane backends: Pluggable OSS/GMX CLI
- CLS Cursor wrapper: Optional integration

Tests: 22/22 passing. Contract compliant."

# 4. Verify
pytest tests/shared/test_policy.py tests/test_agent_direct_write.py \
       tests/test_self_complete_pipeline.py tests/test_dev_lane_backends.py

# 5. Push
git push origin <branch-name>
```

---

## Deployment Status

**Current Status:** ✅ **READY FOR DEPLOYMENT**

**Next Action:** Execute deployment commands above

**Estimated Time:** 10-15 minutes

---

**Deployment Checklist Created:** 2025-11-28  
**Ready for Execution:** ✅ YES

