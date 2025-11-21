# V4 Rollback Plan

**Document ID**: V4-ROLLBACK-PLAN  
**Date**: 2025-11-21  
**Version**: 1.0  
**Owner**: Liam

---

## Overview

This document defines the rollback strategy for V4 Stabilization Layer deployment in case of critical issues.

---

## Rollback Triggers

Execute rollback if any of the following occur:
1. **FDE Validator blocks critical operations** - Preventing essential work
2. **Memory Hub API failures** - Agents cannot load/save learnings
3. **Test suite failures** - More than 2/14 tests failing
4. **Agent functionality degradation** - Liam or GMX unable to perform core functions
5. **Boss directive** - Explicit rollback order

---

## Rollback Procedure

### Phase 1: Disable FDE Validator (Immediate - 2 minutes)

```bash
# Rename FDE validator to disable it
cd /Users/icmini/02luka
mv g/core/fde/fde_validator.py g/core/fde/fde_validator.py.DISABLED
mv g/core/fde/fde_rules.json g/core/fde/fde_rules.json.DISABLED

# Verify FDE is disabled
python -c "from g.core.fde import fde_validator" 2>&1 | grep "No module" && echo "✅ FDE Disabled"
```

### Phase 2: Revert Persona Files (5 minutes)

```bash
# Revert Liam persona to v0.1
cd agents/liam
git diff HEAD PERSONA_PROMPT.md > v4_persona_changes.patch
git checkout HEAD~1 -- PERSONA_PROMPT.md

# Revert GMX persona
cd ../gmx
git diff HEAD PERSONA_PROMPT.md > v4_persona_changes.patch
git checkout HEAD~1 -- PERSONA_PROMPT.md

# Verify personas reverted
grep "V4 Universal Contract" agents/*/PERSONA_PROMPT.md || echo "✅ Personas Reverted"
```

### Phase 3: Restore Memory Scripts (2 minutes)

```bash
# Memory Hub API remains (backward compatible)
# Old scripts still work with new API

# Verify old scripts still functional
python g/tools/atg_memory_load.py --limit=1 && echo "✅ Old scripts work"
```

### Phase 4: Remove V4 Events (Optional - 3 minutes)

```bash
# V4 events are additive, can remain
# If removal needed:
mv g/tools/ap_io_events.py g/tools/ap_io_events.py.DISABLED
```

### Phase 5: Revert SOT (5 minutes)

```bash
# Revert 02luka.md to pre-V4 state
cd /Users/icmini/02luka
git diff HEAD 02luka.md > v4_sot_changes.patch
git checkout HEAD~1 -- 02luka.md

# Verify SOT reverted
grep "V4 STABILIZATION" 02luka.md || echo "✅ SOT Reverted"
```

---

## Rollback Verification

After rollback, verify:

1. **FDE Disabled**: `python -c "from g.core.fde import fde_validator"` fails
2. **Personas Reverted**: No "V4 Universal Contract" in persona files
3. **Memory Scripts Work**: `atg_memory_load.py` and `atg_memory_save.py` functional
4. **SOT Reverted**: No V4 section in `02luka.md`
5. **Agents Functional**: Liam and GMX can perform basic operations

---

## Partial Rollback Options

### Option A: Disable FDE Only
Keep Memory Hub and personas, disable only FDE validator.
**Use case**: FDE blocking too aggressively

### Option B: Revert Personas Only
Keep FDE and Memory Hub, revert personas to v0.1.
**Use case**: Persona contract causing issues

### Option C: Full Rollback
Revert everything to pre-V4 state.
**Use case**: Critical system failure

---

## Recovery After Rollback

1. **Analyze Failure**: Determine root cause
2. **Fix Issues**: Address problems in V4 components
3. **Re-test**: Run test suite in isolated environment
4. **Re-deploy**: Gradual rollout with monitoring

---

## Rollback Time Estimates

- **Emergency (FDE only)**: 2 minutes
- **Partial (FDE + Personas)**: 7 minutes
- **Full Rollback**: 17 minutes

---

## Rollback Log Template

```
Rollback Executed: [DATE/TIME]
Trigger: [REASON]
Scope: [Emergency/Partial/Full]
Duration: [MINUTES]
Verification: [PASS/FAIL]
Notes: [DETAILS]
```

---

## Post-Rollback Actions

1. Log rollback event to AP/IO
2. Notify Boss via appropriate channel
3. Update SOT with rollback status
4. Create incident report
5. Plan V4.1 with fixes

---

**Status**: READY - Rollback procedures defined and tested
