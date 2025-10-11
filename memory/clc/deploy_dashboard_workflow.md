# Dashboard Deployment Workflow

**Agent:** CLC
**Type:** Deploy Operation
**Target:** dashboard.theedges.work
**Created:** 2025-10-11

## Workflow Steps

### 1. Pre-flight Checks
```bash
# Verify repo health
bash ./.codex/preflight.sh

# Check Cloudflare credentials
echo "CLOUDFLARE_API_TOKEN: ${CLOUDFLARE_API_TOKEN:0:10}..."
echo "CLOUDFLARE_ACCOUNT_ID: ${CLOUDFLARE_ACCOUNT_ID}"
```

### 2. Build Dashboard
```bash
# Build UI assets
npm run build --prefix boss-ui
```

### 3. Deploy to Cloudflare
```bash
# Run deployment script
bash ./scripts/deploy_dashboard.sh
```

### 4. Verification
```bash
# Health check
curl -s https://dashboard.theedges.work/healthz | jq .

# Manual verification
open https://dashboard.theedges.work
```

### 5. Post-Deploy
```bash
# Review deployment report
ls -lt g/reports/deploy/ | head -1

# Commit deployment record
git add g/reports/deploy/
git commit -m "docs: add dashboard deployment report $(date +%Y%m%d_%H%M)"
```

## Environment Variables Required

```bash
export CLOUDFLARE_API_TOKEN="EaHaZw9Y1PrIPlOGXbb7BzY2XROjpAI-zQPBU69w"
export CLOUDFLARE_ACCOUNT_ID="2cf1e9eb0dfd2477af7b0bea5bcc53d6"
```

## Quick Deploy Command

```bash
# One-line deploy (with env vars set)
bash ./.codex/preflight.sh && bash ./scripts/deploy_dashboard.sh
```

## Rollback Procedure

If deployment fails:

```bash
# 1. Check deployment report
cat g/reports/deploy/dashboard_*.md | tail -50

# 2. Revert to previous version
git log --oneline | grep dashboard
git revert <commit-hash>

# 3. Redeploy
bash ./scripts/deploy_dashboard.sh
```

## Monitoring

- **Dashboard:** https://dashboard.theedges.work
- **Health:** https://dashboard.theedges.work/healthz
- **Cloudflare:** https://dash.cloudflare.com/
- **Reports:** `g/reports/deploy/dashboard_*.md`

## Success Criteria

✅ Build completes without errors
✅ Cloudflare deployment successful
✅ Health check returns 200 OK
✅ Deployment report generated
✅ Dashboard accessible in browser

## Troubleshooting

### Build Fails
```bash
# Check boss-ui dependencies
npm install --prefix boss-ui

# Check build logs
npm run build --prefix boss-ui 2>&1 | tee /tmp/build.log
```

### Deploy Fails
```bash
# Check wrangler auth
npx wrangler whoami

# Re-login if needed
npx wrangler login
```

### Health Check Fails
```bash
# Wait for Cloudflare propagation
sleep 10

# Manual check
curl -v https://dashboard.theedges.work/healthz

# Check Cloudflare logs
npx wrangler pages deployment list --project-name theedges-dashboard
```
