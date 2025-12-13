# Phase B/C Fixes: Policy Alignment & Test Corrections
**Date:** 2025-12-13  
**Issue:** Policy conflict + incorrect test design

---

## 🔴 Problems Identified

### 1. Policy Conflict
- **Current:** Guard/bootstrap fail if workspace paths are tracked in git
- **Reality:** Repo tracks symlinks (mode 120000) - which is valid and useful
- **Fix:** Allow tracked symlinks, only fail on real dirs/files

### 2. Test Design Issues
- **Test 2:** Creates `test_violation/g/data` (not a real workspace path)
- **Test 3:** Creates `g/data/test` (goes to workspace via symlink, not repo)
- **Fix:** Replace symlinks with real dirs to create actual violations

---

## 📋 Patch Instructions

### Fix 1: `tools/guard_workspace_inside_repo.zsh`

**Lines 55-64: Change tracking check**

**BEFORE:**
```zsh
echo ""
echo "== Guard: Checking workspace paths are NOT tracked in git =="
for path in "${workspace_paths[@]}"; do
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    echo "❌ FAIL: git is tracking '$path' (should be ignored/symlink only)" >&2
    echo "   Fix: git rm -r --cached $path" >&2
    failed=1
  else
    echo "✓ OK: $path not tracked in git"
  fi
done
```

**AFTER:**
```zsh
echo ""
echo "== Guard: Checking workspace paths (if tracked, must be symlinks) =="
for path in "${workspace_paths[@]}"; do
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    # Path is tracked - verify it's a symlink (not real dir/file)
    full_path="$REPO/$path"
    if [[ -L "$full_path" ]]; then
      echo "✓ OK: $path is tracked as symlink (allowed)"
    else
      echo "❌ FAIL: git is tracking '$path' but it's a real dir/file (must be symlink)" >&2
      echo "   Fix: Remove from git, then create symlink: git rm --cached $path && zsh tools/bootstrap_workspace.zsh" >&2
      failed=1
    fi
  else
    # Not tracked - that's fine, but if it exists, must be symlink
    full_path="$REPO/$path"
    if [[ -e "$full_path" ]] && [[ ! -L "$full_path" ]]; then
      echo "❌ FAIL: $path exists as real dir/file but not tracked (should be symlink)" >&2
      echo "   Fix: Run bootstrap_workspace.zsh or create symlink manually" >&2
      failed=1
    else
      echo "✓ OK: $path not tracked (or is symlink)"
    fi
  fi
done
```

---

### Fix 2: `tools/bootstrap_workspace.zsh`

**Lines 101-121: Change tracking check**

**BEFORE:**
```zsh
echo "== Guard: fail if workspace-like paths are tracked in git =="
cd "$REPO"
# patterns that should never be tracked
bad_tracked=0
for p in \
  "g/data" \
  "g/telemetry" \
  "g/followup" \
  "mls/ledger" \
  "bridge/processed"
do
  if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then
    echo "ERROR: git is tracking '$p' (should be workspace symlink / ignored)." >&2
    bad_tracked=1
  fi
done
if [[ "$bad_tracked" -ne 0 ]]; then
  echo "FIX: remove from git tracking (without deleting data) then re-run bootstrap." >&2
  echo "     Example: git rm -r --cached <path>  (then commit)" >&2
  exit 1
fi
```

**AFTER:**
```zsh
echo "== Guard: verify tracked paths are symlinks (if tracked) =="
cd "$REPO"
bad_tracked=0
for p in \
  "g/data" \
  "g/telemetry" \
  "g/followup" \
  "mls/ledger" \
  "bridge/processed"
do
  if git ls-files --error-unmatch "$p" >/dev/null 2>&1; then
    # Path is tracked - verify it's a symlink
    if [[ -L "$REPO/$p" ]]; then
      echo "OK  tracked symlink: $p (allowed)"
    else
      echo "ERROR: git is tracking '$p' but it's a real dir/file (must be symlink)." >&2
      echo "FIX: Remove from git, then re-run bootstrap:" >&2
      echo "     git rm -r --cached $p  (then commit)" >&2
      echo "     zsh tools/bootstrap_workspace.zsh" >&2
      bad_tracked=1
    fi
  else
    # Not tracked - that's fine
    echo "OK  not tracked: $p"
  fi
done
if [[ "$bad_tracked" -ne 0 ]]; then
  exit 1
fi
```

---

### Fix 3: `tools/phase_c_execute.zsh`

**Test 2: Replace with correct violation**

**BEFORE (lines 33-51):**
```zsh
# Test 2: Simulate Pre-commit Failure
echo "=== Test 2: Simulate Pre-commit Failure ==="
echo "   Creating violation (real directory at workspace path)..."
mkdir -p test_violation/g/data
echo "test" > test_violation/g/data/test.txt

# Try to commit (should fail)
if git add test_violation/ 2>/dev/null && git commit -m "test violation" 2>&1 | grep -q "FAIL\|must be symlink"; then
  echo "✅ PASS: Pre-commit hook blocked invalid commit"
  test2_passed=1
else
  echo "⚠️  WARN: Pre-commit may not have blocked (check manually)"
fi

# Cleanup
rm -rf test_violation/
git reset HEAD~1 2>/dev/null || true
git reset test_violation/ 2>/dev/null || true
```

**AFTER:**
```zsh
# Test 2: Simulate Pre-commit Failure
echo "=== Test 2: Simulate Pre-commit Failure ==="
echo "   Creating violation (replace symlink with real directory)..."
# Backup current symlink target
if [[ -L g/data ]]; then
  backup_target=$(readlink g/data)
  # Remove symlink and create real directory (violation)
  rm -f g/data
  mkdir -p g/data
  echo "test" > g/data/test.txt
  
  # Try to commit (should fail)
  if git add g/data/ 2>/dev/null && git commit -m "test violation" 2>&1 | grep -q "FAIL\|must be symlink\|real directory"; then
    echo "✅ PASS: Pre-commit hook blocked invalid commit"
    test2_passed=1
  else
    echo "⚠️  WARN: Pre-commit may not have blocked (check manually)"
  fi
  
  # Cleanup: restore symlink
  rm -rf g/data
  ln -sfn "$backup_target" g/data
  git reset HEAD~1 2>/dev/null || true
  git reset g/data 2>/dev/null || true
else
  echo "⚠️  SKIP: g/data is not a symlink (cannot test)"
fi
```

**Test 3: Replace with correct violation**

**BEFORE (lines 53-67):**
```zsh
# Test 3: Guard Script Verification
echo "=== Test 3: Guard Script Verification ==="
echo "   Creating violations (real directories at workspace paths)..."
mkdir -p g/data/test g/telemetry/test g/followup/test mls/ledger/test bridge/processed/test 2>/dev/null || true

if zsh tools/guard_workspace_inside_repo.zsh 2>&1 | grep -q "FAIL"; then
  echo "✅ PASS: Guard script detected violations"
  test3_passed=1
else
  echo "⚠️  WARN: Guard script may not have detected violations"
fi

# Cleanup
rm -rf g/data/test g/telemetry/test g/followup/test mls/ledger/test bridge/processed/test 2>/dev/null || true
```

**AFTER:**
```zsh
# Test 3: Guard Script Verification
echo "=== Test 3: Guard Script Verification ==="
echo "   Creating violations (replace symlinks with real directories)..."
# Backup symlinks
declare -A backups
for path in g/data g/telemetry; do
  if [[ -L "$path" ]]; then
    backups["$path"]=$(readlink "$path")
    # Remove symlink and create real directory (violation)
    rm -f "$path"
    mkdir -p "$path"
    echo "test" > "$path/test.txt"
  fi
done

# Run guard (should fail)
if zsh tools/guard_workspace_inside_repo.zsh 2>&1 | grep -q "FAIL\|real directory"; then
  echo "✅ PASS: Guard script detected violations"
  test3_passed=1
else
  echo "⚠️  WARN: Guard script may not have detected violations"
fi

# Cleanup: restore symlinks
for path in "${!backups[@]}"; do
  rm -rf "$path"
  ln -sfn "${backups[$path]}" "$path"
done
unset backups
```

**Test 4: Remove bootstrap tracking check (already fixed in bootstrap)**

Test 4 should now pass because bootstrap allows tracked symlinks.

---

## ✅ Summary of Changes

1. **Guard Script:** Allow tracked symlinks, only fail on tracked real dirs/files
2. **Bootstrap:** Allow tracked symlinks, only fail on tracked real dirs/files
3. **Test 2:** Replace actual symlink with real dir (not fake path)
4. **Test 3:** Replace actual symlinks with real dirs (not subdirs)
5. **Test 4:** Should pass now (bootstrap allows tracked symlinks)

---

## 🎯 Expected Results After Fixes

- ✅ Test 1: Safe clean - PASS (unchanged)
- ✅ Test 2: Pre-commit blocks real dir - PASS (fixed)
- ✅ Test 3: Guard detects real dir - PASS (fixed)
- ✅ Test 4: Bootstrap works with tracked symlinks - PASS (fixed)

---

**Status:** Ready for CLS to apply patches
