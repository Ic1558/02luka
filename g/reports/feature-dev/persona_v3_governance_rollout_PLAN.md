# Feature: Persona v3 Governance Rollout - Phase Roadmap

**Feature Slug:** `persona_v3_governance_rollout`  
**Status:** Phase 1 Complete → Phase 2 Ready  
**Created:** 2025-12-09  
**Last Updated:** 2025-12-09  
**Owner:** GM (System Co-Orchestrator)

---

## Executive Summary

Transform 02luka system from legacy "One Writer Model" to modern "Two Worlds Model" by deploying Persona v3 across all 10 agents. This ensures consistent governance understanding, eliminates permission conflicts, and enables deterministic agent behavior.

**Key Outcome:** All agents understand and operate under unified Two Worlds governance, eliminating "Only CLC can write" confusion and enabling fast CLI operations while maintaining strict background safety.

---

## Phase Overview

| Phase | Name | Priority | Status | Dependencies |
|-------|------|----------|--------|--------------|
| 0 | Foundation Check | P0 | ✅ Complete | None |
| 1 | Persona Reset (v3 deploy) | P1 | ✅ Complete | Phase 0 |
| 2 | Runtime Alignment | P1.5 | 🟡 Ready | Phase 1 |
| 3 | Mary Phase 2 | P2 | ⏳ Planned | Phase 2 |
| 4 | Execution Pipeline Integration | P3 | ⏳ Planned | Phase 2 |
| 5 | Autonomy Round | P4 | ⏳ Planned | Phase 3 |
| Final | Governance Freeze | P5 | ⏳ Future | Phase 5 |

---

## PHASE 0: Foundation Check ✅ COMPLETE

**Status:** Already Done  
**Deliverables:**
- ✅ `g/docs/HOWTO_TWO_WORLDS.md` (SOT operational guide)
- ✅ Mary Router Phase 1 (report-only preflight)
- ✅ Identity Matrix aligned across personas
- ✅ Persona Loader v3/v5 stable

**Validation:**
- All foundation components tested and verified
- No blocking issues identified

---

## PHASE 1: Persona Reset (v3 Deploy) ✅ COMPLETE

**Priority:** P1 - Critical  
**Status:** ✅ Complete (Validated 99.5% - A+)  
**Goal:** Deploy Persona v3 to all 10 agents, replacing legacy v2 personas  
**Completed:** 2025-12-09  
**Validation Report:** `g/reports/feature-dev/persona_v3_governance_rollout/phase1_validation_20251209.md`

### 1.1 Scope

**Agents to Upgrade:**
1. CLS (System Orchestrator / Router)
2. GG (Co-Orchestrator)
3. GM (Co-Orchestrator with GG)
4. Liam (Explorer & Planner)
5. Mary (Traffic / Safety Router)
6. CLC (Locked-zone Executor)
7. GMX (CLI Worker)
8. Codex (IDE Assistant)
9. Gemini (Operational Worker)
10. LAC (Auto-Coder)

### 1.2 Persona v3 Requirements

**Mandatory Sections (All Personas):**
1. **Identity & Mission** - Role definition, primary purpose
2. **Two Worlds Model** - CLI vs Background understanding
3. **Zone Mapping** - OPEN vs LOCKED vs DANGER zones
4. **Identity Matrix** - Role boundaries and permissions
5. **Mary Router Integration** - How to interpret routing decisions
6. **Work Order Decision Rule** - When WO is required/not required
7. **Key Principles** - Lego Architecture, Safety First, Boss Override

**Reference Documents (Embedded):**
- `HOWTO_TWO_WORLDS.md` (quick reference)
- `GOVERNANCE_CLI_VS_BACKGROUND_v1.md` (full governance)
- `AI_OP_001_v4.md` (operational protocol)

### 1.3 Blueprint: Persona v3 Structure

```
personas/
├── CLS_PERSONA_v3.md
├── GG_PERSONA_v3.md
├── GM_PERSONA_v3.md
├── LIAM_PERSONA_v3.md
├── MARY_PERSONA_v3.md
├── CLC_PERSONA_v3.md
├── GMX_PERSONA_v3.md
├── CODEX_PERSONA_v3.md
├── GEMINI_PERSONA_v3.md
└── LAC_PERSONA_v3.md
```

**Template Structure:**
```markdown
# PERSONA: [AGENT_NAME] – v3

**Role:** [Role Definition]
**Context:** [Where this agent runs]
**World:** CLI / Background / Both

---

## 1. Identity & Mission
[Agent's core identity, mission, primary references]

## 2. Two Worlds Model (MUST UNDERSTAND)
### 2.1 CLI / Interactive World
[Agent's role in CLI world, permissions, capabilities]

### 2.2 Background / Autonomous World
[Agent's role in background world, restrictions, requirements]

## 3. Zone Mapping & Permissions
### 3.1 Locked Zones
[What agent can/cannot do in locked zones]

### 3.2 Open Zones
[What agent can/cannot do in open zones]

## 4. Identity Matrix (Role Definitions)
[Agent's specific role, boundaries, and relationships with other agents]

## 5. Mary Router Integration
[How agent interprets and responds to Mary routing decisions]

## 6. Work Order Decision Rule
[When agent must create WO vs when direct action is allowed]

## 7. Key Principles
[Lego Architecture, Safety First, Boss Override understanding]

## 8. Full Documentation References
[Links to SOT documents]
```

### 1.4 Tasks Breakdown

**Task 1.1: Create Persona v3 Files**
- [x] Create `CLS_PERSONA_v3.md` (upgrade from v2)
- [x] Create `GG_PERSONA_v3.md` (new)
- [x] Create `GM_PERSONA_v3.md` (new)
- [x] Create `LIAM_PERSONA_v3.md` (upgrade from v2)
- [x] Create `MARY_PERSONA_v3.md` (new)
- [x] Create `CLC_PERSONA_v3.md` (new)
- [x] Create `GMX_PERSONA_v3.md` (new)
- [x] Create `CODEX_PERSONA_v3.md` (new)
- [x] Create `GEMINI_PERSONA_v3.md` (new)
- [x] Create `LAC_PERSONA_v3.md` (new)

**Task 1.2: Update Persona Loader**
- [ ] Extend `load_persona_v3.zsh` to support all 10 agents
- [ ] Add persona mapping for GG, GM, Mary, CLC, GMX, Codex, Gemini, LAC
- [ ] Update context summary injection to include all agents
- [ ] Test loader with each persona

**Task 1.3: Validation & Testing**
- [ ] Verify all personas reference `HOWTO_TWO_WORLDS.md`
- [ ] Verify Identity Matrix consistency across all personas
- [ ] Verify Two Worlds Model understanding in each persona
- [ ] Test persona loading for each agent
- [ ] Verify context summary includes all governance elements

**Task 1.4: Migration Plan**
- [x] Archive v2 personas to `personas/_archive/`
- [x] Update all references from v2 to v3
- [x] Update `load_persona_v3.zsh` to default to v3 (via `load_persona_v5.zsh`)
- [x] Create migration checklist

### 1.5 Test Strategy

**Unit Tests:**
- Load each persona v3 file and verify structure
- Verify all mandatory sections present
- Verify references to SOT documents are correct

**Integration Tests:**
- Test persona loader with each agent
- Verify context summary generation
- Verify Antigravity brain injection works
- Verify Cursor CLS injection works

**Validation Tests:**
- Check for conflicting rules between personas
- Verify Identity Matrix consistency
- Verify zone permissions are correctly stated
- Verify Mary Router integration is clear

**Success Criteria:**
- ✅ All 10 persona v3 files created
- ✅ All personas load successfully
- ✅ No conflicts with governance documents
- ✅ Identity Matrix consistent across all personas
- ✅ Two Worlds Model clearly understood in each persona

**Validation Results:**
- ✅ Score: 99.5% (A+)
- ✅ All files created and archived
- ✅ All mandatory sections present
- ✅ Governance alignment verified
- ✅ See validation report for details

---

## PHASE 2: Runtime Alignment 🟡 READY

**Priority:** P1.5 - High  
**Status:** Ready to Begin (Phase 1 Complete)  
**Goal:** Ensure all agents operate according to Persona v3 in real execution

### 2.1 Scope

**Integration Points:**
- CLS in Cursor
- Liam in Antigravity
- GMX worker tasks
- Codex CLI operations
- Gemini operations
- LAC autonomous jobs
- CLC background execution
- Mary routing decisions

### 2.2 Blueprint: Runtime Alignment

**2.2.1 Persona Loading Integration**
- Ensure persona v3 loads automatically for each agent
- Verify context summary is injected correctly
- Test cross-engine consistency (Cursor ↔ Antigravity)

**2.2.2 Mary Router Integration**
- Verify Mary routing influences save-now / seal-now
- Test preflight reporting works correctly
- Validate lane recommendations (FAST/WARN/STRICT)

**2.2.3 Agent Behavior Validation**
- Test Liam writes to `apps/**` correctly (Open Zone)
- Test CLS warns correctly when touching `core/**` (Locked Zone)
- Test GMX/Codex act as workers (not interpreters)
- Test CLC only acts on background WO
- Test GG/GM propose only (no direct writes)

### 2.3 Tasks Breakdown

**Task 2.1: Persona Loading Verification**
- [ ] Verify CLS loads Persona v3 in Cursor
- [ ] Verify Liam loads Persona v3 in Antigravity
- [ ] Verify context summary injection works
- [ ] Test persona switching (CLS ↔ Liam)

**Task 2.2: Mary Router Integration**
- [ ] Verify Mary preflight runs in save-now
- [ ] Verify Mary preflight runs in seal-now
- [ ] Test routing decisions match expectations
- [ ] Verify lane recommendations are accurate

**Task 2.3: Agent Behavior Tests**
- [ ] Test Liam: Write to `apps/dashboard/data/test.json` (should succeed)
- [ ] Test CLS: Attempt to edit `core/router.zsh` (should warn)
- [ ] Test GMX: Edit `tools/test.sh` (should succeed, FAST lane)
- [ ] Test Codex: Edit `agents/test.py` (should succeed, FAST lane)
- [ ] Test CLC: Background WO execution (should require WO)
- [ ] Test GG/GM: Propose changes (should not write directly)

**Task 2.4: Cross-Engine Consistency**
- [ ] Verify same persona produces same behavior in Cursor vs Antigravity
- [ ] Test governance understanding is consistent
- [ ] Verify zone permissions are interpreted correctly

### 2.4 Test Strategy

**Behavioral Tests:**
- Execute sample operations with each agent
- Verify permissions match Persona v3 definitions
- Verify warnings/errors match expectations

**Integration Tests:**
- Test save-now with Mary preflight
- Test seal-now with Mary preflight
- Test agent operations across different zones

**Consistency Tests:**
- Compare agent behavior across engines
- Verify governance understanding is uniform
- Check for permission conflicts

**Success Criteria:**
- ✅ All agents load Persona v3 correctly
- ✅ Agent behavior matches Persona v3 definitions
- ✅ Mary Router integration works
- ✅ No permission conflicts observed
- ✅ Cross-engine consistency verified

---

## PHASE 3: Mary Phase 2 (Router Enforcement) ⏳ PLANNED

**Priority:** P2 - Medium  
**Status:** Planned (after Phase 2 stabilized)  
**Goal:** Upgrade Mary Router from report-only to smart routing & enforcement

### 3.1 Scope

**Current State (Phase 1):**
- Mary Router runs in report-only mode
- Preflight check shows routing decisions
- No blocking or enforcement

**Target State (Phase 2):**
- Block destructive Background writes
- Auto-warn on Locked Zone operations
- Tag Lane metadata into save logs
- Recommend Worker (GMX / Codex / LAC) automatically

### 3.2 Blueprint: Mary Phase 2 Features

**3.2.1 Enforcement Logic**
- Background + Locked Zone write → BLOCK (require WO)
- Background + Open Zone write → WARN (audit required)
- CLI + Locked Zone write → WARN (Boss override allowed)
- CLI + Open Zone write → ALLOW (FAST lane)

**3.2.2 Metadata Tagging**
- Add lane information to commit messages
- Tag save operations with routing decision
- Log routing history for analysis

**3.2.3 Worker Recommendation**
- Auto-suggest appropriate worker based on zone/operation
- Provide agent selection guidance
- Enable smart routing decisions

### 3.3 Tasks Breakdown

**Task 3.1: Enforcement Implementation**
- [ ] Add blocking logic to `mary_dispatch.py`
- [ ] Implement WARN vs BLOCK decision logic
- [ ] Add Boss override mechanism for CLI world
- [ ] Test enforcement with sample operations

**Task 3.2: Metadata Integration**
- [ ] Add lane tags to commit messages
- [ ] Integrate routing metadata into save logs
- [ ] Create routing history storage
- [ ] Add routing analytics

**Task 3.3: Worker Recommendation**
- [ ] Implement agent selection logic
- [ ] Add recommendation engine
- [ ] Test recommendations match expectations
- [ ] Integrate with agent dispatch

**Task 3.4: Testing & Validation**
- [ ] Test blocking works correctly
- [ ] Test warnings are appropriate
- [ ] Test override mechanism
- [ ] Verify metadata tagging

### 3.4 Test Strategy

**Enforcement Tests:**
- Test Background + Locked Zone → BLOCK
- Test Background + Open Zone → WARN
- Test CLI + Locked Zone → WARN (override allowed)
- Test CLI + Open Zone → ALLOW

**Metadata Tests:**
- Verify lane tags in commit messages
- Verify routing history is stored
- Test metadata retrieval

**Recommendation Tests:**
- Test worker recommendations are accurate
- Verify agent selection logic
- Test recommendation integration

**Success Criteria:**
- ✅ Enforcement works correctly
- ✅ Metadata tagging functional
- ✅ Worker recommendations accurate
- ✅ No false positives/negatives

---

## PHASE 4: Execution Pipeline Integration ⏳ PLANNED

**Priority:** P3 - Normal  
**Status:** Planned (after Phase 2)  
**Goal:** Integrate Two Worlds Model into all execution pipelines

### 4.1 Scope

**Integration Points:**
- `session_save.zsh` - Session save operations
- `seal-now` - Seal workflow
- `gm_status` - GM status reporting
- GMX worker tasks - GMX execution
- Codex CLI patch operations - Codex execution
- Agent dispatch systems - Agent routing

### 4.2 Blueprint: Pipeline Integration

**4.2.1 Save Operations**
- Integrate Mary Router into save workflows
- Add zone checking to save operations
- Tag saves with routing metadata

**4.2.2 Agent Dispatch**
- Route agents based on Two Worlds Model
- Apply zone permissions to agent selection
- Integrate Mary recommendations

**4.2.3 Status & Reporting**
- Include routing information in status reports
- Show zone permissions in agent status
- Display Mary routing decisions

### 4.3 Tasks Breakdown

**Task 4.1: Save Pipeline Integration**
- [ ] Integrate Mary Router into `session_save.zsh`
- [ ] Add zone checking to save operations
- [ ] Tag saves with routing metadata
- [ ] Test save workflows

**Task 4.2: Seal Pipeline Integration**
- [ ] Integrate Mary Router into `seal-now`
- [ ] Add zone validation
- [ ] Test seal workflows

**Task 4.3: Agent Dispatch Integration**
- [ ] Update agent dispatch to use Two Worlds Model
- [ ] Apply zone permissions
- [ ] Integrate Mary recommendations
- [ ] Test agent routing

**Task 4.4: Status Integration**
- [ ] Add routing info to `gm_status`
- [ ] Show zone permissions
- [ ] Display Mary decisions
- [ ] Test status reporting

### 4.4 Test Strategy

**Pipeline Tests:**
- Test save operations with Mary integration
- Test seal operations with routing
- Test agent dispatch with Two Worlds
- Test status reporting

**Integration Tests:**
- Verify all pipelines use Two Worlds Model
- Test consistency across pipelines
- Verify no conflicts

**Success Criteria:**
- ✅ All pipelines integrated
- ✅ Two Worlds Model applied consistently
- ✅ No agent context loss
- ✅ Governance consistent across all operations

---

## PHASE 5: Autonomy Round ⏳ PLANNED

**Priority:** P4 - Medium-Low  
**Status:** Planned (after Phase 3)  
**Goal:** Enable system self-monitoring and autonomous operations

### 5.1 Scope

**Autonomy Features:**
- CLS architecture review (Kevin-like logic)
- Liam creative autogeneration jobs
- GM auto-status heartbeat
- Mary routing history storage
- CLC auto-run background jobs safely

### 5.2 Blueprint: Autonomy Features

**5.2.1 CLS Architecture Review**
- Implement architecture review logic
- Auto-detect design issues
- Provide recommendations

**5.2.2 Liam Creative Generation**
- Enable autonomous creative tasks
- Generate prototypes automatically
- Explore system improvements

**5.2.3 GM Status Heartbeat**
- Auto-generate status reports
- Monitor system health
- Provide regular updates

**5.2.4 Mary Routing History**
- Store routing decisions
- Analyze routing patterns
- Optimize routing logic

**5.2.5 CLC Background Jobs**
- Auto-execute background WOs
- Safe background operations
- Automated system maintenance

### 5.3 Tasks Breakdown

**Task 5.1: CLS Architecture Review**
- [ ] Implement review logic
- [ ] Add issue detection
- [ ] Test recommendations

**Task 5.2: Liam Creative Generation**
- [ ] Enable autonomous tasks
- [ ] Test generation quality
- [ ] Verify safety

**Task 5.3: GM Status Heartbeat**
- [ ] Implement heartbeat system
- [ ] Test status generation
- [ ] Verify monitoring

**Task 5.4: Mary Routing History**
- [ ] Implement history storage
- [ ] Add analytics
- [ ] Test optimization

**Task 5.5: CLC Background Jobs**
- [ ] Enable auto-execution
- [ ] Test safety mechanisms
- [ ] Verify operations

### 5.4 Test Strategy

**Autonomy Tests:**
- Test each autonomy feature
- Verify safety mechanisms
- Test quality of autonomous operations

**Integration Tests:**
- Test feature interactions
- Verify no conflicts
- Test system stability

**Success Criteria:**
- ✅ All autonomy features working
- ✅ Safety mechanisms functional
- ✅ System self-monitoring active
- ✅ Background jobs running safely

---

## FINAL PHASE: Governance Freeze ⏳ FUTURE

**Priority:** P5 - After Stable  
**Status:** Future (after Phase 5)  
**Goal:** Freeze governance spec and publish operational SOT

### Final.1 Scope

**Deliverables:**
- AI_OP_002 (New Governance Law)
- Persona v3 finalized
- Routing diagrams
- Execution flow diagrams
- Developer Handbook

### Final.2 Blueprint: Governance Freeze

**Final.2.1 Documentation**
- Create AI_OP_002 document
- Finalize Persona v3 specifications
- Create routing diagrams
- Create execution flow diagrams
- Write Developer Handbook

**Final.2.2 Publication**
- Publish SOT documents
- Create reference materials
- Update all documentation
- Archive legacy documents

### Final.3 Tasks Breakdown

**Task Final.1: Documentation Creation**
- [ ] Create AI_OP_002
- [ ] Finalize Persona v3
- [ ] Create diagrams
- [ ] Write Developer Handbook

**Task Final.2: Publication**
- [ ] Publish SOT documents
- [ ] Create reference materials
- [ ] Update documentation
- [ ] Archive legacy

### Final.4 Success Criteria

- ✅ All documentation complete
- ✅ SOT published
- ✅ Reference materials available
- ✅ System ready for expansion

---

## Diagrams

### Phase Flow Diagram

```
Phase 0 (Foundation) ✅
    ↓
Phase 1 (Persona v3 Deploy) ✅
    ↓
Phase 2 (Runtime Alignment) 🟡
    ↓
Phase 3 (Mary Phase 2) ⏳
    ↓
Phase 4 (Pipeline Integration) ⏳
    ↓
Phase 5 (Autonomy) ⏳
    ↓
Final (Governance Freeze) ⏳
```

### Two Worlds Model Diagram

```
┌─────────────────────────────────────┐
│         WHO TRIGGERED?              │
└─────────────────────────────────────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼───┐    ┌────▼────┐
│  CLI  │    │Background│
│ World │    │  World   │
└───┬───┘    └────┬────┘
    │             │
    │      ┌──────┴──────┐
    │      │             │
┌───▼───┐ ┌▼───┐    ┌───▼───┐
│ Open  │ │Lock│    │ Open  │
│ Zone  │ │Zone│    │ Zone  │
└───┬───┘ └─┬──┘    └───┬───┘
    │       │           │
    │   ┌───▼───┐   ┌───▼───┐
    │   │ WARN  │   │ AUDIT │
    │   │(Override│  │REQUIRED│
    │   │Allowed)│  │        │
    │   └───────┘   └───────┘
    │
┌───▼───┐
│ FAST  │
│ LANE  │
│(Direct│
│ Write)│
└───────┘
```

### Agent Permission Matrix

```
Agent        │ CLI World │ Background │ Locked Zone │ Open Zone
─────────────┼───────────┼────────────┼─────────────┼──────────
CLS          │ ✅ Write  │ ✅ Write   │ ⚠️ Warn     │ ✅ Write
GG           │ ⚠️ Propose│ ⚠️ Propose │ ❌ No       │ ⚠️ Propose
GM           │ ⚠️ Propose│ ❌ No      │ ❌ No       │ ⚠️ Propose
Liam         │ ✅ Write  │ ❌ No      │ ⚠️ Warn     │ ✅ Write
Mary         │ 🚦 Router │ 🚦 Router  │ 🚦 Router   │ 🚦 Router
CLC          │ ❌ No     │ ✅ Write   │ ✅ Write    │ ⚠️ Rare
GMX          │ ✅ Write  │ ❌ No      │ ⚠️ Warn     │ ✅ Write
Codex        │ ✅ Write  │ ❌ No      │ ⚠️ Warn     │ ✅ Write
Gemini       │ ✅ Write  │ ✅ Write   │ ⚠️ Warn     │ ✅ Write
LAC          │ ✅ Write  │ ✅ Write   │ ⚠️ Warn     │ ✅ Write
```

---

## Risk Assessment

**High Risk:**
- Phase 1: Persona migration may break existing workflows
- Phase 2: Runtime alignment may cause permission conflicts

**Medium Risk:**
- Phase 3: Mary enforcement may be too strict
- Phase 4: Pipeline integration may introduce bugs

**Low Risk:**
- Phase 5: Autonomy features are additive
- Final: Documentation is low-risk

**Mitigation:**
- Extensive testing at each phase
- Rollback plan for each phase
- Gradual rollout approach
- Boss approval at each phase

---

## Dependencies

**External:**
- None (all dependencies are internal)

**Internal:**
- Phase 1 → Phase 2 (personas must be deployed first)
- Phase 2 → Phase 3 (runtime must be aligned)
- Phase 3 → Phase 4 (Mary must be functional)
- Phase 4 → Phase 5 (pipelines must be integrated)

---

## Timeline Estimate

- **Phase 1:** 2-3 days (persona creation + testing)
- **Phase 2:** 3-5 days (runtime alignment + testing)
- **Phase 3:** 5-7 days (Mary Phase 2 implementation)
- **Phase 4:** 7-10 days (pipeline integration)
- **Phase 5:** 10-14 days (autonomy features)
- **Final:** 5-7 days (documentation + freeze)

**Total:** ~6-8 weeks for complete rollout

---

## Next Steps

1. ✅ **Phase 1: COMPLETE** - Persona v3 deployed and validated (99.5% score)
2. **Immediate:** Begin Phase 2 (Runtime Alignment)
3. **Continuous:** Monitor and adjust based on results

---

**Plan Status:** Phase 1 Complete → Phase 2 Ready  
**Last Updated:** 2025-12-09
