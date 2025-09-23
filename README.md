# 02luka

Local AI Agent Gateway UI — minimal, fast, deployable anywhere.

[![pages](https://github.com/Ic1558/02luka/actions/workflows/pages.yml/badge.svg)](https://github.com/Ic1558/02luka/actions/workflows/pages.yml)

🌐 **Live Demo**: https://ic1558.github.io/02luka/

## 🚀 Quick Start

### Option 1: Local Development (Recommended)
```bash
./run_local.sh
# Opens at http://localhost:8080 → connects to local gateways
```

### Option 2: Auto Tunnel (Remote Access)
```bash
./tunnel
# Creates public URLs for your gateways + auto-updates UI
```

### Option 3: Manual Setup
```bash
# Run any HTTP server
python3 -m http.server 8080
open http://localhost:8080
```

## 🔧 Available Scripts

| Script | Purpose |
|--------|---------|
| `./run_local.sh` | Start local dev server |
| `./tunnel` | Auto tunnel + config update |
| `./verify_system.sh` | Full system health check |
| `./expose_gateways.sh` | Manual Cloudflare tunnels |

## 🎯 Gateway Support

- **MCP Docker** (port 5012) - Main gateway
- **MCP FS** (port 8765) - File system operations
- **Ollama** (port 11434) - Local LLM inference

## ✨ Features

- ✅ Send button that actually works
- ✅ Enter-to-send (Shift+Enter = newline)
- ✅ Auto-resize input area
- ✅ Gateway switching
- ✅ Connection status indicator
- ✅ Responsive design
- ✅ No external dependencies

## 🔍 Troubleshooting

**"Cannot connect" errors?**
```bash
./verify_system.sh  # Check what's running
./tunnel            # Auto-fix with public tunnels
```

**UI not loading?**
```bash
# Clear browser cache or try:
open "https://ic1558.github.io/02luka/?v=$(date +%s)"
```
