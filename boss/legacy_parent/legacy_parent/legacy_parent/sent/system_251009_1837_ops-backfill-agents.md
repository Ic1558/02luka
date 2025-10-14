---
project: system-stabilization
tags: [ops,implementation,complete,agents,backfill]
---

# Ops Implementation: Project Backfill + Agents Spine

**Date:** 2025-10-09 18:37
**Status:** ✅ COMPLETE

## ✅ 1) Project Backfill

**Goal:** Auto-group legacy reports via keyword map → improves Boss "By Project"

### What was implemented

**Created keyword map:**
- File: `config/project_keywords.tsv`
- 3 projects defined:
  - `diplomat110` - diplomat, d110, embassy, consulate
  - `system-stabilization` - option c, hybrid spine, boss catalog, SOT, proof, guard, retention, alerts, daily proof
  - `ideo-mobi-rama9` - mobi, rama9, ideo, condo

**Backfill results:**
```
📋 Auto-mapping projects by keywords...
Using: config/project_keywords.tsv

✅ 251009_1707_ops-menu.md → system-stabilization
```

**Verified:**
- Front-matter added to `g/reports/251009_1707_ops-menu.md`
- Project field: `system-stabilization`
- Script is idempotent (safe to re-run)

### Usage

**Run backfill anytime:**
```bash
./scripts/backfill_project_by_keywords.sh
```

**Add new projects:**
Edit `config/project_keywords.tsv`:
```
project-name	keyword1|keyword2|keyword3
```

**Manual project assignment:**
Add front-matter to any report:
```yaml
---
project: your-project-name
tags: [tag1,tag2]
---
```

## ✅ 4) Agents Spine

**Goal:** Create agents/{clc,gg,gc,mary,paula}/README.md + central index for faster onboarding

### What was implemented

**Created structure:**
```
agents/
├── index.md              # Central directory
├── clc/README.md         # CLC agent (human ops & reports)
├── gg/README.md          # GG agent (research)
├── gc/README.md          # GC agent (calendar/orchestrator)
├── mary/README.md        # Mary agent
├── paula/README.md       # Paula agent
├── codex/README.md       # Codex agent (code & automation)
└── boss/README.md        # Boss agent
```

**Each agent README includes:**
- Memory link: `[memory/{agent}/](../../memory/{agent}/)`
- Scope section (template for responsibilities)
- Common commands (make mem, make boss-find)

**Central index:**
- File: `agents/index.md`
- Links to all 7 agent READMEs
- Brief descriptions of each agent's role

### Verification

**View agents directory:**
```bash
ls -la agents/
# boss/ clc/ codex/ gc/ gg/ mary/ paula/ index.md
```

**Open central index:**
```bash
cat agents/index.md
```

**Open specific agent:**
```bash
cat agents/clc/README.md
```

**Memory links work:**
- `agents/clc/README.md` → `../../memory/clc/`
- Relative paths resolve correctly from repo root

### Next steps for users

**Customize agent READMEs:**
Replace `(fill key responsibilities)` with actual scope:
```markdown
## Scope
- Execute user requests via Claude Code
- Generate reports and documentation
- Manage system operations and maintenance
- Coordinate with other agents
```

**Add agent-specific commands:**
```markdown
## Commands
- Create memo: `make mem agent=clc title="Session notes"`
- Run ops menu: `make menu`
- Check status: `make status`
```

## Files Created/Modified

**Created:**
- `config/project_keywords.tsv` - Project keyword mappings
- `scripts/init_agents_spine.sh` - Agent structure generator
- `agents/index.md` - Central agent directory
- `agents/{clc,gg,gc,mary,paula,codex,boss}/README.md` - 7 agent READMEs

**Modified:**
- `config/project_keywords.tsv` - New file (previously empty/missing)
- `g/reports/251009_1707_ops-menu.md` - Added project front-matter

## Test Commands

**Test backfill:**
```bash
./scripts/backfill_project_by_keywords.sh
# Safe to run multiple times (idempotent)
```

**Test agents spine:**
```bash
./scripts/init_agents_spine.sh
# Safe to run multiple times (skips existing files)
```

**Verify structure:**
```bash
make status
ls agents/
cat agents/index.md
```

## Integration with Boss

**Boss catalogs can now group by project:**
- Reports with `project: diplomat110` → grouped under "Diplomat110"
- Reports with `project: system-stabilization` → grouped under "System Stabilization"
- Reports without project tag → ungrouped section

**Agents spine provides:**
- Quick reference for agent responsibilities
- Direct links to agent memory directories
- Common commands for agent operations

## Production Readiness

- ✅ Project keywords defined (3 projects)
- ✅ Backfill script tested and verified
- ✅ Agents spine structure created (7 agents)
- ✅ Central index with navigation
- ✅ Memory links functional
- ⏸️ Agent READMEs need customization (user task)

## Commit Details

```
feat(ops): project backfill + agents spine (Option C)

- Created config/project_keywords.tsv with 3 project definitions
- Backfilled project front-matter to existing reports
- Created agents/ directory structure with 7 agent READMEs
- Added agents/index.md central directory
- Created scripts/init_agents_spine.sh generator (idempotent)

Related: ops menu options 1 + 4
```

## Remaining Options

From original ops menu:

**5) Boss daily HTML view** - Auto-generate views/ops/daily/index.html with latest 10 reports + 10 memory (links only) - open in browser for quick scans

**Select option:** Reply with `5` to implement Boss daily HTML view, or `done` to wrap up.
