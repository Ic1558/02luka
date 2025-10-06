# 02LUKA – System Overview (Cursor + CLC)

## 1) Dual Memory System (Cursor ↔ CLC)
- **Cursor AI Memory**: `.codex/hybrid_memory_system.md`  
- **CLC Memory (SOT)**: `a/section/clc/memory/`  
- **Memory Bridge**: `.codex/codex_memory_bridge.yml` (mode: `mirror-latest`, `selective-merge`)  
- **Autosave Engine**: `.codex/autosave_memory.sh` → `g/reports/memory_autosave/autosave_*.md`

### How it works
1. Edit docs in repo → commit → pre-commit triggers autosave & (optional) write-through.
2. Pre-push gate (preflight + mapping + smoke) ต้องผ่านก่อนขึ้น remote.
3. Memory bridge sync ระหว่าง Cursor/CLC ตาม `mirror-latest`.

---

## 2) CLC Reasoning Model v1.1 (Unified)
- **Spec**: `a/section/clc/logic/REASONING_MODEL_EXPORT.yaml`  
- **Linked in Hybrid Memory**: `.codex/hybrid_memory_system.md` → `reasoning_model.import`  
- **Pipeline (7 steps)**: observe_context → expand_constraints → plan → act_small → self_check → reflect_and_trim → finalize_or_iterate (≤2)  
- **Rubric**: solution_fit / safety / maintainability / observability  
- **Anti-patterns**: Duct Taper, Box Ticker, Goons/Flunkies, Path Confusion  
- **Playbooks**: morning routine, LaunchAgents fix, memory sync  
- **Failure Modes**: API:4000, UI:5173, shebang/perm, Drive placeholder

**Starter prompt (Cursor):**

Use 02LUKA CLC Reasoning v1.1.
GOAL: Add a small, reversible improvement.
ACCEPTANCE: preflight OK, smoke OK, report in g/reports/, atomic patch only.
Follow pipeline v1.1; template: pt-small-safe-change.
Output: heredoc patch + apply/rollback commands.

---

## 3) Morning Routine (one-liner)
```bash
# Auto-start components (MCP FS + Task Bus) already running after login
bash ./.codex/preflight.sh && bash ./run/dev_up_simple.sh && bash ./run/smoke_api_ui.sh
```

**Smoke test verifies:** API (4000), UI (5173), MCP FS (8765/health)

---

## 4) Runtime Path Rules (Important)
- ✅ ใช้: `~/dev/02luka-repo` หรือ `/workspaces/02luka-repo`
- ❌ ห้าม runtime บน CloudStorage (Stream/Mirror) เช่น `/Library/CloudStorage/GoogleDrive-*/My Drive/*`
- ✅ LaunchAgents logs → `~/Library/Logs/02luka/{label}.(out|err)`

---

## 5) Policy Packs
- **Drive**: `a/section/clc/logic/policies/drive.yaml`
- **LaunchAgents**: `a/section/clc/logic/policies/launchagents.yaml`
- **Guard CLI**: `g/tools/policy_guard.sh` (advisory in pre-push)

---

## 6) CLC ↔ Cursor Coordination (Auto-Start)

**Status:** ✅ Both components auto-start on login

### MCP FS Server
- **PID:** Auto-assigned (LaunchAgent: `com.02luka.mcp.fs`)
- **Port:** 8765 (SSE transport)
- **Tools:** `read_text`, `list_dir`, `file_info`
- **Root:** SOT path (`$FS_ROOT`)
- **Health:** `http://127.0.0.1:8765/health`
- **Logs:** `/tmp/mcp_fs_py.{out,err,log}`

### Task Bus Bridge
- **PID:** Auto-assigned (LaunchAgent: `com.02luka.task.bus.bridge`)
- **Redis:** `mcp:tasks` channel
- **Memory:** `~/dev/02luka-repo/a/memory/active_tasks.{json,jsonl}`
- **Logs:** `~/Library/Logs/02luka/task_bus_bridge.{out,err,log}`

### Quick Usage
```bash
# Publish event (CLC or Cursor)
bash g/tools/emit_task_event.sh clc my_action started "context"

# Read events (Cursor via MCP)
read_text('a/memory/active_tasks.json')

# Manual control
launchctl kickstart -k gui/$UID/com.02luka.mcp.fs
launchctl kickstart -k gui/$UID/com.02luka.task.bus.bridge
```

**Documentation:** `AUTOSTART_CONFIG.md`, `TASK_BUS_SYSTEM.md`

---

## 7) Checkpoints & Tags

**Latest:** v2025-10-06-mcp-autostart (MCP FS + Task Bus auto-start deployed)

| Tag | Date | Description |
|-----|------|-------------|
| v2025-10-05-cursor-ready | 2025-10-05 | DevContainer ready, preflight OK |
| v2025-10-05-stabilized | 2025-10-05 | System stabilized, audit + boot guard |
| v2025-10-05-docs-stable | 2025-10-05 | Dual Memory + docs unified |
| v2025-10-04-locked | 2025-10-04 | Dual Memory locked baseline |

**Use:**
```bash
git fetch --tags
git checkout v2025-10-05-docs-stable     # read-only
git checkout main && git pull            # back to latest
```

---

## 8) Verification Quicklinks
- **Reasoning wire report**: `g/reports/REASONING_MODEL_WIRE_*.md`
- **Policy applied report**: `g/reports/POLICY_PACKS_APPLIED_*.md`
- **Memory autosave**: `g/reports/memory_autosave/autosave_*.md`

Last Session: 251006_032355
