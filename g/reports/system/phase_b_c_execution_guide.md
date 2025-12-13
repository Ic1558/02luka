# Phase B & C: Execution Guide
**Date:** 2025-12-13  
**Status:** Ready for Execution

---

## 🎯 Quick Start

### Phase B: Hardening (5 minutes)

```bash
cd ~/02luka

# Run setup script
zsh tools/phase_b_setup.zsh

# Verify alias works
git clean-safe -n
```

**Expected Output:**
- ✅ Git alias 'clean-safe' configured
- ✅ CI workflow ready
- ✅ Guard script verified
- ✅ Pre-commit hook verified

---

### Phase C: Ops Confidence (10-15 minutes)

```bash
cd ~/02luka

# Run all tests
zsh tools/phase_c_execute.zsh
```

**Expected Output:**
- ✅ Test 1: Safe Clean Dry-Run - PASS
- ✅ Test 2: Pre-commit Failure - PASS
- ✅ Test 3: Guard Verification - PASS
- ✅ Test 4: Bootstrap Verification - PASS

---

## 📋 Detailed Steps

### Phase B: Hardening

#### 1. Setup Git Alias

```bash
git config --global alias.clean-safe '!zsh ~/02luka/tools/safe_git_clean.zsh'
```

**Verify:**
```bash
git clean-safe -n
```

#### 2. Enable CI Workflow

**If using GitHub:**
- Push `.github/workflows/workspace_guard.yml` to repository
- Workflow will automatically run on PR/Push
- Check Actions tab to verify

**If using other CI:**
- Adapt `.github/workflows/workspace_guard.yml` to your CI system
- Run `zsh tools/guard_workspace_inside_repo.zsh` in CI pipeline

#### 3. Team Communication

**Share:**
- `g/docs/TEAM_ANNOUNCEMENT_workspace_split.md` - Team announcement
- `g/docs/WORKSPACE_SPLIT_README.md` - Quick reference

---

### Phase C: Ops Confidence

#### Test 1: Safe Clean Dry-Run

```bash
zsh tools/safe_git_clean.zsh -n
```

**Expected:** Shows ignored files only, no workspace data

#### Test 2: Simulate Pre-commit Failure

```bash
# Create violation
mkdir -p test_violation/g/data
echo "test" > test_violation/g/data/test.txt

# Try to commit (should fail)
git add test_violation/
git commit -m "test violation"

# Expected: Pre-commit hook fails with error

# Cleanup
rm -rf test_violation/
git reset HEAD~1 2>/dev/null || true
```

#### Test 3: Guard Script Verification

```bash
# Create violations
mkdir -p g/data/test g/telemetry/test

# Run guard (should fail)
zsh tools/guard_workspace_inside_repo.zsh

# Expected: FAIL messages

# Cleanup
rm -rf g/data/test g/telemetry/test
```

#### Test 4: Bootstrap Verification

```bash
# Remove symlinks
rm -f g/data g/telemetry g/followup mls/ledger bridge/processed

# Run bootstrap
zsh tools/bootstrap_workspace.zsh

# Verify symlinks
for path in g/data g/telemetry g/followup mls/ledger bridge/processed; do
  readlink "$path"
done

# Verify guard passes
zsh tools/guard_workspace_inside_repo.zsh
```

---

## ✅ Success Criteria

### Phase B Complete:
- ✅ Git alias 'clean-safe' works
- ✅ CI workflow enabled (or ready)
- ✅ Team announcement shared

### Phase C Complete:
- ✅ All 4 tests pass
- ✅ Safe clean works correctly
- ✅ Pre-commit blocks violations
- ✅ Guard script catches issues
- ✅ Bootstrap creates correct symlinks

---

## 📝 Notes

- **Phase B:** Can be done in parallel with Phase C
- **Phase C:** Should be done after Phase B (to verify everything works)
- **CI:** Enable on GitHub after pushing workflow file
- **Team:** Share announcement before enforcing rules

---

**Status:** Scripts ready, awaiting execution
