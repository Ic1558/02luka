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
- **FastVLM** (port 8765) - Vision-language AI model (Apple FastVLM 0.5B)
- **Ollama** (port 11434) - Local LLM inference

## ✨ Features

- ✅ Send button that actually works
- ✅ Enter-to-send (Shift+Enter = newline)
- ✅ Auto-resize input area
- ✅ Gateway switching
- ✅ Connection status indicator
- ✅ Responsive design
- ✅ No external dependencies

## 📚 Documentation

- [ChatGPT Native App Integration](docs/chatgpt_native_app.md) — embed `luka.html` inside the ChatGPT desktop client while keeping full visibility into the local 02luka workspace.

## 🤖 FastVLM Vision API

The system includes Apple's FastVLM for real-time image analysis.

**Service Info:**
- **Endpoint:** `http://127.0.0.1:8765`
- **Model:** Apple FastVLM 0.5B Stage 3 (1.4GB)
- **Python:** 3.11 (dedicated venv at `$SOT_PATH/.venv_fastvlm311`)
- **LaunchAgent:** `com.02luka.fastvlm` (auto-starts on login)

**API Endpoints:**
```bash
GET  /health          # Service health + model status
POST /analyze         # Analyze image (multipart/form-data)
POST /batch-analyze   # Batch process multiple images
GET  /info            # Model capabilities and version
```

**Example Usage:**
```bash
curl -X POST http://127.0.0.1:8765/analyze \
  -F "file=@image.png" \
  -F "prompt=Describe what you see"
```

**Model Cache Location:**
```
$SOT_PATH/tools/ml-fastvlm/checkpoints/llava-fastvithd_0.5b_stage3/
```

**Logs:**
```
~/Library/Logs/02luka/com.02luka.fastvlm.{out,err}.log
```

**Rebuild/Reinstall:**
```bash
cd "$SOT_PATH"
source .venv_fastvlm311/bin/activate
pip install -r tools/ml-fastvlm/requirements.lock.txt
launchctl bootout "gui/$(id -u)/com.02luka.fastvlm"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.02luka.fastvlm.plist"
```

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

**FastVLM not responding?**
```bash
launchctl list | grep fastvlm              # Check service status
curl http://127.0.0.1:8765/health          # Verify endpoint
tail -f ~/Library/Logs/02luka/com.02luka.fastvlm.err.log  # Check errors
```
