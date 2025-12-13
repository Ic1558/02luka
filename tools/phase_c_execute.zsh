#!/usr/bin/env zsh
set -euo pipefail

# Ensure a sane PATH even in constrained shells (Cursor/launchd/etc.)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- helpers (PATH-safe core utils)
rm_safe() { /bin/rm "$@"; }
mkdir_safe() { /bin/mkdir "$@"; }
ln_safe() { /bin/ln "$@"; }
grep_safe() { /usr/bin/grep "$@"; }
cat_safe() { /bin/cat "$@"; }

# Phase C: Operations Confidence Tests
# Execute all tests from phase_c_ops_confidence.md


REPO="$HOME/02luka"
cd "$REPO"

# --- helpers (PATH-safe)
readlink_safe() {
  local p="$1"
  if [[ -x /usr/bin/readlink ]]; then
    /usr/bin/readlink "$p"
    return $?
  fi
  # Fallback: python3 (pass the path as argv)
  /usr/bin/python3 - "$p" <<'PY'
import os,sys
p=sys.argv[1]
print(os.readlink(p))
PY
}

echo "=========================================="
echo "Phase C: Operations Confidence Tests"
echo "=========================================="
echo ""

# Test results
test1_passed=0
test2_passed=0
test3_passed=0
test4_passed=0

# Test 1: Safe Clean Dry-Run
echo "=== Test 1: Safe Clean Dry-Run ==="
if zsh tools/safe_git_clean.zsh -n > /tmp/phase_c_test1.log 2>&1; then
  echo "✅ PASS: Safe clean dry-run completed"
  echo "   Output saved to /tmp/phase_c_test1.log"
  test1_passed=1
else
  echo "❌ FAIL: Safe clean dry-run failed"
  cat_safe /tmp/phase_c_test1.log
fi
echo ""

# Test 2: Simulate Pre-commit Failure
echo "=== Test 2: Simulate Pre-commit Failure ==="
echo "   Creating violation (replace symlink with real directory)..."
# Backup current symlink target
if [[ -L g/data ]]; then
  backup_target=$(readlink_safe g/data)

  # Remove symlink and create real directory (violation)
  rm_safe -f g/data
  mkdir_safe -p g/data
  echo "test" > g/data/test.txt

  # Try to commit (should fail due to pre-commit)
  tmp_out="/tmp/phase_c_test2_commit.log"
  set +e
  git add g/data/ >/dev/null 2>&1
  git commit -m "test violation" >"$tmp_out" 2>&1
  commit_rc=$?
  set -e

  if [[ $commit_rc -ne 0 ]] && grep_safe -Eq "FAIL|must be symlink|real directory|Workspace guard checks failed" "$tmp_out"; then
    echo "✅ PASS: Pre-commit hook blocked invalid commit"
    test2_passed=1
  else
    echo "❌ FAIL: Pre-commit did NOT block as expected"
    echo "   See: $tmp_out"
  fi

  # Cleanup: restore symlink
  rm_safe -rf g/data
  ln_safe -sfn "$backup_target" g/data
  # Ensure index is clean even if commit was blocked
  git reset -q g/data >/dev/null 2>&1 || true
else
  echo "⚠️  SKIP: g/data is not a symlink (cannot test)"
fi
echo ""

# Test 3: Guard Script Verification
echo "=== Test 3: Guard Script Verification ==="
echo "   Creating violations (replace symlinks with real directories)..."
# Backup symlinks
declare -A backups
for path in g/data g/telemetry; do
  if [[ -L "$path" ]]; then
    backups["$path"]=$(readlink_safe "$path")
    # Remove symlink and create real directory (violation)
    rm_safe -f "$path"
    mkdir_safe -p "$path"
    echo "test" > "$path/test.txt"
  fi
done

# Run guard (should fail)
if zsh tools/guard_workspace_inside_repo.zsh 2>&1 | grep_safe -q "FAIL\|real directory"; then
  echo "✅ PASS: Guard script detected violations"
  test3_passed=1
else
  echo "⚠️  WARN: Guard script may not have detected violations"
fi

# Cleanup: restore symlinks
for path in "${(@k)backups}"; do
  rm_safe -rf "$path"
  ln_safe -sfn "${backups[$path]}" "$path"
done
unset backups
echo ""

# Test 4: Verify Symlinks After Bootstrap
echo "=== Test 4: Bootstrap Verification ==="
echo "   Removing symlinks (simulating fresh setup)..."
rm_safe -f g/data g/telemetry g/followup mls/ledger bridge/processed 2>/dev/null || true

echo "   Running bootstrap..."
if zsh tools/bootstrap_workspace.zsh > /tmp/phase_c_test4.log 2>&1; then
  echo "   Verifying symlinks..."
  all_symlinks=1
  for path in g/data g/telemetry g/followup mls/ledger bridge/processed; do
    if [[ -L "$path" ]]; then
      target=$(readlink_safe "$path")
      if [[ "$target" == *"02luka_ws"* ]]; then
        echo "   ✅ $path -> $target"
      else
        echo "   ⚠️  $path points to wrong location"
        all_symlinks=0
      fi
    else
      echo "   ❌ $path is NOT a symlink"
      all_symlinks=0
    fi
  done
  
  if [[ $all_symlinks -eq 1 ]]; then
    echo "   ✅ All paths are correct symlinks"
    test4_passed=1
  fi
  
  # Verify guard passes
  if zsh tools/guard_workspace_inside_repo.zsh 2>&1 | grep_safe -q "All workspace guards passed"; then
    echo "   ✅ Guard script passes"
  else
    echo "   ⚠️  Guard script may have issues"
  fi
else
  echo "   ❌ Bootstrap failed"
  cat_safe /tmp/phase_c_test4.log
fi
echo ""

# Summary
echo "=========================================="
echo "Phase C Test Results"
echo "=========================================="
echo ""
echo "Test 1 (Safe Clean Dry-Run):     $([ $test1_passed -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "Test 2 (Pre-commit Failure):     $([ $test2_passed -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "Test 3 (Guard Verification):     $([ $test3_passed -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "Test 4 (Bootstrap Verification):  $([ $test4_passed -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo ""

all_passed=$((test1_passed + test2_passed + test3_passed + test4_passed))
if [[ $all_passed -eq 4 ]]; then
  echo "✅✅✅ All tests passed! System is hardened. ✅✅✅"
  exit 0
elif [[ $all_passed -ge 2 ]]; then
  echo "⚠️  Some tests passed. Review failures above."
  exit 1
else
  echo "❌ Most tests failed. System may not be properly hardened."
  exit 1
fi
