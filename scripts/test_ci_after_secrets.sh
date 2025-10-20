#!/bin/bash
# Test CI after GitHub secrets are configured

set -euo pipefail

echo "=== Testing CI After GitHub Secrets Configuration ==="
echo ""

# Check if gh CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated"
    echo "Run: gh auth login --with-token < .secrets/github_pat"
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Check if secrets are configured
echo ""
echo "Checking repository secrets..."
if gh secret list --repo Ic1558/02luka | grep -q "OPS_ATOMIC_URL"; then
    echo "✅ OPS_ATOMIC_URL secret found"
else
    echo "❌ OPS_ATOMIC_URL secret not found"
    echo "Configure at: https://github.com/Ic1558/02luka/settings/secrets/actions"
fi

if gh secret list --repo Ic1558/02luka | grep -q "OPS_ATOMIC_TOKEN"; then
    echo "✅ OPS_ATOMIC_TOKEN secret found"
else
    echo "❌ OPS_ATOMIC_TOKEN secret not found"
    echo "Configure at: https://github.com/Ic1558/02luka/settings/secrets/actions"
fi

# Check if variables are configured
echo ""
echo "Checking repository variables..."
if gh variable list --repo Ic1558/02luka | grep -q "OPS_GATE_OVERRIDE"; then
    echo "✅ OPS_GATE_OVERRIDE variable found"
else
    echo "❌ OPS_GATE_OVERRIDE variable not found"
    echo "Configure at: https://github.com/Ic1558/02luka/settings/variables/actions"
fi

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

# Trigger CI if everything looks good
echo ""
echo "Triggering CI workflow..."
if gh workflow run ci.yml --repo Ic1558/02luka; then
    echo "✅ CI workflow triggered successfully"
    echo ""
    echo "Watch the run with:"
    echo "gh run watch --repo Ic1558/02luka"
else
    echo "❌ Failed to trigger CI workflow"
fi

echo ""
echo "=== Test Complete ==="
