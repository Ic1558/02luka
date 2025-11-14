# Feature SPEC: Multi-Agent PR Contract & Template Upgrade

**Date:** 2025-11-15  
**Feature:** Multi-Agent PR Contract & Template  
**Branch:** `feature/multi-agent-pr-contract`  
**Type:** Governance / Documentation

---

## 1. Problem Statement

Current PR template is too generic and doesn't help multi-agent system (GG, GC, CLS, Mary, Kim, etc.) understand:
- What type of change this is (PR/Feature vs Local Fix vs WO vs Asking)
- Which agents are impacted
- Whether it affects routing, security, or contracts between agents
- How to route the PR for review and testing

This causes:
- Agents guessing context
- Inconsistent routing decisions
- Missing safety checks (sandbox, security)
- Unclear impact assessment

---

## 2. Goals

1. **Upgrade PR Template** to support:
   - 4 routing types (PR/Feature/Governance, Local Fix, WO/Automation, Asking/Docs-only)
   - Multi-agent impact checklist
   - Sandbox/safety validation
   - Clear before/after behavior changes

2. **Create Multi-Agent PR Contract** document:
   - SOT for routing rules
   - Integration guidelines for GG/GC/CLS/Mary
   - Contract enforcement rules

3. **Create Intent Routing Cheat Sheet** (optional):
   - Human/bot-readable decision tree
   - Signal keywords for auto-routing

---

## 3. Scope

### ✅ Included
- `.github/PULL_REQUEST_TEMPLATE.md` - Complete rewrite
- `docs/MULTI_AGENT_PR_CONTRACT.md` - New contract document
- `docs/MULTI_AGENT_INTENT_ROUTING.md` - Optional cheat sheet

### ❌ Excluded
- No changes to agent code (GG, GC, CLS, Mary, etc.)
- No changes to server code
- No changes to security PR in progress
- No changes to execution scripts
- No implementation of auto-routing bot (docs only)

---

## 4. Requirements

### 4.1 PR Template Requirements
- Must support 4 routing types with clear checkboxes
- Must have multi-agent impact checklist (GG, GC, CLS, Mary, Kim, Lisa, Paula)
- Must include sandbox/safety checklist
- Must have before/after behavior change section
- Must include rollback plan
- Must be human-readable and bot-parseable

### 4.2 Contract Document Requirements
- Must define 4 routing types clearly
- Must explain when to use each type
- Must define multi-agent contract rules
- Must reference existing docs (CODEX_SANDBOX_MODE.md, etc.)
- Must explain integration with local bots/Codex

### 4.3 Intent Routing Requirements (Optional)
- Must provide decision tree
- Must list signal keywords
- Must explain contract between agents

---

## 5. Success Criteria

1. ✅ PR template supports all 4 routing types
2. ✅ Contract document is clear and complete
3. ✅ All files are in correct locations
4. ✅ No syntax errors in markdown
5. ✅ References to existing docs are correct
6. ✅ Template is backward-compatible (can be filled manually)

---

## 6. Clarifying Questions

**Q1:** Should we keep any parts of the existing PR template?  
**A:** No - complete rewrite as specified.

**Q2:** Should the template reference specific agent names or be generic?  
**A:** Use specific names (GG, GC, CLS, Mary, Kim, Lisa, Paula) as per spec.

**Q3:** Should we create a config file for routing rules?  
**A:** Not in this PR - docs only. Future enhancement.

**Q4:** Should we update any existing docs to reference the new contract?  
**A:** Not required for this PR - can be done in follow-up.

---

## 7. Assumptions

- Existing docs structure remains unchanged
- No breaking changes to current PR workflow
- Template will be filled manually initially (auto-fill is future work)
- All agents can read markdown files

---

## 8. Dependencies

- None - this is a standalone governance/documentation change

---

## 9. Risks

- **Low Risk:** Documentation-only change
- **Mitigation:** Review template carefully before merge
- **Rollback:** Simple revert if issues found

---

**Status:** ✅ SPEC Complete  
**Next:** Create PLAN.md

