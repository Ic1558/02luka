# 02luka Agent System

**Last Updated:** 2025-11-15  
**Purpose:** Documentation hub and index for all agents in the 02luka system

---

## Overview

This directory serves as a documentation hub and index for all agents in the 02luka system. Each agent has a dedicated subdirectory with documentation linking to actual implementations.

**Note:** This is a documentation/index layer only. Actual agent implementations remain in their original locations.

---

## Agents

| Agent | Role | Main Implementation | Docs |
|-------|------|---------------------|------|
| **Andy** | Dev Agent (Codex worker) | `config/agents/andy.yaml` (config), code TBD | [Andy README](andy/README.md) |
| **GG-Orchestrator** | System orchestrator contract | `docs/GG_ORCHESTRATOR_CONTRACT.md` | [GG README](gg_orch/README.md) |
| **CLS** | Cognitive Local System | `/CLS/`, `/CLS/agents/CLS_agent_latest.md` | [CLS README](cls/README.md) |
| **CLC** | Privileged patcher | `/CLC/**` (not to be modified) | [CLC README](clc/README.md) |
| **Hybrid** | Luka/Hybrid CLI agent | (paths TBD, use what SPEC/scan found) | [Hybrid README](hybrid/README.md) |
| **Subagents** | Claude subagents orchestrator | `g/tools/claude_subagents/orchestrator.zsh` | [Subagents README](subagents/README.md) |

---

## Agent Roles

### CLS (Cognitive Local System Orchestrator)
- **Role:** System orchestration, agent coordination, governance enforcement
- **Capabilities:** Read operations, safe zone writes, orchestration, evidence collection
- **Governance:** Rules 91-93 (explicit allow-list, Work Orders, evidence-based)
- **Documentation:** [CLS README](cls/README.md)

### GG (System Orchestrator)
- **Role:** System orchestrator, overseer, auditor
- **Capabilities:** Task classification, routing, prompt/contract creation, governance checking
- **Documentation:** [GG README](gg_orch/README.md)

### Andy (Dev Agent / Codex Worker)
- **Role:** Dev Agent (Codex worker) for code implementation, fixes, and PR changes
- **Capabilities:** Code generation, review, refactoring, testing, deployment, PR implementation
- **Documentation:** [Andy README](andy/README.md)

### CLC (Claude Code Agent)
- **Role:** Claude Code agent for privileged operations
- **Capabilities:** SOT modifications, governance changes, privileged execution
- **Documentation:** [CLC README](clc/README.md)

### Hybrid (Luka/Hybrid CLI Agent)
- **Role:** CLI agent for executing system commands, Redis operations, Docker, LaunchAgents
- **Capabilities:** Shell commands, Redis pub/sub, Docker management, service control
- **Documentation:** [Hybrid README](hybrid/README.md)

### Subagents (Subagent Orchestrator)
- **Role:** Coordinate multiple subagents for parallel tasks
- **Capabilities:** Orchestration, result aggregation, strategy execution
- **Documentation:** [Subagents README](subagents/README.md)

---

## Agent Relationships

**High-Level Flow:**
```
Boss
  └── GG (Orchestrator)
       ├── CLS (System Orchestrator)
       │    └── CLC (Privileged Operations)
       ├── Andy (Coding Assistant)
       ├── Hybrid (CLI Operations)
       └── Subagents (Parallel Execution)
```

**Interaction Patterns:**
- **GG → CLS:** System orchestration tasks, governance enforcement, code review
- **GG → Andy:** Code implementation, review, debugging, testing tasks
- **CLS → CLC:** SOT modifications via Work Orders (bridge/inbox/CLC/)
- **GG → Hybrid:** CLI operations, Redis, Docker, launchctl commands
- **Subagents:** Parallel execution for code review, testing, validation
- **GG → Codex:** Direct code changes in allowed zones (via PR prompts)

---

## Quick Links

- [CLS Documentation](cls/README.md) - System orchestrator
- [GG Orchestrator](gg_orch/README.md) - Task routing and orchestration
- [Andy Agent](andy/README.md) - Coding assistant
- [CLC Agent](clc/README.md) - Privileged operations
- [Hybrid Agent](hybrid/README.md) - CLI operations
- [Subagents/Orchestrator](subagents/README.md) - Parallel execution

---

## Governance

**Important:** This directory is a documentation hub only. Actual agent implementations remain in their original locations:

- **CLS:** `/CLS/` - Full CLS documentation and specs
- **GG:** `docs/GG_ORCHESTRATOR_CONTRACT.md` - GG orchestrator contract
- **Andy:** `config/agents/andy.yaml` - Andy agent configuration
- **Subagents:** `g/tools/claude_subagents/orchestrator.zsh` - Orchestrator implementation

**Modifications:**
- CLS cannot modify this directory directly (governance Rule 91)
- Changes must go through CLC/Andy
- This is read-only documentation for CLS

---

## Maintenance

**Updating Documentation:**
1. Identify which agent documentation needs update
2. Create Work Order to CLC if SOT modification needed
3. Update relevant README.md file
4. Verify links still work

**Adding New Agents:**
1. Create new subdirectory: `/agents/<agent_name>/`
2. Create `README.md` with agent documentation
3. Update this index file
4. Add to agent table above

---

**Created:** 2025-11-15  
**Created By:** Andy (with CLS assistance)  
**Source:** `g/reports/feature_agents_layout_SPEC.md` and `g/reports/feature_agents_layout_PLAN.md`
