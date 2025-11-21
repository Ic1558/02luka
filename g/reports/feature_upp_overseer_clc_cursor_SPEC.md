# Feature Specification: UPP + Overseer + Policy + CLC Slot + Cursor Adapter

**Date:** 2025-11-19  
**Feature:** Unified Prompt Protocol (UPP) with Overseer safety layer, Policy system, CLC Slot interface, and Cursor adapter  
**Status:** 📋 **SPEC READY FOR REVIEW**

---

## 1. Clarifying Questions

### Q1: Integration Points with Existing System

**Question:** How should UPP/Overseer integrate with existing agents (Hybrid Shell, Redis, Kim, GG)?

**Current State:**
- Hybrid Shell: CLI executor via Redis pub/sub
- Kim: Telegram bot with routing
- GG: Cloud orchestrator
- Bridge system: WO pipeline with inbox/outbox

**Options:**
- a) Overseer as middleware layer (all requests go through Overseer first)
- b) Overseer as optional safety check (agents can bypass for low-risk operations)
- c) Hybrid: Required for high-risk operations, optional for safe zones

**Default Assumption:** Option c) - Hybrid approach, required for high-risk, optional for safe zones

### Q2: GM/GPT Integration Priority

**Question:** Should GM/GPT advisor be implemented immediately or left as skeleton?

**Options:**
- a) Implement immediately with Gemini 3 Pro
- b) Leave skeleton, implement later
- c) Implement with OpenAI GPT-4 as fallback

**Default Assumption:** Option b) - Leave skeleton, implement GM integration as separate phase

### Q3: CLC Slot Provider Selection

**Question:** Which provider should be default for CLC slot?

**Options:**
- a) OpenAI (Claude via API)
- b) Google (Gemini)
- c) Local (Ollama/other)
- d) Configurable via environment

**Default Assumption:** Option d) - Configurable via environment, default to OpenAI

### Q4: Cursor Integration Depth

**Question:** How deeply should Cursor integrate with UPP?

**Options:**
- a) Manual helper script only (Phase 1)
- b) Cursor extension/plugin (Phase 2)
- c) Auto-detect from Cursor chat and convert (Phase 3)

**Default Assumption:** Option a) - Manual helper script for Phase 1, deeper integration in future phases

---

## 2. Feature Goals

### Primary Goal

Create a unified protocol and safety layer system that:

1. **Unified Prompt Protocol (UPP)**: Standard task specification format for all agents
2. **Overseer**: Rule-based + GM advisor safety layer for patches/shell/UI actions
3. **Policy System**: Configurable safe zones and GM trigger policies
4. **CLC Slot**: Provider-agnostic code execution interface (not tied to Anthropic)
5. **Cursor Adapter**: Helper to convert Cursor requests to UPP format

### Success Criteria

- ✅ UPP schema defined and documented
- ✅ Overseer core implemented (rule-based + GM hooks)
- ✅ Policy loader working with YAML configs
- ✅ CLC interface supports multiple providers (skeleton)
- ✅ Cursor helper script functional
- ✅ All files in correct directory structure
- ✅ No governance violations (files in allowed zones)

---

## 3. Scope

### In Scope

- **UPP Schema**: `context/core/task_spec_schema.yaml`
- **Policy Configs**: `context/safety/safe_zones.yaml`, `context/safety/gm_policy_v4.yaml`
- **Policy Loader**: `governance/policy_loader.py`
- **Overseer Core**: `governance/overseerd.py`
- **GM Adapter**: `governance/gm_overseer_adapter.py` (skeleton)
- **CLC Interface**: `governance/clc_interface.py` (skeleton)
- **Cursor Helper**: `tools/cursor_task_spec_helper.py`

### Out of Scope (Future Phases)

- Full GM/GPT integration implementation
- Cursor extension/plugin development
- Integration with Hybrid Shell/Redis (separate task)
- Integration with Kim bot (separate task)
- Integration with GG orchestrator (separate task)
- UI action execution (Playwright/Puppeteer)
- Automated patch application

---

## 4. Technical Requirements

### 4.1 Directory Structure

**Required Structure:**
```
~/02luka/
├── context/
│   ├── core/
│   │   └── task_spec_schema.yaml
│   └── safety/
│       ├── safe_zones.yaml
│       └── gm_policy_v4.yaml
├── governance/
│   ├── policy_loader.py
│   ├── overseerd.py
│   ├── gm_overseer_adapter.py
│   └── clc_interface.py
└── tools/
    └── cursor_task_spec_helper.py
```

### 4.2 UPP Schema Requirements

**File:** `context/core/task_spec_schema.yaml`

- Define task_spec structure with all fields
- Support intents: fix-bug, refactor, add-feature, generate-file, review, run-command, ui-action, analyze
- Support output formats: unified_patch, file_replacement, plan_only
- Support apply modes: manual, auto, overseer-approved

### 4.3 Policy Requirements

**Safe Zones (`context/safety/safe_zones.yaml`):**
- Define root_project path
- Define write_allowed paths
- Define write_denied paths (system protection)
- Define allowlist_subdirs for fine-grained control

**GM Policy (`context/safety/gm_policy_v4.yaml`):**
- Define files_changed_threshold
- Define sensitive_paths list
- Define file_extensions list
- Define critical_keywords list
- Define shell_keywords list

### 4.4 Overseer Requirements

**File:** `governance/overseerd.py`

- `decide_for_shell()`: Rule-based + GM hook for shell commands
- `decide_for_patch()`: Rule-based + GM hook for file patches
- `decide_for_ui_action()`: Rule-based check for UI actions
- Return Decision objects with approval, confidence_score, reason, used_layers
- Integrate with policy_loader for configs
- Integrate with gm_overseer_adapter for advisor calls

### 4.5 GM Adapter Requirements

**File:** `governance/gm_overseer_adapter.py`

- `maybe_call_gm_for_shell()`: Skeleton for shell command advisor
- `maybe_call_gm_for_patch()`: Skeleton for patch advisor
- Return None by default (not implemented)
- Structure ready for Gemini/OpenAI integration

### 4.6 CLC Interface Requirements

**File:** `governance/clc_interface.py`

- `CLCInterface` class with provider abstraction
- Support providers: openai, google, local
- `run_code_task()` method accepting task_spec and file_slices
- Provider-specific methods (skeleton, not implemented)

### 4.7 Cursor Helper Requirements

**File:** `tools/cursor_task_spec_helper.py`

- `make_task_spec()` function to create UPP-compliant JSON
- CLI interface for manual usage
- JSON output for integration with other tools

---

## 5. Discovered Paths (Read-Only Scan)

### 5.1 Existing Governance Structure
- `/Users/icmini/02luka/governance/` - May exist or need creation
- `/Users/icmini/02luka/context/` - May exist or need creation
- `/Users/icmini/02luka/tools/` - Exists, add helper script

### 5.2 Integration Points
- `/Users/icmini/02luka/bridge/` - WO pipeline
- `/Users/icmini/02luka/tools/gg_local_llm_worker.py` - Existing LLM worker
- `/Users/icmini/02luka/tools/claude_subagents/` - Existing orchestrator

### 5.3 Policy References
- No existing policy loader found
- No existing safe zones config found
- No existing GM policy found

---

## 6. Risk & Constraints

### 6.1 Governance Constraints

**Allowed Actions:**
- ✅ Create `context/` directory (non-governance docs)
- ✅ Create files in `governance/` (policy/overseer code)
- ✅ Add helper script to `tools/`
- ✅ All files in normal_code zones

**Prohibited Actions:**
- ❌ Modify `02luka.md` (Master System Protocol)
- ❌ Modify `core/governance/**` if it exists as SOT
- ❌ Hardcode API keys in source files

### 6.2 Technical Risks

**Risk 1: Path Conflicts**
- `context/` or `governance/` may already exist with different structure
- **Mitigation:** Check existence, create if missing, document structure

**Risk 2: Policy Loader Dependencies**
- Requires PyYAML
- **Mitigation:** Document dependency, add to requirements if project has one

**Risk 3: GM Adapter Not Implemented**
- Skeleton only, no actual GM calls
- **Mitigation:** Document as Phase 1, future work clearly marked

**Risk 4: CLC Interface Not Implemented**
- Provider methods are stubs
- **Mitigation:** Document as skeleton, implementation in future phase

### 6.3 Integration Risks

**Risk 1: No Immediate Integration**
- Files created but not connected to existing agents
- **Mitigation:** Document as foundation, integration in separate task

**Risk 2: Cursor Helper Manual Only**
- No automatic Cursor integration
- **Mitigation:** Document as Phase 1, deeper integration later

---

## 7. Suggested Implementation Approach

### Phase 1: Foundation (This SPEC)
1. Create directory structure
2. Create all skeleton files
3. Implement policy_loader (YAML reading)
4. Implement overseerd.py core logic (rule-based)
5. Create Cursor helper script
6. Leave GM adapter and CLC interface as skeletons

### Phase 2: GM Integration (Future)
- Implement Gemini 3 Pro integration
- Implement OpenAI GPT-4 fallback
- Add prompt templates
- Add response parsing

### Phase 3: CLC Provider Implementation (Future)
- Implement OpenAI provider
- Implement Gemini provider
- Implement local/Ollama provider
- Add provider selection logic

### Phase 4: Agent Integration (Future)
- Integrate with Hybrid Shell
- Integrate with Redis pub/sub
- Integrate with Kim bot
- Integrate with GG orchestrator

### Phase 5: Cursor Deep Integration (Future)
- Cursor extension development
- Auto-detect and convert Cursor requests
- Real-time Overseer checks in Cursor

---

## 8. Work Items for Andy/Codex (No Action by Liam)

**Note:** Liam creates SPEC/PLAN. Andy implements.

### 8.1 Directory Creation
- [ ] Create `~/02luka/context/core/`
- [ ] Create `~/02luka/context/safety/`
- [ ] Verify/create `~/02luka/governance/`
- [ ] Verify `~/02luka/tools/` exists

### 8.2 File Creation
- [ ] Create `context/core/task_spec_schema.yaml`
- [ ] Create `context/safety/safe_zones.yaml`
- [ ] Create `context/safety/gm_policy_v4.yaml`
- [ ] Create `governance/policy_loader.py`
- [ ] Create `governance/overseerd.py`
- [ ] Create `governance/gm_overseer_adapter.py`
- [ ] Create `governance/clc_interface.py`
- [ ] Create `tools/cursor_task_spec_helper.py`

### 8.3 Implementation
- [ ] Implement policy_loader with YAML parsing
- [ ] Implement overseerd.py decision logic
- [ ] Implement Cursor helper CLI
- [ ] Add docstrings and type hints
- [ ] Add basic error handling

### 8.4 Testing
- [ ] Test policy_loader with sample YAMLs
- [ ] Test overseerd.py with sample task_specs
- [ ] Test Cursor helper script
- [ ] Verify all paths resolve correctly
- [ ] Verify no hardcoded API keys

---

## 9. Assumptions

1. **PyYAML available** - For policy_loader (or add to requirements)
2. **Python 3.8+** - For type hints and dataclasses
3. **Directories can be created** - No permission issues
4. **Skeleton is acceptable** - GM adapter and CLC interface not implemented yet
5. **Integration later** - No immediate connection to existing agents required

---

## 10. Dependencies

1. **Python standard library** - os, re, dataclasses, functools, typing
2. **PyYAML** - For YAML parsing (may need to document or add to requirements)
3. **No external API dependencies** - GM adapter and CLC interface are skeletons

---

## 11. Success Metrics

- ✅ All 8 files created in correct locations
- ✅ Directory structure matches specification
- ✅ Policy loader can read YAML configs
- ✅ Overseer can make decisions for shell/patch/UI
- ✅ Cursor helper can generate valid task_spec JSON
- ✅ No governance violations
- ✅ Code is readable and well-documented
- ✅ Skeleton structure ready for future implementation

---

**Spec Status:** 📋 **READY FOR PLAN CREATION**  
**Next Step:** Create PLAN.md with detailed task breakdown and implementation steps
