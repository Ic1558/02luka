# Claude Code Context for 02luka

**Version:** 3.1.0
**Status:** ⚠️ MIGRATED TO FORMAL PROTOCOLS
**Last Updated:** 2025-11-17
**Previous Version:** v2.0.2 (archived below)

---

## ⚠️ MIGRATION NOTICE

**This document has been replaced by formal RFC-style protocols.**

All context information (agent capabilities, paths, tools) is now defined in authoritative protocol documents with enforced rules (MUST/SHALL/MAY language).

---

## 📋 Protocol Reference (Authoritative Sources)

### Core Protocols

| Protocol | Purpose | Path |
|----------|---------|------|
| **Context Engineering Protocol v3.1-REV** | Agent capabilities, Boss override mode, fallback procedures, MLS integration | `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md` |
| **Path and Tool Protocol** | Path usage rules ($SOT variable), tool registry, validation | `g/docs/PATH_AND_TOOL_PROTOCOL.md` |
| **Multi-Agent PR Contract** | PR routing types, agent impact, governance alignment | `g/docs/MULTI_AGENT_PR_CONTRACT.md` |
| **LaunchAgent Registry** | Complete agent inventory, health status, maintenance protocols | `g/docs/LAUNCHAGENT_REGISTRY.md` |

### Status & History

| Document | Purpose | Path |
|----------|---------|------|
| **System Status** | Current state, architecture, operational commands | `02luka.md` |
| **Changelog** | Historical updates (reverse chronological) | `g/docs/CHANGELOG.md` |
| **MLS Database** | Learning & memory system | `g/knowledge/mls_lessons.jsonl` |
| **System Health** | Real-time health dashboard | `g/run/health_dashboard.cjs` |

---

## 🚀 Quick Start (Essential Commands)

### System Health

```bash
# Check LaunchAgent health
bash "$SOT/g/tools/validate_runtime_state.zsh"

# View health dashboard
open "http://127.0.0.1:8766"

# Check all agent status
launchctl list | grep com.02luka
```

### MLS & Knowledge Base

```bash
# Search knowledge base (hybrid semantic + keyword)
node "$SOT/knowledge/index.cjs" --hybrid "your query"

# Capture MLS lesson
bash "$SOT/tools/mls_capture.zsh" \
  --type solution \
  --context "description" \
  --producer "CLC"

# Save CLC session
bash "$SOT/tools/session_save.zsh"
```

### Git Workflow

```bash
# Work in g/ submodule (operational data)
cd "$SOT/g"
git status
git pull origin master
git add -A
git commit -m "Update operational data"
git push origin master

# Update parent repo reference
cd "$SOT"
git add g  # Updates submodule pointer
git commit -m "Update g/ submodule"
git push origin main
```

---

## 📍 Path Rules (MANDATORY)

**⚠️ ALL paths MUST use `$SOT` variable (NEVER hardcode ~/02luka)**

### Environment Setup

```bash
# In ~/.zshrc or ~/.bashrc
export SOT="${HOME}/02luka"
```

### Standard Paths

```bash
# System paths (use $SOT variable)
REPO_PATH="$SOT/g"              # Governance submodule
TOOLS_PATH="$SOT/tools"         # User tools
AGENTS_PATH="$SOT/agents"       # Work order agents
KNOWLEDGE_PATH="$SOT/g/knowledge"  # MLS & knowledge base
```

**For complete path rules, see:** `g/docs/PATH_AND_TOOL_PROTOCOL.md`

---

## 🔧 Context Engineering Rules (Summary)

### Agent Capabilities

| Agent | Think | Write SOT | Scope | Token Limit |
|-------|-------|-----------|-------|-------------|
| **GG** | ✅ Yes | ✅ Yes | Governance | N/A |
| **GC** | ✅ Yes | ✅ Yes | Specs, PRPs | N/A |
| **CLC** | ✅ Yes | ✅ Yes | Code, configs | 200K/session |
| **Codex** | ✅ Yes | ⚠️ MAY (Boss override) | Code suggestions + local edits | N/A |
| **LPE** | ❌ NO | ✅ Yes (Boss-approved) | Emergency writes | N/A |
| **Kim** | ✅ Yes | ❌ NO | Orchestration | N/A |

### Fallback Ladder

```
CLC unavailable → Boss decides:
  Option A: Use LPE (log to MLS)
  Option B: Wait for new CLC session
```

**For complete rules, see:** `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`

---

## 📱 Mobile Access

**Desktop (Primary):**
```bash
$SOT  # Points to ~/02luka
```

**Mobile (Google Drive Stream):**
```bash
GD_PATH="~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"
```

**Note:** Mobile access is read-only. Use CLC on desktop for SOT writes.

---

## 🎯 For New Claude Code Sessions

**Start every session by:**

1. **Read system status:**
   ```bash
   cat "$SOT/02luka.md"  # Current state
   ```

2. **Search knowledge base first:**
   ```bash
   node "$SOT/knowledge/index.cjs" --hybrid "your question"
   ```

3. **Check protocols when needed:**
   - Agent capabilities & Boss override → `CONTEXT_ENGINEERING_PROTOCOL_v3.md` (Section 2.3)
   - Path/tool usage → `PATH_AND_TOOL_PROTOCOL.md`
   - PR workflow → `MULTI_AGENT_PR_CONTRACT.md`

4. **Follow path protocol:**
   - ✅ Use `$SOT` variable
   - ❌ Never hardcode `~/02luka`
   - ✅ Validate paths before write

5. **Log to MLS when done:**
   ```bash
   bash "$SOT/tools/session_save.zsh"
   ```

---

## 🚨 Critical Rules

### MUST (Mandatory)
- Use `$SOT` variable for all paths
- Read protocols before making architectural decisions
- Log all SOT writes to MLS (automatic via tools)
- Follow git pre-commit hooks (no hardcoded paths)
- Validate LaunchAgent scripts exist before commit

### MUST NOT (Forbidden)
- Hardcode `~/02luka` or `/Users/*/02luka` paths
- Create symlinks in SOT directories
- Bypass MLS tools (write directly to mls_lessons.jsonl)
- Commit to SOT as Codex **without Boss override** (use CLC instead, or wait for Boss authorization)
- Skip validation before file writes

### SHOULD (Recommended)
- Search knowledge base before asking questions (saves tokens)
- Use specialized tools over bash commands
- Capture learnings to MLS after solving problems
- Check health dashboard before system changes

**For enforcement mechanisms, see:** `PATH_AND_TOOL_PROTOCOL.md` Section 4

---

## 📚 Documentation Hierarchy

**When you need:**

| Information Type | Primary Source | Secondary |
|------------------|----------------|-----------|
| **Current system state** | `02luka.md` | Health dashboard |
| **Historical updates** | `g/docs/CHANGELOG.md` | MLS sessions |
| **Agent capabilities** | `CONTEXT_ENGINEERING_PROTOCOL_v3.md` | GLOBAL spec (ref only) |
| **Path/tool rules** | `PATH_AND_TOOL_PROTOCOL.md` | LaunchAgent Registry |
| **PR workflow** | `MULTI_AGENT_PR_CONTRACT.md` | PR template |
| **Past learnings** | MLS hybrid search | Session summaries |
| **LaunchAgent info** | `LAUNCHAGENT_REGISTRY.md` | Health dashboard |

---

## 🔄 Migration from v2.0.2

**What changed:**
- ❌ Removed: Hardcoded paths (~/02luka) → Use $SOT
- ❌ Removed: Roadmap progress (outdated) → See 02luka.md
- ❌ Removed: System architecture (narrative) → See protocols
- ✅ Added: Protocol references (authoritative)
- ✅ Added: RFC-style rules (MUST/SHALL/MAY)
- ✅ Added: Enforcement mechanisms

**Old content archived below for reference.**

---

---

## 📦 ARCHIVED CONTENT (v2.0.2 - 2025-11-05)

**⚠️ WARNING: Content below is OUTDATED and for reference only**

**Known issues with archived content:**
- Uses hardcoded paths (violates PATH protocol)
- Roadmap progress is stale
- No enforcement mechanisms
- Missing MLS integration
- Lacks RFC-style rules

---

### Original System Architecture (Archived)

#### Agent Types
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

#### Data Flow (Archived)
```
Scanner → WO Generation → Autopilot Approval → Executor → Telemetry → Dashboard
```

---

### Original Roadmap Progress (Archived - Stale)
- ✅ Phase 1: Local Truth Scanner (100%)
- ✅ Phase 2: R&D Autopilot (100%)
- 🟡 Phase 3: Local AI Integration (50%)
- 🟡 Phase 4: Application Slices (25%)
- ⏳ Phase 5: Agent Communication (0%)

**Note:** Roadmap status is stale. Current priorities defined in `02luka.md` and protocols.

---

### Original Troubleshooting (Archived)

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

**END OF ARCHIVED CONTENT**

For current information, always refer to the protocols and `02luka.md` above.
