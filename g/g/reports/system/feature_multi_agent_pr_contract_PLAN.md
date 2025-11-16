# Feature PLAN: Multi-Agent PR Contract & Template Upgrade

**Date:** 2025-11-15  
**Feature:** Multi-Agent PR Contract & Template  
**Branch:** `feature/multi-agent-pr-contract`

---

## Phase 1: Branch Setup & Preparation

### Tasks
1. ✅ Create feature branch from main
2. ✅ Verify no conflicts with security PR
3. ✅ Check existing PR template location

### Commands
```bash
git checkout main
git pull origin main
git checkout -b feature/multi-agent-pr-contract
```

---

## Phase 2: Create PR Template

### Tasks
1. Replace `.github/PULL_REQUEST_TEMPLATE.md` with new comprehensive template
2. Include all sections:
   - Summary (Title, Problem, Solution, Risk)
   - Change Type (4 routing types)
   - Impacted Areas (Agents checklist)
   - Files & Scope
   - Multi-Agent Contract
   - Codex/Sandbox Safety
   - Testing
   - Rollback Plan
   - Notes for Reviewers

### File: `.github/PULL_REQUEST_TEMPLATE.md`
- Complete rewrite as per spec
- All checkboxes and sections included

---

## Phase 3: Create Contract Document

### Tasks
1. Create `docs/MULTI_AGENT_PR_CONTRACT.md`
2. Include sections:
   - Goals
   - 4 Routing Types (detailed)
   - Multi-Agent Contract rules
   - Integration with PR Template
   - Integration with Local Bot/Codex
   - Rules for GG/GC/CLS/Mary
   - Future expansion

### File: `docs/MULTI_AGENT_PR_CONTRACT.md`
- New file
- Complete contract specification

---

## Phase 4: Create Intent Routing Cheat Sheet

### Tasks
1. Create `docs/MULTI_AGENT_INTENT_ROUTING.md`
2. Include:
   - Routing Question Tree
   - Signal keywords for bot
   - Contract between agents

### File: `docs/MULTI_AGENT_INTENT_ROUTING.md`
- New file
- Optional but recommended

---

## Phase 5: Verification & Testing

### Tasks
1. Syntax check all markdown files
2. Verify all links/references are correct
3. Check template renders correctly on GitHub
4. Manual review of content

### Commands
```bash
# Check markdown syntax
find .github docs -name "*.md" -exec echo "Checking {}" \;

# Verify file locations
ls -la .github/PULL_REQUEST_TEMPLATE.md
ls -la docs/MULTI_AGENT_PR_CONTRACT.md
ls -la docs/MULTI_AGENT_INTENT_ROUTING.md
```

---

## Phase 6: Commit & PR Creation

### Tasks
1. Stage all new/modified files
2. Commit with descriptive message
3. Push branch
4. Create PR with proper title

### Commit Message
```
feat(governance): multi-agent PR contract & template upgrade

- Add comprehensive PR template with 4 routing types
- Add MULTI_AGENT_PR_CONTRACT.md (SOT for routing rules)
- Add MULTI_AGENT_INTENT_ROUTING.md (cheat sheet)
- Support multi-agent impact tracking (GG, GC, CLS, Mary, etc.)
- Include sandbox/safety checklists
- Docs-only change (no code changes)
```

### PR Title
```
feat(governance): multi-agent PR contract & template upgrade
```

---

## Test Strategy

### Manual Testing
1. ✅ Create test PR using new template
2. ✅ Verify all sections render correctly
3. ✅ Check markdown formatting
4. ✅ Verify links work

### Validation
- [ ] Template is complete and clear
- [ ] Contract document is comprehensive
- [ ] Cheat sheet is useful
- [ ] No broken references
- [ ] Files in correct locations

---

## Rollback Plan

If issues found after merge:
1. Revert commit: `git revert <commit-sha>`
2. Restore old template if needed (from git history)
3. No code changes to rollback (docs only)

---

## Timeline

- **Phase 1:** 2 min (branch setup)
- **Phase 2:** 5 min (template creation)
- **Phase 3:** 5 min (contract doc)
- **Phase 4:** 3 min (cheat sheet)
- **Phase 5:** 3 min (verification)
- **Phase 6:** 2 min (commit & PR)

**Total:** ~20 minutes

---

**Status:** ✅ PLAN Complete  
**Next:** Execute implementation

