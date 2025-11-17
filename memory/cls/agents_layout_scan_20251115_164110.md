# CLS Feature-Dev Scan: agents-layout

**Date:** 2025-11-15  
**Runner:** CLS  
**Status:** ✅ **SCAN COMPLETE**

## Summary

Comprehensive scan of paths and files related to CLS/subagents/orchestrator completed. Information prepared for GG/Andy to safely design `/agents/**` structure.

## Discovered Paths

### CLS Core Paths
- `/Users/icmini/02luka/CLS/` - CLS core documentation
- `/Users/icmini/02luka/CLS/agents/CLS_agent_latest.md` - CLS agent spec
- `/Users/icmini/02luka/CLS.md` - CLS quick reference

### Subagent & Orchestrator Scripts
- `/Users/icmini/02luka/g/tools/claude_subagents/orchestrator.zsh` - Main orchestrator
- `/Users/icmini/02luka/tools/claude_subagents/orchestrator.zsh` - Duplicate?
- `/Users/icmini/02luka/tools/claude_subagents/compare_results.zsh` - Comparison tool

### Existing Agent Directories
- `/Users/icmini/02luka/agents/` - Already exists with:
  - `agents/cls_bridge/` - CLS bridge (Python)
  - `agents/gpt_bridge/` - GPT bridge (Python)
  - `agents/kim_bot/` - Kim bot
  - `agents/memory_hub/` - Memory hub

### GG Orchestrator
- `/Users/icmini/02luka/docs/GG_ORCHESTRATOR_CONTRACT.md` - GG contract

### Other Agent Configs
- `/Users/icmini/02luka/config/agents/andy.yaml` - Andy agent config
- `/Users/icmini/02luka/core/agents/agents.identity.json` - Agent identities

## Risk & Constraints

- ❌ CLS cannot modify `/agents/**` directly (governance)
- ❌ CLS cannot modify `/CLS/**` directly
- ✅ CLS can read all paths for discovery
- ✅ CLS can create Work Orders to CLC

## Suggested /agents Layout

Proposed structure (read-only suggestion for GG/Andy):

```
/agents/
├── README.md                    # Master index
├── andy/                        # Andy agent
├── gg_orch/                     # GG Orchestrator
├── cls/                         # CLS (summary + link to /CLS/)
├── clc/                         # CLC agent
├── hybrid/                      # Hybrid agent
└── subagents/                   # Subagents/orchestrator
```

## Work Items for Andy/Codex

- [ ] Create /agents/ structure
- [ ] Create README.md files
- [ ] Mirror CLS spec summary
- [ ] Create index file

CLS does not perform these - suggestions only.

---
**Scan Status:** ✅ Complete  
**SPEC Created:** g/reports/feature_agents_layout_SPEC.md  
**PLAN Created:** g/reports/feature_agents_layout_PLAN.md
