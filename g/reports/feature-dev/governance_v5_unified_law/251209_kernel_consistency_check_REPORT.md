# Kernel Consistency Check Report — Governance v5 Suite

**Date:** 2025-12-10  
**Phase:** 3.1 — Deep Cross-File Review  
**Status:** 🔍 IN PROGRESS  
**Reviewer:** GG (System Orchestrator)

---

## Executive Summary

**Overall Assessment:** ⚠️ **3 Critical Issues Found** — Must fix before Integration

The 5-file suite is **structurally sound** but has **semantic inconsistencies** that would cause Mary Router to misinterpret rules if integrated now.

**Risk Level:** 🔴 **HIGH** — Integration without fixes would cause:
- Lane mismatch errors
- Persona permission conflicts  
- World resolution failures
- Override logic misinterpretation

---

## Cross-Reference Matrix Results

### ✅ PASS: GOVERNANCE v5 ↔ AI_OP_001 v5

**Check:** STRICT Lane + WO semantics alignment

**Result:** ✅ **CONSISTENT**

- GOVERNANCE v5 Section 5.3: STRICT Lane = Background + any Zone → WO required
- AI_OP_001 v5 Section 4.1: WO required for any write in Background World
- **No conflict** — Both agree: Background = STRICT = WO mandatory

**Notes:**
- AI_OP_001 v5 correctly inherits Zone semantics from GOVERNANCE v5
- WO protocol in AI_OP_001 v5 is implementation detail of GOVERNANCE v5 STRICT lane

---

### ⚠️ ISSUE #1: GOVERNANCE v5 ↔ PERSONA v5.1 — CLS "Auto-approve" Semantics

**Location:**
- GOVERNANCE v5 Section 4.2.1: `CLS | LOCKED | ⚠️ | Must warn Boss; may execute if Boss confirms override`
- PERSONA v5.1 Section 3.1: `CLS | LOCKED | ⚠️ Warn / Auto* | *Auto-approve if within Boss-defined Mission Scope`

**Problem:**
- GOVERNANCE v5 says: "warn Boss; may execute **if Boss confirms**"
- PERSONA v5.1 says: "Auto-approve if within **Boss-defined Mission Scope**"

**Semantic Gap:**
- "Boss confirms" = explicit real-time approval
- "Boss-defined Mission Scope" = implicit pre-approved scope

**Impact:** 🔴 **HIGH**
- Mary Router could auto-approve CLS writes to LOCKED zones without Boss confirmation
- Violates GOVERNANCE v5 WARN lane semantics
- Could allow CLS to bypass safety checks

**Fix Required:**
- **Option A (Recommended):** Remove "Auto-approve" from PERSONA v5.1, align with GOVERNANCE v5
- **Option B:** Add explicit definition of "Mission Scope" in GOVERNANCE v5, then reference it in PERSONA v5.1

**Recommendation:** **Option A** — Keep WARN lane strict: always require Boss confirmation for LOCKED zone writes.

---

### ⚠️ ISSUE #2: HOWTO v2 ↔ PERSONA v5.1 — Override Logic Wording

**Location:**
- HOWTO v2 Section 4.1: `GMX/Codex | LOCKED | ⚠️ Warn / Override | Allowed IF Boss explicitly instructs override`
- PERSONA v5.1 Section 3.1: `GMX/Codex | LOCKED | ⚠️ Warn / Override | Allowed IF Boss explicitly instructs override`
- GOVERNANCE v5 Section 4.2.1: `GMX | LOCKED | ⚠️ | Only under explicit Boss/CLS instruction`

**Problem:**
- HOWTO v2 and PERSONA v5.1 say: "Boss explicitly instructs override"
- GOVERNANCE v5 says: "explicit Boss/CLS instruction"

**Semantic Gap:**
- "Boss/CLS instruction" = CLS can also authorize (as Boss Proxy)
- "Boss explicitly instructs" = only Boss, not CLS

**Impact:** 🟡 **MEDIUM**
- Could cause confusion: Can CLS authorize GMX/Codex to write LOCKED zones?
- GOVERNANCE v5 allows CLS as Boss Proxy, but HOWTO/PERSONA don't mention it

**Fix Required:**
- Align HOWTO v2 and PERSONA v5.1 to match GOVERNANCE v5: "explicit Boss/CLS instruction"
- OR clarify in GOVERNANCE v5 that CLS authorization = Boss Proxy authority

**Recommendation:** Update HOWTO v2 and PERSONA v5.1 to say "Boss/CLS instruction" to match GOVERNANCE v5.

---

### ⚠️ ISSUE #3: GOVERNANCE v5 Routing Algorithm — AI_OP_001_v4 Reference

**Location:**
- GOVERNANCE v5 Section 5.4 (Routing Algorithm):
  ```text
  if world == CLI:
      if zone == OPEN:
          return (OPEN, FAST, actor, {CLI_HOWTO, GOVERNANCE_UNIFIED_v5})
      else if zone == LOCKED:
          return (LOCKED, WARN, actor, {CLI_HOWTO, AI_OP_001_v4, GOVERNANCE_UNIFIED_v5})
  
  if world == BACKGROUND:
      return (zone, STRICT, CLC, {AI_OP_001_v4, GOVERNANCE_UNIFIED_v5})
  ```

**Problem:**
- References `AI_OP_001_v4` in LAWSET
- Should reference `AI_OP_001_v5` (the new file we just created)

**Impact:** 🟡 **MEDIUM**
- Outdated reference could cause confusion
- Should point to v5 for consistency

**Fix Required:**
- Update GOVERNANCE v5 Section 5.4 to reference `AI_OP_001_v5` instead of `AI_OP_001_v4`

---

### ✅ PASS: SCOPE v1 ↔ All Files

**Check:** Precedence rules and document scope alignment

**Result:** ✅ **CONSISTENT**

- SCOPE v1 correctly declares:
  - GOVERNANCE_UNIFIED_v5 = Tier 1 (Kernel)
  - SCOPE_DECLARATION_v1 = Tier 1 (Meta-Law)
  - AI_OP_001_v5 = Tier 2 (Background)
  - HOWTO_TWO_WORLDS_v2 = Tier 2 (CLI)
  - PERSONA_MODEL_v5 = Tier 2 (Identities)

- All files correctly reference SCOPE v1 precedence rules
- No conflicts in precedence hierarchy

---

## Single Truth Table (Agent × World × Zone × Lane)

### CLI World (World 1)

| Agent | OPEN | LOCKED | DANGER | Lane Logic |
|-------|------|--------|--------|------------|
| Boss | ✅ Direct | ✅ Direct (warn) | ⚠️ Confirm+Snapshot | ROOT Authority |
| CLS | ✅ Direct | ⚠️ **WARN** (Boss confirm) | ❌ Block | **ISSUE #1: Remove "Auto-approve"** |
| Liam | ✅ Direct | ⚠️ Propose Diff | ❌ Block | Must ask Boss/CLS |
| GMX | ✅ Direct | ⚠️ **WARN** (Boss/CLS) | ❌ Block | **ISSUE #2: Align wording** |
| Codex | ✅ Direct | ⚠️ **WARN** (Boss/CLS) | ❌ Block | **ISSUE #2: Align wording** |
| Gemini | ✅ Direct | ⚠️ **WARN** (Boss/CLS) | ❌ Block | **ISSUE #2: Align wording** |
| LAC | ✅ Direct | ⚠️ **WARN** (Boss/CLS) | ❌ Block | **ISSUE #2: Align wording** |
| GG/GM | ❌ | ❌ | ❌ | Plan only |
| Mary | ❌ | ❌ | ❌ | Route only |
| CLC | ❌ | ❌ | ❌ | Sleeps in CLI |

### Background World (World 2)

| Agent | OPEN | LOCKED | DANGER | Lane Logic |
|-------|------|--------|--------|------------|
| CLC | ⚠️ WO | ✅ WO Required | ❌ Block | STRICT Lane |
| LPE | ⚠️ WO | ⚠️ WO (Emergency) | ❌ Block | STRICT Lane |
| LAC | ❌ | ❌ | ❌ | Must route via CLC |
| Other | ❌ | ❌ | ❌ | Must route via CLC |

**Lane Mapping:**
- CLI + OPEN → FAST
- CLI + LOCKED → WARN
- BACKGROUND + any → STRICT
- any + DANGER → BLOCKED

---

## Patch Plan

### Patch 1: PERSONA_MODEL_v5.md — Remove "Auto-approve" from CLS

**File:** `g/docs/PERSONA_MODEL_v5.md`  
**Section:** 3.1 WORLD 1: CLI / INTERACTIVE  
**Line:** ~80

**Change:**
```diff
- | **CLS** | ✅ Direct | ⚠️ Warn / Auto* | ❌ Block | *Auto-approve if within Boss-defined Mission Scope |
+ | **CLS** | ✅ Direct | ⚠️ Warn / Override | ❌ Block | Must warn Boss; may execute if Boss confirms override |
```

**Also update Section 4 (State Machine):**
```diff
-     * **WARN:** Prompt user -> If Yes (or Mission Scope) -> Write.
+     * **WARN:** Prompt user -> If Yes -> Write.
```

**Rationale:** Align with GOVERNANCE v5 Section 4.2.1 — WARN lane requires explicit Boss confirmation, not implicit "Mission Scope".

---

### Patch 2: HOWTO_TWO_WORLDS_v2.md — Align Override Logic Wording

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

**Rationale:** Match GOVERNANCE v5 Section 4.2.1 which allows "explicit Boss/CLS instruction" (CLS as Boss Proxy).

---

### Patch 3: PERSONA_MODEL_v5.md — Align Override Logic Wording

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

**Rationale:** Same as Patch 2 — align with GOVERNANCE v5.

---

### Patch 4: GOVERNANCE_UNIFIED_v5.md — Update AI_OP_001 Reference

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

## Summary of Issues

| Issue | Severity | Files Affected | Fix Complexity |
|-------|----------|----------------|-----------------|
| #1: CLS "Auto-approve" semantics | 🔴 HIGH | PERSONA_MODEL_v5.md | Low (remove phrase) |
| #2: Override logic wording | 🟡 MEDIUM | HOWTO v2, PERSONA v5.1 | Low (add "/CLS") |
| #3: AI_OP_001_v4 reference | 🟡 MEDIUM | GOVERNANCE v5 | Low (v4→v5) |

**Total Patches Required:** 4  
**Estimated Time:** 10-15 minutes  
**Risk if Skipped:** 🔴 **HIGH** — Mary Router would misinterpret rules

---

## Next Steps

1. ✅ **Apply Patches 1-4** (this session)
2. ✅ **Re-verify consistency** after patches
3. ✅ **Generate final truth table** (post-patch)
4. ✅ **Proceed to Phase 3.2** (Integration) after verification

---

**Status:** ⏸️ **WAITING FOR PATCH APPROVAL**

**Recommendation:** Apply all 4 patches before proceeding to Integration phase.

---

**Last Updated:** 2025-12-10

