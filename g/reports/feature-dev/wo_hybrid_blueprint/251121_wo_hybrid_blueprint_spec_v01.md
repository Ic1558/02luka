# WO HYBRID Blueprint Creation — SPEC

**Version**: V3.5  
**Date**: 2025-11-21  
**Owner**: Liam  
**Type**: Work Order Script (HYBRID Executor)

---

## 1. Objective

Create a **safe, atomic zsh script** that generates a HYBRID Work Order to create the V3.5 Blueprint file via the Hybrid executor.

**Goals**:
- ✅ Use HYBRID executor only (not CLC/CLS)
- ✅ Restrict writes to `g/reports/` zone only
- ✅ Full AP/IO v3.1 logging integration
- ✅ No governance file access
- ✅ Atomic script pattern (fail-safe)

---

## 2. Scope

### In Scope:
- ✅ zsh script that creates WO JSON file
- ✅ WO targets HYBRID executor
- ✅ Blueprint file path: `g/reports/250121_02luka_V3.5_Blueprint.md`
- ✅ AP/IO events: `architecture_blueprint_create_start`, `architecture_blueprint_created`, `architecture_blueprint_create_failed`
- ✅ Safety profile enforcement
- ✅ Zone validation (reports only)

### Out of Scope:
- ❌ Direct file writing (Hybrid does that)
- ❌ CLC/CLS usage
- ❌ Governance file access
- ❌ Execution outside repo

---

## 3. Requirements

### Functional:
1. Script must create WO JSON in `bridge/inbox/HYBRID/`
2. WO must specify target file in `g/reports/` zone
3. WO must include complete blueprint template content
4. WO must enable AP/IO logging with proper events
5. Script must be idempotent (safe to re-run)

### Non-Functional:
1. Script must use `set -euo pipefail` for safety
2. Script must validate paths before writing
3. Script must provide clear success/error messages
4. Script must be executable (`chmod +x`)

---

## 4. Deliverables

1. **`~/wo_create_v35_blueprint.zsh`** - Main WO creation script
2. **`bridge/inbox/HYBRID/WO-250121-CREATE-V35-BLUEPRINT.json`** - Generated WO file
3. **SPEC.md** (this file)
4. **PLAN.md** (implementation plan)

---

## 5. Safety Profile

```yaml
safety_profile:
  scope: "normal_code"
  allow_write_outside_repo: false
  allow_exec: false
  allowed_zones:
    - "g/reports/**"
  forbidden_zones:
    - "02luka.md"
    - "core/governance/**"
    - "CLC/**"
```

---

## 6. AP/IO Events

| Event | When | Data |
|-------|------|------|
| `architecture_blueprint_create_start` | WO execution begins | version, type, scope |
| `architecture_blueprint_created` | File created successfully | path, size, checksum |
| `architecture_blueprint_create_failed` | Creation failed | error, reason |

---

## 7. Constraints

- Must use HYBRID executor only
- Must write to `g/reports/` only
- Must not touch governance files
- Must be atomic (all-or-nothing)
- Must log to AP/IO v3.1

---

## 8. Success Criteria

- [ ] Script creates valid WO JSON
- [ ] WO targets HYBRID executor
- [ ] WO specifies correct file path
- [ ] WO includes complete blueprint content
- [ ] AP/IO logging configured correctly
- [ ] Safety profile enforced
- [ ] Script is executable and documented

---

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Path calculation error | Medium | Medium | Use git rev-parse for repo root |
| WO already exists | Low | Low | Add existence check |
| Invalid JSON format | Low | High | Validate JSON before writing |
| Wrong zone access | Low | Critical | Enforce zone validation in WO |

---

**Status**: ✅ SPEC COMPLETE
