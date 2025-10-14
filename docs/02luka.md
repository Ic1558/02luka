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

**Latest:** v251015_0212_atomic_phase4 (Atomic Operations Phase 4 + Linear-lite UI)

| Tag | Date | Description |
|-----|------|-------------|
| v251015_0212_atomic_phase4 | 2025-10-15 | Phase 4 MCP Verification + Linear-lite UI + stub mode |
| v251011_1845_domain_migration | 2025-10-11 | Dashboard deployment to Cloudflare Pages |
| v2025-10-06-mcp-autostart | 2025-10-06 | MCP FS + Task Bus auto-start deployed |
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

**Tag:** v251011_1845_domain_migration

---

## 11) Latest Deployment (2025-10-15)

**Atomic Operations Phase 4 + Linear-lite UI** ✅

### Phase 4: MCP Verification Integration
- **Script:** `run/ops_atomic.sh` now includes 4 phases (was 3)
- **Automation:** Phase 4 extracts MCP test results from existing verification reports
- **Fallback:** Live health check if no report available
- **Metrics Tracked:** Container status, uptime, connectivity, tools, OAuth status
- **Report Example:** `g/reports/OPS_ATOMIC_251015_021806.md`

### Linear-lite UI Integration
- **Multipage Serving:** boss-api now serves UI directly on port 4000
- **Routes Added:** `/`, `/chat`, `/plan`, `/build`, `/ship`
- **Static Assets:** `/shared/ui.css`, `/shared/api.js`, `/shared/components.js`
- **Benefits:** Single-origin serving eliminates CORS issues
- **Architecture:** Express static middleware + page routing

### API Enhancements
- **Stub Mode:** `/api/plan` supports fast health checks via `stub:true` or `X-Smoke: 1` header
- **Reports API:** `/api/reports/list`, `/api/reports/latest`, `/api/reports/summary`
- **Response Time:** Stub mode returns in <100ms for smoke tests
- **Schema Fix:** `/api/plan` now correctly uses `goal` field (not `prompt`)

### Smoke Testing Improvements
- **Timeout Support:** All tests now have configurable timeouts (3-10s)
- **Fast Testing:** Stub mode enables complete test suite in ~3 seconds
- **Coverage:** 5 critical tests (API, UI, MCP) + 3 optional (agents, Paula)
- **CI Ready:** No false failures, clear PASS/WARN/FAIL categorization

### Key Commits
- `[pending]` - Phase 4: MCP Verification integration
- `[pending]` - Linear-lite UI routing in boss-api
- `[pending]` - Stub mode for /api/plan
- `[pending]` - Smoke test timeout fixes

### Reports
- Phase 4 integration: `g/reports/251015_0118_phase4_mcp_integration.md`
- Atomic operations: `g/reports/OPS_ATOMIC_251015_021806.md`
- Documentation updates: (this file)

**Tag:** v251015_0212_atomic_phase4

---

Last Session: 251015_021237
