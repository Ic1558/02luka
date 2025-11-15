# Feature PLAN: Liam - Local Orchestrator System

**Date:** 2025-11-16  
**Feature:** Liam - Local Orchestrator with GG-level reasoning + Andy-level execution

---

## Phase 1: Identity Definition & Contract Creation

### Tasks
1. Create Liam agent contract document
2. Define identity boundaries (Liam ≠ GG, ≠ Andy, ≠ CLS, ≠ CLC)
3. Document core principle: "Reason like GG. Operate like Andy. Review like CLS. Respect governance like CLC."
4. Define personality traits

### Files to Create
- `docs/LIAM_LOCAL_ORCHESTRATOR_CONTRACT.md` - Full agent definition
- `docs/AGENT_IDENTITY_MATRIX.md` - Comparison table (Liam vs other agents)

### Implementation Notes
- Use GG Orchestrator Contract as base template
- Clearly distinguish Liam from other agents
- Document personality and behavior patterns

---

## Phase 2: Standard Output Format Implementation

### Tasks
1. Implement `gg_decision` block generation
2. Create helper function/template for standard output
3. Ensure every actionable response includes decision block
4. Validate decision block format

### Files to Create
- `tools/liam_decision_block.zsh` - Helper script for decision block generation
- `schemas/liam_decision_schema.yaml` - Schema definition

### Implementation Notes
- Decision block MUST be produced BEFORE execution
- Include all required fields: task_type, complexity, risk_level, impact_zone, route, next_step, notes
- Format as YAML for machine readability

---

## Phase 3: Routing Logic Implementation

### Tasks
1. Implement task classification logic
2. Implement routing decision matrix
3. Create routing helper functions
4. Support non-linear, parallel routing

### Files to Create
- `tools/liam_router.zsh` - Routing logic implementation
- `schemas/liam_routing_matrix.yaml` - Routing decision matrix

### Implementation Notes
- Inherit routing logic from GG Orchestrator Contract
- Support parallel agent execution
- Handle delegation to Andy, CLS, CLC, Luka, Gemini

---

## Phase 4: Governance Boundary Enforcement

### Tasks
1. Implement prohibited zone detection
2. Implement allowed zone validation
3. Create SPEC-only mode for governance changes
4. Implement CLC routing for prohibited zones

### Files to Create
- `tools/liam_governance_check.zsh` - Governance boundary checker
- `schemas/liam_prohibited_zones.yaml` - Prohibited zone list
- `schemas/liam_allowed_zones.yaml` - Allowed zone list

### Implementation Notes
- Check impact_zone before any file write
- If prohibited → Generate SPEC only, route to CLC
- If allowed → Proceed with execution

---

## Phase 5: PR Prompt Contract Generator

### Tasks
1. Implement PR Prompt Contract template
2. Generate contracts for `pr_change` tasks
3. Include all required sections (Background, Scope, Changes, Tests, Safety)
4. Validate contract completeness

### Files to Create
- `tools/liam_pr_contract_generator.zsh` - PR contract generator
- `templates/liam_pr_contract_template.md` - Contract template

### Implementation Notes
- Generate contracts automatically for pr_change tasks
- Include safety boundaries
- Reference Codex Sandbox Mode

---

## Phase 6: SPEC/PLAN Generator

### Tasks
1. Implement SPEC document generator
2. Implement PLAN document generator
3. Create templates for SPEC/PLAN
4. Support complex task breakdown

### Files to Create
- `tools/liam_spec_generator.zsh` - SPEC generator
- `tools/liam_plan_generator.zsh` - PLAN generator
- `templates/liam_spec_template.md` - SPEC template
- `templates/liam_plan_template.md` - PLAN template

### Implementation Notes
- Use `/feature-dev` workflow
- Ask clarifying questions when needed
- Generate TODO lists
- Propose test strategies

---

## Phase 7: Multi-Agent Collaboration Integration

### Tasks
1. Implement delegation to Andy
2. Implement validation with CLS
3. Implement SPEC routing to CLC
4. Implement execution routing to Luka/Gemini

### Files to Create
- `tools/liam_agent_delegator.zsh` - Agent delegation helper
- `docs/LIAM_COLLABORATION_GUIDE.md` - Collaboration patterns

### Implementation Notes
- Define clear handoff protocols
- Support parallel execution
- Track delegation status

---

## Phase 8: Testing & Validation

### Tasks
1. Test task classification
2. Test routing decisions
3. Test governance boundary enforcement
4. Test file writes in allowed zones
5. Test SPEC-only mode for prohibited zones
6. Test PR contract generation
7. Test SPEC/PLAN generation
8. Test multi-agent collaboration

### Test Cases

#### Classification Tests
- [ ] Pure Q&A → task_type=qa, route=GG
- [ ] Single file fix → task_type=local_fix, route=Andy
- [ ] Multi-file change → task_type=pr_change, route=Liam
- [ ] Governance change → task_type=pr_change, impact_zone=governance, route=CLC

#### Routing Tests
- [ ] Dev work (complex) → Liam
- [ ] Dev work (simple) → Andy
- [ ] Dev work (needs review) → Liam → CLS
- [ ] Governance → Liam → SPEC → CLC
- [ ] CLI execution → Luka/Gemini

#### Governance Tests
- [ ] Attempt write to prohibited zone → Generate SPEC only
- [ ] Write to allowed zone → Proceed with execution
- [ ] Validate impact_zone detection

#### Output Format Tests
- [ ] Every execution includes gg_decision block
- [ ] Decision block has all required fields
- [ ] Format is valid YAML

#### PR Contract Tests
- [ ] pr_change tasks generate contracts
- [ ] Contracts include all required sections
- [ ] Safety boundaries included

#### SPEC/PLAN Tests
- [ ] Complex tasks generate SPEC
- [ ] SPEC includes clarifying questions
- [ ] PLAN includes TODO list
- [ ] PLAN includes test strategy

### Test Commands
```bash
# Test classification
tools/liam_router.zsh "fix bug in apps/dashboard/dashboard.js"

# Test governance check
tools/liam_governance_check.zsh "02luka.md"

# Test PR contract generation
tools/liam_pr_contract_generator.zsh pr_change "feat: new feature"

# Test SPEC generation
tools/liam_spec_generator.zsh "feature_xyz"
```

---

## Phase 9: Documentation

### Tasks
1. Document Liam identity and role
2. Document routing rules
3. Document governance boundaries
4. Document collaboration patterns
5. Document usage examples

### Files to Create
- `docs/LIAM_LOCAL_ORCHESTRATOR_CONTRACT.md` - Full contract (from Phase 1)
- `docs/LIAM_USAGE_GUIDE.md` - Usage guide
- `docs/LIAM_EXAMPLES.md` - Example workflows

---

## Phase 10: CLS Verification

### Tasks
1. CLS reviews implementation
2. CLS verifies governance boundaries
3. CLS validates routing logic
4. CLS checks identity clarity
5. Fix any issues found

---

## TODO List

### Phase 1: Identity
- [ ] Create `docs/LIAM_LOCAL_ORCHESTRATOR_CONTRACT.md`
- [ ] Create `docs/AGENT_IDENTITY_MATRIX.md`
- [ ] Document core principle
- [ ] Define personality traits

### Phase 2: Output Format
- [ ] Create `tools/liam_decision_block.zsh`
- [ ] Create `schemas/liam_decision_schema.yaml`
- [ ] Implement decision block generation
- [ ] Validate format

### Phase 3: Routing
- [ ] Create `tools/liam_router.zsh`
- [ ] Create `schemas/liam_routing_matrix.yaml`
- [ ] Implement classification logic
- [ ] Implement routing decisions

### Phase 4: Governance
- [ ] Create `tools/liam_governance_check.zsh`
- [ ] Create `schemas/liam_prohibited_zones.yaml`
- [ ] Create `schemas/liam_allowed_zones.yaml`
- [ ] Implement boundary enforcement

### Phase 5: PR Contracts
- [ ] Create `tools/liam_pr_contract_generator.zsh`
- [ ] Create `templates/liam_pr_contract_template.md`
- [ ] Implement contract generation
- [ ] Validate completeness

### Phase 6: SPEC/PLAN
- [ ] Create `tools/liam_spec_generator.zsh`
- [ ] Create `tools/liam_plan_generator.zsh`
- [ ] Create `templates/liam_spec_template.md`
- [ ] Create `templates/liam_plan_template.md`
- [ ] Implement generators

### Phase 7: Collaboration
- [ ] Create `tools/liam_agent_delegator.zsh`
- [ ] Create `docs/LIAM_COLLABORATION_GUIDE.md`
- [ ] Implement delegation
- [ ] Implement validation routing

### Phase 8: Testing
- [ ] Test classification
- [ ] Test routing
- [ ] Test governance boundaries
- [ ] Test file writes
- [ ] Test PR contracts
- [ ] Test SPEC/PLAN
- [ ] Test collaboration

### Phase 9: Documentation
- [ ] Create `docs/LIAM_USAGE_GUIDE.md`
- [ ] Create `docs/LIAM_EXAMPLES.md`
- [ ] Document all features

### Phase 10: Verification
- [ ] CLS reviews
- [ ] Fix issues
- [ ] Final validation

---

## Test Strategy

### Unit Tests
- Classification logic: Test task_type, complexity, risk_level, impact_zone
- Routing logic: Test routing decisions for different scenarios
- Governance check: Test prohibited/allowed zone detection
- Output format: Test gg_decision block generation

### Integration Tests
- Full workflow: Boss request → Classification → Routing → Execution
- Multi-agent: Test delegation to Andy, CLS, CLC
- PR workflow: Test PR contract generation → PR creation
- SPEC workflow: Test SPEC generation → CLC routing

### Safety Tests
- Prohibited zone protection: Attempt write → Should generate SPEC only
- Allowed zone access: Write should succeed
- Identity clarity: Never confuse with other agents
- Governance boundaries: Always respect prohibited zones

### Performance Tests
- Classification speed
- Routing decision speed
- File write performance
- Contract generation speed

---

## Implementation Priority

1. **Phase 1** (Identity) - Foundation, must complete first
2. **Phase 2** (Output Format) - Required for all operations
3. **Phase 3** (Routing) - Core functionality
4. **Phase 4** (Governance) - Safety critical
5. **Phase 5** (PR Contracts) - Important for workflow
6. **Phase 6** (SPEC/PLAN) - Complex task support
7. **Phase 7** (Collaboration) - Multi-agent support
8. **Phase 8** (Testing) - Validation
9. **Phase 9** (Documentation) - User guidance
10. **Phase 10** (Verification) - Quality gate

---

## Risk Mitigation

1. **Identity Confusion**
   - Clear documentation
   - Explicit identity checks
   - Never claim to be GG/Andy/CLS/CLC

2. **Governance Violations**
   - Strict boundary checking
   - SPEC-only mode for prohibited zones
   - CLS verification

3. **Routing Errors**
   - Comprehensive test coverage
   - Clear decision matrix
   - Fallback to safe defaults

4. **Execution Failures**
   - Graceful error handling
   - Rollback capabilities
   - Clear error messages

---

**Plan Owner:** Liam (self-implementation)  
**Implementer:** Liam (self-implementation)  
**Verifier:** CLS
