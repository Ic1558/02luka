#!/usr/bin/env zsh
# tools/pre-push-hook.zsh
# Pre-push hook: Block direct push to origin/main (enforce PR-only workflow)
# Install: zsh tools/install_pre_push_hook.zsh
# Override: ALLOW_PUSH_MAIN=1 git push origin main

set -euo pipefail

# Read stdin from git push
while read local_ref local_sha remote_ref remote_sha; do
  # Skip if empty
  [[ -z "$remote_ref" ]] && continue
  
  # Check if pushing to origin/main
  if [[ "$remote_ref" == "refs/heads/main" ]]; then
    # Extract remote name (usually "origin")
    remote_name=$(echo "$remote_ref" | cut -d'/' -f1 || echo "")
    
    # Check if this is origin/main
    if [[ "$remote_name" == "origin" ]] || [[ "$remote_ref" == "refs/heads/main" ]]; then
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
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      exit 1
    fi
  fi
done

exit 0
