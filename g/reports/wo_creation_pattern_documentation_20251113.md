# WO Creation Pattern - Documentation & Improvement

**Date:** 2025-11-13  
**Status:** 📋 DOCUMENTING PATTERN FOR IMPROVEMENT

---

## Pattern (Confirmed by User)

### Decision Rule

```
IF issues_count <= 1 AND critical:
    → Fix DIRECTLY (immediate action)
ELSE IF issues_count >= 2:
    → Create WO (deferred to agents)
```

### Examples

**Example 1: 1 Critical Issue**
- Issue: Server crashed (critical)
- Count: 1
- Action: Fix directly ✅
- Reason: Single critical issue, immediate action needed

**Example 2: 3 Issues**
- Issue 1: Hard-coded password
- Issue 2: Hard-coded URLs
- Issue 3: Missing endpoint
- Count: 3
- Action: Create WO ✅
- Reason: Multiple issues (2+), can be handled by agents

---

## Current Gap

### What Happened (Dashboard Fix)

**Issues Found:**
1. Hard-coded Redis password
2. Hard-coded localhost URLs
3. Missing `/api/auth-token` endpoint

**Count:** 3 issues

**Expected Action (per pattern):**
- ✅ 3 issues = **2+** → Should create **WO**

**Actual Action:**
- ❌ Fixed directly (bypassed WO system)
- ❌ Didn't follow pattern
- ❌ Didn't create WO file

---

## Improvement Plan

### 1. Document Pattern in Rules

**File:** `02luka.md` or `CLS.md`

**Add Section:**
```markdown
## WO Creation Decision Rule

**Pattern:**
- 0-1 critical issues → Fix DIRECTLY
- 2+ issues → Create WO

**Rationale:**
- Single critical issue: Immediate action needed
- Multiple issues: Can be batched and handled by agents

**Examples:**
- 1 critical bug → Fix directly
- 3 security issues → Create WO
- 1 typo → Fix directly
- 5 code quality issues → Create WO
```

### 2. Add Pattern Check Before Direct Fixes

**Implementation:**
```zsh
# Before fixing directly, check:
if (( issues_count >= 2 )); then
    echo "⚠️  Multiple issues detected (${issues_count})"
    echo "📋 Should create WO instead of fixing directly"
    echo "🔍 Pattern: 2+ issues → Create WO"
    exit 1  # Force WO creation
fi
```

### 3. Add MLS Verification

**Before Direct Fix:**
1. Check MLS for promises
2. Verify if WO was promised
3. If WO promised but not created → Create WO first

**Implementation:**
```zsh
# Check MLS for WO promises
if grep -q "create.*wo\|wo.*will.*be" mls/ledger/*.jsonl; then
    echo "⚠️  WO was promised but not created"
    echo "📋 Creating WO now..."
    create_wo_file
fi
```

### 4. WO Creation Verification

**After Promising WO:**
1. Create WO file immediately
2. Verify file exists
3. Log to MLS
4. Set reminder to check execution

**Implementation:**
```zsh
# After saying "I'll create WO"
create_wo_file() {
    local wo_file="bridge/inbox/ENTRY/WO-$(date +%Y%m%d-%H%M%S)-FIX.yaml"
    # Create WO file
    # Verify exists
    [[ -f "$wo_file" ]] || { echo "ERROR: WO not created!"; exit 1; }
    # Log to MLS
    mls_capture "followup" "WO Created" "Created WO: $wo_file"
}
```

---

## Pattern Enforcement

### Pre-Fix Check

**Before ANY direct fix:**
1. Count issues
2. Check if count >= 2
3. If yes → Create WO instead
4. If no → Proceed with direct fix

### Post-Promise Verification

**After promising WO:**
1. Create WO file immediately
2. Verify file exists
3. Log to MLS
4. Don't fix directly

---

## Success Criteria

- ✅ Pattern documented in rules
- ✅ Pattern check before direct fixes
- ✅ MLS verification before fixes
- ✅ WO creation verification
- ✅ Pattern followed consistently

---

## Next Steps

1. **Document pattern** in `02luka.md` or `CLS.md`
2. **Add pattern check** to fix workflow
3. **Add MLS verification** before fixes
4. **Add WO creation verification** after promises
5. **Test pattern** with next set of issues

---

## Questions for User

1. **Is pattern correct?**
   - 0-1 critical → Fix directly
   - 2+ → Create WO

2. **What defines "critical"?**
   - Severity? Urgency? Impact?

3. **Should pattern be enforced automatically?**
   - Block direct fixes if 2+ issues?
   - Force WO creation?

4. **Where should pattern be documented?**
   - `02luka.md`?
   - `CLS.md`?
   - Separate `WO_PATTERN.md`?

---

**Status:** Pattern documented, ready for implementation
