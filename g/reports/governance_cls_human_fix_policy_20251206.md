# Governance Policy: CLS/Human Fix Authorization

**Date:** 2025-12-06  
**Type:** Policy Update  
**Status:** 📋 **PROPOSED**  
**Owner:** Governance / System Policy

---

## 🎯 **OBJECTIVE**

Formalize the policy that allows CLS/human to directly fix governance files when:
1. There is a documented Incident Report
2. There is a detailed Plan/Spec document
3. The fix follows the documented specification
4. (Optional) A Work Order exists (can be created retroactively)

**Rationale:** Governance should be flexible enough to allow critical fixes while maintaining audit trail and accountability.

---

## 📋 **AUTHORIZATION CRITERIA**

### **Required Documentation:**

1. **Incident Report:**
   - Documents the problem
   - Explains why governance is blocking
   - Provides evidence/logs

2. **Plan/Spec Document:**
   - Defines the fix scope
   - Lists required changes
   - Specifies acceptance criteria
   - Documents constraints

3. **Fix Implementation:**
   - Follows the spec exactly
   - Minimal changes only
   - Does not relax locked_zone protections
   - Maintains backward compatibility

4. **Verification:**
   - Acceptance criteria met
   - Tests pass
   - Telemetry confirms fix

---

## ✅ **EXAMPLE: LAC Writer Role Fix**

### **Documentation:**
- ✅ Incident Report: `g/reports/lac_incident_resolution_v1_20251206.md`
- ✅ Clarification: `g/reports/governance_lac_writer_clarification_20251206.md`
- ✅ Implementation Plan: `g/reports/governance_lac_allowed_paths_PLAN_20251206.md`

### **Fix Applied:**
- ✅ `shared/governance_router_v41.py` - Added `"lac": "LAC"` to CANON_WRITERS
- ✅ `g/governance/zone_definitions_v41.yaml` - Added `"LAC"` to open_zone.allowed_writers
- ✅ `g/governance/zone_definitions_v41.yaml` - Added `"tools/**"` to open_zone patterns

### **Verification:**
- ✅ `normalize_writer('LAC')` → `'LAC'` (not 'UNKNOWN')
- ✅ `check_writer_permission('LAC', 'open_zone')` → `True`
- ✅ Telemetry shows `writer: "LAC", allowed: true`
- ✅ Acceptance criteria A1, A2, A4, A5 met

### **Work Order:**
- ✅ `WO-20251206-GOV-LAC-WRITER-V1` created (retroactively documents the fix)

---

## 🔒 **CONSTRAINTS**

### **What is NOT Allowed:**
- ❌ Relaxing locked_zone patterns
- ❌ Granting access to protected paths (CLC, CLS, system reports, etc.)
- ❌ Making changes without documentation
- ❌ Breaking backward compatibility

### **What IS Allowed:**
- ✅ Adding new writers to open_zone (with proper documentation)
- ✅ Adding new open_zone patterns (with justification)
- ✅ Fixing normalization bugs
- ✅ Updating allowed_writers lists (open_zone only)

---

## 📝 **PROCESS**

### **Step 1: Document the Problem**
Create Incident Report explaining:
- What is blocked
- Why governance is blocking it
- Evidence/logs

### **Step 2: Create Implementation Plan**
Create Plan document with:
- Required changes
- Acceptance criteria
- Constraints
- Verification steps

### **Step 3: Apply Fix**
- Follow the plan exactly
- Make minimal changes
- Add code comments where appropriate

### **Step 4: Verify**
- Run acceptance criteria tests
- Check telemetry
- Verify no regressions

### **Step 5: Document (Optional)**
- Create Work Order retroactively if needed
- Update Incident Report with resolution status

---

## 🎯 **ROLES**

### **GG (Governance Gate):**
- **Responsibility:** Design WO/spec, define requirements
- **NOT Responsible:** Directly modifying governance files

### **CLS/Human:**
- **Responsibility:** Apply fixes according to spec
- **Authorization:** Allowed when Incident + Plan exist
- **Accountability:** Must follow spec exactly

### **CLC:**
- **Responsibility:** Verify fixes, review changes
- **Can Also:** Apply fixes if assigned via WO

---

## ✅ **AUDIT TRAIL**

All governance fixes must have:
1. **Incident Report** - Documents the problem
2. **Plan Document** - Defines the solution
3. **Fix Implementation** - Actual code changes
4. **Verification** - Proof that fix works
5. **Work Order (Optional)** - Retroactive documentation

This ensures:
- **Traceability:** Every change is documented
- **Accountability:** Clear who did what and why
- **Reviewability:** Changes can be verified
- **Reversibility:** Changes can be rolled back if needed

---

## 📊 **CURRENT STATUS**

**LAC Writer Role Fix:**
- ✅ **COMPLETE** - All criteria met
- ✅ **VERIFIED** - Tests pass, telemetry confirms
- ✅ **DOCUMENTED** - Incident + Plan + WO exist

**Policy Status:**
- 📋 **PROPOSED** - Awaiting formal adoption in AI_OP_001

---

## 🔗 **RELATED DOCUMENTS**

- Incident Report: `g/reports/lac_incident_resolution_v1_20251206.md`
- Clarification: `g/reports/governance_lac_writer_clarification_20251206.md`
- Implementation Plan: `g/reports/governance_lac_allowed_paths_PLAN_20251206.md`
- Work Order: `bridge/inbox/CLC/WO-20251206-GOV-LAC-WRITER-V1.yaml`

---

**Status:** 📋 **PROPOSED** - Ready for AI_OP_001 integration
