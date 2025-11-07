#!/bin/bash
# Creates resolution patches for all conflicting branches
# Useful when direct push is not possible

set -euo pipefail

PATCH_DIR="conflict_resolution_patches"
mkdir -p "${PATCH_DIR}"

echo "Creating Resolution Patches"
echo "============================"
echo ""

BRANCHES=(
  "codex/add-user-authentication-feature"
  "codex/add-user-authentication-feature-hhs830"
  "codex/add-user-authentication-feature-not1zo"
  "codex/add-user-authentication-feature-yiytty"
)

create_resolution_patch() {
  local branch="$1"
  local patch_name="${branch//\//-}.patch"
  local patch_file="${PATCH_DIR}/${patch_name}"

  echo "Processing: ${branch}"

  # Create a temporary branch to work in
  local temp_branch="temp-resolve-${RANDOM}"

  # Checkout branch
  if ! git checkout "${branch}" 2>/dev/null; then
    git checkout -b "${branch}" "origin/${branch}"
  fi

  # Create temp branch
  git checkout -b "${temp_branch}"

  # Merge with strategy
  if git merge origin/main --no-commit --no-ff 2>&1 | grep -q "Automatic merge failed"; then
    # Resolve conflicts
    [ -f boss-api/server.cjs ] && git rm boss-api/server.cjs
    git status | grep -q "scripts/smoke.sh" && git checkout --theirs scripts/smoke.sh && git add scripts/smoke.sh

    # Commit resolution
    git commit -m "Resolve merge conflicts with main"

    # Create patch from the resolution
    git format-patch -1 --stdout > "${patch_file}"

    echo "  ✓ Patch created: ${patch_file}"
  else
    echo "  ℹ No conflicts detected"
    git merge --abort 2>/dev/null || true
  fi

  # Cleanup
  git checkout "${branch}"
  git branch -D "${temp_branch}" 2>/dev/null || true

  echo ""
}

# Generate patches
for branch in "${BRANCHES[@]}"; do
  create_resolution_patch "${branch}"
done

# Create README for patches
cat > "${PATCH_DIR}/README.md" <<'EOF'
# Conflict Resolution Patches

This directory contains patches to resolve merge conflicts for each problematic branch.

## How to Apply

For each branch, apply the corresponding patch:

```bash
# Example for first branch
git checkout codex/add-user-authentication-feature
git merge origin/main  # This will show conflicts

# Apply the patch
git apply conflict_resolution_patches/codex-add-user-authentication-feature.patch

# Or use:
git am < conflict_resolution_patches/codex-add-user-authentication-feature.patch

# Then push
git push origin codex/add-user-authentication-feature
```

## Patches Included

1. `codex-add-user-authentication-feature.patch`
2. `codex-add-user-authentication-feature-hhs830.patch`
3. `codex-add-user-authentication-feature-not1zo.patch`
4. `codex-add-user-authentication-feature-yiytty.patch`

Each patch:
- Removes `boss-api/server.cjs` (accepts deletion)
- Uses main's version of `scripts/smoke.sh`
- Commits the resolution

## Alternative: Manual Application

If patches don't apply cleanly:

```bash
git checkout <branch>
git merge origin/main
git rm boss-api/server.cjs
git checkout --theirs scripts/smoke.sh
git add scripts/smoke.sh
git commit -m "Resolve merge conflicts with main"
git push origin <branch>
```
EOF

echo "=========================================="
echo "✓ Patch creation complete!"
echo "  Patches saved to: ${PATCH_DIR}/"
echo "  See ${PATCH_DIR}/README.md for usage"
echo ""
