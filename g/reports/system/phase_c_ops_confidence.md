# Phase C: Operations Confidence Tests
**Date:** 2025-12-13  
**Purpose:** Verify system hardening works in practice

---

## 🎯 Objective

**Goal:** Confirm that workspace protection works in real scenarios

**Tests:**
1. Safe clean dry-run
2. Simulate pre-commit failure
3. Verify guard script catches violations

---

## ✅ Test 1: Safe Clean Dry-Run

**Purpose:** Verify safe clean script works correctly

**Commands:**
```bash
cd ~/02luka

# Dry-run (safe, shows what would be deleted)
zsh tools/safe_git_clean.zsh -n

# Expected: Shows ignored files only, no workspace data
```

**Success Criteria:**
- ✅ Shows only ignored files
- ✅ Does NOT show workspace paths
- ✅ Guard script runs before clean

---

## ✅ Test 2: Simulate Pre-commit Failure

**Purpose:** Verify pre-commit hook blocks invalid commits

**Steps:**
```bash
cd ~/02luka

# 1. Create a real directory at workspace path (violation)
mkdir -p test_violation/g/data
echo "test" > test_violation/g/data/test.txt

# 2. Try to commit (should fail)
git add test_violation/
git commit -m "test violation"

# Expected: Pre-commit hook fails with error
# Error: "❌ FAIL: g/data exists as real directory (must be symlink to workspace)"
```

**Success Criteria:**
- ✅ Pre-commit hook runs guard script
- ✅ Commit is blocked
- ✅ Error message is clear

**Cleanup:**
```bash
rm -rf test_violation/
git reset HEAD~1 2>/dev/null || true
```

---

## ✅ Test 3: Guard Script Verification

**Purpose:** Verify guard script catches all violations

**Steps:**
```bash
cd ~/02luka

# 1. Create real directory at each workspace path
mkdir -p g/data/test
mkdir -p g/telemetry/test
mkdir -p g/followup/test
mkdir -p mls/ledger/test
mkdir -p bridge/processed/test

# 2. Run guard script (should fail)
zsh tools/guard_workspace_inside_repo.zsh

# Expected: Multiple FAIL messages
```

**Success Criteria:**
- ✅ Guard script detects all violations
- ✅ Clear error messages
- ✅ Exit code = 1 (failure)

**Cleanup:**
```bash
rm -rf g/data/test g/telemetry/test g/followup/test mls/ledger/test bridge/processed/test
```

---

## ✅ Test 4: Verify Symlinks After Bootstrap

**Purpose:** Confirm bootstrap script creates correct symlinks

**Steps:**
```bash
cd ~/02luka

# 1. Remove all symlinks (simulate fresh setup)
rm g/data g/telemetry g/followup mls/ledger bridge/processed 2>/dev/null || true

# 2. Run bootstrap
zsh tools/bootstrap_workspace.zsh

# 3. Verify all are symlinks
for path in g/data g/telemetry g/followup mls/ledger bridge/processed; do
  if [[ -L "$path" ]]; then
    echo "✅ $path -> $(readlink "$path")"
  else
    echo "❌ $path is NOT a symlink"
  fi
done

# 4. Run guard (should pass)
zsh tools/guard_workspace_inside_repo.zsh
```

**Success Criteria:**
- ✅ All paths are symlinks
- ✅ All point to `~/02luka_ws/...`
- ✅ Guard script passes

---

## 📊 Test Results Template

```markdown
# Phase C Test Results
**Date:** YYYY-MM-DD

## Test 1: Safe Clean Dry-Run
- Status: ✅ PASS / ❌ FAIL
- Notes: ...

## Test 2: Pre-commit Failure
- Status: ✅ PASS / ❌ FAIL
- Notes: ...

## Test 3: Guard Script Verification
- Status: ✅ PASS / ❌ FAIL
- Notes: ...

## Test 4: Bootstrap Verification
- Status: ✅ PASS / ❌ FAIL
- Notes: ...

## Overall Status
- All tests: ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
```

---

## 🎯 Success Criteria

**Phase C Complete when:**
- ✅ All 4 tests pass
- ✅ Safe clean works correctly
- ✅ Pre-commit blocks violations
- ✅ Guard script catches all issues
- ✅ Bootstrap creates correct symlinks

---

**Status:** Ready for execution
