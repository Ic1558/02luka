# Hub Quicken v2

> **AI-powered real-time hub monitoring dashboard**
> Zero-build · PWA · Privacy-first · Mobile-optimized

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Build](https://img.shields.io/badge/build-passing-success.svg)](../../.github/workflows/hub-quicken-check.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](../../CONTRIBUTING.md)

---

## 📊 Overview

Hub Quicken v2 is a lightweight, static web dashboard for monitoring hub health, MCP registry, and system performance. Built with pure HTML/CSS/JavaScript (zero build dependencies), it features AI-powered analysis, offline support, and comprehensive UX enhancements.

**Live Demo:** [View in your browser](../../web/hub-quicken/)

---

## ✨ Features

### Core Monitoring
- 📈 **Real-time Data:** Hub index, MCP registry, health status
- 🔄 **Auto-refresh:** Configurable intervals (5s/10s/30s/1m)
- 🔍 **Smart Search:** Live filtering with regex support
- 📸 **History:** 50 snapshots with comparison view
- 📊 **Status Badges:** Color-coded health indicators

### AI-Powered Analysis
- 🤖 **Local AI Integration:** Ollama, LM Studio, OpenAI support
- 🧠 **Smart Insights:** Anomaly detection, trends, recommendations
- 🎯 **Auto-Analysis:** Optional background analysis on refresh
- 🔒 **Privacy-First:** Data stays local with local AI

### User Experience
- ⌨️ **Keyboard Shortcuts:** 7 productivity shortcuts
- 🌓 **Dark/Light Themes:** Persisted preference
- 📋 **Copy-to-Clipboard:** One-click data export
- 💾 **Full Export:** JSON download of all data
- 📱 **Pull-to-Refresh:** Native mobile gesture
- 🔕 **Collapsible Cards:** Maximize screen space

### Technical
- 📦 **PWA Support:** Installable on desktop & mobile
- 🚀 **Service Worker:** Offline-first caching
- 🎨 **Responsive:** Mobile, tablet, desktop optimized
- ♿ **Accessible:** ARIA labels, semantic HTML
- 🔧 **Zero Build:** No npm, no webpack, no framework

---

## 🚀 Quick Start

### Prerequisites
- Modern web browser (Chrome 90+, Firefox 88+, Safari 14+)
- HTTP server (for development)
- Local AI (optional): Ollama or LM Studio

### Installation

**Option 1: Direct Access**
```bash
# From repository root
./tools/hub_quicken_dev.zsh

# Visit: http://localhost:8090/web/hub-quicken/
```

**Option 2: Any HTTP Server**
```bash
# Python 3
cd /path/to/02luka
python3 -m http.server 8090

# Node.js
npx http-server -p 8090

# Visit: http://localhost:8090/web/hub-quicken/
```

**Option 3: Production Deploy**
```bash
# Copy files to web server
cp -r web/hub-quicken /var/www/html/

# Visit: https://your-domain.com/hub-quicken/
```

---

## 🤖 AI Setup (Optional)

### Ollama (Recommended)
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull model
ollama pull llama3.2:latest

# Ollama runs on http://localhost:11434 automatically
```

**In Hub Quicken:**
1. Click **🤖 AI** button
2. Select **"Ollama (default)"** preset
3. Click **"Test Connection"**
4. Click **"Save Settings"**
5. Click **"🔍 Analyze"** to run analysis

### LM Studio
```bash
# Download LM Studio from https://lmstudio.ai
# Load any local model
# Start local server (default port 1234)
```

**In Hub Quicken:**
1. Click **🤖 AI** button
2. Select **"LM Studio"** preset
3. Adjust port if needed
4. Test & save

### OpenAI API
**In Hub Quicken:**
1. Click **🤖 AI** button
2. Select **"OpenAI API"** preset
3. Enter your API key
4. Test & save

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+K` | Focus search |
| `Ctrl+E` | Export data |
| `Ctrl+H` | View history |
| `Alt+T` | Toggle theme |
| `Alt+R` | Toggle regex search |
| `?` | Show shortcuts help |
| `Esc` | Close modals |

---

## 📁 File Structure

```
web/hub-quicken/
├── index.html          # Main UI structure (245 lines)
├── app.js              # Core logic (868 lines)
│   ├── Data fetching & rendering
│   ├── Search & filtering
│   ├── History management
│   ├── AI analysis engine
│   └── Event handlers
├── style.css           # Styles & themes (793 lines)
│   ├── CSS variables (themes)
│   ├── Responsive grid
│   ├── Component styles
│   └── Mobile optimizations
├── sw.js               # Service worker (126 lines)
├── manifest.json       # PWA manifest (31 lines)
└── README.md           # This file
```

**Total:** 2,063 lines of production code

---

## 🎨 Customization

### Themes
Edit `style.css` CSS variables:
```css
:root {
  --bg: #0b0f19;        /* Background */
  --fg: #e6e6e6;        /* Foreground */
  --accent: #60a5fa;    /* Accent color */
  --ok: #22c55e;        /* Success */
  --warn: #eab308;      /* Warning */
  --err: #ef4444;       /* Error */
}
```

### Endpoints
Edit `app.js` constants:
```javascript
const ENDPOINTS = {
  index: "../../hub/index.json",
  registry: "../../hub/mcp_registry.json",
  health: "../../hub/mcp_health.json"
};
```

### Refresh Intervals
Edit `index.html`:
```html
<select id="refresh-interval">
  <option value="5000">5s</option>
  <option value="10000" selected>10s</option>
  <option value="30000">30s</option>
  <option value="60000">1m</option>
</select>
```

---

## 🧪 Testing

### Manual Testing
```bash
# Start server
./tools/hub_quicken_dev.zsh

# Test checklist:
✓ Data loads correctly
✓ Search filters results
✓ Auto-refresh works
✓ Export downloads JSON
✓ History saves snapshots
✓ AI analysis runs (if configured)
✓ Theme toggle works
✓ Keyboard shortcuts respond
✓ Mobile pull-to-refresh works
✓ Offline mode caches data
```

### Browser Compatibility
```bash
# Test in:
- Chrome 90+ ✓
- Firefox 88+ ✓
- Safari 14+ ✓
- Edge 90+ ✓
- Mobile Chrome/Safari ✓
```

### Performance
```bash
# Lighthouse scores:
- Performance: 95+
- Accessibility: 95+
- Best Practices: 90+
- SEO: 90+
- PWA: 100
```

---

## 🔧 API Reference

### Data Format

**Hub Index (`hub/index.json`)**
```json
{
  "_meta": {
    "created_at": "2025-11-08T12:00:00Z",
    "source": "hub_indexer",
    "total": 1247,
    "mem_root": "/path/to/memory"
  },
  "items": [
    {
      "path": "memory/file.md",
      "size": 1024,
      "modified": "2025-11-08T11:00:00Z"
    }
  ]
}
```

**MCP Registry (`hub/mcp_registry.json`)**
```json
{
  "_meta": {
    "created_at": "2025-11-08T12:00:00Z",
    "source": "mcp_scanner",
    "total": 15,
    "config_path": "/path/to/mcp.json"
  },
  "servers": [
    {
      "name": "mcp-database",
      "command": "node",
      "args": ["server.js"],
      "env": {}
    }
  ]
}
```

**MCP Health (`hub/mcp_health.json`)**
```json
{
  "_meta": {
    "created_at": "2025-11-08T12:00:00Z",
    "healthy": 13,
    "total": 15
  },
  "results": [
    {
      "server": "mcp-database",
      "status": "healthy",
      "latency_ms": 45,
      "last_check": "2025-11-08T12:00:00Z"
    }
  ]
}
```

### AI Endpoints

**Ollama**
```bash
POST http://localhost:11434/api/generate
Content-Type: application/json

{
  "model": "llama3.2:latest",
  "prompt": "Your prompt here",
  "stream": false
}
```

**OpenAI / LM Studio**
```bash
POST http://localhost:1234/v1/chat/completions
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY

{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "You are..."},
    {"role": "user", "content": "Your prompt"}
  ]
}
```

---

## 🐛 Troubleshooting

### Data Not Loading
```bash
# Check endpoints exist:
curl http://localhost:8090/hub/index.json
curl http://localhost:8090/hub/mcp_registry.json
curl http://localhost:8090/hub/mcp_health.json

# Verify CORS headers if using different domain
# Check browser console for errors
```

### AI Connection Failed
```bash
# Ollama
curl http://localhost:11434/api/generate \
  -d '{"model":"llama3.2:latest","prompt":"test","stream":false}'

# LM Studio
curl http://localhost:1234/v1/models

# Check:
- Is AI service running?
- Is port correct?
- Is model loaded?
- Check browser console for CORS errors
```

### Service Worker Issues
```bash
# Clear cache:
1. Open DevTools (F12)
2. Application tab
3. Clear storage
4. Refresh page
```

### Performance Issues
```bash
# Reduce refresh interval
# Disable auto-refresh
# Collapse unused cards
# Disable auto-analyze
# Use smaller AI model
```

---

## 🔒 Security

### Best Practices
1. **HTTPS Only:** Always use HTTPS in production
2. **API Keys:** Never commit API keys to git
3. **CSP Headers:** Add Content-Security-Policy headers
4. **Local AI:** Prefer local AI for sensitive data
5. **Audit Endpoints:** Validate data source integrity

### Content Security Policy
```html
<meta http-equiv="Content-Security-Policy"
  content="default-src 'self';
           script-src 'self';
           style-src 'self' 'unsafe-inline';
           connect-src 'self' http://localhost:*;">
```

---

## 📈 Performance

### Optimization Tips
1. **Lazy Load:** Cards load independently
2. **Debounced Search:** 300ms delay prevents lag
3. **Service Worker:** Caches static assets
4. **Minimal Dependencies:** Zero external libraries
5. **Efficient Rendering:** Only updates changed data

### Bundle Size
- `index.html`: 9.4 KB
- `app.js`: 24 KB
- `style.css`: 14 KB
- `sw.js`: 3.4 KB
- `manifest.json`: 948 B
- **Total:** ~52 KB (uncompressed)
- **Gzipped:** ~15 KB

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](../../CONTRIBUTING.md)

**Development Setup:**
```bash
# Fork & clone
git clone https://github.com/YOUR_USERNAME/02luka.git
cd 02luka

# Create branch
git checkout -b feature/your-feature

# Make changes
# Test locally
./tools/hub_quicken_dev.zsh

# Commit & push
git add web/hub-quicken/
git commit -m "feat(web): your feature"
git push origin feature/your-feature

# Open PR
```

---

## 📝 Changelog

### v2.1.0 (2025-11-08)
- ✨ AI-powered analysis integration
- ✨ Local AI support (Ollama, LM Studio)
- ✨ Auto-analysis on refresh
- 📊 Quick stats dashboard

### v2.0.0 (2025-11-08)
- ✨ Major UX optimizations
- ✨ Historical snapshots (50 max)
- ✨ Debounced search
- ✨ Pull-to-refresh
- ✨ Keyboard shortcuts
- ✨ Toast notifications
- ✨ PWA support

### v1.0.0 (2025-11-08)
- 🎉 Initial release
- 📊 Hub monitoring dashboard
- 🔍 Search & filter
- 🌓 Dark/light themes
- 💾 Export functionality

---

## 📄 License

MIT License - see [LICENSE](../../LICENSE) for details

---

## 🙏 Acknowledgments

- Built with ❤️ for the 02LUKA project
- Inspired by modern DevOps monitoring tools
- AI integration powered by Ollama & OpenAI

---

## 📞 Support

- **Issues:** [GitHub Issues](../../issues)
- **Discussions:** [GitHub Discussions](../../discussions)
- **Docs:** [Full Documentation](../../docs/)

---

**Made with zero dependencies · Built for speed · Optimized for monitoring**
