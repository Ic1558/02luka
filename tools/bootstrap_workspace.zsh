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

# Helper: readlink with fallback
readlink_safe() {
  local p="$1"
  if command -v readlink >/dev/null 2>&1; then
    readlink "$p"
  else
    # Fallback: python3 (pass the path as argv)
    /usr/bin/python3 - "$p" <<'PY'
import os,sys
p=sys.argv[1]
try:
    print(os.readlink(p))
except OSError:
    sys.exit(1)
PY
  fi
}

echo "=== Phase C Execute Tests ==="

# Test 1: Basic symlink creation and readlink
echo "Test 1: Basic symlink and readlink"
rm_safe -f g/data
mkdir_safe -p g/data
ln_safe -sfn /tmp g/data
echo "Link target of g/data:"
readlink_safe g/data

cat_safe /tmp/phase_c_test1.log 2>/dev/null || echo "(no log)"

# Test 2: Backup and restore symlink
echo "Test 2: Backup and restore symlink"
backup_target=$(readlink_safe g/data)
rm_safe -rf g/data
mkdir_safe -p g/data
ln_safe -sfn "$backup_target" g/data

# Test 3: Multiple symlink operations
echo "Test 3: Multiple symlink operations"
declare -A backups
for path in g/data g/telemetry g/followup mls/ledger bridge/processed; do
  rm_safe -f "$path"
  mkdir_safe -p "$path"
  ln_safe -sfn "/backup/$path" "$path"
  backups[$path]="/backup/$path"
done

# Test 4: Guard checks for symlinks
echo "Test 4: Guard checks for symlinks"
rm_safe -f g/data g/telemetry g/followup mls/ledger bridge/processed 2>/dev/null || true

if tools/guard_workspace_inside_repo.zsh | grep_safe -q "FAIL\|real directory"; then
  echo "Guard check failed"
else
  echo "All workspace guards passed"
fi | grep_safe -q "All workspace guards passed"

cat_safe /tmp/phase_c_test4.log || echo "(no log)"

echo "=== Phase C Execute Tests Complete ==="
