# 02luka V3.5 Blueprint — SPEC

**Version**: 3.5 (Minor Upgrade)  
**Type**: Architecture Refresh + Persona Upgrade  
**Date**: 2025-11-21  
**Owner**: Liam (Local Orchestrator)  
**Approved by**: Boss

---

## 1. Objective

Create a formal **02luka V3.5 Stable Architecture Blueprint** that:

- Documents the current stable architecture
- Formalizes Liam V3.5 persona with lane system
- Clarifies GMX v2 integration
- Defines safeguard model (soft/hard)
- Ensures zero breaking changes
- Requires zero migration effort

---

## 2. Scope

### In Scope:
- ✅ Architecture documentation (6-layer model)
- ✅ Liam V3.5 persona formalization
- ✅ GMX v2 planner role clarification
- ✅ Lane system (feature-dev, code-review, deploy)
- ✅ Safeguard architecture (soft/hard)
- ✅ Comparison table (CLC vs V3.5)
- ✅ Migration plan (zero effort)

### Out of Scope:
- ❌ Code changes to executor.py
- ❌ Code changes to GMX CLI
- ❌ Code changes to overseer
- ❌ AP/IO schema changes
- ❌ Bridge format changes
- ❌ Breaking changes of any kind

---

## 3. Deliverables

### Primary:
1. **`g/reports/250121_02luka_V3.5_Blueprint.md`**
   - Complete architecture blueprint
   - 6-layer model diagram
   - Role definitions
   - Flow diagrams
   - Safeguard matrix

### Supporting:
2. **`g/reports/250121_02luka_V3.5_SPEC.md`** (this file)
3. **`g/reports/250121_02luka_V3.5_PLAN.md`** (implementation plan)
4. **AP/IO ledger entry**: `architecture_blueprint_created`

---

## 4. Requirements

### Functional:
- Blueprint must be readable by all agents (GG, Liam, GMX, etc.)
- Must serve as SOT-level reference for 2025
- Must clearly distinguish V3 vs V3.5 changes
- Must document zero-migration path

### Non-Functional:
- Document length: ~2000-3000 words
- Format: Markdown with clear sections
- Diagrams: ASCII art (no external tools)
- Language: Professional technical documentation

---

## 5. Constraints

- **No code changes** (documentation only)
- **Backward compatible** with all V3 workflows
- **Zero migration** required
- **No breaking changes**

---

## 6. Success Criteria

- [ ] Blueprint document created in `g/reports/`
- [ ] All 9 sections complete (Executive Summary → Next Steps)
- [ ] 6-layer architecture diagram included
- [ ] Comparison table (CLC vs V3.5) included
- [ ] Migration plan confirms zero effort
- [ ] AP/IO event logged
- [ ] Boss approval received

---

## 7. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Users expect V4-level changes | Medium | Low | Clearly label as "V3.5 Minor Upgrade" |
| Confusion about migration | Low | Low | Emphasize "zero migration" throughout |
| Documentation drift | Low | Medium | Make this the SOT reference |

---

## 8. Dependencies

- None (documentation-only task)

---

## 9. Timeline

- **Spec creation**: Immediate
- **Plan creation**: Immediate
- **Blueprint creation**: 5 minutes
- **Review**: Boss approval
- **Total**: < 1 hour

---

**Status**: ✅ SPEC COMPLETE - READY FOR PLAN
