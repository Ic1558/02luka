# Phase 2: Secret Allowlist/Whitelist Feature

**Date:** 2025-12-06  
**Status:** ✅ **Implemented** (2025-12-06)  
**Priority:** Medium (reduces false positives)

---

## Problem Statement

Current `PrivacyGuard` scans for secrets and blocks review if any are detected. However, this can cause false positives in:
- Test files with dummy API keys
- Documentation with example keys
- Configuration templates
- Mock data

**Goal:** Allow specific patterns/files to bypass secret detection while maintaining security.

---

## Design

### Configuration Schema

Add to `g/config/local_agent_review.yaml`:

```yaml
review:
  secret_scan:
    enabled: true
    allowlist:
      # File patterns (glob)
      file_patterns:
        - "**/test_*.py"
        - "**/*_test.py"
        - "**/tests/**"
        - "**/docs/**/*.md"
        - "**/examples/**"
      
      # Content patterns (regex)
      content_patterns:
        - "sk-test-.*"  # Test keys
        - "TEST_API_KEY.*"
        - "example.*key"
        - "dummy.*secret"
      
      # Specific file paths (absolute or relative to repo root)
      file_paths:
        - "tests/fixtures/test_keys.py"
        - "docs/examples/api_keys.md"
    
    # Safe patterns that are always allowed (even if not in allowlist)
    safe_patterns:
      - "sk-test-[a-z0-9]{32}"  # Standard test key format
      - "TEST_.*_KEY"
      - "MOCK_.*"
```

### Implementation

#### 1. Update `PrivacyGuard` Class

```python
@dataclass
class PrivacyGuard:
    ignore_patterns: List[str]
    exclude_files: List[str]
    redact_secrets: bool
    allowlist: Optional[SecretAllowlist] = None  # NEW

    def scan_diff(self, diff_text: str) -> List[SecurityWarning]:
        warnings = []
        for line_num, line in enumerate(diff_text.splitlines(), 1):
            # Check if line matches allowlist
            if self.allowlist and self.allowlist.is_allowed(line, line_num):
                continue
            
            # Existing secret detection logic
            for pattern in SECRET_PATTERNS:
                if pattern.match(line):
                    warnings.append(SecurityWarning(...))
        return warnings
```

#### 2. Create `SecretAllowlist` Class

```python
@dataclass
class SecretAllowlist:
    file_patterns: List[str]
    content_patterns: List[str]
    file_paths: List[str]
    safe_patterns: List[str]
    
    def is_allowed(self, line: str, line_num: int, file_path: Optional[str] = None) -> bool:
        # Check safe patterns first (always allowed)
        for pattern in self.safe_patterns:
            if re.match(pattern, line, re.IGNORECASE):
                return True
        
        # Check content patterns
        for pattern in self.content_patterns:
            if re.search(pattern, line, re.IGNORECASE):
                return True
        
        # Check file patterns (if file_path provided)
        if file_path:
            for pattern in self.file_patterns:
                if fnmatch.fnmatch(file_path, pattern):
                    return True
            
            # Check specific file paths
            if file_path in self.file_paths:
                return True
        
        return False
```

#### 3. Update Config Loading

```python
def build_privacy_guard(config: AppConfig) -> PrivacyGuard:
    review_cfg = config.review
    secret_cfg = review_cfg.get("secret_scan", {})
    
    allowlist = None
    if secret_cfg.get("enabled", True) and secret_cfg.get("allowlist"):
        allowlist = SecretAllowlist(
            file_patterns=secret_cfg["allowlist"].get("file_patterns", []),
            content_patterns=secret_cfg["allowlist"].get("content_patterns", []),
            file_paths=secret_cfg["allowlist"].get("file_paths", []),
            safe_patterns=secret_cfg.get("safe_patterns", []),
        )
    
    return PrivacyGuard(
        ignore_patterns=review_cfg.get("ignore_patterns", []),
        exclude_files=review_cfg.get("exclude_files", []),
        redact_secrets=bool(review_cfg.get("redact_secrets", True)),
        allowlist=allowlist,
    )
```

---

## Usage Examples

### Example 1: Test Files

```yaml
review:
  secret_scan:
    allowlist:
      file_patterns:
        - "**/test_*.py"
        - "**/tests/**"
```

**Result:** Test files with dummy keys won't trigger secret detection.

### Example 2: Documentation

```yaml
review:
  secret_scan:
    allowlist:
      file_patterns:
        - "**/docs/**"
      content_patterns:
        - "example.*key"
```

**Result:** Documentation with example keys won't trigger detection.

### Example 3: Safe Patterns

```yaml
review:
  secret_scan:
    safe_patterns:
      - "sk-test-[a-z0-9]{32}"
```

**Result:** Any line matching this pattern is automatically allowed.

---

## Security Considerations

1. **Default Deny:** If allowlist is not configured, all secrets are blocked (current behavior).

2. **Pattern Validation:** 
   - File patterns must be relative to repo root
   - Content patterns are regex (validate on load)
   - Safe patterns are always checked first

3. **Audit Trail:**
   - Log when allowlist bypasses detection
   - Include in telemetry: `allowlist_bypassed: true`

4. **Whitelist vs Allowlist:**
   - Use "allowlist" terminology (more inclusive)
   - Support both terms in config for backward compatibility

---

## Testing

### Unit Tests

```python
def test_allowlist_file_pattern():
    allowlist = SecretAllowlist(
        file_patterns=["**/test_*.py"],
        content_patterns=[],
        file_paths=[],
        safe_patterns=[],
    )
    assert allowlist.is_allowed("sk-real-key-123", file_path="tests/test_api.py")
    assert not allowlist.is_allowed("sk-real-key-123", file_path="src/api.py")

def test_allowlist_content_pattern():
    allowlist = SecretAllowlist(
        file_patterns=[],
        content_patterns=["sk-test-.*"],
        file_paths=[],
        safe_patterns=[],
    )
    assert allowlist.is_allowed("api_key = 'sk-test-abc123'")
    assert not allowlist.is_allowed("api_key = 'sk-prod-xyz789'")

def test_safe_patterns():
    allowlist = SecretAllowlist(
        file_patterns=[],
        content_patterns=[],
        file_paths=[],
        safe_patterns=["TEST_.*_KEY"],
    )
    assert allowlist.is_allowed("TEST_API_KEY=abc123")
```

### Integration Tests

- Test with real test files containing dummy keys
- Test with documentation files
- Verify actual secrets still trigger detection

---

## Migration Path

1. **Phase 2.1:** Add allowlist config (disabled by default)
2. **Phase 2.2:** Enable allowlist with safe defaults
3. **Phase 2.3:** Add telemetry for allowlist usage
4. **Phase 2.4:** Document common patterns

---

## Related Issues

- Reduces false positives from test files
- Improves developer experience
- Maintains security for production code
- Aligns with industry best practices (allowlist vs blocklist)

---

**Implementation Status:**
- ✅ `SecretAllowlist` class implemented in `tools/lib/privacy_guard.py`
- ✅ `PrivacyGuard.scan_diff()` updated to respect allowlist with per-file context
- ✅ `SecurityWarning` extended with `file` and `line` fields
- ✅ Config support added to `g/config/local_agent_review.yaml`
- ✅ `build_privacy_guard()` updated to load allowlist config
- ✅ Unit test added: `test_allowlist_content_and_file_patterns()`
- ✅ All 9 tests passing (pytest validation)

**Implementation Notes:**
- Uses keyword-only `file_path` parameter in `is_allowed()` for clarity
- Per-file context extracted from diff headers (`+++ b/path`)
- Safe patterns checked first, then content patterns, then file patterns
- Maintains security: default deny if allowlist not configured

---

**Last Updated:** 2025-12-06  
**Implementation Date:** 2025-12-06
