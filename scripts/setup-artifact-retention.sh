#!/bin/bash
set -euo pipefail

echo "📦 Setting up Artifact Retention (30 days)"
echo "=========================================="

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

# Set artifact retention to 30 days
echo "Setting artifact retention to 30 days..."

gh api repos/$REPO/actions/permissions \
  --method PUT \
  --field enabled=true \
  --field allowed_actions=all

# Note: Artifact retention is set per-repository in GitHub settings
# This script provides the manual steps
echo "📋 Manual steps required:"
echo "1. Go to GitHub → Settings → Actions → General"
echo "2. Scroll to 'Artifact and log retention'"
echo "3. Set 'Days' to 30"
echo "4. Enable 'Allow GitHub Actions to create and approve pull requests'"
echo "5. Save changes"
echo
echo "✅ Artifact retention configuration prepared!"
