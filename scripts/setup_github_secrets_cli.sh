#!/bin/bash
# CLI Setup for GitHub Secrets and Variables

set -euo pipefail

echo "=== GitHub Secrets CLI Setup ==="
echo ""

# Check if gh CLI is available
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI not found. Install with:"
    echo "   brew install gh"
    echo "   or visit: https://cli.github.com/"
    exit 1
fi

echo "✅ GitHub CLI found"

# Check if we have a fine-grained token
if [ -f ".secrets/github_fine_grained_pat" ]; then
    echo "✅ Fine-grained PAT found"
    FINE_GRAINED_PAT=$(cat .secrets/github_fine_grained_pat)
else
    echo "❌ Fine-grained PAT not found"
    echo ""
    echo "Please create a Fine-Grained PAT:"
    echo "1. Go to: https://github.com/settings/personal-access-tokens"
    echo "2. Click 'Fine-grained personal access token' → 'Generate new'"
    echo "3. Repository access: Only selected → select Ic1558/02luka"
    echo "4. Permissions: Actions (Read/Write), Secrets (Read/Write), Variables (Read/Write), Contents (Read/Write), Metadata (Read-only)"
    echo "5. Generate token and save to .secrets/github_fine_grained_pat"
    echo ""
    read -p "Press Enter when you have the token ready..."
    
    if [ -f ".secrets/github_fine_grained_pat" ]; then
        FINE_GRAINED_PAT=$(cat .secrets/github_fine_grained_pat)
    else
        echo "❌ Still no fine-grained PAT found. Exiting."
        exit 1
    fi
fi

# Authenticate with fine-grained token
echo ""
echo "Authenticating with fine-grained PAT..."
if echo "$FINE_GRAINED_PAT" | gh auth login --hostname github.com --with-token; then
    echo "✅ Authentication successful"
else
    echo "❌ Authentication failed"
    exit 1
fi

# Verify authentication
echo ""
echo "Verifying authentication..."
gh auth status

# Configure secrets
echo ""
echo "Configuring repository secrets..."
if echo "https://boss-api.ittipong-c.workers.dev" | gh secret set OPS_ATOMIC_URL --repo Ic1558/02luka; then
    echo "✅ OPS_ATOMIC_URL secret set"
else
    echo "❌ Failed to set OPS_ATOMIC_URL secret"
fi

if echo "NA" | gh secret set OPS_ATOMIC_TOKEN --repo Ic1558/02luka; then
    echo "✅ OPS_ATOMIC_TOKEN secret set"
else
    echo "❌ Failed to set OPS_ATOMIC_TOKEN secret"
fi

# Configure variables
echo ""
echo "Configuring repository variables..."
if gh variable set OPS_GATE_OVERRIDE --repo Ic1558/02luka --body "0"; then
    echo "✅ OPS_GATE_OVERRIDE variable set"
else
    echo "❌ Failed to set OPS_GATE_OVERRIDE variable"
fi

# Verify configuration
echo ""
echo "Verifying configuration..."
echo "Secrets:"
gh secret list --repo Ic1558/02luka

echo ""
echo "Variables:"
gh variable list --repo Ic1558/02luka

# Test worker endpoints
echo ""
echo "Testing worker endpoints..."
if curl -s https://boss-api.ittipong-c.workers.dev/healthz >/dev/null; then
    echo "✅ Worker healthz endpoint responding"
else
    echo "❌ Worker healthz endpoint not responding"
fi

if curl -s https://boss-api.ittipong-c.workers.dev/api/reports/summary >/dev/null; then
    echo "✅ Worker summary endpoint responding"
else
    echo "❌ Worker summary endpoint not responding"
fi

# Trigger CI
echo ""
echo "Triggering CI workflow..."
if gh workflow run ci.yml --repo Ic1558/02luka; then
    echo "✅ CI workflow triggered successfully"
    echo ""
    echo "Watch the run with:"
    echo "gh run watch --repo Ic1558/02luka"
    echo ""
    echo "Or check recent runs:"
    echo "gh run list --repo Ic1558/02luka --limit 5"
else
    echo "❌ Failed to trigger CI workflow"
fi

echo ""
echo "=== CLI Setup Complete ==="
