# MLS Ledger File Disappearing Issue - Root Cause Analysis

**Date:** 2025-11-13  
**Status:** 🔴 ISSUE IDENTIFIED

---

## Problem Description

The `mls/ledger/2025-11-13.jsonl` file appears and disappears intermittently. User reports it should be auto-generated but keeps vanishing.

---

## Root Cause Analysis

### Issue 1: CI Sanitization Step Can Create Empty Files

**Location:** `.github/workflows/cls-ci.yml` lines 316-333

**Problem:**
```bash
TMP="$(mktemp)"
# Keep only non-empty lines that are valid JSON
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if echo "$line" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$line" >> "$TMP"
  fi
done < "$LEDGER"
mv "$TMP" "$LEDGER"  # ⚠️ PROBLEM: Replaces file even if TMP is empty
```

**What Happens:**
1. If ledger file gets corrupted (e.g., shell script code written to it)
2. Sanitization filters out all invalid JSON lines
3. Temp file ends up empty (no valid JSON found)
4. `mv "$TMP" "$LEDGER"` replaces ledger file with empty file
5. File still exists but is 0 bytes
6. Next CI run appends to empty file → file "reappears"

### Issue 2: File Corruption Risk

**Problem:** File can be accidentally overwritten with non-JSON content (as happened with shell script code).

**When It Happens:**
- Manual edits that overwrite instead of append
- Script errors that write to wrong file
- Copy/paste mistakes

### Issue 3: Git Tracking Status

**Current Status:** File is **untracked** in git
- Not in `.gitignore` (good)
- But also not committed (so it's not persisted in git)
- CI creates it in GitHub Actions, but local copy can differ

---

## Solutions

### Solution 1: Fix CI Sanitization to Preserve File

**Fix:** Don't replace file if sanitization results in empty file

```bash
# Keep only non-empty lines that are valid JSON
TMP="$(mktemp)"
VALID_LINES=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if echo "$line" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$line" >> "$TMP"
    ((VALID_LINES++))
  fi
done < "$LEDGER"

# Only replace if we have valid lines OR if original was empty
if [ "$VALID_LINES" -gt 0 ] || [ ! -s "$LEDGER" ]; then
  mv "$TMP" "$LEDGER"
  echo "✅ Sanitized ledger → $LEDGER ($VALID_LINES valid lines)"
else
  # Original had content but all invalid - preserve it for debugging
  rm -f "$TMP"
  echo "⚠️  Ledger has no valid JSON lines - preserving original for debugging"
  echo "   File: $LEDGER"
fi
```

### Solution 2: Add File Protection

**Add validation before overwriting:**

```bash
# Before sanitization, check if file exists and has content
if [ -s "$LEDGER" ]; then
  # Backup before sanitization
  cp "$LEDGER" "${LEDGER}.backup.$(date +%s)"
fi
```

### Solution 3: Commit Ledger Files to Git

**Option A:** Add to git tracking (recommended for audit trail)
```bash
git add mls/ledger/*.jsonl
git commit -m "chore(mls): track ledger files for audit trail"
```

**Option B:** Keep untracked but add to `.gitignore` with exception
```gitignore
# Ignore all ledger files except today's
mls/ledger/*.jsonl
!mls/ledger/$(date +%Y-%m-%d).jsonl
```

### Solution 4: Add Local Monitoring Script

Create a script to detect when file disappears:

```zsh
#!/usr/bin/env zsh
# Monitor MLS ledger file existence
LEDGER="$HOME/02luka/mls/ledger/$(date +%Y-%m-%d).jsonl"

if [ ! -f "$LEDGER" ]; then
  echo "⚠️  WARNING: Ledger file missing: $LEDGER"
  echo "   Creating empty file..."
  touch "$LEDGER"
elif [ ! -s "$LEDGER" ]; then
  echo "⚠️  WARNING: Ledger file is empty: $LEDGER"
fi
```

---

## Immediate Actions

1. ✅ **File Restored:** Fixed corrupted `2025-11-13.jsonl` from git history
2. ⏳ **Fix CI Sanitization:** Update workflow to preserve file even if empty
3. ⏳ **Add Protection:** Add backup before sanitization
4. ⏳ **Decide Git Strategy:** Commit ledger files or add to `.gitignore`

---

## Prevention

1. **Never overwrite ledger files directly** - always append
2. **Validate before writing** - check file is JSONL before appending
3. **Use `mls_add.zsh` tool** - don't write directly to ledger files
4. **Monitor file size** - alert if file becomes 0 bytes unexpectedly

---

## Testing

After fixes are applied:

1. **Test corruption recovery:**
   ```bash
   # Corrupt file
   echo "#!/bin/bash" > mls/ledger/2025-11-13.jsonl
   # Run CI sanitization
   # Verify file is preserved (not deleted)
   ```

2. **Test empty file handling:**
   ```bash
   # Create empty file
   touch mls/ledger/2025-11-13.jsonl
   # Run CI sanitization
   # Verify file still exists
   ```

3. **Test normal operation:**
   ```bash
   # Add valid entry
   ~/02luka/tools/mls_add.zsh --type solution --title "Test" --summary "Test entry" --producer clc
   # Verify file has content
   ```

---

**Status:** Root cause identified, solutions proposed, ready for implementation
