# Block 2: SandboxGuard v5 — Review Fixes Summary

**Date:** 2025-12-10  
**Status:** ✅ All Review Fixes Applied  
**Reviewer:** Boss (CLS)

---

## ✅ Fixes Applied

### P0.1: FORBIDDEN_ROOTS Logic Cleanup ✅

**Problem:** FORBIDDEN_ROOTS in `check_path_allowed()` was dead code (rel_path never matches "/System/", etc.)

**Fix Applied:**
- ✅ Removed FORBIDDEN_ROOTS check from `check_path_allowed()`
- ✅ Added clear documentation that absolute path hazards are checked in `validate_path_syntax()`
- ✅ Updated YAML config with note about forbidden_roots removal

**Result:** Clear separation of concerns:
- `validate_path_syntax()` → Handles absolute paths, system paths, path traversal
- `check_path_allowed()` → Handles relative path policy within 02luka root

---

### P0.2: Path Traversal Check (STRICT Mode) ✅

**Problem:** Need to decide on ".." check policy

**Fix Applied:**
- ✅ Kept strict ".." check in `validate_path_syntax()` (100% block)
- ✅ Enhanced error message to clarify agents must send normalized paths
- ✅ Added documentation note about path normalization requirements

**Note:** Will add FAQ entry in HOWTO_TWO_WORLDS_v2.md:
> "Q: Why does SandboxGuard reject paths with '..'?"
> "A: SandboxGuard enforces strict path normalization. All agents must send normalized paths (no '..') to Router/Sandbox. Use `normalize_path()` before calling routing/sandbox functions."

---

### P1.1: YAML Config vs Code ✅

**Problem:** YAML config exists but code uses hard-coded patterns (risk of drift)

**Fix Applied:**
- ✅ Added clear note in YAML config header:
  ```yaml
  # NOTE: This YAML file is currently a REFERENCE SPECIFICATION.
  # The actual implementation in sandbox_guard_v5.py uses hard-coded patterns.
  # To use this config file, implement load_sandbox_config() function.
  ```

**Future Enhancement:** Can implement `load_sandbox_config()` function to read from YAML if needed.

---

### P1.2: SecurityViolation Type Clarity ✅

**Problem:** `FORBIDDEN_PATTERN` used for both path and content violations (unclear in logs)

**Fix Applied:**
- ✅ Split into:
  - `FORBIDDEN_PATH_PATTERN` (path policy violations)
  - `FORBIDDEN_CONTENT_PATTERN` (content pattern violations)
- ✅ Enhanced `reason` messages:
  - Path: `"Path policy violation: {reason}"`
  - Content: `"Content contains forbidden command patterns (e.g., rm -rf, sudo, curl | sh). See sandbox_guard_config.yaml for full list."`

**Result:** Logs/errors are now clear about violation type.

---

### P2.1: Context Contract Documentation ✅

**Problem:** Context format not documented for developers

**Fix Applied:**
- ✅ Added complete "SandboxGuard Context Contract" section
- ✅ Documented all context fields with types and descriptions
- ✅ Provided usage examples for different scenarios:
  - CLI World, OPEN Zone
  - CLI World, LOCKED Zone (Boss authorized)
  - Background World, LOCKED Zone (with SIP)

**Result:** Developers now have clear contract for `context` parameter.

---

## 📋 Final Verdict

**Block 2: SandboxGuard v5 — Status: ✅ PROD-GRADE DRAFT**

**Strengths:**
- ✅ 3-layer guard: path, zone, content
- ✅ Governance v5 compliant
- ✅ Clear separation: Router (policy) vs Sandbox (safety)
- ✅ Context contract documented
- ✅ All review issues resolved

**Ready for:**
- ✅ Implementation (can write files)
- ✅ Integration with Router v5
- ✅ Integration with CLC Enforcement Engine v5

---

**Next Steps:**
1. ✅ Block 2 fixes complete
2. ⏭️ Proceed to Block 3: CLC Enforcement Engine v5
3. 📝 Add FAQ entry to HOWTO_TWO_WORLDS_v2.md about path normalization (separate task)

---

**Last Updated:** 2025-12-10

