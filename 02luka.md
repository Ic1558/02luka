# 02LUKA – System Overview (Cursor + CLC)

## 0) Quick System Verification

**Use this section to double-check what's actually running**

### ✅ 30-Second Health Check
```bash
# Check services
lsof -i :4000 -i :5173 -i :8765 2>/dev/null | grep LISTEN

# Expected:
# Python   ... TCP localhost:ultraseek-http (LISTEN)  ← Port 4000: MCP FS Server
# node     ... TCP localhost:terabase (LISTEN)        ← Port 8765: Boss API
# Python   ... TCP localhost:5173 (LISTEN)            ← Port 5173: UI Server

# Check workflows
gh workflow list | head -3
# Expected: 10 active workflows including "OPS Monitoring"

# Check automation
launchctl list | grep -i 02luka | wc -l
# Expected: ~36 LaunchAgents running
```

### 🏗️ Current System Architecture (2025-10-17)

**Services Running:**
| Port | Service | Process | Status |
|------|---------|---------|--------|
| 4000 | MCP FS Server | `mcp_fs_server.py` | ✅ Running |
| 8765 | Boss API | `node server.cjs` | ✅ Running |
| 5173 | UI Server | `python -m http.server` | ✅ Running |

**GitHub Actions (10 Workflows):**
- ✅ OPS Monitoring (scheduled every 6h) - Last run: 2025-10-16 18:36 (success)
- ✅ CI (on push/PR)
- ✅ Auto Update PR branches (on main push)
- ✅ Deploy Dashboard (manual/scheduled)
- ✅ Daily Proof (Option C)
- ✅ Deploy to GitHub Pages

**Automation:**
- 36 LaunchAgents providing background automation
- SOT rendering every 12h
- MCP FS Server auto-start on login

**Pipeline Flow:**
```
Entry → Claude Code/Web UI/GitHub Actions → Processing (MCP/API/ops_atomic.sh) → Output (Reports/Artifacts/Discord)
```

**Detailed Verification:** See `SYSTEM_VERIFICATION.md` for complete commands

---

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

## 3a) Phase 4 – MCP Verification + Linear-lite UI

- **Verification Trigger:** `curl -X POST http://127.0.0.1:4000/api/mcp/verify -d '{"providers":["fs","docker"]}'`.
- **Verification Status Panel:** Luka dashboard → _Ops → MCP_ uses `/api/mcp/verify/status` to render freshness badges.
- **Linear-lite Inbox:** New sidebar tile pulling `/api/linear-lite/cards` (active + triage states) every 90 seconds.
- **Sync Command:** `curl -X POST http://127.0.0.1:4000/api/linear-lite/sync -H "Content-Type: application/json" -d '{"broadcast":true}'`.
- **Reporting:** Automation drops receipts into `g/reports/mcp_verify/` and `g/reports/linear-lite/` with matching runIds.
- **Guardrail:** Preflight now fails if MCP verification older than 15 minutes or Linear-lite cache stale (>30 minutes).

**Operational Notes:**
1. `run/smoke_api_ui.sh` now includes MCP verification + Linear-lite smoke stages (warnings only if upstream offline).
2. LaunchAgents auto-refresh the Linear-lite cache hourly; manual `sync` only needed for urgent card refreshes.
3. Boss UI now surfaces MCP drift alerts sourced from the verification endpoint.

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

**Latest:** v2025-10-15-phase4-mcp-linear-lite (MCP verification + Linear-lite UI promoted)

| Tag | Date | Description |
|-----|------|-------------|
| v2025-10-15-phase4-mcp-linear-lite | 2025-10-15 | Phase 4 verification + Linear-lite dashboard shipped |
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

## 8) Repository Structure (Option C: Hybrid Spine) ⭐

**Architecture:** Option C (Hybrid Spine) - SOT + UX layers
**Documentation:** `docs/REPOSITORY_STRUCTURE.md` (v2.0 - comprehensive guide)
**Zone Definitions:** `config/zones.txt` (updated 2025-10-08)

### **Boss-Only Workflow** (Single-Pane Access) ⭐
```bash
# Boss works from boss/ only - never needs to navigate system
cd boss/

# View all reports (50 latest + proof evidence)
cat reports/index.md

# View all agent sessions (20 latest per agent)
cat memory/index.md

# Refresh catalogs after system changes
make boss-refresh
```

**Catalogs auto-update from SOT locations:**
- `boss/reports/index.md` ← aggregates `g/reports/` (50 latest)
- `boss/memory/index.md` ← aggregates `memory/<agent>/` (20/agent)

### **Core Zones:**
- **memory/<agent>/** - Per-agent session SOT (clc, gg, gc, mary, paula, codex, boss) ⭐
- **boss/** - Human workspace (catalogs + inbox/outbox) ⭐
- **a/** - Agent workspace (CLC protocols, commands, logic)
- **g/reports/** - System reports SOT (operational data, proof) ⭐
- **g/tools/** - System automation tools
- **scripts/** - Dev/ops utilities (manual tools, proof harness)
- **docs/** - Documentation (all user + developer guides)
- **.trash/** - Backups & deleted files (organized: backup/, temp/, conflict/)

### **Guards & Enforcement** ⭐
- **Pre-commit hook:** Blocks reports outside `g/reports/`
- **Pre-commit hook:** Blocks sessions outside `memory/<agent>/`
- **Pre-commit hook:** Blocks files at root (except allowlist)
- **Makefile:** `make validate-zones` checks SOT compliance

**Decision Tree:** See `docs/REPOSITORY_STRUCTURE.md` → "Where Should This File Go?"

**Migration Complete (2025-10-08):**
- ✅ Option C critical trio deployed (memory/, boss/, guards)
- ✅ 15 sessions moved: g/reports/sessions/ → memory/clc/
- ✅ Boss catalogs auto-generated from SOT locations
- ✅ Pre-commit guards prevent SOT violations
- ✅ Consolidated 3 report locations → 1 (`g/reports/`)
- ✅ Consolidated 2 script locations → 1 (`scripts/`)
- ✅ Moved 11 scattered .bak files → `.trash/backup/`
- ✅ Removed 3 empty directories (backups/, output/, g/reports/sessions/)

**Proof Evidence:**
- Structure consolidation: `g/reports/STRUCTURE_IMPROVEMENT_251008_0353.md`
- Option C deployment: `g/reports/proof/251008_1229_proof.md` (1273 files, 5 out-of-zone)

---

## 9) Verification Quicklinks
- **Reasoning wire report**: `g/reports/REASONING_MODEL_WIRE_*.md`
- **Policy applied report**: `g/reports/POLICY_PACKS_APPLIED_*.md`
- **Memory autosave**: `g/reports/memory_autosave/autosave_*.md`
- **Structure improvement**: `g/reports/STRUCTURE_IMPROVEMENT_251008_0353.md`
- **Proof baseline**: `g/reports/proof/251008_0353_proof.md`

---

## 10) Latest Deployment (2025-10-11)

**Dashboard Deployment to Cloudflare Pages** ✅

### Infrastructure
- **Boss-UI Dashboard**: https://dashboard.theedges.work (Cloudflare Pages)
- **Boss-UI (alternate)**: https://theedges-dashboard.pages.dev
- **n8n Workflow**: https://n8n.theedges.work (Cloudflare Tunnel)

### Deployment Features
- OAuth authentication for Cloudflare API
- Automated deployment script: `scripts/deploy_dashboard.sh`
- Health check endpoints: `/healthz`, `/api/smoke`
- Complete API documentation: `docs/api_endpoints.md`
- CI/CD workflow: `.github/workflows/deploy_dashboard.yml`

### Key Commits
- `67c83ed` - OAuth authentication in deploy script
- `8fc8291` - /api/smoke endpoint + API docs
- `eff81c5` - Git conflict resolution (api.js merge)
- `4e7db50` - Deployment reports

### Reports
- Dashboard deployment: `g/reports/deploy/dashboard_20251011_190534.md`
- Domain migration: `g/reports/deploy/domain_migration_20251011_184500.md`
- MCP verification receipts: `g/reports/mcp_verify/verify-20251015-*.json`
- Linear-lite sync receipts: `g/reports/linear-lite/sync-20251015-*.json`

**Tag:** v251011_1845_domain_migration → superseded by `v251015_phase4_release`

---

## 11) Latest Deployment (2025-10-17)

**GitHub Actions CI/CD Integration** ✅

### Automated OPS Monitoring
- **Workflow**: `.github/workflows/ops-monitoring.yml`
- **Schedule**: Every 6 hours (00:00, 06:00, 12:00, 18:00 UTC)
- **Manual Trigger**: workflow_dispatch enabled
- **Timeout**: 15 minutes
- **Artifacts**: 30-day retention (OPS_ATOMIC_*.md, OPS_SUMMARY.json)

### Critical Bug Fixes
- Fixed TypeError in `.github/workflows/auto-update-pr.yml` (line 24)
- Fixed TypeError in `.github/workflows/auto-update-branch.yml` (line 23)
- Root cause: github-script v7 API change (`github.pulls.list` → `github.rest.pulls.list`)

### Documentation
- Manual: `g/manuals/ops_monitoring_cicd.md` (439 lines)
- Deployment report: `g/reports/DEPLOYMENT_GITHUB_ACTIONS_251017.md`

### Key Features
- ✅ Mock API server provisioning for CI health checks
- ✅ PASS/WARN/FAIL status parsing from OPS_SUMMARY.json
- ✅ Workflow fails if OPS status is "fail"
- ✅ Optional Discord notifications (requires DISCORD_WEBHOOK_DEFAULT secret)
- ✅ Auto-update workflows now operational (PR branch sync restored)

### Key Commits
- `4661cea` - OPS monitoring workflow + manual
- `13232e4` - Fixed github-script API compatibility

**Verification:** Run #7 succeeded with status: "completed", conclusion: "success"

**Tag:** (pending) v251017_cicd_ops_monitoring

---

Last Session: 251017_0429
