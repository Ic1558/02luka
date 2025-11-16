# Deployment Guide - PD17 AI Formwork Calculator

## Prerequisites

1. **Cloudflare Account** - [Sign up](https://dash.cloudflare.com/sign-up)
2. **Domain** - www.theedges.work (configured in Cloudflare)
3. **Node.js** - v18+ installed
4. **Wrangler CLI** - `npm install -g wrangler`

## Step 1: Setup Cloudflare Workers Backend

### 1.1 Login to Cloudflare
```bash
wrangler login
```

### 1.2 Create KV Namespace
```bash
# Production namespace
wrangler kv:namespace create "CALCULATIONS_KV"

# Preview namespace (for testing)
wrangler kv:namespace create "CALCULATIONS_KV" --preview
```

Copy the IDs returned and update `workers/wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "CALCULATIONS_KV"
id = "YOUR_PRODUCTION_KV_ID_HERE"
preview_id = "YOUR_PREVIEW_KV_ID_HERE"
```

### 1.3 Update Account ID
Get your account ID from Cloudflare Dashboard URL:
`https://dash.cloudflare.com/YOUR_ACCOUNT_ID/...`

Update in `workers/wrangler.toml`:
```toml
account_id = "YOUR_ACCOUNT_ID_HERE"
```

### 1.4 Set API Keys (Secrets)

#### OpenRouter (Free Tier Available)
1. Sign up at [OpenRouter](https://openrouter.ai/)
2. Get API key from dashboard
3. Set secret:
```bash
cd workers
wrangler secret put OPENROUTER_API_KEY
# Paste your key when prompted
```

#### Kimi (Optional)
1. Sign up at [Moonshot AI](https://platform.moonshot.cn/)
2. Get API key
3. Set secret:
```bash
wrangler secret put KIMI_API_KEY
```

#### GLM-4 (Optional)
1. Sign up at [ChatGLM](https://open.bigmodel.cn/)
2. Get API key
3. Set secret:
```bash
wrangler secret put GLM_API_KEY
```

### 1.5 Deploy Worker
```bash
cd workers
wrangler deploy
```

Expected output:
```
✨ Successfully published your script to
 https://formwork-calculator-api.YOUR_SUBDOMAIN.workers.dev
```

### 1.6 Configure Custom Domain
1. Go to Cloudflare Dashboard
2. Workers & Pages > formwork-calculator-api
3. Settings > Triggers > Custom Domains
4. Add: `formwork-api.theedges.work`
5. Wait for DNS propagation (~5 mins)

## Step 2: Deploy Frontend

### Option A: Cloudflare Pages (Recommended)

#### 2.1 Deploy via Wrangler
```bash
# From project root
wrangler pages deploy . --project-name=formwork-calculator
```

#### 2.2 Configure Custom Domain
1. Cloudflare Dashboard > Workers & Pages > formwork-calculator
2. Custom Domains > Set up a custom domain
3. Add: `www.theedges.work`
4. Cloudflare will auto-configure DNS

### Option B: Manual Upload

1. Go to Cloudflare Dashboard
2. Workers & Pages > Create application > Pages
3. Upload assets > Select all files (except workers/, node_modules/)
4. Deploy

### Option C: Connect GitHub

1. Cloudflare Dashboard > Workers & Pages > Connect to Git
2. Select repository
3. Build settings:
   - Build command: (leave empty)
   - Build output directory: `/`
4. Environment variables: (none needed)
5. Save and Deploy

## Step 3: DNS Configuration

If using custom domain `www.theedges.work`:

### 3.1 Add DNS Records
In Cloudflare DNS:

```
Type: CNAME
Name: www
Target: formwork-calculator.pages.dev
Proxy: Enabled (Orange cloud)
```

```
Type: CNAME
Name: formwork-api
Target: formwork-calculator-api.YOUR_SUBDOMAIN.workers.dev
Proxy: Enabled
```

### 3.2 Verify
Wait 5-10 minutes, then test:
```bash
# Frontend
curl https://www.theedges.work

# Backend
curl https://formwork-api.theedges.work/health
```

## Step 4: Update Frontend API URL

If backend URL is different, update in `src/services/api.js`:

```javascript
const API = {
    baseURL: window.location.hostname === 'localhost'
        ? 'http://localhost:8787'
        : 'https://formwork-api.theedges.work', // Your actual URL
    ...
};
```

Re-deploy frontend after changes.

## Step 5: Test Deployment

### 5.1 Backend Health Check
```bash
curl https://formwork-api.theedges.work/health
```

Expected:
```json
{"status":"ok","timestamp":1234567890}
```

### 5.2 AI Chat Test
```bash
curl -X POST https://formwork-api.theedges.work/api/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"ชั้น 1 มีเสา 40x40 สูง 3.5 เมตร 24 ต้น","provider":"openrouter"}'
```

### 5.3 Frontend Test
1. Visit: https://www.theedges.work
2. Try file upload
3. Chat with AI
4. Calculate formwork
5. Export Excel/PDF

## Step 6: PWA Installation

### Desktop (Chrome/Edge)
1. Visit website
2. Click install icon in address bar ⊕
3. "Install PD17 AI Formwork Calculator"

### Mobile (iOS Safari)
1. Visit website
2. Tap Share button
3. "Add to Home Screen"

### Mobile (Android Chrome)
1. Visit website
2. Tap menu (⋮)
3. "Add to Home screen"

## Monitoring & Logs

### View Worker Logs
```bash
cd workers
wrangler tail
```

### View Analytics
Cloudflare Dashboard > Workers & Pages > formwork-calculator-api > Analytics

## Troubleshooting

### Issue: "KV namespace not found"
**Solution:** Make sure KV namespace IDs in `wrangler.toml` match the ones created

### Issue: "API key not set"
**Solution:**
```bash
cd workers
wrangler secret list
# If missing, set again:
wrangler secret put OPENROUTER_API_KEY
```

### Issue: "CORS error"
**Solution:** Check that CORS headers are enabled in `workers/index.js`

### Issue: "Frontend can't reach backend"
**Solution:**
1. Check API URL in `src/services/api.js`
2. Test backend directly: `curl https://formwork-api.theedges.work/health`
3. Check browser console for errors

### Issue: "PWA not installing"
**Solution:**
1. Ensure HTTPS (required for PWA)
2. Check manifest.json is accessible
3. Check service worker registration in browser DevTools > Application > Service Workers

## Updating

### Update Backend
```bash
cd workers
# Make changes to index.js
wrangler deploy
```

### Update Frontend
```bash
# Make changes to files
wrangler pages deploy . --project-name=formwork-calculator
```

Or if using Git:
```bash
git push origin main
# Cloudflare auto-deploys on push
```

## Cost Estimate

### Free Tier Limits
- **Workers**: 100,000 requests/day
- **Pages**: Unlimited requests, unlimited bandwidth
- **KV**: 100,000 reads/day, 1,000 writes/day
- **OpenRouter**: Varies by model (some free models available)

### Paid (if exceeding free tier)
- **Workers**: $5/month for 10M requests
- **KV**: $0.50/million reads, $5/million writes
- **OpenRouter**: Pay-per-use (~$0.001-0.01 per request)

## Security Checklist

- ✅ API keys stored as secrets (not in code)
- ✅ CORS configured properly
- ✅ HTTPS enforced
- ✅ Rate limiting via Cloudflare
- ✅ Input validation
- ✅ No sensitive data in frontend code

## Next Steps

1. ✅ Monitor analytics and errors
2. ✅ Add more AI providers (GPT-4o, Claude)
3. ✅ Implement user authentication (optional)
4. ✅ Add more calculation templates
5. ✅ Integrate with project management tools

---

Need help? Contact support@theedges.work
