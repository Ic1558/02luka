# 02luka Repository Structure

**Version:** 2.0 - Option C (Hybrid Spine) ⭐
**Created:** 2025-10-08
**Updated:** 2025-10-08 (Option C migration complete)
**Purpose:** Definitive guide to directory organization and file placement rules

**Architecture:** Option C (Hybrid Spine)
- SOT locations: `g/reports/`, `memory/<agent>/`
- UX layers: `boss/reports/`, `boss/memory/` (auto-generated catalogs)
- Boss-only workflow: Single-pane access to all system data

---

## 🎯 Core Principle

**Every file has a home.** If you're creating a file and don't know where it goes, consult the decision tree below.

---

## 📁 Top-Level Directory Zones

### **a/** - Agent Workspace (CLC Memory & Logic)
**Purpose:** Agent-specific data, protocols, and memory systems
**Ownership:** CLC (Claude Code) agent
**Contents:**
- `a/memory/` - Shared task memory (active_tasks.json, task history)
- `a/memory_center/core/` - CLAUDE_MEMORY_SYSTEM.md (persistent learning)
- `a/section/clc/` - CLC commands, protocols, logic, current work

**When to use:** Agent configuration, memory files, delegation protocols

**Examples:**
```
a/section/clc/commands/save.sh        ← CLC save command
a/memory_center/core/CLAUDE_MEMORY_SYSTEM.md  ← Persistent lessons
a/section/clc/logic/REASONING_MODEL_EXPORT.yaml  ← Reasoning model
```

---

### **boss/** - Human Workspace (Single-Pane Workflow) ⭐ NEW
**Purpose:** Boss-only workflow with auto-generated catalogs (Option C implementation)
**Ownership:** Boss (human operator)
**Architecture:** Hybrid Spine - catalogs reference SOT locations

**Contents:**
- `boss/reports/index.md` - Auto-catalog of g/reports/ (50 latest + proof evidence)
- `boss/memory/index.md` - Auto-catalog of memory/<agent>/ (20 latest per agent)
- `boss/inbox/` - Incoming tasks/requests
- `boss/outbox/` - Completed deliverables
- `boss/sent/` - Archived sent items
- `boss/dropbox/` - Temporary file exchange
- `boss/deliverables/` - Final outputs

**When to use:** Human-facing task management, single-pane access to all system data

**Boss-Only Workflow:**
```bash
# Boss never needs to leave boss/ directory
cd boss/
cat reports/index.md    # View latest 50 reports + proof
cat memory/index.md     # View all agent sessions
make boss-refresh       # Update catalogs from SOT
```

**Catalogs updated by:** `make boss-refresh` or `scripts/generate_boss_catalogs.sh`

---

### **boss-api/** - Boss API Backend
**Purpose:** Node.js API server for Boss workspace
**Ownership:** Backend team
**Contents:**
- `boss-api/server.cjs` - Main server
- `boss-api/src/` - Source modules
- `boss-api/data/` - Runtime data

**When to use:** API implementation, server-side logic

---

### **boss-ui/** - Boss UI Frontend
**Purpose:** Vite-based React UI for Boss workspace
**Ownership:** Frontend team
**Contents:**
- `boss-ui/src/` - React components
- `boss-ui/public/` - Static assets
- `boss-ui/index.html` - UI entry point

**When to use:** UI components, frontend assets

---

### **f/** - Foundation/Framework Layer
**Purpose:** Cross-cutting concerns and bridge implementations
**Ownership:** System architecture
**Contents:**
- `f/ai_context/` - AI context management
- `f/bridge/` - Integration bridge points

**When to use:** System-wide abstractions, bridge implementations

---

### **g/** - Global/General System Tools
**Purpose:** System-level automation, tools, and operational data
**Ownership:** System operations
**Contents:**
- `g/tools/` - System automation scripts (23 files)
  - Example: `mcp_fs_server.py`, `automated_discovery_merge.sh`
- `g/reports/` - System operational reports
  - Audits, deployments, proof evidence, changelog
- `g/web/` - Web assets (HTML, CSS, JS)
- `g/fixed_launchagents/` - LaunchAgent plist sources
- `g/manuals/` - System operation manuals
- `g/tests/` - System test suites
- `g/bridges/`, `g/bridge/`, `g/connectors/` - Integration components

**When to use:** System tools, operational reports, web assets, LaunchAgents

**Examples:**
```
g/tools/clc                          ← CLC CLI tool
g/tools/automated_discovery_merge.sh ← Discovery automation
g/reports/AGENT_VALUE_AUDIT_*.json   ← Audit reports
g/reports/proof/                     ← Proof harness evidence
g/web/luka.html                      ← Web UI
g/fixed_launchagents/*.plist         ← Agent configs
```

---

### **memory/** - Per-Agent Memory SOT ⭐ NEW
**Purpose:** Single source of truth for agent session memory (Option C implementation)
**Ownership:** Per-agent (clc, gg, gc, mary, paula, codex, boss)
**Architecture:** Per-agent subdirectories with timestamped session files

**Contents:**
- `memory/clc/` - CLC (Claude Code) sessions
- `memory/gg/` - GG sessions
- `memory/gc/` - GC sessions
- `memory/mary/` - Mary sessions
- `memory/paula/` - Paula sessions
- `memory/codex/` - Codex sessions
- `memory/boss/` - Boss sessions

**When to use:** ALL agent session files (session_YYYYMMDD_HHMMSS.md)

**Pattern:**
```bash
# Sessions MUST be in memory/<agent>/, enforced by pre-commit hook
memory/clc/session_251008_030329.md  ✅
g/reports/sessions/session_*.md      ❌ (blocked by guard)
```

**Guards:** Pre-commit hook blocks session files outside memory/

---

### **scripts/** - Development & Operations Utilities
**Purpose:** Dev/ops scripts, manual utilities, one-off tools
**Ownership:** DevOps
**Contents:**
- Development setup scripts
- Utility scripts for manual operations
- Proof harness scripts
- System verification tools

**When to use:** Non-automated dev tools, manual utilities, helper scripts

**Examples:**
```
scripts/proof_harness_simple.sh      ← Proof measurement
scripts/apply_moveplan.zsh           ← File organization
scripts/verify_system.sh             ← System health check
scripts/auto_tunnel.zsh              ← Network utilities
```

**vs g/tools/:** `g/tools/` = automated system tools, `scripts/` = manual utilities

---

### **docs/** - Documentation
**Purpose:** User-facing and developer documentation
**Ownership:** Documentation team
**Contents:**
- System overviews (02luka.md, architecture.md)
- Feature documentation (AUTOSTART_CONFIG.md, TASK_BUS_SYSTEM.md)
- Deployment guides (DEPLOY.md)
- Integration instructions (MCP_*, CODEx_*)

**When to use:** Any documentation, guides, tutorials

**Examples:**
```
docs/02luka.md                ← System overview
docs/REPOSITORY_STRUCTURE.md  ← This file
docs/DEPLOY.md                ← Deployment guide
docs/TASK_BUS_SYSTEM.md       ← Feature documentation
```

---

### **config/** - Configuration Files
**Purpose:** System-wide configuration
**Ownership:** System config
**Contents:**
- `config/zones.txt` - Directory zone definitions
- `config/findability_queries.txt` - Proof harness queries

**When to use:** Non-code configuration files

---

### **contracts/** - API Contracts & Schemas
**Purpose:** API specifications, JSON schemas, contract definitions
**Ownership:** API team
**Contents:**
- Example request/response files
- MCP tool schemas
- API contract definitions

**When to use:** API contracts, JSON schemas

---

### **run/** - Runtime Data & Logs
**Purpose:** Runtime-generated data, logs, status files
**Ownership:** Runtime system
**Contents:**
- `run/auto_context/` - Auto-generated context
- `run/daily_reports/` - Daily automated reports
- `run/status/` - System status snapshots
- `run/worklog/` - Work logs
- `run/tickets/` - Ticket tracking

**When to use:** Runtime-generated data, not committed to git

---

### **gateway/** - Gateway Services
**Purpose:** API gateway and proxy services
**Ownership:** Gateway team

**When to use:** Gateway-specific implementations

---

### **setup/** - Installation & Setup Scripts
**Purpose:** First-time setup, installation automation
**Ownership:** Installation team

**When to use:** Installation scripts, bootstrap utilities

---

### **test-results/** - Test Output
**Purpose:** Playwright and other test result artifacts
**Ownership:** Test framework (auto-generated)

**When to use:** Never manually - auto-generated by test runners

---

### **.trash/** - Deleted/Backup Files
**Purpose:** Safe storage for deleted files (reversible cleanup)
**Ownership:** Cleanup system
**Contents:**
- `.trash/backup/` - Backup files (.bak, .old)
- `.trash/temp/` - Temporary files
- `.trash/conflict/` - Merge conflict files
- `.trash/YYYYMMDD_HHMM/` - Timestamped cleanup batches

**When to use:** Moving files instead of deleting (allows undo)

**Pattern:**
```bash
# Don't delete, move to trash with timestamp
mv old_file.txt .trash/backup/old_file.txt.$(date +%s)
```

---

## 🌳 Zone Hierarchy Summary

```
02luka-repo/
├── a/                    ← Agent workspace (CLC protocols, commands)
├── boss/                 ← Human workspace (catalogs + inbox/outbox) ⭐
│   ├── reports/         ← Auto-catalog: g/reports/ (50 latest) ⭐
│   └── memory/          ← Auto-catalog: memory/<agent>/ (20/agent) ⭐
├── boss-api/             ← Boss backend
├── boss-ui/              ← Boss frontend
├── f/                    ← Foundation layer
├── g/                    ← Global system tools (SOT for reports, tools)
│   ├── tools/           ← System automation (23 files)
│   ├── reports/         ← Operational reports (SOT) ⭐
│   ├── web/             ← Web assets
│   └── fixed_launchagents/ ← LaunchAgent sources
├── memory/               ← Per-agent session memory (SOT) ⭐
│   ├── clc/             ← CLC sessions (15 files) ⭐
│   ├── gg/              ← GG sessions ⭐
│   ├── gc/              ← GC sessions ⭐
│   ├── mary/            ← Mary sessions ⭐
│   ├── paula/           ← Paula sessions ⭐
│   ├── codex/           ← Codex sessions ⭐
│   └── boss/            ← Boss sessions ⭐
├── scripts/              ← Dev/ops utilities (14 files)
├── docs/                 ← Documentation
├── config/               ← Configuration
├── contracts/            ← API contracts
├── run/                  ← Runtime data
├── gateway/              ← Gateway services
├── setup/                ← Installation
├── test-results/         ← Test output
└── .trash/               ← Deleted files (reversible)

⭐ = Option C (Hybrid Spine) components
```

---

## 🧭 Decision Tree: "Where Should This File Go?"

### **Is it an agent session file (session_*.md)?** ⭐ NEW
→ `memory/<agent>/` (clc, gg, gc, mary, paula, codex, boss)
**Enforced by:** Pre-commit hook (will block commits outside memory/)

### **Is it documentation?**
→ `docs/` (user guides, system docs, architecture)

### **Is it a script?**
- **Automated system tool?** → `g/tools/`
- **Manual dev/ops utility?** → `scripts/`

### **Is it a report?**
- **System/operational report?** → `g/reports/`
- **Proof/evidence?** → `g/reports/proof/`
**Enforced by:** Pre-commit hook (will block commits outside g/reports/)

### **Is it agent-specific?**
- **CLC memory/protocols?** → `a/`
- **Agent commands?** → `a/section/clc/commands/`

### **Is it human-facing workspace?**
→ `boss/` (inbox, outbox, deliverables)

### **Is it API/backend code?**
- **Boss API?** → `boss-api/`
- **Gateway?** → `gateway/`

### **Is it frontend code?**
→ `boss-ui/`

### **Is it a web asset (HTML/CSS/JS)?**
→ `g/web/`

### **Is it configuration?**
→ `config/`

### **Is it an API contract?**
→ `contracts/`

### **Is it runtime data?**
→ `run/`

### **Is it a backup/deleted file?**
→ `.trash/backup/` or `.trash/temp/`

### **Is it a LaunchAgent plist?**
- **Source plist?** → `g/fixed_launchagents/`
- **Deployed plist?** → `~/Library/LaunchAgents/` (copied, not symlinked)

---

## ⚠️ Anti-Patterns (Don't Do This)

### **❌ Creating duplicate zones**
```
✗ Both g/reports/ and reports/ exist
✗ Both g/scripts/ and scripts/ exist with same purpose
```

### **❌ Scattered backup files**
```
✗ server.cjs.bak in boss-api/
✗ script.sh.bak in run/
→ Move to .trash/backup/
```

### **❌ Deep nesting without reason**
```
✗ g/reports/system/audit/daily/2025/10/08/report.json
✓ g/reports/AUDIT_20251008_0300.json
```

### **❌ Ambiguous directory names**
```
✗ output/   (what output?)
✗ temp/     (temporary what?)
✓ test-results/  (clear purpose)
```

### **❌ Files at root level**
Only these are allowed at root:
- Build tools: `Makefile`, `package.json`, `package-lock.json`
- Project readme: `README.md`
- Test config: `playwright.config.ts`
- Hidden configs: `.gitignore`, `.env`, `.codex/`

**Everything else** → proper zone

---

## 🔄 Migration Patterns

### **Moving files between zones**
```bash
# 1. Move file
mv old/location/file.txt new/location/file.txt

# 2. Update any references
grep -r "old/location/file.txt" .

# 3. Test affected systems
make proof && make validate

# 4. Commit with clear message
git add -A && git commit -m "refactor: move file.txt to correct zone"
```

### **Consolidating duplicate zones**
1. Choose canonical location (usually g/ for global, scripts/ for utilities)
2. Move all files to canonical location
3. Delete empty directory
4. Update references
5. Proof before/after

---

## 📊 Proof System Integration

**Before any structure changes:**
```bash
make proof  # Create baseline
```

**After changes:**
```bash
make proof  # Create comparison
diff reports/proof/BEFORE.md reports/proof/AFTER.md
```

**Metrics to track:**
- Out-of-zone files (target: <5)
- Duplicate directories (target: 0)
- Scattered backups (target: 0 outside .trash/)

---

## 🎓 Best Practices

### **1. Zone Purity**
Each zone should have ONE clear purpose. If a zone holds mixed content, split it.

### **2. Name Clarity**
Directory names should be immediately obvious:
- ✅ `g/fixed_launchagents/` (clear: LaunchAgent sources)
- ❌ `stuff/` (unclear)

### **3. Flat is Better Than Nested**
Prefer flat structure with clear naming over deep nesting:
- ✅ `g/reports/AUDIT_20251008_0300.json`
- ❌ `g/reports/audit/daily/2025-10-08/report.json`

### **4. Timestamped Artifacts**
Runtime-generated files should have timestamps:
- ✅ `session_251008_034105.md`
- ✅ `AUDIT_20251005_0248.json`
- ❌ `latest.json`

### **5. No Symlinks in CloudStorage**
**NEVER** use symlinks in SOT path (Drive Mirror mode unsafe):
```bash
❌ ln -s "$SOT_PATH/g/script.sh" ~/Library/LaunchAgents/
✅ cp -a "$SOT_PATH/g/script.sh" ~/Library/LaunchAgents/
```

---

## 🛡️ Guards & Enforcement ⭐ NEW

**Option C includes automated guards to prevent SOT violations:**

### **Pre-Commit Hook** (`.git/hooks/pre-commit`)
Three guards prevent commits that violate structure rules:

**Guard 1: Reports must live in g/reports/**
```bash
# Blocks:  reports/my_report.md
# Allows:  g/reports/my_report.md
```

**Guard 2: Sessions must live in memory/<agent>/**
```bash
# Blocks:  g/reports/sessions/session_251008_123456.md
# Blocks:  a/section/clc/session_251008_123456.md
# Allows:  memory/clc/session_251008_123456.md
```

**Guard 3: No files at root (except allowlist)**
```bash
# Allowlist: Makefile, README.md, package.json, package-lock.json,
#            playwright.config.ts, .gitignore, .gitattributes, .dockerignore
# Blocks:   my_script.sh  (at root)
# Allows:   scripts/my_script.sh
```

### **Makefile Targets**

**`make validate-zones`** - Check SOT compliance
```bash
# Scans for:
# - Reports outside g/reports/
# - Sessions outside memory/<agent>/
# Returns: ✅ or ❌ with violating files
```

**`make boss-refresh`** - Update boss catalogs
```bash
# Regenerates:
# - boss/reports/index.md  (from g/reports/)
# - boss/memory/index.md   (from memory/<agent>/)
```

---

## 📊 Structure SLA

**Service Level Agreement for Repository Structure**

### Targets

- **Out-of-zone files:** ≤ 1% of total files (or < 10 files absolute)
- **Boss findability:** Any content accessible within ≤ 2 clicks from `boss/` directory
- **Daily Proof:** Must pass; if failing, must be fixed same day

### Monitoring

```bash
make status              # Quick check: latest proof + metrics
make validate-zones      # Detailed: check all zone violations
make proof               # Full proof with all metrics
```

### Response

**If out-of-zone count exceeds SLA:**
1. Run `make tidy-plan` to generate move plan
2. Review plan at `g/reports/proof/*_MOVEPLAN.tsv`
3. Execute: `make tidy-apply`
4. Verify: `make validate-zones && make proof`

**If Daily Proof CI fails:**
1. Check GitHub Actions → Daily Proof (Option C) job
2. Download artifact `latest-proof` for details
3. Fix violations same day
4. If urgent work blocks fix, use `docs/BREAKGLASS.md` procedures

---

## 📝 Maintenance

**This document should be updated when:**
- New top-level directory is created
- Zone purpose changes
- File placement patterns evolve
- Anti-patterns are discovered

**Owner:** CLC
**Review:** After major refactoring or P-phase completion

---

**Last Updated:** 2025-10-08 (Option C migration complete)
**Version:** 2.0 - Option C (Hybrid Spine)
**Status:** ✅ Active
**Migration:** Option C critical trio deployed (memory/, boss/, guards)
