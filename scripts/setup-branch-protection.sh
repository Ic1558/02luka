#!/bin/bash
set -euo pipefail

echo "🔒 Setting up Branch Protection for main branch"
echo "=============================================="

# Check if gh CLI is available
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) not found. Please install it first:"
    echo "   brew install gh  # macOS"
    echo "   apt install gh   # Ubuntu"
    echo "   Or download from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub CLI. Please run:"
    echo "   gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Repository: $REPO"

# Create branch protection rule
echo "Creating branch protection rule for main branch..."

gh api repos/$REPO/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["Validate structure (Option C)","Daily Proof"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":false}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false

echo "✅ Branch protection rule created successfully!"
echo
echo "📋 Protection settings:"
echo "├── Require PR reviews: ✅ (1 approval required)"
echo "├── Require status checks: ✅ (Validate structure + Daily Proof)"
echo "├── Require up-to-date branches: ✅"
echo "├── Enforce admins: ✅"
echo "├── Allow force pushes: ❌"
echo "└── Allow deletions: ❌"
echo
echo "🎉 Branch protection is now active!"
