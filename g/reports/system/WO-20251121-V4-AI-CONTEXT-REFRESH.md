# V4 AI Context Refresh Work Order

**WO-ID**: WO-20251121-V4-AI-CONTEXT-REFRESH  
**Date**: 2025-11-21  
**Requester**: Liam (Deploy Impact Assessment)  
**Priority**: HIGH  
**Type**: AI Context Update

---

## Objective

Update AI context files to reflect V4 Stabilization Layer deployment and new agent capabilities.

---

## Background

V4 deployed with:
- FDE validator enforcing spec-first development
- Memory Hub API for centralized memory management
- Universal Memory Contract for all agents
- New AP/IO v4 events
- Writer policy v4 zones

AI agents need updated context to understand V4 capabilities and constraints.

---

## Files to Update

### 1. `f/ai_context/system_capabilities.json`
Add V4 capabilities:
```json
{
  "v4_enforcement": {
    "fde_validator": {
      "enabled": true,
      "rules": ["feature_development", "legacy_zone_protection", "memory_validation"],
      "enforcement_level": "blocking"
    },
    "memory_hub": {
      "api": "agents.memory_hub.memory_hub",
      "functions": ["load_memory", "save_memory"],
      "ledger_path": "g/memory/ledger/{agent}_memory.jsonl"
    },
    "universal_contract": {
      "mandatory": true,
      "agents": ["liam", "gmx"],
      "protocol": "load -> validate -> save"
    }
  }
}
```

### 2. `f/ai_context/agent_capabilities.json`
Update agent entries:
```json
{
  "liam": {
    "memory_system": "v4_universal_contract",
    "enforcement": "fde_validator",
    "capabilities": ["spec_first_development", "proof_of_use_validation"]
  },
  "gmx": {
    "memory_system": "v4_universal_contract",
    "auto_enforcement": "deploy_impact_assessment",
    "capabilities": ["work_order_planning", "auto_trigger_safeguards"]
  }
}
```

### 3. `ai_context_entry.md` (if exists)
Add V4 section:
```markdown
## V4 Stabilization Layer (2025-11-21)

**FDE Validator**: Enforces spec-first development
- Blocks writes to legacy zones (`g/g/`, `~/02luka/`)
- Requires spec/plan before code changes
- Validates feature-dev artifacts

**Memory Hub**: Centralized memory management
- API: `agents.memory_hub.memory_hub.load_memory()`, `save_memory()`
- Ledgers: `g/memory/ledger/{agent}_memory.jsonl`
- Universal Contract: All agents must load/validate/save

**V4 Events**: Extended AP/IO logging
- FDE validation events
- Memory lifecycle events
- Persona migration events
```

---

## Verification Steps

1. Verify JSON files are valid
2. Verify all V4 components documented
3. Verify agent capabilities accurately reflect V4 migration status
4. Test AI context loading with V4 updates

---

## Execution Plan

1. Locate AI context files (check `f/ai_context/`, `docs/`, `CLC/`)
2. Update or create necessary files
3. Validate JSON syntax
4. Log to AP/IO: `ai_context_refreshed`

---

**Status**: READY FOR EXECUTION
