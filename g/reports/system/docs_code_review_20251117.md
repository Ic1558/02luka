# Code Review: Documentation Files Conflict Analysis
**Date:** 2025-11-17  
**Reviewer:** Codex (Layer 4)  
**Files Reviewed:**
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`
- `g/docs/LPE_PATCH_SCHEMA.md`
- `docs/GG_ORCHESTRATOR_CONTRACT.md`

---

## Executive Summary

**Verdict:** ⚠️ **MODERATE RISK** - Found 7 conflicts, 3 style inconsistencies, and 2 potential bugs. Documentation is functional but needs alignment.

**Key Findings:**
- Locked zones definitions differ between documents
- Routing rules have minor inconsistencies
- Fallback mechanisms described with slight variations
- Mixed language (English/Thai) reduces clarity
- Some edge cases in delegation logic are unclear

---

## 1. Conflicts & Inconsistencies

### 🔴 P1: Locked Zones Definition Mismatch

**Location:** Multiple files

**Issue:**
- `CONTEXT_ENGINEERING_PROTOCOL_v3.md` (line 248) lists:
  - `/CLC/**`, `/core/governance/**`, `/memory_center/**`, `/launchd/**`, `/production_bridges/**`, `/wo_pipeline_core/**`
- `GG_ORCHESTRATOR_CONTRACT.md` (line 56-63) lists:
  - `/CLC/**`, `/core/governance/**`, `memory_center/**`, `launchd/**`, `production bridges/**`, `dynamic agents behaviors/**`, `wo pipeline core/**`

**Differences:**
1. Missing leading `/` in some paths (inconsistent path format)
2. `production bridges/**` vs `/production_bridges/**` (underscore vs space)
3. `dynamic agents behaviors/**` appears only in GG_CONTRACT, not in PROTOCOL
4. `memory_center/**` vs `/memory_center/**` (leading slash inconsistency)

**Impact:** HIGH - Agents may incorrectly identify prohibited zones, leading to protocol violations.

**Recommendation:**
- Standardize on absolute paths with leading `/`
- Use consistent naming (underscores vs spaces)
- Add `dynamic agents behaviors/**` to PROTOCOL if it's a real zone
- Create a single source of truth for zone definitions

---

### 🟡 P2: Routing Rules Inconsistency

**Location:** `GG_ORCHESTRATOR_CONTRACT.md` vs `CONTEXT_ENGINEERING_PROTOCOL_v3.md`

**Issue:**
- GG_CONTRACT (line 96-99) routes `local_fix` → Gemini
- PROTOCOL (line 40, 190) states Gemini is "primary operational writer" but doesn't explicitly define routing for `local_fix`
- PROTOCOL (line 56) mentions fallback: "Gemini/CLC unavailable → LPE or Emergency Override"
- GG_CONTRACT doesn't mention fallback ladder for Gemini

**Impact:** MEDIUM - Unclear which document takes precedence for routing decisions.

**Recommendation:**
- PROTOCOL should explicitly define routing matrix (similar to GG_CONTRACT)
- GG_CONTRACT should reference PROTOCOL as authoritative source
- Add cross-references between documents

---

### 🟡 P3: LPE Fallback Trigger Conditions Differ

**Location:** Multiple sections

**Issue:**
- PROTOCOL Section 4.2: "CLC reaches 190K+ tokens" → LPE fallback
- PROTOCOL Section 4.3: "CLC session unavailable" → LPE fallback
- PROTOCOL Section 4.5: "CLC unavailable OR out of tokens" → Emergency Codex/Liam Write Mode
- GG_CONTRACT: No explicit LPE fallback rules

**Impact:** MEDIUM - Unclear when to use LPE vs Emergency Codex/Liam mode.

**Recommendation:**
- Clarify decision tree: CLC unavailable → LPE (Boss approval) vs Emergency Codex/Liam (Boss override)
- Add explicit priority: LPE first, then Emergency Codex/Liam if LPE unavailable

---

### 🟡 P4: Codex Write Capability Ambiguity

**Location:** `CONTEXT_ENGINEERING_PROTOCOL_v3.md` Section 2.2.4 and 4.5

**Issue:**
- Section 2.2.4 (Layer 4: Codex): "Normal Mode: MUST NOT write to SOT. Override Mode: MAY write when Boss override"
- Section 4.5: "Emergency Codex/Liam Write Mode" allows writes when CLC unavailable
- Section 2.3: "Boss Override Mode" for IDE agents

**Impact:** MEDIUM - Three different mechanisms for Codex writes, unclear which takes precedence.

**Recommendation:**
- Consolidate into single "Boss Override" mechanism
- Clarify: Normal → Override → Emergency (in order of precedence)

---

### 🟡 P5: Gemini Scope Definition Overlap

**Location:** `CONTEXT_ENGINEERING_PROTOCOL_v3.md` vs `GG_ORCHESTRATOR_CONTRACT.md`

**Issue:**
- PROTOCOL (line 190): Gemini writes "non-locked zones (apps, tools, tests, normal docs)"
- PROTOCOL (line 267): "Primary operational writer for: `apps/**`, `tools/**`, `tests/**`, `docs/**` (non-governance)"
- GG_CONTRACT (line 104): "Primary operational writer สำหรับ `apps`, `tools`, `docs`, etc. (non-locked zones)"
- GG_CONTRACT (line 77-85): Lists allowed zones including `docs/**` (except governance)

**Impact:** LOW - Generally consistent, but "normal docs" vs "docs (non-governance)" could be clearer.

**Recommendation:**
- Use consistent terminology: "non-governance docs" or "operational docs"
- Explicitly exclude governance docs in both documents

---

### 🟡 P6: LPE Patch Schema Path Validation

**Location:** `LPE_PATCH_SCHEMA.md` vs `CONTEXT_ENGINEERING_PROTOCOL_v3.md`

**Issue:**
- LPE_SCHEMA (line 31): "Must stay inside allowed roots (g, core, LaunchAgents, tools, etc.)"
- PROTOCOL (line 248): Lists locked zones that LPE should not modify
- No explicit mapping between "allowed roots" and "locked zones"

**Impact:** MEDIUM - LPE could potentially write to locked zones if validation is insufficient.

**Recommendation:**
- LPE_SCHEMA should explicitly list prohibited zones
- Add validation rule: LPE patches must not target locked zones
- Reference PROTOCOL for authoritative zone definitions

---

### 🟡 P7: Agent Authorization Matrix Inconsistency

**Location:** `CONTEXT_ENGINEERING_PROTOCOL_v3.md` Section 3 (Capability Matrix)

**Issue:**
- Matrix (line 393): Gemini "CAN (via patch)" for writes
- Matrix (line 394): Codex "MAY (override)" for writes
- Section 2.2.4.5 (Gemini): Detailed Safety-Belt Mode rules
- Section 2.2.4 (Codex): Simple "Override Mode" rules

**Impact:** LOW - Matrix is accurate but doesn't capture complexity of Safety-Belt Mode.

**Recommendation:**
- Add footnote to matrix: "See Section 2.2.4.5 for Gemini Safety-Belt Mode details"
- Consider expanding matrix to include "Mode" column

---

## 2. Style & Clarity Issues

### 🟡 S1: Mixed Language (English/Thai)

**Location:** All files, especially `GG_ORCHESTRATOR_CONTRACT.md`

**Issue:**
- Documents mix English and Thai, reducing readability for non-Thai speakers
- Technical terms sometimes in English, explanations in Thai

**Impact:** LOW - Reduces international accessibility but functional for current team.

**Recommendation:**
- Consider English-only for protocol documents
- Or provide English translations for key sections

---

### 🟡 S2: Terminology Inconsistency

**Location:** Multiple files

**Issue:**
- "Locked zones" vs "Prohibited zones" vs "Privileged zones"
- "Fallback ladder" vs "Fallback protocol" vs "Emergency fallback"
- "Boss override" vs "Emergency Override Mode" vs "Override Mode"

**Impact:** LOW - Functional but confusing for new readers.

**Recommendation:**
- Create glossary with preferred terms
- Use consistent terminology throughout

---

### 🟡 S3: Missing Cross-References

**Location:** All files

**Issue:**
- Documents reference each other but don't include explicit file paths
- No version numbers in cross-references
- Some references may be outdated

**Impact:** LOW - Makes navigation harder.

**Recommendation:**
- Add explicit file paths in references
- Include version numbers where applicable
- Add "See also" sections

---

## 3. Potential Bugs

### 🔴 B1: LPE Can Write to Locked Zones (Theoretical)

**Location:** `LPE_PATCH_SCHEMA.md` + `CONTEXT_ENGINEERING_PROTOCOL_v3.md`

**Issue:**
- LPE_SCHEMA allows paths in "g, core, LaunchAgents, tools, etc."
- PROTOCOL lists `/core/governance/**` as locked zone
- If LPE receives patch for `core/governance/something.yaml`, validation may pass if it only checks "core" is in allowed roots

**Impact:** HIGH - Security risk if LPE validation is insufficient.

**Recommendation:**
- LPE worker must validate against locked zones list from PROTOCOL
- Add explicit check: `if path matches locked_zone_pattern: reject`
- Test with locked zone path to verify rejection

---

### 🟡 B2: Ambiguous Fallback Priority

**Location:** `CONTEXT_ENGINEERING_PROTOCOL_v3.md` Section 4

**Issue:**
- Section 4.2: CLC out of tokens → LPE fallback
- Section 4.3: CLC unavailable → LPE fallback
- Section 4.5: CLC unavailable → Emergency Codex/Liam Write Mode
- No explicit decision tree for: "CLC unavailable, should I use LPE or Codex/Liam?"

**Impact:** MEDIUM - Could lead to inconsistent behavior.

**Recommendation:**
- Add explicit decision tree:
  ```
  IF CLC unavailable:
    IF Boss explicitly requests Codex/Liam → Emergency Codex/Liam Mode
    ELSE → LPE fallback (default)
  ```
- Document Boss preference vs default behavior

---

## 4. Risk Areas

### 🔴 R1: Zone Definition Drift

**Risk:** Locked zones may diverge between documents over time.

**Mitigation:**
- Create single source of truth (e.g., `g/config/locked_zones.yaml`)
- Both documents reference this file
- Automated validation in pre-commit hook

---

### 🟡 R2: Routing Rule Conflicts

**Risk:** GG_CONTRACT and PROTOCOL may give conflicting routing advice.

**Mitigation:**
- PROTOCOL should be authoritative
- GG_CONTRACT should explicitly state: "See PROTOCOL for authoritative routing rules"
- Add validation: GG_CONTRACT routing must match PROTOCOL

---

### 🟡 R3: Emergency Mode Abuse

**Risk:** Emergency Codex/Liam Write Mode could be overused, bypassing normal protocols.

**Mitigation:**
- Add explicit logging requirement for all emergency writes
- Require post-hoc CLC review for all emergency writes
- Monitor frequency of emergency mode usage

---

## 5. Diff Hotspots (Areas Likely Changed Recently)

### Recent Changes Detected:
1. **Section 4.5 (Emergency Codex/Liam Write Mode)** - Likely added in v3.1-REV
2. **Section 2.2.4.5 (Gemini Safety-Belt Mode)** - Complex section, may have been updated
3. **Capability Matrix (Section 3)** - Updated to include Gemini and Codex override capabilities
4. **Locked Zones List (Section 2.2.4.5)** - May have been modified during protocol revisions

**Recommendation:**
- Review git history for these sections
- Verify changes align with intended protocol updates
- Check for unintended side effects

---

## 6. Recommendations Summary

### Immediate Actions (P1, B1):
1. ✅ **Standardize locked zones definition** - Create single source of truth
2. ✅ **Add LPE locked zone validation** - Prevent writes to prohibited zones
3. ✅ **Fix path format inconsistencies** - Use consistent absolute paths

### Short-term (P2-P4, B2):
4. ⚠️ **Clarify routing rules** - Make PROTOCOL authoritative, GG_CONTRACT references it
5. ⚠️ **Consolidate Codex write mechanisms** - Single "Boss Override" with clear precedence
6. ⚠️ **Add explicit fallback decision tree** - Document LPE vs Emergency Codex/Liam priority

### Long-term (S1-S3, R1-R3):
7. 📝 **Improve terminology consistency** - Create glossary, use preferred terms
8. 📝 **Add cross-references** - Include file paths and versions
9. 📝 **Monitor emergency mode usage** - Track frequency, require reviews

---

## 7. Testing Recommendations

1. **Zone Validation Test:**
   - Attempt LPE patch to `/core/governance/test.yaml`
   - Verify rejection with clear error message

2. **Routing Consistency Test:**
   - Create test cases for `local_fix`, `pr_change`, `governance` tasks
   - Verify GG_CONTRACT routing matches PROTOCOL rules

3. **Fallback Decision Test:**
   - Simulate CLC unavailable scenarios
   - Verify correct fallback selection (LPE vs Emergency Codex/Liam)

---

## Final Verdict

⚠️ **MODERATE RISK** - Documentation is functional but has conflicts that could lead to protocol violations. Priority fixes needed for zone definitions and LPE validation.

**Confidence:** High - All conflicts are clearly identified with specific line references.

**Next Steps:**
1. Address P1 (zone definitions) immediately
2. Fix B1 (LPE validation) before next deployment
3. Schedule review session to align routing rules (P2-P4)

---

**Review completed:** 2025-11-17  
**Reviewer:** Codex (Layer 4) - Read-only analysis, no SOT writes

