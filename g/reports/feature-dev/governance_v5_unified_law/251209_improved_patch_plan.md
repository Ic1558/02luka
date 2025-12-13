# Improved Patch Plan — Governance v5 Consistency Fixes

**Date:** 2025-12-10  
**Status:** 🎯 IMPROVED APPROACH  
**Rationale:** Enhance CLS capabilities with safety, rather than remove features

---

## Strategic Decision

**Issue #1:** Instead of removing "Auto-approve", we **enhance it with safety conditions** in GOVERNANCE v5, then reference it in PERSONA v5.1.

**Issue #2:** Add "/CLS" to align with GOVERNANCE v5's "Boss/CLS" authorization model.

---

## Patch 1: GOVERNANCE_UNIFIED_v5.md — Add CLS Auto-approve with Safety

**File:** `g/docs/GOVERNANCE_UNIFIED_v5.md`  
**Section:** 5.3 Lane Definitions — WARN Lane  
**Lines:** ~278-285

**Change:**
```markdown
- **WARN Lane**
  - **World**: CLI
  - **Zone**: LOCKED
  - **Behavior**:
    - Emit warning: "Locked Zone".
    - Ask Boss/CLS for override decision.
    - **CLS Auto-approve Conditions** (CLS may auto-approve if ALL conditions met):
      - Path is in **Mission Scope Whitelist** (see below)
      - Risk level = **LOW** (non-governance, non-routing, non-security)
      - **Rollback strategy exists** (git revert, backup, or snapshot)
      - **Full audit log enabled** (operation logged with checksum)
      - Boss has **previously approved** similar operations (pattern match)
    - If override/auto-approve: allow write; log context with rollback info.
    - If not: propose WO → CLC.

**Mission Scope Whitelist (CLS Auto-approve allowed):**
- `bridge/templates/**` (templates, not core routing logic)
- `g/reports/**` (reports, not governance docs)
- `tools/**` (non-governance tools)
- `bridge/docs/**` (documentation, not production code)

**Mission Scope Blacklist (CLS Auto-approve NOT allowed):**
- `core/**` (system core)
- `bridge/core/**` (bridge core logic)
- `bridge/handlers/**` (request handlers)
- `bridge/production/**` (production config)
- `g/docs/governance/**` (governance documents)
- `launchd/**` (system services)
```

**Rationale:** 
- Defines "Mission Scope" explicitly in kernel law
- Adds safety conditions (rollback, audit, risk threshold)
- Maintains CLS as "Boss Proxy" while preventing dangerous auto-approves

---

## Patch 2: PERSONA_MODEL_v5.md — Reference GOVERNANCE v5 Auto-approve Rules

**File:** `g/docs/PERSONA_MODEL_v5.md`  
**Section:** 3.1 WORLD 1: CLI / INTERACTIVE  
**Line:** ~80

**Change:**
```diff
- | **CLS** | ✅ Direct | ⚠️ Warn / Auto* | ❌ Block | *Auto-approve if within Boss-defined Mission Scope |
+ | **CLS** | ✅ Direct | ⚠️ Warn / Auto* | ❌ Block | *Auto-approve per GOVERNANCE v5 Section 5.3 (Mission Scope + Safety Conditions) |
```

**Also update Section 4 (State Machine):**
```diff
-     * **WARN:** Prompt user -> If Yes (or Mission Scope) -> Write.
+     * **WARN:** Prompt user -> If Yes OR (CLS auto-approve per GOVERNANCE v5 Section 5.3) -> Write.
```

**Rationale:** References kernel law instead of undefined "Mission Scope", maintains consistency.

---

## Patch 3: HOWTO_TWO_WORLDS_v2.md — Add "/CLS" to Override Logic

**File:** `g/docs/HOWTO_TWO_WORLDS_v2.md`  
**Section:** 4.1 Cheatsheet  
**Lines:** ~82-83

**Change:**
```diff
- | **GMX/Codex** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss explicitly instructs override |
- | **LAC** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss explicitly instructs override |
+ | **GMX/Codex** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss/CLS explicitly instructs override |
+ | **LAC** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss/CLS explicitly instructs override |
```

**Rationale:** Aligns with GOVERNANCE v5 Section 4.2.1 and 5.3 which allow "Boss/CLS instruction" (CLS as Boss Proxy).

---

## Patch 4: PERSONA_MODEL_v5.md — Add "/CLS" to Override Logic

**File:** `g/docs/PERSONA_MODEL_v5.md`  
**Section:** 3.1 WORLD 1: CLI / INTERACTIVE  
**Lines:** ~82-83

**Change:**
```diff
- | **GMX/Codex** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss explicitly instructs override |
- | **LAC** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss explicitly instructs override |
+ | **GMX/Codex** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss/CLS explicitly instructs override |
+ | **LAC** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Allowed IF Boss/CLS explicitly instructs override |
```

**Rationale:** Same as Patch 3 — align with GOVERNANCE v5.

---

## Patch 5: GOVERNANCE_UNIFIED_v5.md — Update AI_OP_001 Reference

**File:** `g/docs/GOVERNANCE_UNIFIED_v5.md`  
**Section:** 5.4 Routing Algorithm  
**Lines:** ~320, ~323

**Change:**
```diff
      else if zone == LOCKED:
-         return (LOCKED, WARN, actor, {CLI_HOWTO, AI_OP_001_v4, GOVERNANCE_UNIFIED_v5})
+         return (LOCKED, WARN, actor, {CLI_HOWTO, AI_OP_001_v5, GOVERNANCE_UNIFIED_v5})

      if world == BACKGROUND:
-         return (zone, STRICT, CLC, {AI_OP_001_v4, GOVERNANCE_UNIFIED_v5})
+         return (zone, STRICT, CLC, {AI_OP_001_v5, GOVERNANCE_UNIFIED_v5})
```

**Rationale:** Update to reference v5 (the new file) instead of v4.

---

## Summary of Improved Approach

| Issue | Original Fix | Improved Fix | Benefit |
|-------|--------------|-------------|---------|
| #1: CLS Auto-approve | Remove "Auto-approve" | **Define with safety conditions** | CLS more capable, still safe |
| #2: Override wording | Add "/CLS" | **Add "/CLS"** (same) | Aligns with Boss Proxy model |
| #3: AI_OP reference | v4→v5 | **v4→v5** (same) | Update version reference |

**Key Improvement:**
- Instead of **removing** CLS auto-approve capability, we **enhance it with explicit safety conditions** in GOVERNANCE v5
- This makes CLS more powerful (as "Boss Proxy") while maintaining safety through:
  - Mission Scope whitelist/blacklist
  - Rollback requirement
  - Risk threshold (LOW only)
  - Audit trail requirement

---

## Safety Guarantees

After these patches:

1. ✅ CLS can auto-approve **only** in safe paths (whitelist)
2. ✅ CLS **cannot** auto-approve governance/routing/core changes
3. ✅ All auto-approves require **rollback strategy**
4. ✅ All auto-approves are **fully audited**
5. ✅ CLS authorization aligns with "Boss Proxy" model

---

**Status:** ✅ **READY TO APPLY**

**Recommendation:** Apply all 5 patches to enhance CLS capabilities while maintaining safety.

---

**Last Updated:** 2025-12-10

