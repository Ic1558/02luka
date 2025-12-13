# Block 4: Multi-File SIP Transaction Engine — Implementation Plan

**Date:** 2025-12-10  
**Feature Slug:** `block4_multifile_sip`  
**Status:** 📋 PLAN  
**Priority:** P1 (Critical for Governance v5 Integration)  
**Owner:** GG (System Orchestrator)

---

## 🎯 Executive Summary

**Problem:** Single-file SIP works, but multi-file operations need atomic transaction semantics to ensure consistency across related files.

**Solution:** Implement Multi-File SIP Transaction Engine that:
- Prepares all files in temp before any commit
- Validates entire transaction before applying
- Applies files atomically (all-or-nothing)
- Supports rollback on partial failure
- Integrates with CLC Executor v5 and WO Processor v5

**Impact:** Enables safe multi-file operations (e.g., config + schema updates, related file refactors) with full transaction guarantees.

---

## 📋 Current State Analysis

### Existing System
- **Single-File SIP:** Implemented in Block 3 (CLC Executor v5)
- **SIP Algorithm:** Defined in `AI_OP_001_v5.md` Section 5.2
- **Multi-File Mention:** Section 5.3 mentions requirements but not implementation

### Problems
1. ❌ No transaction semantics for multi-file operations
2. ❌ Partial failures leave system in inconsistent state
3. ❌ No atomic commit/rollback for related files
4. ❌ CLC Executor v5 processes files sequentially (no transaction boundary)

---

## 🎯 Target State

### Multi-File SIP Transaction Flow
```
1. WO arrives with multiple file operations
2. Transaction Engine:
   a. Prepare all files in temp (no target files modified yet)
   b. Validate entire transaction (syntax, dependencies, constraints)
   c. If validation fails → abort, no files changed
   d. If validation passes → atomic commit:
      - Apply all files in sequence (mv temp → target)
      - If any file fails → rollback all changes
   e. Post-commit verification (checksums, integrity)
3. Log transaction result (success/partial failure/rollback)
```

### Transaction Semantics
| Aspect | Behavior |
|--------|----------|
| **Atomicity** | All files commit or none (all-or-nothing) |
| **Validation** | Entire transaction validated before any commit |
| **Rollback** | Automatic rollback on any failure during commit |
| **Idempotency** | Safe to re-run (checksums prevent duplicate work) |
| **Audit** | Full transaction log with before/after checksums |

---

## 📝 Tasks Breakdown

### Task 1: Transaction Engine Core
- [ ] Create `bridge/core/sip_engine_v5.py`
- [ ] Implement transaction context manager
- [ ] Implement temp file preparation for all files
- [ ] Implement transaction validation
- [ ] Implement atomic commit (all-or-nothing)
- [ ] Implement rollback mechanism

### Task 2: Validation Layer
- [ ] Syntax validation (JSON/YAML/Python/etc.)
- [ ] Dependency validation (file A depends on file B)
- [ ] Constraint validation (e.g., schema compatibility)
- [ ] Pre-commit dry-run checks

### Task 3: Rollback Strategy
- [ ] Store original file checksums before transaction
- [ ] Implement rollback to original state
- [ ] Handle partial rollback (if some files already committed)
- [ ] Log rollback events

### Task 4: Integration Points
- [ ] Integrate with CLC Executor v5 (use for multi-file WOs)
- [ ] Integrate with WO Processor v5 (transaction-aware routing)
- [ ] Update Block 3 to use transaction engine for multi-file ops

### Task 5: Testing & Verification
- [ ] Test successful multi-file transaction
- [ ] Test validation failure (no files changed)
- [ ] Test rollback on commit failure
- [ ] Test idempotency (re-run same transaction)
- [ ] Test partial rollback scenarios

---

## 🧪 Test Strategy

### Unit Tests
- Transaction preparation (all files in temp)
- Validation logic (syntax, dependencies, constraints)
- Atomic commit (all-or-nothing)
- Rollback mechanism

### Integration Tests
- End-to-end: WO with 3 files → transaction → all committed
- Failure scenario: WO with 3 files → validation fails → no changes
- Rollback scenario: WO with 3 files → commit fails on file 2 → rollback all

### Edge Cases
- Empty transaction (no files)
- Single file (should use single-file SIP)
- Very large transactions (10+ files)
- Cross-zone transactions (OPEN + LOCKED files)

---

## 📊 Success Criteria

1. ✅ All files prepared in temp before any commit
2. ✅ Entire transaction validated before applying
3. ✅ Atomic commit (all files or none)
4. ✅ Automatic rollback on any failure
5. ✅ Full audit trail (before/after checksums, transaction log)
6. ✅ Integration with CLC Executor v5 and WO Processor v5

---

## 🔗 Dependencies

- ✅ Block 1: Router v5 Core (Complete)
- ✅ Block 2: SandboxGuard v5 (Complete)
- ✅ Block 3: CLC Enforcement Engine v5 (Complete - has single-file SIP)
- ⏳ Block 4: Multi-File SIP Engine (This Plan)
- ⏳ Block 5: WO Processor v5 (Depends on Block 4)

---

## 📅 Timeline

- **Phase 1:** Transaction Engine Core (2-3 hours)
- **Phase 2:** Validation Layer (1-2 hours)
- **Phase 3:** Rollback Strategy (1 hour)
- **Phase 4:** Integration & Testing (1-2 hours)

**Total:** ~5-8 hours

---

## 📐 Architecture Overview

### Component Structure
```
sip_engine_v5.py
├── TransactionContext (context manager)
│   ├── prepare_files()      # Prepare all in temp
│   ├── validate()            # Validate entire transaction
│   ├── commit()              # Atomic commit (all-or-nothing)
│   └── rollback()            # Rollback all changes
├── ValidationEngine
│   ├── validate_syntax()     # JSON/YAML/Python syntax
│   ├── validate_dependencies() # File dependencies
│   └── validate_constraints() # Business constraints
└── RollbackEngine
    ├── store_state()         # Store original checksums
    └── restore_state()      # Restore original files
```

### Integration Points
- **CLC Executor v5:** Uses transaction engine for multi-file WOs
- **WO Processor v5:** Aware of transaction boundaries
- **SandboxGuard v5:** Pre-write checks before transaction commit

---

## 📚 Reference Documents

- `g/docs/AI_OP_001_v5.md` Section 5.2 (Single-File SIP)
- `g/docs/AI_OP_001_v5.md` Section 5.3 (Multi-File SIP Requirements)
- `g/reports/feature-dev/governance_v5_unified_law/251209_block3_clc_enforcement_v5_DRYRUN.md` (Single-File SIP Implementation)

---

**Status:** 📋 PLAN Complete — Ready for SPEC

**Next:** Create SPEC.md with detailed implementation

