# Feature: PR Management Decision System — PLAN

**Feature Slug:** `pr_management_decision_system`  
**Status:** Planning Phase  
**Created:** 2025-12-19  
**Based on:** SPEC.md

---

## Implementation Approach

### Phase 1: Decision Framework (Documentation)
**Goal**: Document clear rules for PR management decisions

**Tasks**:
1. Create decision framework document
   - When to create PR vs direct commit
   - PR merge order rules
   - Conflict resolution guidelines
   - Branch cleanup rules
2. Document decision patterns from recent experience
   - PR #407, #408 merge order (governance first, then persona)
   - Conflict resolution (use origin/main for auto-generated files)
   - File restoration workflow (worktree verification)

**Deliverable**: `g/docs/PR_MANAGEMENT_DECISION_FRAMEWORK_v1.md`

---

### Phase 2: Advisory Tool (Semi-Automated)
**Goal**: Create tool that provides PR management recommendations

**Tasks**:
1. Create `tools/pr_decision_advisory.zsh`
   - Analyze current PR state
   - Check branch status (diverged, conflicts)
   - Recommend merge order
   - Suggest conflict resolution approach
2. Integrate with gh CLI
   - Read PR status (mergeable, conflicts, dependencies)
   - Check branch relationships
3. Provide clear recommendations with evidence
   - Why this order?
   - What are the risks?
   - What needs Boss approval?

**Deliverable**: `tools/pr_decision_advisory.zsh`

---

### Phase 3: Safe Automation (Automated Operations)
**Goal**: Automate safe operations (verification, cleanup)

**Tasks**:
1. Enhance existing verification tools
   - `verify_persona_v5_after_merge.zsh` (already exists)
   - Add PR-specific verification
2. Create automated cleanup tool
   - Safe branch deletion (only if merged)
   - Worktree cleanup
3. Create decision log
   - Log decisions made
   - Log recommendations provided
   - Audit trail

**Deliverables**:
- Enhanced verification tools
- `tools/pr_cleanup_safe.zsh`
- `g/reports/pr_decisions/` (decision logs)

---

### Phase 4: Integration & Catalog
**Goal**: Integrate with existing systems

**Tasks**:
1. Add tools to catalog
   - `pr-decision-advisory`
   - `pr-cleanup-safe`
   - `pr-verify-after-merge`
2. Update documentation
   - Add to "What Gemini Should Know"
   - Update workflow guides
3. Create quick reference
   - PR management cheat sheet

**Deliverables**:
- Catalog entries
- Updated documentation
- Quick reference guide

---

## Task Breakdown

### TODO List

#### Phase 1: Decision Framework
- [ ] **Task 1.1**: Create PR_MANAGEMENT_DECISION_FRAMEWORK_v1.md
  - Document: When to PR vs commit directly
  - Document: PR merge order rules
  - Document: Conflict resolution guidelines
  - Document: Branch cleanup rules
  - Reference: Recent PR #407, #408 experience
  
- [ ] **Task 1.2**: Document decision patterns
  - Extract patterns from PR #407, #408
  - Document conflict resolution approach (hub/index.json case)
  - Document verification workflow (worktree approach)

#### Phase 2: Advisory Tool
- [ ] **Task 2.1**: Create pr_decision_advisory.zsh
  - Analyze PR state (mergeable, conflicts, dependencies)
  - Check branch relationships (diverged, ahead/behind)
  - Recommend merge order
  - Suggest conflict resolution
  
- [ ] **Task 2.2**: Integrate with gh CLI
  - Read PR status via gh CLI
  - Check PR dependencies
  - Detect conflicts early
  
- [ ] **Task 2.3**: Provide recommendations
  - Clear reasoning (why this order?)
  - Risk assessment
  - Boss approval flags

#### Phase 3: Safe Automation
- [ ] **Task 3.1**: Enhance verification tools
  - Extend verify_persona_v5_after_merge.zsh pattern
  - Create generic pr_verify_after_merge.zsh
  
- [ ] **Task 3.2**: Create cleanup tool
  - Safe branch deletion (check merged status)
  - Worktree cleanup
  - Confirmation prompts
  
- [ ] **Task 3.3**: Decision logging
  - Create decision log structure
  - Log recommendations
  - Log decisions made

#### Phase 4: Integration
- [ ] **Task 4.1**: Add to catalog
  - pr-decision-advisory
  - pr-cleanup-safe
  - pr-verify-after-merge
  
- [ ] **Task 4.2**: Update documentation
  - Add to gemini_context_what_to_know.md
  - Update workflow guides
  
- [ ] **Task 4.3**: Create quick reference
  - PR management cheat sheet

---

## Test Strategy

### Unit Tests
- [ ] Test decision framework logic (when to PR vs commit)
- [ ] Test advisory tool recommendations
- [ ] Test conflict detection

### Integration Tests
- [ ] Test with real PRs (dry-run mode)
- [ ] Test verification workflow
- [ ] Test cleanup operations

### Manual Verification
- [ ] Boss reviews decision framework
- [ ] Test advisory tool with actual PRs
- [ ] Verify decision logs

---

## Risk Assessment

### High Risk
- **Wrong merge order**: Could break dependencies
  - **Mitigation**: Clear rules, Boss approval for critical decisions
  
- **Lost work**: Incorrect conflict resolution
  - **Mitigation**: Always backup, use worktree for verification

### Medium Risk
- **Over-automation**: Automating things that need human judgment
  - **Mitigation**: Keep Boss approval for critical decisions

### Low Risk
- **Tool integration issues**: gh CLI API changes
  - **Mitigation**: Fallback to manual process

---

## Dependencies

- gh CLI (already installed)
- git (already installed)
- Existing tools (catalog, verification scripts)
- Governance docs (GOVERNANCE_UNIFIED_v5.md, AI_OP_001_v5.md)

---

## Timeline Estimate

- **Phase 1**: 1-2 hours (documentation)
- **Phase 2**: 2-3 hours (advisory tool)
- **Phase 3**: 1-2 hours (automation)
- **Phase 4**: 1 hour (integration)

**Total**: ~5-8 hours

---

## Success Metrics

- [ ] Decision framework document created and reviewed
- [ ] Advisory tool provides useful recommendations
- [ ] No PR management mistakes after implementation
- [ ] Boss confidence in PR management decisions increases
- [ ] Decision logs provide useful audit trail

---

**Next Step**: Review PLAN with Boss, then proceed with Phase 1
