# Feature Specification: /agents/** Layout Design

**Date:** 2025-11-15  
**Feature:** Design and implement standardized `/agents/**` directory structure  
**Status:** 📋 **SPEC READY FOR REVIEW**

---

## 1. Clarifying Questions

### Q1: Relationship Between /agents/ and Existing Agent Directories

**Question:** How should `/agents/**` relate to existing agent directories?

**Current State:**
- `/CLS/` - CLS core documentation and specs
- `/agents/` - Already exists with some subdirectories (cls_bridge, gpt_bridge, kim_bot, memory_hub)
- `/core/agents/` - Contains `agents.identity.json`
- `/g/tools/claude_subagents/` - Orchestrator scripts
- `/tools/claude_subagents/` - Orchestrator scripts (duplicate?)

**Options:**
- a) `/agents/` as new unified structure, migrate existing
- b) `/agents/` as read-only index/summary, keep existing locations
- c) `/agents/` as symlinks to existing locations
- d) Hybrid: Some agents in `/agents/`, others remain in place

**Default Assumption:** Option b) - `/agents/` as read-only index/summary, keep existing locations (safer, no migration risk)

### Q2: Agent Directory Structure

**Question:** What should each agent directory contain?

**Boss Requirements:**
- `/agents/andy/`
- `/agents/gg_orch/`
- `/agents/cls/`
- `/agents/clc/`
- `/agents/hybrid/`
- `/agents/subagents/`

**Options:**
- a) Each directory contains: README.md, spec.md, links to actual implementation
- b) Each directory contains: Full implementation (migrate from existing)
- c) Each directory contains: README.md only (minimal, links to real locations)

**Default Assumption:** Option a) - README.md + spec summary + links to actual implementation

### Q3: CLS Directory Content

**Question:** What should `/agents/cls/` contain specifically?

**Current CLS Location:** `/CLS/` with full documentation

**Options:**
- a) Mirror all CLS docs to `/agents/cls/`
- b) Only README.md with summary + link to `/CLS/`
- c) README.md + spec summary from `CLS_agent_latest.md`

**Default Assumption:** Option c) - README.md + spec summary from `CLS_agent_latest.md` + link to `/CLS/`

### Q4: Governance and Write Permissions

**Question:** Who can write to `/agents/**`?

**Constraints:**
- CLS cannot modify SOT zones directly (Rule 91)
- `/agents/` might be considered SOT (documentation)
- Need to avoid governance violations

**Options:**
- a) `/agents/` is read-only for CLS, only CLC/Andy can write
- b) `/agents/` is safe zone, CLS can write READMEs
- c) `/agents/` requires Work Order to CLC for changes

**Default Assumption:** Option a) - `/agents/` is read-only for CLS, only CLC/Andy can write (safer)

### Q5: Orchestrator and Subagents Location

**Question:** Where should orchestrator/subagents documentation live?

**Current Locations:**
- `/g/tools/claude_subagents/orchestrator.zsh` - Implementation
- `/tools/claude_subagents/orchestrator.zsh` - Implementation (duplicate?)
- LaunchAgent: `com.02luka.claude_subagents.plist`

**Options:**
- a) `/agents/subagents/` contains orchestrator docs + links to scripts
- b) `/agents/subagents/` contains full orchestrator implementation
- c) `/agents/subagents/` contains README only, scripts stay in tools/

**Default Assumption:** Option a) - `/agents/subagents/` contains orchestrator docs + links to scripts

---

## 2. Feature Goals

### Primary Goal
Create a standardized `/agents/**` directory structure that:
1. Provides clear index of all agents in the system
2. Links to actual agent implementations (no duplication)
3. Maintains governance compliance (read-only for CLS)
4. Serves as documentation hub for GG/Andy/other agents

### Success Criteria
- ✅ `/agents/` directory structure created
- ✅ Each agent has dedicated subdirectory with README
- ✅ CLS spec summarized in `/agents/cls/`
- ✅ Links to actual implementations maintained
- ✅ No governance violations (CLS read-only)
- ✅ Index file `/agents/README.md` created
- ✅ All agent roles documented

---

## 3. Scope

### In Scope
- Creating `/agents/**` directory structure
- Writing README.md files for each agent
- Summarizing CLS spec in `/agents/cls/`
- Creating index file `/agents/README.md`
- Documenting agent roles and relationships
- Linking to actual implementations

### Out of Scope
- Migrating actual agent implementations
- Modifying existing agent code
- Creating new agent implementations
- Modifying LaunchAgents
- Changing orchestrator scripts

---

## 4. Technical Requirements

### 4.1 Directory Structure

**Required Structure:**
```
/agents/
├── README.md                    # Index of all agents
├── andy/
│   └── README.md                # Andy agent documentation
├── gg_orch/
│   └── README.md                # GG Orchestrator documentation
├── cls/
│   └── README.md                # CLS spec summary + link to /CLS/
├── clc/
│   └── README.md                # CLC agent documentation
├── hybrid/
│   └── README.md                # Hybrid agent documentation
└── subagents/
    └── README.md                # Subagents/orchestrator documentation
```

### 4.2 Content Requirements

**Each Agent README.md Should Include:**
- Agent name and role
- Primary location (where actual implementation lives)
- Key capabilities
- Governance rules (if applicable)
- Links to detailed documentation
- Relationship to other agents

**Index README.md Should Include:**
- Overview of agent system
- Table of all agents with roles
- Quick links to each agent
- Agent interaction patterns

**CLS Specific (`/agents/cls/README.md`):**
- CLS role summary (from CLS_agent_latest.md)
- Governance rules (Rules 91-93)
- Safe zones and capabilities
- Link to `/CLS/` for full documentation
- Link to bridge tools

### 4.3 Governance Compliance

**Requirements:**
- `/agents/` is read-only for CLS (Rule 91)
- Changes must go through CLC/Andy
- No direct modifications by CLS
- Documentation only (no code changes)

---

## 5. Discovered Paths (Read-Only Scan)

### 5.1 CLS Core Paths
- `/Users/icmini/02luka/CLS/` - CLS core documentation
  - `CLS/agents/CLS_agent_latest.md` - CLS agent spec
  - `CLS/README.md` - CLS overview
  - `CLS/ENHANCEMENT_SUMMARY.md` - CLS enhancements
- `/Users/icmini/02luka/CLS.md` - CLS quick reference

### 5.2 Subagent & Orchestrator Scripts
- `/Users/icmini/02luka/g/tools/claude_subagents/orchestrator.zsh` - Main orchestrator
- `/Users/icmini/02luka/tools/claude_subagents/orchestrator.zsh` - Duplicate?
- `/Users/icmini/02luka/tools/claude_subagents/compare_results.zsh` - Comparison tool
- `/Users/icmini/02luka/tools/subagents/orchestrator.zsh` - Alternative orchestrator?

### 5.3 LaunchAgents / Services
- `~/Library/LaunchAgents/com.02luka.*.plist` - Multiple LaunchAgents
- No specific `com.02luka.claude_subagents.plist` found in scan
- LaunchAgents for various services (adaptive, autopilot, bridge, etc.)

### 5.4 Bridge / WO Integration
- `/Users/icmini/02luka/bridge/inbox/CLC/` - Work Order inbox
- `/Users/icmini/02luka/bridge/inbox/CLC/templates/` - WO templates
- No `tools/bridge_cls_clc.zsh` found (may not exist or different name)

### 5.5 Existing Agent Directories
- `/Users/icmini/02luka/agents/` - Already exists with:
  - `agents/cls_bridge/` - CLS bridge (Python)
  - `agents/gpt_bridge/` - GPT bridge (Python)
  - `agents/kim_bot/` - Kim bot (Python, shell, YAML)
  - `agents/memory_hub/` - Memory hub (Python)
- `/Users/icmini/02luka/core/agents/agents.identity.json` - Agent identity definitions

### 5.6 GG Orchestrator
- `/Users/icmini/02luka/docs/GG_ORCHESTRATOR_CONTRACT.md` - GG orchestrator contract
- Defines routing matrix, agent roles, decision flow

---

## 6. Risk & Constraints

### 6.1 Governance Constraints

**Prohibited Actions (CLS Rule 91):**
- ❌ CLS cannot modify `/agents/**` directly (if considered SOT)
- ❌ CLS cannot modify `/CLS/**` directly
- ❌ CLS cannot modify `/docs/**` directly
- ❌ CLS cannot modify `/core/**` directly

**Safe Actions:**
- ✅ CLS can read all paths for discovery
- ✅ CLS can create Work Orders to CLC for changes
- ✅ CLS can write to `memory/cls/` for documentation
- ✅ CLS can write to `g/reports/` for reports

### 6.2 Path Conflicts

**Potential Conflicts:**
- `/agents/` already exists with different structure
- Multiple orchestrator script locations (duplicates?)
- Need to avoid breaking existing functionality

**Mitigation:**
- Read-only approach (no migration)
- Link to existing locations
- Document current state before changes

### 6.3 Missing Information

**Unknowns:**
- Exact location of Andy agent implementation
- Exact location of GG orchestrator implementation
- Exact location of CLC agent implementation
- Exact location of Hybrid agent implementation
- Relationship between different orchestrator scripts

**Mitigation:**
- Document what is found
- Mark unknowns in documentation
- Allow for future updates

---

## 7. Suggested /agents Layout (Read-Only Suggestion)

### 7.1 Proposed Structure

```
/agents/
├── README.md                    # Master index
├── andy/
│   └── README.md                # TBD: Link to Andy implementation
├── gg_orch/
│   └── README.md                # Link to GG_ORCHESTRATOR_CONTRACT.md
├── cls/
│   └── README.md                # CLS spec summary + link to /CLS/
├── clc/
│   └── README.md                # TBD: Link to CLC implementation
├── hybrid/
│   └── README.md                # TBD: Link to Hybrid implementation
└── subagents/
    └── README.md                # Orchestrator docs + links to scripts
```

### 7.2 CLS Directory Content

**`/agents/cls/README.md` should contain:**
1. **CLS Role Summary**
   - Cognitive Local System Orchestrator
   - System orchestration, agent coordination, governance

2. **Governance Rules (Rules 91-93)**
   - Rule 91: Explicit allow-list (safe zones)
   - Rule 92: Work Orders for SOT changes
   - Rule 93: Evidence-based operations

3. **Capabilities**
   - Read operations (all system files)
   - Write to safe zones (bridge, memory, telemetry, logs)
   - Orchestration (tasks, monitoring, validation)
   - Evidence collection (SHA256, diffs, snapshots)

4. **Links**
   - Full spec: `/CLS/agents/CLS_agent_latest.md`
   - Overview: `/CLS/README.md`
   - Quick reference: `/CLS.md`
   - Bridge tool: `bridge/inbox/CLC/`

5. **Memory & Data**
   - Primary: `memory/cls/`
   - Audit: `g/telemetry/cls_audit.jsonl`

---

## 8. Work Items for Andy/Codex (No Action by CLS)

**Note:** CLS does not perform these actions. These are suggestions for GG/Andy.

### 8.1 Directory Creation
- [ ] Create `/agents/` directory structure
- [ ] Create subdirectories: `andy/`, `gg_orch/`, `cls/`, `clc/`, `hybrid/`, `subagents/`

### 8.2 Documentation Creation
- [ ] Create `/agents/README.md` - Master index
- [ ] Create `/agents/cls/README.md` - CLS spec summary
- [ ] Create `/agents/gg_orch/README.md` - GG orchestrator summary
- [ ] Create `/agents/subagents/README.md` - Orchestrator documentation
- [ ] Create `/agents/andy/README.md` - Andy agent documentation (TBD)
- [ ] Create `/agents/clc/README.md` - CLC agent documentation (TBD)
- [ ] Create `/agents/hybrid/README.md` - Hybrid agent documentation (TBD)

### 8.3 Content Population
- [ ] Summarize CLS spec from `CLS_agent_latest.md`
- [ ] Link to GG orchestrator contract
- [ ] Document orchestrator scripts locations
- [ ] Document agent relationships
- [ ] Add links to actual implementations

### 8.4 Verification
- [ ] Verify all links work
- [ ] Verify governance compliance
- [ ] Verify no broken references
- [ ] Test documentation readability

---

## 9. Assumptions

1. **`/agents/` is read-only for CLS** - CLS cannot modify directly
2. **Existing locations remain** - No migration of actual implementations
3. **Documentation only** - `/agents/` serves as index/documentation hub
4. **CLS spec can be summarized** - Key points from `CLS_agent_latest.md` can be extracted
5. **Other agent implementations exist** - Andy, CLC, Hybrid have implementations somewhere

---

## 10. Dependencies

1. **GG/Andy availability** - To create `/agents/` structure
2. **CLC availability** - For any SOT modifications if needed
3. **Agent implementation locations** - To create accurate links
4. **Documentation sources** - CLS spec, GG contract, etc.

---

## 11. Success Metrics

- ✅ `/agents/` directory structure created
- ✅ All 6 agent directories exist with README.md
- ✅ CLS spec summarized correctly
- ✅ All links to implementations work
- ✅ Index file provides clear overview
- ✅ No governance violations
- ✅ Documentation is readable and useful

---

**Spec Status:** 📋 **READY FOR PLAN CREATION**  
**Next Step:** Create PLAN.md with detailed task breakdown
