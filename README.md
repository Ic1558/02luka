<!-- CLS_STATUS_BADGE_START -->

[![](https://github.com/Ic1558/02luka/actions/workflows/cls-contract.yml/badge.svg?branch=main)](https://github.com/Ic1558/02luka/actions/workflows/cls-contract.yml) • [OPS Mirror](https://ops.theedges.work)

<!-- CLS_STATUS_BADGE_END -->

![BrowserOS CI](https://github.com/Ic1558/02luka/actions/workflows/browseros_phase77_ci.yml/badge.svg)
# 02luka

Local AI Agent Gateway UI — minimal, fast, deployable anywhere.

[![pages](https://github.com/Ic1558/02luka/actions/workflows/pages.yml/badge.svg)](https://github.com/Ic1558/02luka/actions/workflows/pages.yml)

🌐 **Live Demo**: https://ic1558.github.io/02luka/

## 🚀 Quick Start

### Direct HTTP Access (No MCP Required)

- **API**: [http://127.0.0.1:4000/api/capabilities](http://127.0.0.1:4000/api/capabilities)
- **UI**: [http://127.0.0.1:5173/luka.html](http://127.0.0.1:5173/luka.html)
- **MCP FS Stub**: [http://127.0.0.1:8765/health](http://127.0.0.1:8765/health)

> ℹ️ **VS Code tip:** Forward ports **4000**, **5173**, and **8765** (Ports tab → *Add Port* → set to *Forwarded*) so they are reachable from your host machine.

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

## 🌅 Morning Routine

**One-liner to start your day:**
```bash
bash ./.codex/preflight.sh && bash ./run/dev_up_simple.sh && bash ./run/smoke_api_ui.sh
```

**Or use the convenience script:**
```bash
./run/dev_morning.sh
```

## 🧠 Dual Memory System (CLC ↔ Cursor AI)

The **Dual Memory System** integrates Claude Code (CLC) and Cursor AI memory into one synchronized framework.

### 🌉 Architecture Overview
| Layer | Description | Path |
|-------|--------------|------|
| **1️⃣ Cursor AI Memory** | Local hybrid memory profile and behavioral state | `.codex/hybrid_memory_system.md` |
| **2️⃣ CLC Memory (SOT)** | Persistent system memory for 02LUKA agents | `a/section/clc/memory/` |
| **3️⃣ Memory Bridge** | YAML-based synchronization between Cursor and CLC | `.codex/codex_memory_bridge.yml` |
| **4️⃣ Autosave Engine** | Auto snapshot of memory context during commits | `.codex/autosave_memory.sh` → `g/reports/memory_autosave/` |

---

### 🧩 Autosave Workflow
- Triggered automatically on every **git commit**
- Saves current Cursor AI memory and context to:

```
g/reports/memory_autosave/autosave_YYYYMMDD_HHMMSS.md
```

- Mirrors active context between Cursor and CLC folders (`mirror-latest` strategy)

---

### 🔄 Real-Time Coordination (CLC ↔ Cursor)

**Auto-Start Components:**
- ✅ **MCP FS Server** (port 8765) - Cursor reads 02luka files via MCP tools
- ✅ **Task Bus Bridge** - Real-time task event sharing between AIs

**Quick Usage:**
```bash
# Cursor can read any file via MCP
read_text('a/memory/active_tasks.json')
list_dir('g/tools')

# Both AIs publish task events
bash g/tools/emit_task_event.sh clc my_action started "context"
```

**Benefits:**
- 🎯 Instant visibility: Both AIs see each other's work in real-time
- 📡 Event-driven: Task events sync via Redis + file storage
- 🚀 Zero manual setup: Auto-starts on login

**Documentation:** See `AUTOSTART_CONFIG.md`, `TASK_BUS_SYSTEM.md`

---

### ⚙️ Development Routine

**Option 1 — One-liner**
```bash
bash ./.codex/preflight.sh && bash ./run/dev_up_simple.sh && bash ./run/smoke_api_ui.sh
```

**Option 2 — Convenience Script**
```bash
./run/dev_morning.sh
```

---

### 🩺 System Health Check

Run at any time to validate agents, log paths, and exit statuses:

```bash
bash "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/g/runbooks/agent_value_audit.sh"
```

**Expected output:**
```
Bad log paths: 0
Exit 127/126/78: 0
All systems operational ✅
```

---

### 📦 Latest Checkpoint

| Component | Status |
|-----------|--------|
| **Commit** | 846d993 |
| **Tag** | v2025-10-05-cursor-ready |
| **Memory Autosave** | ✅ autosave_20251004_194118.md |
| **API/UI** | ✅ Running and verified |
| **CLC Gate** | ✅ Passed (3/3 checks) |

---

### 🔒 Notes
- **Do not run** from `GoogleDrive-ittipong.c@gmail.com/My Drive/...` inside devcontainer.
- **Always open project** from symlinked path: `~/dev/02luka-repo`
- The devcontainer automatically mounts `.codex/` memory and loads the hybrid context.

## 🔧 Available Scripts

| Script | Purpose |
|--------|---------|
| `./run_local.sh` | Start local dev server |
| `./run/dev_morning.sh` | **Morning routine** - preflight + dev + smoke |
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
- ✅ Universal bridge directories checked into the repo so real files can flow between sandbox and
      the outside world

## 🌉 Bridge & Tunnel Workflow

To break out of the "purely theoretical" sandbox, the repository now ships with a persistent bridge
workspace under `f/bridge/`:

- `f/bridge/inbox/` — drop real-world inputs here for the agent to read.
- `f/bridge/outbox/` — the agent writes outputs here for humans to collect.
- `f/bridge/processed/` — move handled assets here to keep the bridge clean.

On a host machine you can sync these folders to a shared drive, tunnel, or any filesystem that is
visible to external operators. Pair them with `./tunnel` or your own networking setup to make the
bridge live in the real world, not just in documentation.

## 📚 Documentation

- [ChatGPT Native App Integration](docs/chatgpt_native_app.md) — embed `luka.html` inside the ChatGPT desktop client while keeping full visibility into the local 02luka workspace.
- [GG Local Bridge setup](docs/gg-local-bridge.md) — bootstrap the macOS worker that connects Redis queues to the local orchestrator.
- [Telemetry System](docs/TELEMETRY.md) — self-metrics for agent runs with append-only JSON logging.

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

## 🗂️ Persistent Change Tracking

The repository now ships with a Codex-friendly workflow for carrying context between sessions. See [docs/persistent_change_workflow.md](docs/persistent_change_workflow.md) for details on change units, session logs, and daily reports that live inside the repo.

---

## 🔖 Checkpoints & Tags

| Tag | Date | Description |
|-----|------|--------------|
| v2025-10-05-cursor-ready | 2025-10-05 | Cursor DevContainer ready, preflight OK |
| v2025-10-05-stabilized | 2025-10-05 | System stabilized, daily audit + boot guard enforced |
| v2025-10-05-docs-stable | 2025-10-05 | Stable baseline after Dual Memory + documentation unification |

### 🧭 Tag Usage Guide

To **switch** to a tag version (read-only snapshot):

```bash
git fetch --tags
git checkout v2025-10-05-docs-stable
```

To return to the latest development branch:

```bash
git checkout main
git pull origin main
```

To rollback (hard reset local state):

```bash
git reset --hard v2025-10-05-docs-stable
```

---

### 🧠 Tag Policy:
- All tags are annotated (-a) and signed by GG system.
- Each tag marks a system-stable snapshot after validation (CLC + preflight + smoke tests).
- Tags ending in -ready are development-ready checkpoints; tags ending in -stable are production-grade baselines.

## Concurrency & Autosave (CLC + Cursor AI)
- Autosave is flock-locked and hash-deduped. Running both CLC and Cursor AI will not create duplicate memory files.
- Files live in `g/reports/memory_autosave/` with content-hash in filenames, older duplicates are auto-archived to `.archive/`.
- Bridge runs in `mirror-latest` mode with `prefer_run_id: newest`.

---
## Boss API/UI Folders (merged in batch2)
- boss-api/: server.cjs canonical, .env.sample added
- boss-ui/: index.html redirects to luka.html

## MCP config
- Edit \ only.
- \ is local-only and ignored.
- Run \JSON OK: /workspaces/02luka-repo/.cursor/mcp.example.json and /workspaces/02luka-repo/.cursor/mcp.example.json
dev-setup complete. after clone to bootstrap.
