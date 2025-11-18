# Claude Code Context for 02luka

**Last Updated:** 2025-11-05 06:30 ICT
**Version:** 2.0.2
**Status:** 70% Roadmap Complete

---

## 📍 Source of Truth Paths

### Desktop (Primary Development)
```bash
REPO_PATH="~/02luka/g"
SYSTEM_PATH="~/02luka"
TOOLS_PATH="~/02luka/tools"
AGENTS_PATH="~/02luka/agents"
BRIDGE_PATH="~/02luka/bridge"
TELEMETRY_PATH="~/02luka/telemetry"
```

### Mobile (Read-Only Access)
```bash
# Via Google Drive Stream
GD_PATH="~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"

# This repo syncs to:
GD_REPO="$GD_PATH/g"
```

---

## 🎯 Current State (2025-11-05)

### Roadmap Progress: 70%
- ✅ Phase 1: Local Truth Scanner (100%)
- ✅ Phase 2: R&D Autopilot (100%)
- 🟡 Phase 3: Local AI Integration (50%)
- 🟡 Phase 4: Application Slices (25%)
- ⏳ Phase 5: Agent Communication (0%)

### Active Issues
None - system stable after roadmap acceleration

### Recent Work
- Dashboard v2.0.2 deployed with WO detail drawer
- Ollama + qwen2.5:0.5b installed (397 MB)
- Agent thrashing fixed (90x reduction)
- 4 WOs executed successfully (100% success rate)

---

## 🔧 Key Tools & Commands

### System Health
```bash
# Check all agents
~/02luka/tools/agent_status.zsh

# Check autopilot
~/02luka/tools/autopilot_status.zsh

# Check scanner
~/02luka/tools/scanner_status.zsh

# View dashboard
open http://127.0.0.1:8766
```

### Progress Tracking
```bash
# Current progress
~/02luka/tools/show_progress.zsh

# Latest roadmap
cat ~/02luka/g/roadmaps/ROADMAP_2025-11-04_autonomous_systems.md
```

### Git Workflow
```bash
# This repo (operational data only)
cd ~/02luka/g
git status
git pull origin master
git add -A
git commit -m "Update operational data"
git push origin master
```

---

## 📊 System Architecture

### Agent Types
1. **Execution Agents**
   - WO Executor (`agents/wo_executor/wo_executor.zsh`)
   - JSON WO Processor (`agents/json_wo_processor/json_wo_processor.zsh`)

2. **R&D Autopilot**
   - Autopilot (`agents/rd_autopilot/rd_autopilot.zsh`)
   - Local Truth Scanner (`tools/local_truth_scan.zsh`)
   - Autopilot Digest (daily at 10 PM)

3. **Infrastructure**
   - Dashboard v2.0.2 (http://127.0.0.1:8766)
   - Dashboard API (http://127.0.0.1:8767)
   - Ollama (local AI on port 11434)

### Data Flow
```
Scanner → WO Generation → Autopilot Approval → Executor → Telemetry → Dashboard
```

### Gemini Layer (4.5) – Heavy Compute Offload

- Gemini is available as a **non-writing** engine for heavy computation:
  - bulk test generation
  - large-scale refactor proposals
  - complex multi-file analysis
- Gemini outputs are treated as **specs or patches for review**, never direct writes.
- CLC/LPE/CLS remain the only actors allowed to apply changes to SOT via SIP.
- See `g/manuals/GEMINI_INTEGRATION.md` for routing rules and examples.

---

## 🚨 Important Configuration

### LaunchAgents Location
```bash
~/Library/LaunchAgents/com.02luka.*.plist
```

### ThrottleInterval Fix
All file-watching agents have 30-second throttle to prevent feedback loops.

### Dashboard Data Source
```bash
~/02luka/g/apps/dashboard/dashboard_data.json
```
This file is manually updated when roadmap changes.

---

## 📱 Mobile Access Setup

### 1. Google Drive Sync (Already Configured)
- Desktop: `~/02luka/` → Google Drive
- Mobile: Access via Google Drive app
- Sync: Two-way, every 4 hours

### 2. Claude Code Mobile Context
When using Claude Code on mobile:
1. Open this file: `CLAUDE_CONTEXT.md`
2. Reference paths as `$GD_PATH/...` instead of `~/02luka/...`
3. Read-only mode (no file edits on mobile)

### 3. Quick Status Check (Mobile)
```bash
# View latest roadmap
cat "$GD_PATH/g/roadmaps/ROADMAP_*.md" | tail -50

# View latest report
cat "$GD_PATH/g/reports/ROADMAP_ACCELERATION_*.md"

# View dashboard data
cat "$GD_PATH/g/apps/dashboard/dashboard_data.json"
```

---

## 🎓 Learning & Memory

### MLS (Memory & Learning System)
- Location: `~/02luka/g/knowledge/mls_lessons.jsonl`
- 15+ lessons captured (solutions, failures, patterns)
- Auto-captured by WO Executor

### Knowledge Base
- Location: `~/02luka/g/knowledge/`
- Hybrid vector search operational (7-8ms avg)
- 4,002 chunks from 258 documents

---

## 🔐 Security & Credentials

### No Secrets in Git
- `.gitignore` excludes: `.env`, `*.key`, `*.pem`, `credentials.json`
- All secrets in: `~/.config/02luka/` (not in repo)

### SSH Keys
```bash
# GitHub access
~/.ssh/id_ed25519  # For github.com:lc1558/02luka.git
```

---

## 📞 Support & Troubleshooting

### If Something Breaks
1. Check agent status: `~/02luka/tools/agent_status.zsh`
2. Check logs: `~/02luka/logs/`
3. Check telemetry: `~/02luka/telemetry/`
4. View latest session: `~/02luka/g/reports/sessions/session_*.md`

### Common Issues

**Dashboard not loading?**
```bash
# Restart API server
pkill -f api_server.py
cd ~/02luka/g/apps/dashboard && python3 api_server.py &
```

**Agents thrashing?**
```bash
# Check ThrottleInterval in plists
grep -A1 "ThrottleInterval" ~/Library/LaunchAgents/com.02luka.*.plist
```

**Ollama not responding?**
```bash
# Check Ollama status
ollama list
ollama run qwen2.5:0.5b "test"
```

---

## 🎯 Next Steps (Phase 3 & 4)

### Phase 3: Complete Local AI Integration
- Integrate Ollama with expense OCR workflow
- Build keyword extraction pipeline
- Performance tuning

### Phase 4: Build 2nd Application
- Expense Tracker (if slips accumulate)
- OR Project Rollup (if project activity increases)
- Based on scanner recommendations

---

## 📚 Key Documentation

### Roadmaps
- `/Users/icmini/02luka/g/roadmaps/ROADMAP_2025-11-04_autonomous_systems.md`

### Reports
- `/Users/icmini/02luka/g/reports/ROADMAP_ACCELERATION_20251105.md`
- `/Users/icmini/02luka/g/reports/AGENT_IMPROVEMENTS_20251105.md`

### Manuals
- `/Users/icmini/02luka/g/manuals/MOBILE_ACCESS_GUIDE.md`
- `/Users/icmini/02luka/g/manuals/SYSTEM_DASHBOARD_GUIDE.md`

---

**For Claude Code Mobile Users:**
This file contains everything you need to understand the current state of 02luka. All paths are relative to either `~/02luka/` (desktop) or `$GD_PATH/` (mobile via Google Drive).

**Version History:**
- v2.0.2 (2025-11-05): Roadmap acceleration to 70%, Ollama integration, Dashboard v2.0.2
- v2.0.1 (2025-11-04): Agent thrashing fix, unified monitoring
- v2.0.0 (2025-11-04): Initial autonomous systems deployment
