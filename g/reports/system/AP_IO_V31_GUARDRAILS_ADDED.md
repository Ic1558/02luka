# AP/IO v3.1 Guardrails - Implementation Complete

**Date:** 2025-11-16  
**Status:** ✅ **GUARDRAILS ACTIVE**

---

## Problem

AP/IO v3.1 Ledger system files were accidentally deleted. These are critical infrastructure files that should be protected.

---

## Solution: Guardrails Implemented

### 1. Protected Files List
**File:** `.cursor/protected_files.txt`

Lists all critical AP/IO v3.1 files and patterns:
- `tools/ap_io_v31/**` - All AP/IO tools
- `schemas/ap_io_v31*.json` - Protocol schemas
- `docs/AP_IO_V31*.md` - Documentation
- `agents/*/ap_io_v31_integration.zsh` - Agent integrations
- `tests/ap_io_v31/**` - Test suites

### 2. Protection Script
**File:** `tools/protect_critical_files.zsh`

- Checks git diff for deleted files
- Matches against protected patterns
- Exits with error if protected files detected
- Provides clear error messages

### 3. Pre-commit Hook
**File:** `.git/hooks/pre-commit`

- Automatically runs protection script before commits
- Blocks commits that delete protected files
- Prevents accidental deletion from being committed

---

## How It Works

1. **Before Commit:**
   - Git pre-commit hook runs automatically
   - Protection script checks for deleted files
   - If protected file is deleted → commit blocked

2. **Manual Check:**
   ```bash
   tools/protect_critical_files.zsh
   ```

3. **Bypass (if needed):**
   - Temporarily rename `.git/hooks/pre-commit`
   - Or update `.cursor/protected_files.txt` first

---

## Testing

Test the guardrail:
```bash
# Try to delete a protected file (will be blocked)
git rm tools/ap_io_v31/writer.zsh
git commit -m "test"
# Should fail with protection error
```

---

## Maintenance

### Adding New Protected Files
Edit `.cursor/protected_files.txt`:
```
# New critical file pattern
path/to/protected/**/*
```

### Updating Protection Script
Edit `tools/protect_critical_files.zsh` if pattern matching needs changes.

---

## Status

✅ **Guardrails Active**
- Protected files list: Created
- Protection script: Created and executable
- Pre-commit hook: Installed and executable

**Next:** Restore deleted AP/IO v3.1 files (see `AP_IO_V31_RESTORATION_PLAN.md`)

---

**Protection Owner:** System  
**Last Updated:** 2025-11-16
