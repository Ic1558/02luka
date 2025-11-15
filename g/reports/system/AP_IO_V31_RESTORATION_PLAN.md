# AP/IO v3.1 Ledger System - Restoration Plan

**Date:** 2025-11-16  
**Status:** Files Deleted - Restoration Required  
**Priority:** P0 - Critical

---

## Problem

AP/IO v3.1 Ledger system files were accidentally deleted. These files are critical infrastructure and must be restored.

---

## Deleted Files Inventory

### Core Tools
- `tools/ap_io_v31/writer.zsh` - Ledger entry writer
- `tools/ap_io_v31/reader.zsh` - Ledger entry reader
- `tools/ap_io_v31/validator.zsh` - Schema validator
- `tools/ap_io_v31/correlation_id.zsh` - Correlation ID generator
- `tools/ap_io_v31/router.zsh` - Event router
- `tools/ap_io_v31/pretty_print.zsh` - Ledger viewer

### Schemas
- `schemas/ap_io_v31.schema.json` - Protocol schema
- `schemas/ap_io_v31_ledger.schema.json` - Ledger entry schema

### Documentation
- `docs/AP_IO_V31_PROTOCOL.md` - Protocol documentation
- `docs/AP_IO_V31_INTEGRATION_GUIDE.md` - Integration guide
- `docs/AP_IO_V31_ROUTING_GUIDE.md` - Routing guide
- `docs/AP_IO_V31_MIGRATION.md` - Migration guide

### Agent Integrations
- `agents/cls/ap_io_v31_integration.zsh`
- `agents/andy/ap_io_v31_integration.zsh`
- `agents/hybrid/ap_io_v31_integration.zsh`
- `agents/liam/ap_io_v31_integration.zsh`
- `agents/gg/ap_io_v31_integration.zsh`

### Tests
- `tests/ap_io_v31/cls_testcases.zsh`
- `tests/ap_io_v31/test_protocol_validation.zsh`
- `tests/ap_io_v31/test_routing.zsh`
- `tests/ap_io_v31/test_correlation.zsh`
- `tests/ap_io_v31/test_backward_compat.zsh`

### Reports
- `g/reports/feature_ap_io_v31_ledger_SPEC.md`
- `g/reports/feature_ap_io_v31_ledger_PLAN.md`
- `g/reports/feature_ap_io_v31_ledger_PR_CONTRACT.md`
- `g/reports/feature_ap_io_v31_ledger_ROUTING_INTEGRATION.md`
- `g/reports/feature_ap_io_v31_ledger_FULL_PIPELINE_PROPOSAL.md`

---

## Restoration Strategy

### Option 1: Git History Recovery
If files were committed before deletion:
```bash
# Find commit with files
git log --all --full-history --oneline -- "**/ap_io_v31*"

# Restore from specific commit
git checkout <commit-hash> -- tools/ap_io_v31/
git checkout <commit-hash> -- docs/AP_IO_V31*.md
# ... etc
```

### Option 2: Recreate from Documentation
If files were never committed, recreate from:
- `g/reports/feature_ap_io_v31_ledger_verification_enhancement_SPEC.md`
- `g/reports/feature_ap_io_v31_ledger_verification_enhancement_PLAN.md`
- `g/reports/feature_ap_io_v31_hybrid_integration_PR_CONTRACT.md`
- Implementation summaries and test results

### Option 3: Backup Recovery
Check for backups:
- Time Machine
- Git reflog
- Local backups
- Cursor/IDE history

---

## Guardrails Added

### 1. Protected Files List
Created: `.cursor/protected_files.txt`
- Lists all critical AP/IO v3.1 files
- Prevents accidental deletion

### 2. Pre-commit Hook
Created: `.git/hooks/pre-commit`
- Runs `tools/protect_critical_files.zsh`
- Blocks commits that delete protected files

### 3. Protection Script
Created: `tools/protect_critical_files.zsh`
- Checks deleted files against protected patterns
- Exits with error if protected files detected

---

## Immediate Actions

1. ✅ **Guardrails Created** - Prevents future deletions
2. ⏳ **Restore Files** - Use one of the restoration strategies above
3. ⏳ **Verify Functionality** - Run `tools/run_ap_io_v31_tests.zsh`
4. ⏳ **Commit Protection** - Commit guardrails to prevent future issues

---

## Prevention Measures

### Short-term
- ✅ Protected files list
- ✅ Pre-commit hook
- ✅ Protection script

### Long-term
- Consider git-annex for critical files
- Regular backups of critical infrastructure
- Documentation of file importance
- Team awareness of protected files

---

**Status:** Guardrails in place, restoration pending  
**Next:** Restore files using one of the strategies above
