# LPE Path ACL Security Analysis

**Date:** 2025-11-18  
**File:** `g/tools/lpe_worker.zsh`  
**Status:** ✅ **BASIC SECURITY VERIFIED**

---

## Security Analysis

### ✅ Path Validation Found

**Location:** `normalize_patch_path()` function (lines 41-48)

**Implementation:**
```python
def normalize_patch_path(path_str: str) -> str:
    raw = pathlib.Path(path_str)
    resolved = (base / raw).resolve() if not raw.is_absolute() else raw.resolve()
    try:
        resolved.relative_to(base)
    except ValueError:
        raise ValueError(f"patch path escapes repo: {resolved}")
    return str(resolved)
```

**Security Check:**
- ✅ Validates that resolved path is within `$BASE` directory
- ✅ Raises `ValueError` if path escapes repo
- ✅ Prevents absolute paths outside repo
- ✅ Prevents relative paths that escape via `../`

**Status:** ✅ **BASIC PATH VALIDATION EXISTS**

---

## Security Assessment

### ✅ What's Protected

1. **Path Escaping Prevention:**
   - Cannot use `../` to escape repo
   - Cannot use absolute paths outside repo
   - All paths must be relative to `$BASE`

2. **Error Handling:**
   - Invalid paths raise exceptions
   - Exceptions are caught and logged
   - WO marked as "invalid" if path check fails

### ⚠️ What's Missing (Optional Enhancements)

1. **Allow List:**
   - No explicit allow list of directories
   - Could add `path_acl` checking for specific directories
   - Could restrict to certain subdirectories only

2. **Operation Restrictions:**
   - No `allow_create` / `allow_delete` checks
   - Could add per-operation permissions

3. **File Type Restrictions:**
   - No restriction on file types that can be patched
   - Could add whitelist of allowed extensions

---

## Recommendation

**Current Status:** ✅ **ACCEPTABLE SECURITY**

**Reasoning:**
- Basic path validation prevents escaping repo
- Error handling prevents invalid patches
- Security is sufficient for current use case

**Optional Enhancements:**
- Add allow list for fine-grained control
- Add operation-level permissions
- Add file type restrictions

**Priority:** Low (current security is adequate)

---

## Verification

**File:** `g/tools/lpe_worker.zsh`  
**Lines:** 41-48 (normalize_patch_path)  
**Status:** ✅ Verified on main branch

**Conclusion:** LPE worker has basic path ACL security. No critical security issues found.

---

**Status:** ✅ Security verified  
**Next:** Optional enhancements can be added later
