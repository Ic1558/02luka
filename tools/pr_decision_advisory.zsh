#!/usr/bin/env zsh
# tools/pr_decision_advisory.zsh
# PR Decision Advisory Tool (advisory-only, no auto-merge)
# Implements PR_MANAGEMENT_DECISION_FRAMEWORK_v1.md

set -euo pipefail

# Usage: pr-check [PR_NUMBER...]
# If no number given, analyzes all open PRs

LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
FRAMEWORK="$LUKA_SOT/g/docs/PR_MANAGEMENT_DECISION_FRAMEWORK_v1.md"

if [[ ! -f "$FRAMEWORK" ]]; then
  echo "❌ Framework not found: $FRAMEWORK"
  exit 1
fi

PR_NUMS=("$@")
if [[ ${#PR_NUMS[@]} -eq 0 ]]; then
  # Get all open PRs
  pr_list=$(gh pr list --state open --json number --jq '.[].number' 2>/dev/null || echo "")
  if [[ -z "$pr_list" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ℹ️  No open PRs found"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
  fi
  PR_NUMS=(${(@f)pr_list})
fi

for pr_num in "${PR_NUMS[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 PR #$pr_num Analysis"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Get PR metadata (with safer parsing)
  pr_data=$(gh pr view "$pr_num" --json title,state,mergeable,files,headRefName,baseRefName 2>/dev/null)
  if [[ $? -ne 0 || -z "$pr_data" ]]; then
    echo "❌ Failed to fetch PR #$pr_num (not found or no access)"
    echo ""
    continue
  fi

  # Parse with error handling
  title=$(echo "$pr_data" | jq -r '.title' 2>/dev/null || echo "[Title unavailable]")
  mergeable=$(echo "$pr_data" | jq -r '.mergeable' 2>/dev/null || echo "UNKNOWN")
  files=$(echo "$pr_data" | jq -r '.files[].path' 2>/dev/null || echo "")

  echo "📋 Title: $title"
  echo "🌿 Branch: $(echo "$pr_data" | jq -r '.headRefName') → $(echo "$pr_data" | jq -r '.baseRefName')"
  echo ""

  # GATE A: Classify PR
  echo "🚪 GATE A: Zone Classification"

  zone="UNKNOWN"
  # Check highest priority zones first
  if echo "$files" | grep -qE '^g/docs/(GOVERNANCE|AI_OP_001)'; then
    zone="GOVERNANCE"
  elif echo "$files" | grep -qE '^(bridge/core|core/)'; then
    zone="LOCKED_CORE"
  elif echo "$files" | grep -qE '^(hub/index\.json|hub/README\.md)'; then
    zone="AUTO_GENERATED"
  elif echo "$files" | grep -qE '^(g/docs|g/reports|g/manuals|personas)'; then
    # Include personas/ as DOCS zone
    zone="DOCS"
  elif echo "$files" | grep -qE '^(tools|tests|apps)'; then
    zone="OPEN"
  fi

  echo "  Zone: $zone"
  echo ""

  # GATE B: Dependency check
  echo "🚪 GATE B: Dependency Order"

  # Check if other open PRs might block this
  open_prs=$(gh pr list --state open --json number,title,files 2>/dev/null | jq -c '.[]')
  blockers=()

  while IFS= read -r other_pr; do
    [[ -z "$other_pr" ]] && continue
    other_num=$(echo "$other_pr" | jq -r '.number')
    [[ "$other_num" == "$pr_num" ]] && continue

    other_files=$(echo "$other_pr" | jq -r '.files[].path')
    if echo "$other_files" | grep -qE '^g/docs/(GOVERNANCE|AI_OP_001)'; then
      if [[ "$zone" != "GOVERNANCE" ]]; then
        blockers+=("PR #$other_num (governance should merge first)")
      fi
    fi
  done <<< "$open_prs"

  if [[ ${#blockers[@]} -gt 0 ]]; then
    echo "  ⚠️  Blocked by:"
    for blocker in "${blockers[@]}"; do
      echo "     - $blocker"
    done
  else
    echo "  ✅ No dependency blockers"
  fi
  echo ""

  # GATE C: Mergeability
  echo "🚪 GATE C: Mergeability Status"
  echo "  Mergeable: $mergeable"

  # Check branch divergence
  commits_data=$(gh pr view "$pr_num" --json commits 2>/dev/null)
  if [[ -n "$commits_data" ]]; then
    divergence=$(echo "$commits_data" | jq -r '.commits | length')
    echo "  Commits: $divergence"
  fi

  # Check for conflicts in auto-generated files
  if [[ "$mergeable" == "CONFLICTING" ]]; then
    conflict_auto_gen=$(echo "$files" | grep -E '(hub/index\.json|hub/README\.md)' || true)
    if [[ -n "$conflict_auto_gen" ]]; then
      echo "  🔧 Conflict in auto-generated files detected:"
      echo "$conflict_auto_gen" | sed 's/^/     - /'
    fi
  elif [[ "$mergeable" == "UNKNOWN" ]]; then
    echo "  ℹ️  Mergeable status unknown (PR may be closed/merged)"
  fi
  echo ""

  # OUTCOME: Recommendation
  echo "💡 RECOMMENDATION"

  if [[ ${#blockers[@]} -gt 0 ]]; then
    echo "  ⏸️  WAIT - Merge blockers first:"
    for blocker in "${blockers[@]}"; do
      echo "     - $blocker"
    done
  elif [[ "$mergeable" == "CONFLICTING" ]]; then
    if [[ -n "$conflict_auto_gen" ]]; then
      echo "  🔧 RESOLVE CONFLICTS (Policy: use origin/main for auto-generated files)"
      echo "     Files to resolve:"
      echo "$conflict_auto_gen" | sed 's/^/     - /'
      echo ""
      echo "     Commands:"
      echo "     gh pr checkout $pr_num"
      echo "     git pull origin main"
      echo "     git checkout origin/main -- hub/index.json  # Use main version"
      echo "     git add hub/index.json"
      echo "     git commit -m 'resolve: use origin/main for auto-generated hub/index.json'"
      echo "     git push"
    else
      echo "  ⚠️  BLOCK & ASK BOSS - Complex conflicts in $zone zone"
    fi
  elif [[ "$zone" == "GOVERNANCE" || "$zone" == "LOCKED_CORE" ]]; then
    echo "  ⚠️  BOSS APPROVAL REQUIRED - High-impact zone: $zone"
    echo "     After Boss approval: gh pr merge $pr_num --squash"
  elif [[ "$zone" == "DOCS" || "$zone" == "OPEN" ]]; then
    if [[ "$mergeable" == "MERGEABLE" ]]; then
      echo "  ✅ MERGE NOW - Safe zone, no conflicts"
      echo "     Command: gh pr merge $pr_num --squash"
    else
      echo "  ⏸️  REBASE - Update from main first"
      echo "     Commands:"
      echo "     gh pr checkout $pr_num"
      echo "     git pull origin main --rebase"
      echo "     git push --force-with-lease"
    fi
  else
    echo "  ❓ UNKNOWN - Manual review needed"
  fi

  echo ""
  echo "📊 Risk Level: $(
    case "$zone" in
      GOVERNANCE|LOCKED_CORE) echo "HIGH" ;;
      OPEN) echo "MEDIUM" ;;
      DOCS|AUTO_GENERATED) echo "LOW" ;;
      *) echo "UNKNOWN" ;;
    esac
  )"

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 Framework: $FRAMEWORK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
