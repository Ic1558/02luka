#!/usr/bin/env zsh
set -eu
setopt extended_glob
setopt null_glob  # Don't error on unmatched globs

# File Structure Organization Migration Script
# Purpose: Safely migrate files to function-first structure
# Usage: ./fsorg_migrate.zsh [--apply]
#   - Without --apply: Dry-run mode (shows what would be done)
#   - With --apply: Actually moves files using git mv (preserves history)

# Default: dry-run (safe mode)
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

REPO="$HOME/02luka"
cd "$REPO"

# Helper functions
say() { print -r -- "$@"; }
doit() { 
  if (( APPLY )); then 
    eval "$1" || { say "❌ Error executing: $1"; exit 1; }
  else 
    say "[dry-run] $1"
    return 0  # Always succeed in dry-run
  fi
}

say "=== File Structure Organization Migration ==="
say "Mode: $([ $APPLY -eq 1 ] && echo 'APPLY (will move files)' || echo 'DRY-RUN (safe preview)')"
say ""

# Step 1: Create directory structure according to Guidelines
say "== Step 1: Creating directory structure =="
doit 'mkdir -p g/reports/{phase5_governance,phase6_paula,system,sessions,ci}'
doit 'mkdir -p mls/{paula/intel,memory/adaptive,ledger,schema,status}'
doit 'mkdir -p bridge/{inbox/{CLC,RND,ENTRY},outbox/{SYSTEM,LOGS},memory/{inbox,outbox}}'
say "✅ Directory structure created"
say ""

# Step 2: Define file migration lists
# Reports — Phase 5: Governance & Reporting
say "== Step 2: Phase 5 Governance Reports =="
mv_list_phase5=(
  "g/reports/feature_phase5_governance_reporting_SPEC.md g/reports/phase5_governance/"
  "g/reports/feature_phase5_governance_reporting_PLAN.md g/reports/phase5_governance/"
  "g/reports/DEPLOYMENT_CERTIFICATE_phase5_*.md g/reports/phase5_governance/"
  "g/reports/code_review_phase5*.md g/reports/phase5_governance/"
  "g/reports/governance_audit_*.md g/reports/phase5_governance/"
  "g/reports/PRODUCTION_READINESS_phase5_*.md g/reports/phase5_governance/"
  "g/reports/SYSTEM_STATUS_phase5_*.md g/reports/phase5_governance/"
)

# Reports — Phase 6: Paula Data Intelligence
say "== Step 3: Phase 6 Paula Reports =="
mv_list_phase6=(
  "g/reports/feature_phase6_1_paula_intel_SPEC.md g/reports/phase6_paula/"
  "g/reports/feature_phase6_1_paula_intel_PLAN.md g/reports/phase6_paula/"
  "g/reports/DEPLOYMENT_CERTIFICATE_phase5_6.1_*.md g/reports/phase6_paula/"
  "g/reports/DEPLOYMENT_SUMMARY_phase5_6.1_*.md g/reports/phase6_paula/"
  "g/reports/code_review_phase6_1*.md g/reports/phase6_paula/"
)

# System reports (system-wide, not phase-specific)
say "== Step 4: System Reports =="
mv_list_system=(
  "g/reports/undeployed_scan_*.md g/reports/system/"
  "g/reports/system_governance_WEEKLY_*.md g/reports/system/"
  "g/reports/FINAL_SYSTEM_STATUS_*.md g/reports/system/"
  "g/reports/PRODUCTION_READINESS_SUMMARY_*.md g/reports/system/"
  "g/reports/code_review_20251112_cls.md g/reports/system/"
  "g/reports/feature_complete_phase5_6.1_deployment_PLAN.md g/reports/system/"
  "g/reports/feature_quick_deploy_phase5_6.1_PLAN.md g/reports/system/"
  "g/reports/feature_file_structure_organization_*.md g/reports/system/"
  "g/reports/FILE_STRUCTURE_MIGRATION_GUIDE.md g/reports/system/"
)

# Step 3: Migration function using git mv (preserves history)
# Supports glob patterns and multiple files
move_group() {
  local src dst count=0 f
  for spec in "$@"; do
    src="${spec% *}"      # Everything before last space
    dst="${spec##* }"      # Everything after last space
    
    # Expand glob pattern - use extended_glob for wildcards
    for f in ${~src}; do
      # Skip if pattern didn't expand (file doesn't exist)
      [[ "$f" == "$src" ]] && [[ "$src" == *"*"* ]] && continue
      [[ -f "$f" ]] || continue
      
      # Skip if already in target directory
      [[ "$(dirname "$f")" == "$dst" ]] && continue
      
      if (( APPLY )); then
        # Check if file is tracked by git
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
          # Tracked file - use git mv
          git mv "$f" "$dst" || { say "❌ Failed to move: $f"; continue; }
        else
          # Untracked file - use regular mv then git add
          mv "$f" "$dst" || { say "❌ Failed to move: $f"; continue; }
          git add "$dst" || { say "⚠️  Warning: Could not add to git: $dst"; }
        fi
      else
        # Check if file is tracked
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
          say "[dry-run] git mv \"$f\" \"$dst\""
        else
          say "[dry-run] mv \"$f\" \"$dst\" && git add \"$dst\""
        fi
      fi
      ((count++))
    done
  done
  say "  → Would move $count file(s)"
}

# Execute migrations
say "Moving Phase 5 files..."
move_group "${mv_list_phase5[@]}" || true
say ""
say "Moving Phase 6 files..."
move_group "${mv_list_phase6[@]}" || true
say ""
say "Moving System files..."
move_group "${mv_list_system[@]}" || true
say ""

# Step 4: Verify MLS structure (data files should already be organized)
say "== Step 5: Verifying MLS structure =="
if [[ -d "mls/paula/intel" ]]; then
  say "✅ MLS Paula structure exists"
  # Note: We don't move generated data files - they're already in correct location
  # Only organize if they're in wrong place (not needed for current structure)
fi
say ""

# Step 5: Update .gitignore to prevent committing generated artifacts
say "== Step 6: Updating .gitignore =="
gitignore_updates=()

# Check and add rules for logs (if not present)
if ! grep -q '^logs/' .gitignore 2>/dev/null; then
  gitignore_updates+=("logs/")
fi

# Check and add rules for generated MLS data (if not present)
# Note: We want to commit ledger and schema, but not generated intel data
if ! grep -q '^mls/paula/intel/.*\.json$' .gitignore 2>/dev/null; then
  gitignore_updates+=("mls/paula/intel/*.json")
fi

if ! grep -q '^mls/memory/adaptive/.*\.json$' .gitignore 2>/dev/null; then
  gitignore_updates+=("mls/memory/adaptive/*.json")
fi

if (( ${#gitignore_updates[@]} > 0 )); then
  say "  Adding .gitignore rules:"
  for rule in "${gitignore_updates[@]}"; do
    doit "echo '$rule' >> .gitignore"
    say "    + $rule"
  done
else
  say "  ✅ .gitignore already has required rules"
fi
say ""

# Step 6: Summary and next steps
say "=== Migration Summary ==="
if (( APPLY )); then
  say "✅ Apply mode: Files moved using git mv (history preserved)"
  say ""
  say "Next steps:"
  say "  1. Review changes: git status"
  say "  2. Verify file locations"
  say "  3. Commit: git commit -m 'chore(fsorg): migrate reports into function-first structure'"
  say "  4. Push: git push origin main"
  say ""
  say "⚠️  Important: Check these after migration:"
  say "  - LaunchAgents: Verify tool paths still work (tools/ unchanged)"
  say "  - CI/Workflows: Update report paths if they reference old locations"
  say "  - Scripts: Update any hard-coded report paths"
else
  say "✅ Dry-run complete - no files were moved"
  say ""
  say "To apply changes, run:"
  say "  ~/02luka/tools/fsorg_migrate.zsh --apply"
  say ""
  say "Review the [dry-run] commands above to see what will be moved."
fi

say ""
say "=== Done ==="
