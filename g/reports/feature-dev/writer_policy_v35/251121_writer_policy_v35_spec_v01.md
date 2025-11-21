# V3.5 Writer Policy — SPEC

**Version**: V3.5  
**Date**: 2025-11-21  
**Owner**: Liam  
**Type**: Governance Policy (YAML)

---

## 1. Objective

Define a **formal Writer Policy** for 02luka V3.5 that specifies which agents/components can write which files/paths.

**Goals**:
- ✅ Protect governance/SOT zones from accidental modification
- ✅ Centralize all file-writing through HYBRID executor
- ✅ Make all write operations visible via AP/IO v3.1
- ✅ Deprecate CLC/CLS as direct writers
- ✅ Enable enforcement via overseer pre-checks

---

## 2. Scope

### In Scope:
- ✅ Zone definitions (governance, normal_code, reports, ledger, bridge, scratch, wo_specs)
- ✅ Writer role definitions (Hybrid, Liam, GMX, GG/GC, CLC/CLS)
- ✅ Safeguard model (soft vs hard)
- ✅ Enforcement mechanism
- ✅ AP/IO logging requirements
- ✅ Override procedures

### Out of Scope:
- ❌ Implementation code (enforcement script)
- ❌ Migration from V3.x (no migration needed)
- ❌ V4 writer policy (future work)

---

## 3. Requirements

### Functional:
1. Policy must define all repo zones with clear path patterns
2. Policy must specify which agents can write to which zones
3. Policy must distinguish soft vs hard safeguards
4. Policy must include enforcement mechanism
5. Policy must specify AP/IO logging requirements

### Non-Functional:
1. Policy must be machine-readable (YAML format)
2. Policy must be human-readable (clear descriptions)
3. Policy must be version-controlled
4. Policy must include examples

---

## 4. Deliverables

1. **`docs/WRITER_POLICY_V35.yaml`** - Main policy file
2. **SPEC.md** (this file)
3. **PLAN.md** (implementation plan)
4. **Examples** (allowed/blocked scenarios)

---

## 5. Zone Definitions

| Zone | Paths | Write Allowed | Purpose |
|------|-------|---------------|---------|
| governance | `02luka.md`, `core/governance/**` | ❌ Never | Master protocols, SOT |
| normal_code | `tools/**`, `schemas/**`, `agents/**` | ✅ Via HYBRID | Regular code |
| reports | `g/reports/**` | ✅ Via HYBRID | Specs, plans, blueprints |
| ledger | `g/ledger/**` | ✅ Via HYBRID | AP/IO logs |
| bridge | `bridge/inbox/**`, `bridge/outbox/**` | ✅ Via HYBRID | Work Orders |
| scratch | `g/scratch/**` | ✅ Via HYBRID | Temporary files |
| wo_specs | `g/wo_specs/**` | ✅ Via GMX | GMX-generated specs |

---

## 6. Writer Roles

| Agent | Type | Can Write Files | Allowed Zones |
|-------|------|----------------|---------------|
| Hybrid | Executor | ✅ Yes | normal_code, reports, ledger, bridge, scratch |
| Liam | Orchestrator | ❌ No | N/A (plan only) |
| GMX | Planner | ✅ Limited | wo_specs only |
| GG/GC | Overseers | ❌ No | N/A (advise only) |
| CLC/CLS | Deprecated | ❌ No | N/A (deprecated) |

---

## 7. Safeguard Model

### Soft Safeguards (Overridable):
- Invalid/incomplete spec
- Unknown target agent
- Unsupported executor step

**Override**: Boss can say "override safeguard and proceed"  
**Logging**: `boss_override_requested` with risks

### Hard Safeguards (Never Override):
- Write to governance zone
- Write outside repo root
- Fake execution claims

**Response**: Downgrade to PLAN-only, log `security_blocked`

---

## 8. Enforcement Mechanism

```yaml
enforcement:
  method: "overseer_pre_check"
  implementation:
    - "All WOs validated against zone rules before execution"
    - "Hybrid executor checks target path against allowed zones"
    - "AP/IO logs all write attempts (success + blocked)"
  validation_script: "tools/validate_writer_policy.zsh"
```

---

## 9. Success Criteria

- [ ] Policy file created in `docs/`
- [ ] All 7 zones defined with clear paths
- [ ] All 5 writer roles defined
- [ ] Soft/hard safeguards documented
- [ ] Enforcement mechanism specified
- [ ] AP/IO events listed
- [ ] Examples included

---

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Policy not enforced | Medium | High | Create validation script |
| GMX spec zone missing | Low | Medium | Add wo_specs zone |
| Confusion about overrides | Medium | Low | Clear examples + docs |

---

**Status**: ✅ SPEC COMPLETE
