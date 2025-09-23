# 🚀 Deploy Instructions for 02luka Agent Interface

## Manual Deployment Steps

### 1. Create GitHub Repository
1. Go to [github.com/new](https://github.com/new)
2. Repository name: `02luka`
3. Set to **Public**
4. **DON'T** initialize with README (we already have files)
5. Click "Create repository"

### 2. Push to GitHub
```bash
cd "/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka-repo"

# Add GitHub remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/02luka.git

# Push to GitHub
git push -u origin main
```

### 3. Deploy to Cloudflare Pages
1. Go to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click "Pages" in sidebar
3. Click "Create a project"
4. Connect to Git → Select your `02luka` repository
5. Configure build:
   - **Project name**: `02luka-ui`
   - **Production branch**: `main`
   - **Build command**: (leave empty)
   - **Build output directory**: (leave empty)
6. Click "Save and Deploy"

### 4. Get Your Live URL
After deployment completes, you'll get a URL like:
```
https://02luka-ui.pages.dev
```

### 5. Test the Deployment
1. Visit your Cloudflare Pages URL
2. Open browser dev tools → Network tab
3. Try connecting to different gateways
4. Check for CORS errors

## CORS Configuration (Important!)

Your 02luka agents need CORS headers for the deployed UI:

### For Express.js Agents
```javascript
app.use(cors({
  origin: 'https://02luka-ui.pages.dev', // Your actual URL
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### For Docker Containers
Add environment variable:
```bash
CORS_ORIGIN=https://02luka-ui.pages.dev
```

## Alternative: Quick Deploy via File Upload

If GitHub setup is complex, you can deploy directly:

### Option A: Vercel
1. Go to [vercel.com](https://vercel.com/new)
2. Drag `luka_minimal.html` to the upload area
3. Deploy → Get instant URL

### Option B: Netlify
1. Go to [app.netlify.com/drop](https://app.netlify.com/drop)
2. Drag the entire `/02luka-repo` folder
3. Deploy → Get instant URL

### Option C: Local Network Access
```bash
# Serve locally but accessible on network
cd "/Users/icmini/My Drive (ittipong.c@gmail.com) (1)/02luka-repo"
python3 -m http.server 8080 --bind 0.0.0.0

# Access from other devices: http://YOUR_MAC_IP:8080/luka_minimal.html
```

## Codex Integration (After GitHub Deploy)

1. Go to [chatgpt.com/codex](https://chatgpt.com/codex)
2. Click "Connect GitHub"
3. Select your `02luka` repository
4. Create environment
5. Enable "Agent internet access" during setup

Then you can command Codex:
```
"Add automatic CORS detection and configuration"
"Create custom domain setup for production"
"Add gateway health monitoring dashboard"
"Implement offline mode with service workers"
```

---

**Next Steps After Deploy:**
1. Update gateway URLs in the UI for WAN access
2. Set up Cloudflare Tunnels for secure agent access
3. Configure monitoring and error tracking
4. Test file upload functionality over HTTPS

**Repository Ready for Codex!** 🎯
---

## 🌐 GitHub Pages Deployment (PR #2)

After merging PR #2, GitHub Pages is auto-enabled.

Endpoints:
- Health check → https://ic1558.github.io/02luka/_health.html
- Manifest → https://ic1558.github.io/02luka/manifest.json

Every push to `main` will:
- Auto-generate `_health.html` and `manifest.json`
- Deploy latest code to GitHub Pages
