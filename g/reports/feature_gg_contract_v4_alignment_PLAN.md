# Feature: GG Orchestrator Contract v4 Alignment

**Feature Slug:** `gg_contract_v4_alignment`  
**Status:** Planning  
**Priority:** P1 (Governance Alignment)  
**Created:** 2025-12-05  
**Owner:** CLS → CLC (for Locked Zone edits)

---

## 🎯 **OBJECTIVE**

Update `docs/GG_ORCHESTRATOR_CONTRACT.md` to align with:
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md` (SOT)
- `g/docs/AI_OP_001_v4.md` (Lego Architecture)
- `g/docs/02LUKA_PHILOSOPHY_v1.3.md` (Agent roles)

**Root Cause:** Contract still references deprecated v3.2, causing GG to route based on outdated zone definitions and agent capabilities.

---

## 🔍 **PROBLEM ANALYSIS**

### **Current Issues:**

1. **Outdated References:**
   - Line 74: References `CONTEXT_ENGINEERING_PROTOCOL_v3.md`
   - Line 181: YAML comment says "Based on CONTEXT_ENGINEERING_PROTOCOL_v3.2"
   - Version: 1.1.0 (Last-Updated: 2025-11-17)

2. **Zone Mismatch:**
   - Contract Prohibited Zones ≠ Context v4 Locked Zones
   - Missing bridge/** paths from v4
   - Extra paths not in v4 (e.g., `/memory_center/**`, `/production_bridges/**`)

3. **CLC Definition Confusion:**
   - Still implies "CLC = Claude Code" (privileged writer)
   - Doesn't reflect "CLC = Local Code Layer" (generic executor)
   - Philosophy v1.3 still says "Claude Local Core" but system uses generic executor

4. **Routing Matrix Outdated:**
   - Doesn't reflect v4 First-Writer-Locks rule
   - Doesn't mention Drift-to-Locked escalation
   - Missing LAC, GMX CLI roles

---

## 📋 **SPECIFICATION**

### **1. Header Updates**

**Current:**
```markdown
**Version:** 1.1.0
**Last-Updated:** 2025-11-17
```

**Target:**
```markdown
**Version:** 1.2.0
**Last-Updated:** 2025-12-05
**SOT Alignment:**
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md`
- `g/docs/AI_OP_001_v4.md` (Lego Edition)
- `g/docs/02LUKA_PHILOSOPHY_v1.3.md`
```

### **2. Section 3: Prohibited Zones Update**

**Current:**
```markdown
## 3. Prohibited Zones (Needs CLC)

GG **ห้าม**ออกแบบ patch ที่ไปแตะ path เหล่านี้โดยตรง:

- `/CLC/**`
- `/core/governance/**`
- `/memory_center/**`
- `/launchd/**`
- `/production_bridges/**`
- `/wo_pipeline_core/**`
- `02luka Master System Protocol` (ทุกไฟล์ที่เป็น SOT governance)

> **Note:** Locked zones list matches `CONTEXT_ENGINEERING_PROTOCOL_v3.md` Section 2.2.4.5 (canonical SOT).
```

**Target:**
```markdown
## 3. Prohibited Zones (Locked Zones - CLC/LPE Only)

GG **ห้าม**ออกแบบ patch ที่ไปแตะ path เหล่านี้โดยตรง:

**Locked Zones (per Context v4 SOT):**
- `core/**`
- `CLC/**`
- `launchd/**`
- `bridge/inbox/**`
- `bridge/outbox/**`
- `bridge/handlers/**`
- `bridge/core/**`
- `bridge/templates/**`
- `bridge/production/**`

**Additional Governance Files (SOT):**
- `g/docs/AI_OP_001_v4.md`
- `g/docs/02LUKA_PHILOSOPHY_v1.3.md`
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md`
- `CLS/agents/CLS_agent_latest.md`
- LaunchAgent registry files
- Queue/routing specifications

> **Note:** Prohibited zones align with **Locked Zones** defined in `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md` (SOT).  
> GG must use the **union** of Context v4 Locked Zones + additional governance files listed above.  
> If Context v4 adds new Locked Zones → GG automatically prohibits them.
```

### **3. Section 4: Allowed Zones Update**

**Current:**
```markdown
## 4. Allowed Zones (Normal Dev Work)

GG สามารถ orchestrate งาน (ผ่าน Codex/CLS/CLC/CLI) ได้เต็มที่ใน:

- `apps/**`
- `server/**`
- `schemas/**`
- `scripts/**`
- `docs/**` (ยกเว้น governance core)
- `tools/**`
- `roadmaps/**`
- `tests/**`
- log/report ที่ไม่ใช่ SOT
```

**Target:**
```markdown
## 4. Allowed Zones (Open Zones - Multi-Writer)

GG สามารถ orchestrate งาน (ผ่าน Gemini/LAC/Codex/CLS/GC) ได้เต็มที่ใน:

**Open Zones (per Context v4 SOT):**
- `apps/**`
- `tools/**`
- `agents/**`
- `tests/**`
- `docs/**` (non-governance only)
- `bridge/docs/**`
- `bridge/samples/**`

**Additional Operational Areas:**
- `schemas/**` (non-core)
- `scripts/**` (non-launchd)
- `roadmaps/**`
- Log/report files (non-SOT)

> **Note:** Open Zones follow **First-Writer-Locks** rule (v4).  
> Once a writer lane is active, no other agent may write to the same files until task completion.
```

### **4. Section 5: Routing Matrix Update**

**Current:**
```markdown
| governance/memory/bridges | any | GG → CLC (spec only) | For privileged zones |
```

**Target:**
```markdown
| governance/locked_zones | any | GG → CLC/LPE (spec only) | For Locked Zones (v4) |
```

**Add to Agent Roles section:**
```markdown
- **LAC (Local Auto-Coder)**
  - **Autonomous code generation** in Open Zones
  - Works via work orders or direct execution (Open Zone only)
  - Cannot write to Locked Zones
- **GMX CLI**
  - **Command-line executor** for system operations
  - Runs scripts, Docker, Redis, launchctl, etc.
  - Follows playbooks and routing decisions
- **CLC (Core Local Writer)**
  - **Primary writer for Locked Zones** (not Claude-specific)
  - Can be implemented by any engine (Claude, Gemini, LAC) following SIP
  - Applies patches with full audit trail
```

### **5. Section 7: Output Format Update**

**Current:**
```yaml
route: # Based on CONTEXT_ENGINEERING_PROTOCOL_v3.2
```

**Target:**
```yaml
route: # Based on CONTEXT_ENGINEERING_PROTOCOL_v4 (Lego) + AI/OP-001 v4
```

### **6. Section 9: Escalation Rules Update**

**Add:**
```markdown
### 9.1 Drift-to-Locked Escalation

If a task starts in an Open Zone but discovers a need to modify a Locked Zone file:
1. Stop writing immediately
2. Escalate to CLC via Work Order
3. CLC takes over the Locked Zone portion
4. Original writer continues with Open Zone portion only

This follows Context v4 "Drift-to-Locked" rule.
```

---

## ✅ **TASK BREAKDOWN**

### **Phase 1: Analysis & Planning** ✅ (Complete)
- [x] Analyze current contract vs v4 protocols
- [x] Identify all mismatches
- [x] Create specification document

### **Phase 2: Content Updates** ✅ (Complete)
- [x] Update header (version, date, SOT references)
- [x] Rewrite Section 3 (Prohibited Zones)
- [x] Rewrite Section 4 (Allowed Zones)
- [x] Update Section 5 (Routing Matrix)
- [x] Update Section 7 (Output Format YAML comment)
- [x] Add Section 9.1 (Drift-to-Locked)

### **Phase 3: Validation** (CLS review)
- [ ] Verify all zone paths match Context v4
- [ ] Verify routing rules match v4 capabilities
- [ ] Check for any remaining v3.2 references
- [ ] Verify CLC definition clarity

### **Phase 4: Documentation** (Open Zone)
- [ ] Update any cross-references to this contract
- [ ] Add entry to governance index if exists
- [ ] Create changelog entry

---

## 🧪 **TEST STRATEGY**

### **1. Reference Validation**
```bash
# Check no v3.2 references remain
grep -r "v3\.2\|v3\.md" docs/GG_ORCHESTRATOR_CONTRACT.md

# Verify all zone paths exist in Context v4
# (Manual check against g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md)
```

### **2. Zone Path Verification**
- [ ] All Prohibited Zones match Context v4 Locked Zones
- [ ] All Allowed Zones match Context v4 Open Zones
- [ ] No orphaned paths (paths in contract but not in v4)

### **3. Routing Logic Test**
- [ ] Test routing decision for Locked Zone task → should route to CLC
- [ ] Test routing decision for Open Zone task → should route to Gemini/LAC
- [ ] Test drift-to-locked scenario → should escalate

### **4. Documentation Consistency**
- [ ] Contract references match actual SOT file names
- [ ] Version numbers consistent
- [ ] Agent role descriptions match Philosophy v1.3

---

## 📊 **RISK ASSESSMENT**

| Risk | Level | Mitigation |
|------|-------|------------|
| Breaking existing GG routing | Medium | Keep backward-compatible routing for non-conflicting cases |
| Zone path errors | High | Manual verification against Context v4 SOT |
| CLC definition confusion | Medium | Add explicit note about generic executor vs Claude |
| Missing agent roles | Low | Add LAC, GMX CLI to routing matrix |

---

## 🎯 **SUCCESS CRITERIA**

1. ✅ All v3.2 references removed
2. ✅ All zone paths match Context v4 SOT
3. ✅ Routing matrix reflects v4 capabilities
4. ✅ CLC definition clarified (generic, not Claude-specific)
5. ✅ Version updated to 1.2.0
6. ✅ Last-Updated set to 2025-12-05
7. ✅ SOT references added to header
8. ✅ Drift-to-Locked escalation documented

---

## 📝 **IMPLEMENTATION NOTES**

### **File Location:**
- **Source:** `docs/GG_ORCHESTRATOR_CONTRACT.md`
- **Zone:** Open Zone (docs/** non-governance)
- **Writer:** Gemini/LAC can write (per v4 rules)

### **Governance Check:**
- ✅ File is in Open Zone (`docs/**`)
- ✅ Not a governance SOT file itself
- ✅ Updates align with SOT (Context v4, AI/OP-001 v4)
- ⚠️ **Note:** While file is Open Zone, changes affect GG behavior → recommend CLS review before merge

### **Backup Strategy:**
- Create backup: `docs/GG_ORCHESTRATOR_CONTRACT.md.bak.20251205`
- Use `mktemp → validate → mv` pattern

---

## 🔄 **NEXT STEPS**

1. **Boss Approval** → Review this spec
2. **Assign Writer** → Gemini/LAC for Open Zone edits
3. **Execute Updates** → Follow task breakdown
4. **CLS Review** → Validate against SOT
5. **Merge & Deploy** → Update version, commit

---

**End of Specification**
