# Feature: Gemini Routing & Work Order Integration (Phase 2-3)

**Status:** SPEC (Planning Phase)  
**Date:** 2025-11-19  
**Requested Via:** `/feature-dev`  
**Phase:** 2-3 (Routing + WO Integration)  
**Prerequisite:** Phase 1 (Foundation) ✅ Complete

---

## 1. Problem Statement

**Current State:**
- ✅ Phase 1 Complete: Gemini connector, handler, memory loader, persona exist
- ✅ Basic routing exists in Liam and Kim router
- ✅ WO dispatcher has GEMINI case
- ✅ Protocol v3.2 has Layer 4.5 section

**Gaps:**
- Liam routing rules need enhancement (more comprehensive guardrails)
- GG Orchestrator Contract lacks dedicated Layer 4.5 section
- Template may need alignment with canonical WO format
- Missing explicit locked-zone rejection rules in routing logic

**Goal:**
Wire Gemini into the full routing + WO system with proper governance guardrails, ensuring it never touches locked zones and remains opt-in only.

---

## 2. Goals

### Primary Goals
1. **Enhanced Liam Routing:**
   - Comprehensive routing rules with locked-zone guards
   - Clear task-type → engine mapping
   - Explicit fallback chains

2. **GG Orchestrator Contract:**
   - Dedicated Layer 4.5 section for Gemini lane
   - Clear role definition and constraints

3. **Protocol v3.2 Alignment:**
   - Ensure Layer 4.5 section matches routing rules
   - Clarify fallback ladder for Gemini

4. **WO Template Standardization:**
   - Align template with canonical WO format
   - Add review_required_by and constraints fields

5. **Kim Router Enhancement:**
   - Explicit locked-zone rejection
   - Task-type validation

### Secondary Goals
- Ensure .gitkeep files exist for GEMINI inbox/outbox
- Add validation checks to prevent locked-zone routing
- Document routing decision flow

---

## 3. Technical Approach

### 3.1 Architecture Overview

```
┌─────────────┐
│   GG/Liam   │  ← Routing decision
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Kim Router │  ← WO creation + validation
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ WO Dispatcher│  ← Route to GEMINI inbox
└──────┬──────┘
       │
       ▼
┌─────────────┐
│Gemini Handler│  ← Process WO
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ GEMINI Outbox│  ← Results (patch/spec)
└─────────────┘
```

### 3.2 Components to Modify

#### A. Liam Routing (`agents/liam/PERSONA_PROMPT.md`)

**Current State:**
- Has `gemini` in route_to enum ✅
- Basic routing rules exist ✅
- Needs: More comprehensive rules + locked-zone guards

**Changes Required:**
```yaml
gg_decision:
  route_to: andy | cls | clc_spec | gemini | external

routing_rules:
  # Heavy compute tasks → Gemini
  - when:
      task_type: ["bulk_operations", "test_generation", "heavy_refactor", "code_explain"]
      impact_zone: ["apps", "tools", "tests", "docs"]
      locked_zone: false
    then:
      prefer: gemini
      fallback: [andy, cls]
      reason: "Heavy compute, non-locked zone → offload to Gemini"

  # Locked zones → NEVER Gemini
  - when:
      impact_zone: ["locked", "governance", "bridge_core", "/CLC", "/CLS"]
    then:
      prefer: clc_spec
      forbid: [gemini, andy, cls]
      reason: "Locked zone → CLC only"

  # Multi-file operations → Gemini
  - when:
      file_count: [">=5"]
      impact_zone: ["apps", "tools"]
      locked_zone: false
    then:
      prefer: gemini
      reason: "Multi-file bulk operation → Gemini"

  # Default fallback
  - when:
      impact_zone: ["apps", "tools"]
      locked_zone: false
    then:
      prefer: cls
      fallback: [andy, gemini]
```

#### B. GG Orchestrator Contract (`g/docs/GG_ORCHESTRATOR_CONTRACT.md`)

**Current State:**
- Mentions Gemini in section 4.0 ✅
- Lacks dedicated Layer 4.5 section ❌

**Changes Required:**
Add new section after 4.3:

```markdown
### 4.4 Layer 4.5 — Gemini (Heavy Compute / Non-Locked Zones)

**Role:**
- Heavy compute offloader for bulk operations
- Bulk test generation
- Non-locked refactors
- Multi-file code analysis

**Input:**
- Work Order with `engine: gemini`
- Target files (non-locked zones only)
- Constraints (max_tokens, temperature, timeout)

**Output:**
- Patch/spec in `bridge/outbox/GEMINI/`
- Always reviewed by Andy/CLS before apply
- Never directly modifies SOT

**Constraints:**
- **May NOT:**
  - Touch `/CLC`, `/CLS`, `/bridge/core`, governance docs
  - Bypass SIP / WO system
  - Write directly to SOT (patch-only)
- **Must:**
  - Respect Protocol v3.2 locked zones
  - Generate reviewable patches/specs
  - Log all operations to MLS

**Fallback:**
- If Gemini quota exhausted → CLC or Gemini IDE
- If locked zone detected → route to CLC
```

#### C. Context Protocol v3.2 (`g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`)

**Current State:**
- Layer 4.5 section exists (lines 286-498) ✅
- Comprehensive documentation ✅

**Changes Required:**
- Verify fallback ladder mentions Gemini → CLC/Gemini IDE
- Ensure locked-zone rules are explicit
- Add note about WO integration

**Verification:**
- Section 4.5 exists and is accurate ✅
- Fallback ladder mentions Gemini API (line 80) ✅
- May need minor clarification on WO path

#### D. WO Dispatcher (`tools/wo_dispatcher.zsh`)

**Current State:**
- Has GEMINI case (line 32) ✅
- Handles `engine: gemini` → `GEMINI` conversion ✅

**Changes Required:**
- ✅ Already complete
- Verify logging includes `engine=gemini` in trace

#### E. Kim Router (`agents/kim_bot/kim_router.py`)

**Current State:**
- Has `route_engine()` function with GEMINI logic ✅
- Has `HEAVY_INTENTS` set ✅
- Needs: Explicit locked-zone rejection

**Changes Required:**
```python
def route_engine(intent: str, payload: Dict[str, Any]) -> str:
    """Return the execution engine for a given Kim intent and payload."""
    
    # CRITICAL: Locked zones → CLC only
    if payload.get("locked_zone") or payload.get("impact_zone") in [
        "locked", "governance", "bridge_core", "/CLC", "/CLS"
    ]:
        return "CLC"
    
    # Heavy intents → Gemini (non-locked only)
    if intent in HEAVY_INTENTS:
        return "GEMINI"
    
    # Default → CLC
    return "CLC"
```

#### F. WO Template (`bridge/templates/gemini_task_template.yaml`)

**Current State:**
- Template exists ✅
- Format is close but may need alignment

**Changes Required:**
Align with canonical WO format from spec:

```yaml
wo_id: GEMINI_YYYYMMDD_HHMMSS_xxx
engine: gemini
task_type: bulk_test_generation  # or code_transform, non_locked_refactor
impact_zone: apps  # apps, tools, tests, docs (non-locked only)
priority: normal

routing:
  prefer_agent: gemini
  review_required_by: andy  # or cls
  locked_zone_allowed: false  # MUST be false

target_files:
  - "g/apps/dashboard/**/*.js"

context:
  title: "Generate Jest tests for dashboard handlers"
  instructions: |
    Generate comprehensive Jest tests with 80%+ coverage.
    Focus on success, failure, and edge cases.

constraints:
  max_tokens: 4096
  temperature: 0.2
  allow_write: false  # Gemini produces patches only
  output_format: patch_unified
  timeout_seconds: 300

artifacts:
  expected_outputs:
    - "patches/dashboard_tests.diff"
    - "notes/dashboard_tests_review.md"

metadata:
  created_by: gg  # or kim, liam
  requested_via: "liam/feature-dev"
  tags:
    - "engine:gemini"
    - "kind:test_generation"
    - "zone:apps"
    - "protocol:v3.2"
```

#### G. Directory Structure

**Verify/Create:**
- `bridge/inbox/GEMINI/.gitkeep` ✅ (directory exists, check .gitkeep)
- `bridge/outbox/GEMINI/.gitkeep` ✅ (directory exists, check .gitkeep)

---

## 4. Implementation Tasks

### Phase 2: Routing Logic

- [ ] **Task 2.1:** Enhance Liam routing rules
  - Add comprehensive routing matrix with locked-zone guards
  - Add task-type → engine mapping
  - Add fallback chains
  - File: `agents/liam/PERSONA_PROMPT.md`

- [ ] **Task 2.2:** Add Layer 4.5 section to GG Contract
  - Create dedicated section 4.4
  - Define role, input, output, constraints
  - File: `g/docs/GG_ORCHESTRATOR_CONTRACT.md`

- [ ] **Task 2.3:** Verify Protocol v3.2 Layer 4.5
  - Check fallback ladder mentions Gemini
  - Verify locked-zone rules are explicit
  - Add WO integration note if needed
  - File: `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`

### Phase 3: Work Order Integration

- [ ] **Task 3.1:** Enhance Kim router
  - Add explicit locked-zone rejection
  - Validate task-type before routing
  - File: `agents/kim_bot/kim_router.py`

- [ ] **Task 3.2:** Standardize WO template
  - Align with canonical format
  - Add routing, constraints, artifacts sections
  - File: `bridge/templates/gemini_task_template.yaml`

- [ ] **Task 3.3:** Verify WO dispatcher
  - Confirm GEMINI case works
  - Verify logging includes engine=gemini
  - File: `tools/wo_dispatcher.zsh` (verify only)

- [ ] **Task 3.4:** Ensure directory structure
  - Check/create `.gitkeep` files
  - Verify GEMINI inbox/outbox exist
  - Files: `bridge/inbox/GEMINI/.gitkeep`, `bridge/outbox/GEMINI/.gitkeep`

---

## 5. Test Strategy

### Unit Tests
- **Liam Routing:** Test routing rules with various task types and zones
- **Kim Router:** Test locked-zone rejection, heavy intent routing
- **WO Template:** Validate YAML structure with `yq` or Python YAML parser

### Integration Tests
- **End-to-end:** GG → Liam → Kim → WO Dispatcher → Gemini Handler
- **Locked Zone Guard:** Verify Gemini never receives locked-zone tasks
- **WO Flow:** Create test WO, verify routing, check outbox

### Manual Validation
- [ ] `grep -R "GEMINI" bridge/tools/agents` shows only expected wiring
- [ ] No diff under `/CLC`, `/CLS`, `AI:OP-001`, or bridge core
- [ ] Liam prompt renders correctly and keeps locked-zone rules
- [ ] `bridge/templates/gemini_task_template.yaml` loads with `yq`/`python -c 'yaml.safe_load'`
- [ ] Dry-run WO example (manual): GEMINI_… yaml matches template layout

---

## 6. Risks & Mitigation

### Risks

1. **Locked Zone Bypass:**
   - **Risk:** Gemini receives locked-zone task
   - **Mitigation:** Multiple guards (Liam, Kim, WO dispatcher, handler)

2. **Routing Conflicts:**
   - **Risk:** Multiple routers disagree on engine
   - **Mitigation:** Clear precedence: locked-zone check → task-type → default

3. **Template Mismatch:**
   - **Risk:** WO format doesn't match handler expectations
   - **Mitigation:** Align template with handler schema, validate with YAML parser

4. **Documentation Drift:**
   - **Risk:** Protocol/Contract docs don't match implementation
   - **Mitigation:** Update docs in same PR, verify with grep checks

### Safety Constraints

- ✅ **No direct edits to:** `/CLC`, `/CLS`, `AI:OP-001`, `bridge/core`
- ✅ **Gemini never default:** Only picked for heavy/non-locked tasks
- ✅ **Always reviewed:** All Gemini output reviewed by Andy/CLS
- ✅ **Patch-only:** Gemini never writes directly to SOT

---

## 7. Dependencies

- **Existing:**
  - Phase 1 foundation (connector, handler, persona) ✅
  - WO dispatcher with GEMINI case ✅
  - Protocol v3.2 Layer 4.5 section ✅
  - Kim router with basic GEMINI logic ✅

- **New:**
  - None (all changes are enhancements to existing files)

---

## 8. Success Criteria

- ✅ Liam routing rules include comprehensive locked-zone guards
- ✅ GG Contract has dedicated Layer 4.5 section
- ✅ Kim router explicitly rejects locked zones
- ✅ WO template matches canonical format
- ✅ All validation checks pass (grep, YAML parsing, dry-run)
- ✅ No changes to locked/governance zones
- ✅ Documentation aligned with implementation

---

## 9. PR Description Template

```markdown
## feat(agent): wire Gemini routing + WO integration (Phase 2–3)

### Summary

Wire the existing Gemini agent foundation into:
- Liam routing rules (`route_to: gemini` for heavy/non-locked tasks)
- GG orchestrator contract + Context Protocol v3 (Layer 4.5)
- Work Order system (`bridge/inbox/outbox/GEMINI`)
- Kim router (NLP → GEMINI WO)

All changes are additive and respect locked/non-locked zone constraints.

### Changes

- **Liam:** Enhanced routing rules with locked-zone guards
- **GG Contract:** Added Layer 4.5 section for Gemini lane
- **Kim Router:** Explicit locked-zone rejection
- **WO Template:** Standardized to canonical format
- **Protocol v3.2:** Verified Layer 4.5 alignment

### Risks

- Low (routing + plumbing only)
- Gemini remains opt-in, never default
- Locked zones still enforced via protocol + router guards

### Validation

- [x] `grep -R "GEMINI" bridge/tools/agents` shows only expected wiring
- [x] No diff under /CLC, /CLS, AI:OP-001, or bridge core
- [x] Liam prompt renders correctly and keeps locked-zone rules
- [x] `bridge/templates/gemini_task_template.yaml` loads with `yq`/`python -c 'yaml.safe_load'`
- [x] Dry-run WO example (manual): GEMINI_… yaml matches template layout

### PR Score Rubric (target ≥ 85)

- Scope focused (routing + WO only): ✅
- Docs updated (contract + protocol): ✅
- Risks identified + mitigated: ✅
- Clear validation steps: ✅
- No surprise side effects: ✅
```

---

## 10. Related Documents

- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md` (Layer 4.5)
- `g/docs/GG_ORCHESTRATOR_CONTRACT.md` (Section 4.0)
- `g/docs/GEMINI_CLI_RULES.md` (Operational rules)
- `g/reports/feature_gemini_wo_templates_assessment.md` (WO templates)
- `g/reports/system/GEMINI_INTEGRATION_PLAN_20251118.md` (Phase 1)

---

**Status:** Ready for implementation. All Phase 1 foundation exists. Changes are additive and governance-compliant.
