# 02luka Agent Interface

Minimal, responsive UI for connecting to 02luka system agents with file upload, drag & drop, and smart gateway selection.

## 🚀 Quick Start

### Local Development
```bash
# Open directly in browser
open luka_minimal.html

# Or serve with Python
python3 -m http.server 8080
# Visit: http://localhost:8080/luka_minimal.html
```

### Production Deployment

#### Option 1: Cloudflare Pages
```bash
# Deploy to Cloudflare Pages
wrangler pages publish . --project-name=02luka-ui

# Custom domain (optional)
wrangler pages domain add 02luka-ui yourdomain.com
```

#### Option 2: Static Hosting
Upload `luka_minimal.html` to any static host:
- Vercel: `vercel --prod`
- Netlify: Drag & drop to dashboard
- GitHub Pages: Push to `gh-pages` branch

## 🔧 Gateway Configuration

### Default Gateways (Pre-configured)
- **🔮 Auto-Select**: Automatically finds best available gateway
- **🧠 GC Core** (5009): Co-Core Orchestrator
- **⚡ GG Core** (5010): External coordination
- **🐳 MCP Gateway** (5012): Docker tools access
- **👩 Mary Agent** (5001): Task management
- **📊 Lisa Agent** (5007): Data analysis
- **🤖 Kim Bot** (5011): Bot functions
- **🦙 Ollama LLM** (11434): Local inference
- **🧮 NPU Core** (7000): Neural processing

### WAN Access Setup

#### 1. CORS Configuration
Add to your gateway servers:
```javascript
// Express.js example
app.use(cors({
  origin: 'https://your-luka-ui.yourdomain.com',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

#### 2. Cloudflare Tunnel (Recommended)
```bash
# Expose MCP Gateway to WAN
cloudflared tunnel create 02luka-mcp
cloudflared tunnel route dns 02luka-mcp mcp.yourdomain.com

# Tunnel config
ingress:
  - hostname: mcp.yourdomain.com
    service: http://127.0.0.1:5012
  - hostname: ollama.yourdomain.com
    service: http://127.0.0.1:11434
```

#### 3. Update Gateway URLs
In the UI settings, change from:
- `http://127.0.0.1:5012` → `https://mcp.yourdomain.com`
- `http://localhost:11434` → `https://ollama.yourdomain.com`

### Agent API Endpoints

Each agent supports multiple endpoint patterns (auto-detected):
- `/chat` - Standard chat interface
- `/api/chat` - API namespace
- `/message` - Simple messaging
- `/query` - Query interface
- `/` - Root endpoint

### File Upload Support
- **Images**: PNG, JPG, GIF, WebP, SVG
- **Documents**: PDF, DOC, DOCX, TXT, MD
- **Data**: JSON, CSV, XML
- **Size Limit**: 10MB per file
- **Method**: Base64 encoding for transmission

## 🎯 Usage Examples

### Basic Chat
1. Select gateway from dropdown
2. Type message and press ⌘+Enter
3. View response with latency metrics

### File Analysis
1. Drag & drop images/documents onto input area
2. Add descriptive message
3. Send to appropriate agent (Lisa for data, Mary for tasks)

### Multi-Agent Workflow
1. Start with **Auto-Select** for routing
2. Switch to specific agents for specialized tasks:
   - **Mary**: Task management and planning
   - **Lisa**: Data analysis and reports
   - **GC Core**: System orchestration
   - **MCP Gateway**: File operations and Docker tools

## 🔍 Troubleshooting

### Connection Issues
- Check gateway dropdown shows "Connected" status
- Verify agent containers are running: `docker ps`
- Test direct endpoint: `curl http://localhost:5012/health`

### CORS Errors
- Add UI domain to gateway CORS whitelist
- Check browser console for specific error details
- Ensure OPTIONS requests are handled

### File Upload Failures
- Verify file size < 10MB
- Check agent supports file processing
- Monitor network tab for upload progress

## 📊 Agent Specializations

| Agent | Port | Best For | API Style |
|-------|------|----------|-----------|
| Mary | 5001 | Task management, planning | RESTful |
| Lisa | 5007 | Data analysis, reporting | JSON-RPC |
| Kim | 5011 | Bot interactions | WebSocket/HTTP |
| GC Core | 5009 | System orchestration | Custom |
| MCP Gateway | 5012 | File ops, Docker tools | MCP Protocol |
| NPU Core | 7000 | Heavy processing | Binary/HTTP |

## 🛠️ Development

### Adding New Gateways
Edit the `gateways` object in `luka_minimal.html`:
```javascript
const state = {
  gateways: {
    my_agent: {
      url: 'http://127.0.0.1:5020',
      name: '🎯 My Agent',
      type: 'agent'
    }
  }
};
```

### Custom Themes
Modify CSS variables in the `<style>` section:
```css
:root {
  --bg: #0a0a0a;        /* Background */
  --surface: #141414;    /* Cards/inputs */
  --accent: #3b82f6;     /* Primary color */
  --text: #fafafa;       /* Text color */
}
```

## 📋 Deployment Checklist

- [ ] Test all gateways locally
- [ ] Configure CORS for production domain
- [ ] Set up Cloudflare Tunnels for WAN access
- [ ] Update gateway URLs in UI
- [ ] Test file upload functionality
- [ ] Verify responsive design on mobile
- [ ] Set up monitoring for gateway health

---

**Built for 02luka System** • Production Ready • Zero Dependencies