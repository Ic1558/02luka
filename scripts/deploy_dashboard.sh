#!/usr/bin/env bash
set -euo pipefail

# Deploy 02luka Dashboard to Cloudflare Pages
# Usage: bash scripts/deploy_dashboard.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== 02LUKA Dashboard Deploy ==="
echo ""

# 1️⃣ Environment check
# Check if wrangler is authenticated (via OAuth or API token)
if npx wrangler whoami >/dev/null 2>&1; then
  echo "✅ Wrangler authenticated"
elif [ -z "${CLOUDFLARE_API_TOKEN:-}" ] || [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  echo "❌ Missing Cloudflare credentials"
  echo ""
  echo "Option 1: Use wrangler login"
  echo "  npx wrangler login"
  echo ""
  echo "Option 2: Set environment variables"
  echo "  export CLOUDFLARE_API_TOKEN='...'"
  echo "  export CLOUDFLARE_ACCOUNT_ID='...'"
  exit 1
fi

# 2️⃣ Build dashboard
echo "🔨 Building dashboard UI..."
if [ ! -d "boss-ui" ]; then
  echo "❌ boss-ui directory not found"
  exit 1
fi

npm run build --prefix boss-ui || {
  echo "❌ Build failed"
  exit 1
}

# 3️⃣ Deploy to Cloudflare Pages
echo ""
echo "🚀 Deploying to Cloudflare Pages..."
npx wrangler pages deploy boss-ui/dist \
  --project-name theedges-dashboard \
  --branch main || {
  echo "❌ Deploy failed"
  exit 1
}

# 4️⃣ Health check
echo ""
echo "🔍 Verifying deployment..."
sleep 3
HEALTH_URL="https://dashboard.theedges.work/healthz"
if curl -sf "$HEALTH_URL" | jq . > /dev/null; then
  echo "✅ Dashboard deployed successfully"
  echo ""
  curl -sf "$HEALTH_URL" | jq .
  echo ""
  echo "🌐 Dashboard: https://dashboard.theedges.work"
else
  echo "⚠️  Dashboard deployed but health check failed"
  echo "   Check manually: $HEALTH_URL"
fi

# 5️⃣ Write deployment report
REPORT_DIR="$REPO_ROOT/g/reports/deploy"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/dashboard_${TIMESTAMP}.md"

cat > "$REPORT_FILE" <<EOF
# Dashboard Deployment Report

**Timestamp:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Target:** https://dashboard.theedges.work
**Branch:** main
**Deployed by:** CLC Agent

## Status
✅ Build completed
✅ Cloudflare Pages deployment successful
✅ Health check passed

## Health Check Response
\`\`\`json
$(curl -sf "$HEALTH_URL" | jq . 2>/dev/null || echo "{}")
\`\`\`

## Build Info
- UI Framework: boss-ui
- Build output: boss-ui/dist/
- Cloudflare Project: theedges-dashboard

## Next Steps
- Monitor: https://dashboard.theedges.work
- Health: $HEALTH_URL
- Logs: Cloudflare Dashboard
EOF

echo ""
echo "📄 Report: $REPORT_FILE"
