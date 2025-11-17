# Feature Plan: /agents/** Layout Design

**Date:** 2025-11-15  
**Feature:** Design and implement standardized `/agents/**` directory structure  
**Status:** 📋 **PLAN READY FOR EXECUTION**

---

## Executive Summary

Create a standardized `/agents/**` directory structure that serves as a documentation hub and index for all agents in the 02luka system. This is a read-only documentation effort - no code migration or implementation changes.

**Estimated Time:** 2-3 hours  
**Priority:** Medium (documentation/organization)  
**Risk Level:** Low (read-only, no code changes)

---

## Task Breakdown

### Phase 1: Discovery & Documentation (30 min)

**Task 1.1: Complete Path Discovery**
- **Status:** 🔄 In Progress
- **Action:**
  - Document all agent-related paths discovered
  - Identify all orchestrator script locations
  - Document LaunchAgent references
  - Identify all agent implementations (Andy, CLC, Hybrid, etc.)
  - Create path inventory document
- **Deliverable:** Complete path discovery report
- **Time:** 15 min

**Task 1.2: Document Current State**
- **Status:** 🔄 Pending
- **Action:**
  - Document existing `/agents/` structure
  - Document `/CLS/` structure
  - Document orchestrator scripts and locations
  - Document agent relationships
  - Create current state baseline
- **Deliverable:** Current state documentation
- **Time:** 15 min

---

### Phase 2: Design /agents Structure (45 min)

**Task 2.1: Design Directory Layout**
- **Status:** 🔄 Pending
- **Action:**
  - Design `/agents/` directory structure
  - Define content requirements for each subdirectory
  - Define README.md template
  - Define index file structure
  - Document design decisions
- **Deliverable:** Directory layout design document
- **Time:** 20 min

**Task 2.2: Design CLS Directory Content**
- **Status:** 🔄 Pending
- **Action:**
  - Extract key points from `CLS_agent_latest.md`
  - Design `/agents/cls/README.md` structure
  - Define what to include (role, governance, capabilities, links)
  - Create content outline
- **Deliverable:** CLS directory content design
- **Time:** 15 min

**Task 2.3: Design Other Agent Directories**
- **Status:** 🔄 Pending
- **Action:**
  - Design `/agents/gg_orch/README.md` structure
  - Design `/agents/subagents/README.md` structure
  - Design placeholder structures for Andy, CLC, Hybrid
  - Create templates for unknown agents
- **Deliverable:** Agent directory content designs
- **Time:** 10 min

---

### Phase 3: Create Work Order for Andy/Codex (30 min)

**Task 3.1: Prepare Work Order Content**
- **Status:** 🔄 Pending
- **Action:**
  - Create detailed work order specification
  - Include directory structure requirements
  - Include README.md content requirements
  - Include links and references
  - Include governance constraints
- **Deliverable:** Work Order specification
- **Time:** 20 min

**Task 3.2: Create Work Order to CLC**
- **Status:** 🔄 Pending
- **Action:**
  - Create Work Order YAML file
  - Include evidence (path discovery, current state)
  - Include design documents
  - Drop to `bridge/inbox/CLC/`
  - Log to audit trail
- **Deliverable:** Work Order dropped to CLC
- **Time:** 10 min

---

### Phase 4: Verification & Documentation (30 min)

**Task 4.1: Verify Implementation (After Andy Completes)**
- **Status:** 🔄 Pending
- **Action:**
  - Verify `/agents/` structure created correctly
  - Verify all README.md files exist
  - Verify links work correctly
  - Verify CLS spec summary is accurate
  - Verify governance compliance
- **Deliverable:** Verification report
- **Time:** 15 min

**Task 4.2: Create Final Documentation**
- **Status:** 🔄 Pending
- **Action:**
  - Document final `/agents/` structure
  - Create usage guide
  - Document agent relationships
  - Create maintenance guide
- **Deliverable:** Final documentation
- **Time:** 15 min

---

## Test Strategy

### Test Approach

**Read-Only Verification:**
- Verify directory structure exists
- Verify README.md files are readable
- Verify links point to correct locations
- Verify content accuracy (CLS spec summary)
- Verify no broken references

**No Functional Testing Required:**
- This is documentation only
- No code changes
- No implementation modifications
- No migration testing needed

### Test Cases

**TC1: Directory Structure Verification**
```
1. Check /agents/ directory exists
2. Check all subdirectories exist (andy, gg_orch, cls, clc, hybrid, subagents)
3. Check each subdirectory has README.md
4. Check /agents/README.md exists
```

**TC2: Content Verification**
```
1. Read /agents/README.md - verify index content
2. Read /agents/cls/README.md - verify CLS spec summary
3. Verify links to /CLS/ work
4. Verify links to orchestrator scripts work
5. Verify governance rules documented correctly
```

**TC3: Link Verification**
```
1. Verify all links in /agents/README.md work
2. Verify all links in /agents/cls/README.md work
3. Verify links to actual implementations work
4. Verify no broken references
```

**TC4: Governance Compliance**
```
1. Verify /agents/ is read-only for CLS (if SOT)
2. Verify no direct modifications by CLS
3. Verify Work Order process followed
4. Verify audit trail logged
```

---

## Implementation Details

### Directory Structure

```
/agents/
├── README.md                    # Master index
├── andy/
│   └── README.md                # Andy agent documentation
├── gg_orch/
│   └── README.md                # GG Orchestrator documentation
├── cls/
│   └── README.md                # CLS spec summary + link to /CLS/
├── clc/
│   └── README.md                # CLC agent documentation
├── hybrid/
│   └── README.md                # Hybrid agent documentation
└── subagents/
    └── README.md                # Subagents/orchestrator documentation
```

### README.md Template

**Master Index (`/agents/README.md`):**
```markdown
# 02luka Agent System

Overview of all agents in the 02luka system.

## Agents

| Agent | Role | Location | Documentation |
|-------|------|----------|---------------|
| CLS | System Orchestrator | /CLS/ | [CLS README](cls/README.md) |
| GG | Orchestrator | docs/GG_ORCHESTRATOR_CONTRACT.md | [GG README](gg_orch/README.md) |
| ... | ... | ... | ... |

## Agent Relationships

[Diagram or description of how agents interact]

## Quick Links

- [CLS Documentation](cls/README.md)
- [GG Orchestrator](gg_orch/README.md)
- [Subagents/Orchestrator](subagents/README.md)
```

**CLS Directory (`/agents/cls/README.md`):**
```markdown
# CLS - Cognitive Local System Orchestrator

## Role
Cognitive Local System Orchestrator for 02luka system.

## Governance Rules
- Rule 91: Explicit allow-list (safe zones)
- Rule 92: Work Orders for SOT changes
- Rule 93: Evidence-based operations

## Capabilities
- Read operations (all system files)
- Write to safe zones (bridge, memory, telemetry, logs)
- Orchestration (tasks, monitoring, validation)

## Links
- Full spec: /CLS/agents/CLS_agent_latest.md
- Overview: /CLS/README.md
- Quick reference: /CLS.md

## Memory & Data
- Primary: memory/cls/
- Audit: g/telemetry/cls_audit.jsonl
```

---

## Risk Mitigation

### Risk 1: Governance Violations
**Mitigation:**
- CLS only creates Work Orders, doesn't modify directly
- All changes go through CLC/Andy
- Read-only approach for CLS

### Risk 2: Broken Links
**Mitigation:**
- Verify all links before finalizing
- Use relative paths where possible
- Document link maintenance process

### Risk 3: Incomplete Information
**Mitigation:**
- Document what is known
- Mark unknowns clearly (TBD)
- Allow for future updates

### Risk 4: Path Conflicts
**Mitigation:**
- Document existing structure
- No migration (read-only approach)
- Link to existing locations

---

## Success Criteria

- ✅ `/agents/` directory structure created
- ✅ All 6 agent subdirectories exist with README.md
- ✅ `/agents/README.md` index file created
- ✅ CLS spec summarized correctly in `/agents/cls/README.md`
- ✅ All links to implementations work
- ✅ No governance violations
- ✅ Documentation is readable and useful
- ✅ Verification tests pass

---

## Deliverables

1. **Path Discovery Report** - Complete inventory of agent-related paths
2. **Current State Documentation** - Baseline of existing structure
3. **Directory Layout Design** - Proposed structure design
4. **Work Order to CLC** - Specification for Andy/Codex
5. **Verification Report** - After implementation verification
6. **Final Documentation** - Usage and maintenance guide

---

## Timeline

**Phase 1: Discovery & Documentation** - 30 min
- Task 1.1: 15 min
- Task 1.2: 15 min

**Phase 2: Design /agents Structure** - 45 min
- Task 2.1: 20 min
- Task 2.2: 15 min
- Task 2.3: 10 min

**Phase 3: Create Work Order** - 30 min
- Task 3.1: 20 min
- Task 3.2: 10 min

**Phase 4: Verification & Documentation** - 30 min
- Task 4.1: 15 min (after Andy completes)
- Task 4.2: 15 min

**Total Estimated Time:** 2.25 hours

**Note:** Phase 4 depends on Andy/Codex completing implementation. CLS portion (Phases 1-3) can be completed independently.

---

## Dependencies

1. **GG/Andy availability** - To create `/agents/` structure (Phase 3+)
2. **CLC availability** - For any SOT modifications if needed
3. **Agent implementation locations** - To create accurate links
4. **Documentation sources** - CLS spec, GG contract, etc.

---

## Next Steps

1. **Complete Phase 1** - Finish path discovery and current state documentation
2. **Complete Phase 2** - Finalize directory structure design
3. **Create Work Order** - Drop specification to CLC for Andy/Codex
4. **Wait for Implementation** - Andy/Codex creates `/agents/` structure
5. **Verify & Document** - Verify implementation and create final docs

---

**Plan Status:** 📋 **READY FOR EXECUTION**  
**Priority:** Medium  
**Dependencies:** GG/Andy availability for implementation
