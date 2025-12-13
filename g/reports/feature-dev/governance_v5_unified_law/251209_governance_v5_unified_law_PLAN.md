# Governance v5 Unified Law Suite — PLAN

**Version**: v01  
**Date**: 2025-12-09  
**Owner**: GG (Strategist)  
**Executor**: GG → GM → CLS (Documentation)  
**Style**: Linux Kernel / System Architecture Specification (Style C)

---

## 1. Overview

Create **Governance Model v5 (Unified Law)** as a complete kernel-grade specification suite, replacing all legacy governance documents with a single, deterministic, multi-agent-executable specification.

**Effort**: High (15-20k words, 5 major documents)  
**Risk**: Medium (affects all agents, must be 100% consistent)  
**Duration**: 2-4 hours (depending on approach)

---

## 2. Approach Decision (REQUIRES BOSS CONFIRMATION)

Boss must choose one of three approaches:

### Option A: Generate All Files at Once
- **Pros**: Complete suite immediately, full consistency check
- **Cons**: Large output, harder to review incrementally
- **Output**: All 5 files (~15-20k words total)
- **Time**: ~2-3 hours

### Option B: Generate File-by-File (Recommended)
- **Pros**: Incremental review, refinement per file, better control
- **Cons**: Takes longer, need to maintain consistency across files
- **Output**: One file at a time, Boss approves each
- **Time**: ~4 hours total (with reviews)

### Option C: Generate FILE 1 First, Then Pause
- **Pros**: Boss reviews master spec before others, ensures direction
- **Cons**: Slower start, but safest approach
- **Output**: FILE 1 only, then pause for approval
- **Time**: ~1 hour for FILE 1, then variable

**GG Recommendation**: **Option C** (safest, ensures alignment before full generation)

---

## 3. File Structure

### FILE 1: GOVERNANCE_UNIFIED_v5.md
**Location**: `g/docs/GOVERNANCE_UNIFIED_v5.md`  
**Purpose**: Master kernel specification  
**Size**: ~5-6k words  
**Sections**:
1. System Model (2-World Execution Model, Deterministic Routing Law, State Space)
2. Execution Layers (L0 Boss, L1 CLI, L2 Background)
3. Zone Semantics (Open, Locked, Danger)
4. Writer Capability Table (Kernel Style)
5. Routing Semantics (Mary Router v5)
6. Safety Invariants
7. Undefined Behavior & Forbidden Behavior
8. Concurrency & Race Condition Prevention
9. Work Order Kernel Protocol
10. Auditability & Deterministic Logging

### FILE 2: AI_OP_001_v5.md
**Location**: `g/docs/AI_OP_001_v5.md`  
**Purpose**: Background World Kernel Law (replaces v4)  
**Size**: ~3-4k words  
**Sections**:
1. Execution Semantics (strict, deterministic)
2. Routing Law
3. Writer Constraints
4. Queue & Work Order Protocol
5. Drift Handling (Open→Locked Auto-Escalation)
6. Safety Belt Enforcement
7. SIP Mandatory Specification
8. Example Execution Traces
9. Kernel-Style Consistency Checks

### FILE 3: HOWTO_TWO_WORLDS_v2.md
**Location**: `g/docs/HOWTO_TWO_WORLDS_v2.md`  
**Purpose**: Developer Edition Two-World Model  
**Size**: ~3-4k words  
**Sections**:
1. Formal Definition of "World"
2. Trigger → World Resolution Algorithm
3. Zone → Lane Resolution Table
4. Authority Ladder
5. State Machine Diagram
6. Conflict Resolution Rules
7. Override Semantics
8. Agent Mapping Table
9. Memory & Audit Requirements

### FILE 4: SCOPE_DECLARATION_v1.md
**Location**: `g/docs/SCOPE_DECLARATION_v1.md`  
**Purpose**: Prevent ambiguous interpretation  
**Size**: ~1-2k words  
**Sections**:
1. Declare which documents apply to which world
2. Declare how precedence works (Kernel-style)
3. World + Zone → Active Law
4. Versioning & Deprecation Policy
5. Guarantees

### FILE 5: PERSONA_MODEL_v5.md
**Location**: `g/docs/PERSONA_MODEL_v5.md`  
**Purpose**: Formal agent identity & capability model  
**Size**: ~3-4k words  
**Sections**:
1. Kernel-Defined Persona Attributes
2. Agent Classification (Planner, Writer, Worker, Router, Executor)
3. Capability Table (per World + per Zone)
4. Deterministic Routing Matrix
5. Override Semantics (Boss / Mary / Router / CLC)
6. Undefined Behavior (agent must not do X)

---

## 4. Implementation Steps

### Phase 0: Boss Confirmation (CURRENT)
- [x] Create PLAN.md
- [ ] Boss confirms approach (A/B/C)
- [ ] Boss approves outline

### Phase 1: FILE 1 Generation (if Option C)
- [x] Generate GOVERNANCE_UNIFIED_v5.md
- [x] Review with Boss (Boss provided content)
- [x] Save to g/docs/GOVERNANCE_UNIFIED_v5.md
- [x] Add scope notices to existing governance docs
- [x] Boss approves FILE 1 ✅

### Phase 2: Remaining Files (if Option C approved)
- [x] Generate FILE 2 (AI_OP_001_v5.md) ✅
- [x] Generate FILE 3 (HOWTO_TWO_WORLDS_v2.md) ✅
- [x] Generate FILE 4 (SCOPE_DECLARATION_v1.md) ✅
- [x] Generate FILE 5 (PERSONA_MODEL_v5.md) ✅
- [ ] Cross-reference consistency check

### Phase 3: Integration
- [ ] Update all persona files to reference v5
- [ ] Archive legacy governance docs (v1-v4)
- [ ] Update routing engine references
- [ ] Update Mary Router to use v5 semantics

### Phase 4: Validation
- [ ] All agents can parse v5 specs
- [ ] No conflicts between files
- [ ] All legacy references updated
- [ ] Test with sample routing scenarios

---

## 5. Style Guidelines (Style C: Kernel-Grade)

### Language Requirements:
- **Precise**: Zero ambiguity, deterministic semantics
- **OS Developer Language**: Not user-friendly, but implementable
- **Invariants**: Must be provable, testable
- **Contracts**: Clear preconditions, postconditions
- **State Diagrams**: Formal state transitions
- **Authority Boundaries**: Explicit, non-negotiable
- **Lane Guarantees**: What each lane promises
- **Capability Tables**: Hardware-style capability matrix
- **Undefined Behaviors**: Explicitly forbidden operations
- **Conflict Resolution**: Deterministic algorithms

### Format Requirements:
- Use formal specification language
- Include state diagrams (ASCII or Mermaid)
- Include capability tables (markdown tables)
- Include routing matrices (deterministic lookup)
- Include example execution traces
- Include consistency checks

---

## 6. Success Criteria

- [ ] All 5 files generated and consistent
- [ ] Zero conflicts with existing system
- [ ] All agents can understand and follow v5
- [ ] Legacy governance docs properly archived
- [ ] Routing engine can implement v5 semantics
- [ ] Boss approves final suite

---

## 7. Risks & Mitigation

### Risk 1: Inconsistency Between Files
- **Mitigation**: Generate FILE 1 first, use as master reference

### Risk 2: Too Complex for Agents
- **Mitigation**: Include example traces, clear capability tables

### Risk 3: Breaking Existing System
- **Mitigation**: Maintain backward compatibility notes, gradual migration

### Risk 4: Ambiguity in Specification
- **Mitigation**: Style C (kernel-grade), zero-ambiguity requirement

---

## 8. Dependencies

- Boss approval of approach (A/B/C)
- Boss approval of FILE 1 (if Option C)
- Access to existing governance docs (v1-v4)
- Access to persona definitions
- Access to routing engine code

---

## 9. Next Steps

**IMMEDIATE**: Boss must confirm approach (A/B/C)

**IF Option C**:
1. GG generates FILE 1 (GOVERNANCE_UNIFIED_v5.md)
2. Boss reviews and approves
3. GG generates remaining 4 files
4. Integration and validation

**IF Option A**:
1. GG generates all 5 files
2. Boss reviews complete suite
3. Refinement if needed
4. Integration and validation

**IF Option B**:
1. GG generates FILE 1
2. Boss approves FILE 1
3. GG generates FILE 2
4. Boss approves FILE 2
5. Repeat for remaining files
6. Integration and validation

---

**Status**: ⏸️ **WAITING FOR BOSS CONFIRMATION**

**Question for Boss**: Which approach do you prefer? (A / B / C)

---

**Last Updated**: 2025-12-09

