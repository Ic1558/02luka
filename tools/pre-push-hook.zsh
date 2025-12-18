#!/usr/bin/env zsh
# tools/pre-push-hook.zsh
# Pre-push hook: Block direct push to origin/main (enforce PR-only workflow)
# Install: zsh tools/install_pre_push_hook.zsh
# Override: ALLOW_PUSH_MAIN=1 git push origin main
#
# Git pre-push hook receives:
#   $1 = remote_name (e.g., "origin")
#   $2 = remote_url (e.g., "git@github.com:user/repo.git")
#   stdin = refspecs: "local_ref local_sha remote_ref remote_sha" per line
#
# Test without pushing: git push --dry-run origin HEAD:main

set -euo pipefail

# Get remote name from $1 (NOT from stdin)
remote_name="${1:-}"
remote_url="${2:-}"

# Read refspecs from stdin
while read local_ref local_sha remote_ref remote_sha; do
  # Skip if empty
  [[ -z "$remote_ref" ]] && continue
  
  # Check if pushing to main branch
  if [[ "$remote_ref" == "refs/heads/main" ]]; then
    # Check if this is a push to origin (the protected remote)
    if [[ "$remote_name" == "origin" ]]; then
      # Allow override for Boss
      if [[ "${ALLOW_PUSH_MAIN:-}" == "1" ]]; then
        echo "⚠️  ALLOW_PUSH_MAIN=1 detected - allowing push to origin/main (Boss override)"
        continue
      fi
      
      # Block the push
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "❌ BLOCKED: Direct push to origin/main is forbidden"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "Policy: main branch accepts changes via PR only."
      echo ""
      echo "To push this change:"
      echo "  1. Create a branch: git checkout -b feat/your-feature"
      echo "  2. Push branch: git push -u origin feat/your-feature"
      echo "  3. Create PR: gh pr create"
      echo ""
      echo "Override (Boss only): ALLOW_PUSH_MAIN=1 git push origin main"
      echo ""
      echo "Test (dry-run): git push --dry-run origin HEAD:main"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      exit 1
    fi
  fi
done

exit 0
