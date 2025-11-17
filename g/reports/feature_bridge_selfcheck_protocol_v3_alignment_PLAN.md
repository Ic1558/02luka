# Feature Plan: Bridge Self-Check Aligned with Context Protocol v3.2

**Feature:** `feat(ci): bridge self-check aligned with Context Protocol v3.2`  
**Priority:** #1 (Next PR)  
**Date:** 2025-11-18  
**Author:** GG (Spec) → Codex/CLC (Implementation)  
**Status:** 📋 Planning

---

## 1. Scope & Purpose

### Goal
Align `.github/workflows/bridge-selfcheck.yml` with Context Engineering Protocol v3.2 rules, ensuring bridge self-check escalation and MLS logging follow the new agent hierarchy and routing rules.

### Why
- Current escalation goes directly to CLC, bypassing Mary/GC routing
- MLS events don't reference Protocol v3.2
- Need governance comments linking CI to protocol documentation

### Success Criteria
- ✅ Escalation prompts route through Mary/GC first (per Protocol v3.2)
- ✅ MLS events tagged with `context-protocol-v3.2`
- ✅ Governance comments added to workflow file
- ✅ All changes align with `CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`

---

## 2. Specification

### 2.1 Files to Modify

1. **`.github/workflows/bridge-selfcheck.yml`**
   - Add governance header comment
   - Update escalation prompt logic (lines 249-286)
   - Update MLS event tags (line 354)

2. **`g/docs/PROTOCOL_QUICK_REF.md`** (optional)
   - Add reference to bridge self-check if needed
   - Link to escalation flow

### 2.2 Changes Required

#### Change 1: Add Governance Header Comment

**Location:** After line 3 (`name: Bridge Self-Check`)

**Content:**
```yaml
# Governance: Aligned with Context Engineering Protocol v3.2
# - Critical issues → Mary/GC route to CLC (locked) or Gemini (non-locked)
# - Warnings → Mary/GC review, optional escalation
# - MLS logging follows Protocol v3.2 (tags include context-protocol-v3.2)
```

#### Change 2: Update Escalation Prompt (Critical)

**Location:** Lines 262-270

**Current:**
```bash
if [[ "$STATUS" == "critical" || "$CRIT" != "0" ]]; then
  {
    echo "NEEDS ELEVATION → CLC (privileged)"
    echo "เหตุผล: พบ critical issues ใน bridge/self-check"
    echo "การดำเนินการ: ใช้ CLC เพื่อแก้ไฟล์/สิทธิ์/ระบบที่ต้องการ privileged write"
    ...
  } > "$prompt_file"
```

**New:**
```bash
if [[ "$STATUS" == "critical" || "$CRIT" != "0" ]]; then
  {
    echo "NEEDS ELEVATION → Mary/GC → (route to CLC/Gemini)"
    echo "เหตุผล: พบ critical issues ใน bridge/self-check ตาม Context Protocol v3.2"
    echo "การดำเนินการ:"
    echo "  1) ให้ Mary/GC ตรวจ zone (locked vs non-locked)"
    echo "  2) ถ้า locked → ส่ง CLC (privileged writer)"
    echo "  3) ถ้า non-locked → ส่ง Gemini (patch mode, primary operational writer)"
    echo ""
    echo "Reference: g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md Section 2.2, 4"
    echo ""
    echo "Run URL: $RUN_URL"
    echo "Status: $STATUS, warnings=$WARN, critical=$CRIT"
  } > "$prompt_file"
```

#### Change 3: Update Escalation Prompt (Warning)

**Location:** Lines 271-279

**Current:**
```bash
elif [[ "$STATUS" == "warning" || "$WARN" != "0" ]]; then
  {
    echo "ATTENTION → Mary/GC"
    echo "เหตุผล: พบ warnings ใน bridge/self-check"
    echo "การดำเนินการ: ตรวจสอบและตัดสินใจว่าจะ escalate ไป CLC หรือรอรอบถัดไป"
    ...
  } > "$prompt_file"
```

**New:**
```bash
elif [[ "$STATUS" == "warning" || "$WARN" != "0" ]]; then
  {
    echo "ATTENTION → Mary/GC"
    echo "เหตุผล: พบ warnings ใน bridge/self-check (ไม่ถึง critical) ตาม Context Protocol v3.2"
    echo "การดำเนินการ: Mary/GC ตัดสินใจว่าจะ escalate ไป CLC/Gemini หรือรอรอบถัดไป"
    echo ""
    echo "Reference: g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md Section 2.2, 4"
    echo ""
    echo "Run URL: $RUN_URL"
    echo "Status: $STATUS, warnings=$WARN, critical=$CRIT"
  } > "$prompt_file"
```

#### Change 4: Update MLS Event Tags

**Location:** Line 354

**Current:**
```json
tags: ["bridge","strict","artifact","healthy"],
```

**New:**
```json
tags: ["bridge","strict","artifact","healthy","context-protocol-v3.2"],
```

---

## 3. Task Breakdown (TODO)

### Phase 1: Preparation
- [ ] Review current `bridge-selfcheck.yml` structure
- [ ] Verify Protocol v3.2 schema and quick ref docs exist
- [ ] Check if PROTOCOL_QUICK_REF.md needs bridge self-check reference

### Phase 2: Implementation
- [ ] Add governance header comment to workflow file
- [ ] Update critical escalation prompt (Change 2)
- [ ] Update warning escalation prompt (Change 3)
- [ ] Update MLS event tags (Change 4)
- [ ] Verify YAML syntax is valid

### Phase 3: Documentation (Optional)
- [ ] Add bridge self-check reference to PROTOCOL_QUICK_REF.md (if needed)
- [ ] Update any related documentation

### Phase 4: Validation
- [ ] Run YAML linter on modified workflow
- [ ] Verify escalation prompts match spec exactly
- [ ] Verify MLS tags include `context-protocol-v3.2`
- [ ] Test workflow syntax (dry-run if possible)

### Phase 5: Review & Merge
- [ ] CLC reviews changes for Protocol v3.2 compliance
- [ ] Verify governance comments are clear
- [ ] Create PR with proper description
- [ ] Wait for CI validation

---

## 4. Test Strategy

### 4.1 Syntax Validation
```bash
# Validate YAML syntax
yamllint .github/workflows/bridge-selfcheck.yml

# Or use GitHub Actions workflow linter
act -l  # List workflows (if act is installed)
```

### 4.2 Manual Review Checklist
- [ ] Governance comment present and accurate
- [ ] Critical escalation mentions Mary/GC routing
- [ ] Warning escalation mentions Mary/GC review
- [ ] Both escalations reference Protocol v3.2
- [ ] MLS tags include `context-protocol-v3.2`
- [ ] No breaking changes to existing logic

### 4.3 Integration Testing
- [ ] Trigger workflow manually (workflow_dispatch)
- [ ] Verify escalation prompts are generated correctly
- [ ] Check MLS event includes new tag
- [ ] Verify prompts route to Mary/GC (not directly to CLC)

### 4.4 Protocol Compliance Check
- [ ] Escalation flow matches Protocol v3.2 Section 2.2 (Agent Capabilities)
- [ ] Routing logic matches Protocol v3.2 Section 4 (Fallback Ladder)
- [ ] MLS logging matches Protocol v3.2 Section 6.3 (MLS Audit Trail)

---

## 5. Implementation Notes

### 5.1 Key Protocol v3.2 Rules Applied

**Agent Hierarchy:**
- **Mary/GC** (Layer 2): Routes tasks, reviews governance
- **CLC** (Layer 3): Privileged writer for locked zones
- **Gemini** (Layer 4.5): Primary operational writer for non-locked zones

**Escalation Flow:**
1. Critical/Warning detected → Mary/GC
2. Mary/GC determines zone (locked vs non-locked)
3. Locked → Route to CLC
4. Non-locked → Route to Gemini

### 5.2 Backward Compatibility

- Existing workflow logic unchanged (only prompt text updated)
- MLS event structure unchanged (only tags added)
- No breaking changes to CI behavior

### 5.3 Reference Documents

- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md` - Full protocol
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json` - Machine-readable schema
- `g/docs/PROTOCOL_QUICK_REF.md` - Quick reference

---

## 6. PR Description Template

```markdown
## feat(ci): bridge self-check aligned with Context Protocol v3.2

### Summary
Aligns bridge self-check escalation and MLS logging with Context Engineering Protocol v3.2 agent hierarchy and routing rules.

### Changes
- Add governance header comment linking CI to Protocol v3.2
- Update escalation prompts to route through Mary/GC first (per Protocol v3.2)
- Add `context-protocol-v3.2` tag to MLS events
- Reference Protocol v3.2 documentation in escalation messages

### Protocol Compliance
- ✅ Escalation follows Protocol v3.2 Section 2.2 (Agent Capabilities)
- ✅ Routing matches Protocol v3.2 Section 4 (Fallback Ladder)
- ✅ MLS logging follows Protocol v3.2 Section 6.3 (MLS Audit Trail)

### Testing
- [x] YAML syntax validated
- [x] Escalation prompts reviewed
- [x] MLS tags verified
- [x] Protocol compliance checked

### References
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`
- `g/docs/PROTOCOL_QUICK_REF.md`
```

---

## 7. Risks & Mitigation

### Risk 1: Escalation Prompt Format Changes
- **Risk:** Mary/GC might not parse new format correctly
- **Mitigation:** Keep structure similar, only update routing instructions
- **Test:** Verify Mary/GC can process new format

### Risk 2: YAML Syntax Errors
- **Risk:** Invalid YAML breaks workflow
- **Mitigation:** Use YAML linter before commit
- **Test:** Validate syntax with `yamllint` or GitHub Actions

### Risk 3: Protocol v3.2 Changes
- **Risk:** Protocol might be updated after this PR
- **Mitigation:** Reference specific version (v3.2) in comments
- **Test:** Verify references are accurate

---

## 8. Success Metrics

- ✅ Escalation prompts route through Mary/GC
- ✅ MLS events tagged with `context-protocol-v3.2`
- ✅ Governance comments present and accurate
- ✅ No breaking changes to workflow
- ✅ CI passes all checks

---

## 9. Next Steps After This PR

**Priority #2:** PR #5 – Philosophy & Design Principles (02luka PHILOSOPHY.md)
- Document "Why" of the system (not just "How")
- Reference Context Protocol v3, Multi-Agent roles
- Create 1-2 page document for new contributors

---

**Generated by:** Andy (Codex Layer 4) following `/feature-dev` pattern  
**Review Status:** Ready for Codex/CLC implementation  
**Plan Date:** 2025-11-18
