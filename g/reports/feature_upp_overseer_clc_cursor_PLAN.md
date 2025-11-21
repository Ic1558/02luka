# Feature Plan: UPP + Overseer + Policy + CLC Slot + Cursor Adapter

**Date:** 2025-11-19  
**Feature:** Unified Prompt Protocol (UPP) with Overseer safety layer, Policy system, CLC Slot interface, and Cursor adapter  
**Status:** 📋 **PLAN READY FOR EXECUTION**

---

## Executive Summary

Create a unified protocol and safety layer system foundation. This is Phase 1: skeleton implementation with rule-based Overseer, policy system, and helper tools. GM integration and CLC provider implementation are deferred to future phases.

**Estimated Time:** 3-4 hours  
**Priority:** High (foundation for agent safety)  
**Risk Level:** Low (skeleton implementation, no external dependencies)

---

## Task Breakdown

### Phase 1: Directory Structure Setup (15 min)

**Task 1.1: Create Context Directories**
- **Status:** 🔄 Pending
- **Action:**
  - Create `~/02luka/context/core/`
  - Create `~/02luka/context/safety/`
  - Verify permissions and structure
- **Deliverable:** Directory structure created
- **Time:** 5 min

**Task 1.2: Verify/Create Governance Directory**
- **Status:** 🔄 Pending
- **Action:**
  - Check if `~/02luka/governance/` exists
  - Create if missing
  - Verify it's not a forbidden SOT zone
- **Deliverable:** Governance directory ready
- **Time:** 5 min

**Task 1.3: Verify Tools Directory**
- **Status:** 🔄 Pending
- **Action:**
  - Verify `~/02luka/tools/` exists
  - Confirm write permissions
- **Deliverable:** Tools directory confirmed
- **Time:** 5 min

---

### Phase 2: UPP Schema & Policy Configs (30 min)

**Task 2.1: Create UPP Schema YAML**
- **Status:** 🔄 Pending
- **Action:**
  - Create `context/core/task_spec_schema.yaml`
  - Include all fields from Boss specification:
    - task_spec structure (id, source, intent, target_files, command, ui_action, context, output)
    - Intent types: fix-bug, refactor, add-feature, generate-file, review, run-command, ui-action, analyze
    - Output formats: unified_patch, file_replacement, plan_only
    - Apply modes: manual, auto, overseer-approved
  - Add comments explaining each field
- **Deliverable:** UPP schema file
- **Time:** 10 min

**Task 2.2: Create Safe Zones Config**
- **Status:** 🔄 Pending
- **Action:**
  - Create `context/safety/safe_zones.yaml`
  - Set root_project: "/Users/icmini/02luka"
  - Define write_allowed paths
  - Define write_denied paths (system protection)
  - Define allowlist_subdirs
- **Deliverable:** Safe zones configuration
- **Time:** 10 min

**Task 2.3: Create GM Policy Config**
- **Status:** 🔄 Pending
- **Action:**
  - Create `context/safety/gm_policy_v4.yaml`
  - Define gm_trigger_policy with:
    - files_changed_threshold: 2
    - sensitive_paths list
    - file_extensions list
    - critical_keywords list
    - shell_keywords list
  - Add comments explaining trigger conditions
- **Deliverable:** GM policy configuration
- **Time:** 10 min

---

### Phase 3: Policy Loader Implementation (45 min)

**Task 3.1: Create Policy Loader Module**
- **Status:** 🔄 Pending
- **Action:**
  - Create `governance/policy_loader.py`
  - Implement SafeZones dataclass
  - Implement GmPolicy dataclass
  - Implement `load_safe_zones()` with @lru_cache
  - Implement `load_gm_policy()` with @lru_cache
  - Add error handling for missing files
  - Add type hints
- **Deliverable:** Policy loader module
- **Time:** 30 min

**Task 3.2: Test Policy Loader**
- **Status:** 🔄 Pending
- **Action:**
  - Create simple test script or manual verification
  - Test loading safe_zones.yaml
  - Test loading gm_policy_v4.yaml
  - Verify caching works
  - Verify error handling for missing files
- **Deliverable:** Policy loader tested
- **Time:** 15 min

---

### Phase 4: Overseer Core Implementation (90 min)

**Task 4.1: Create Overseer Module Structure**
- **Status:** 🔄 Pending
- **Action:**
  - Create `governance/overseerd.py`
  - Import policy_loader
  - Create TaskSpec dataclass
  - Create Decision dataclass
  - Add helper functions: `_normalize_path()`, `_is_path_allowed()`, `_matches_any()`
- **Deliverable:** Overseer module structure
- **Time:** 20 min

**Task 4.2: Implement decide_for_shell()**
- **Status:** 🔄 Pending
- **Action:**
  - Implement hard-block patterns (rm -rf /)
  - Implement path safety checks
  - Implement GM trigger by keywords
  - Call gm_overseer_adapter.maybe_call_gm_for_shell()
  - Return Decision objects
  - Add comprehensive comments
- **Deliverable:** Shell command decision logic
- **Time:** 25 min

**Task 4.3: Implement decide_for_patch()**
- **Status:** 🔄 Pending
- **Action:**
  - Implement zone checks for all changed files
  - Implement GM trigger by file count
  - Implement GM trigger by sensitive paths
  - Implement GM trigger by file extensions
  - Implement GM trigger by critical keywords
  - Call gm_overseer_adapter.maybe_call_gm_for_patch()
  - Return Decision objects
- **Deliverable:** Patch decision logic
- **Time:** 30 min

**Task 4.4: Implement decide_for_ui_action()**
- **Status:** 🔄 Pending
- **Action:**
  - Implement conservative keyword checks
  - Check for destructive actions (delete, remove, etc.)
  - Return Decision objects
- **Deliverable:** UI action decision logic
- **Time:** 15 min

---

### Phase 5: GM Adapter Skeleton (20 min)

**Task 5.1: Create GM Adapter Module**
- **Status:** 🔄 Pending
- **Action:**
  - Create `governance/gm_overseer_adapter.py`
  - Implement `maybe_call_gm_for_shell()` skeleton
  - Implement `maybe_call_gm_for_patch()` skeleton
  - Add TODO comments for future implementation
  - Document expected return format
  - Add note about API key handling (ENV only)
- **Deliverable:** GM adapter skeleton
- **Time:** 20 min

---

### Phase 6: CLC Interface Skeleton (30 min)

**Task 6.1: Create CLC Interface Module**
- **Status:** 🔄 Pending
- **Action:**
  - Create `governance/clc_interface.py`
  - Implement ClcConfig dataclass
  - Implement CLCInterface class
  - Implement `run_code_task()` method
  - Implement provider-specific stubs:
    - `_run_openai()` - NotImplementedError
    - `_run_gemini()` - NotImplementedError
    - `_run_local()` - NotImplementedError
  - Add docstrings explaining provider abstraction
- **Deliverable:** CLC interface skeleton
- **Time:** 30 min

---

### Phase 7: Cursor Helper Script (30 min)

**Task 7.1: Create Cursor Helper Script**
- **Status:** 🔄 Pending
- **Action:**
  - Create `tools/cursor_task_spec_helper.py`
  - Add shebang: `#!/usr/bin/env python3`
  - Implement `make_task_spec()` function
  - Implement CLI interface in `main()`
  - Add usage message
  - Add JSON output formatting
  - Make executable: `chmod +x`
- **Deliverable:** Cursor helper script
- **Time:** 25 min

**Task 7.2: Test Cursor Helper**
- **Status:** 🔄 Pending
- **Action:**
  - Test with sample inputs
  - Verify JSON output is valid
  - Verify all fields populated correctly
  - Test error handling for missing args
- **Deliverable:** Cursor helper tested
- **Time:** 5 min

---

### Phase 8: Integration & Verification (30 min)

**Task 8.1: Verify File Structure**
- **Status:** 🔄 Pending
- **Action:**
  - Verify all 8 files exist in correct locations
  - Verify directory structure matches spec
  - Check file permissions
- **Deliverable:** Structure verified
- **Time:** 10 min

**Task 8.2: Test Overseer with Sample Inputs**
- **Status:** 🔄 Pending
- **Action:**
  - Create sample task_spec for shell command
  - Test `decide_for_shell()` with safe command
  - Test `decide_for_shell()` with dangerous command
  - Create sample task_spec for patch
  - Test `decide_for_patch()` with safe patch
  - Test `decide_for_patch()` with high-risk patch
  - Verify Decision objects returned correctly
- **Deliverable:** Overseer tested
- **Time:** 15 min

**Task 8.3: Documentation & Cleanup**
- **Status:** 🔄 Pending
- **Action:**
  - Add README or comments explaining system
  - Verify no hardcoded API keys
  - Verify no hardcoded paths (use env/expanduser)
  - Check for linting errors
- **Deliverable:** Code documented and clean
- **Time:** 5 min

---

## Test Strategy

### Test Approach

**Unit Testing:**
- Policy loader: Test YAML parsing, caching, error handling
- Overseer: Test decision logic with various inputs
- Cursor helper: Test JSON generation

**Integration Testing:**
- Test policy_loader → overseerd flow
- Test overseerd → gm_adapter flow (skeleton returns None)
- Test full pipeline with sample task_spec

**No External Dependencies:**
- No API calls (GM adapter is skeleton)
- No file system writes (read-only configs)
- No database connections

### Test Cases

**TC1: Policy Loader**
```
1. Load safe_zones.yaml → verify SafeZones object
2. Load gm_policy_v4.yaml → verify GmPolicy object
3. Test caching (load twice, verify same object)
4. Test missing file → verify error handling
```

**TC2: Overseer Shell Decisions**
```
1. Safe command: "ls -la" → approval="Yes"
2. Dangerous: "rm -rf /" → approval="No"
3. Risky: "rm -rf ~/tmp" → approval="Review" or GM call
4. GM keyword: "docker compose up" → GM trigger
```

**TC3: Overseer Patch Decisions**
```
1. Safe file: "test.py" → approval="Yes"
2. Outside zone: "/etc/passwd" → approval="No"
3. Multi-file (>= threshold) → GM trigger
4. Sensitive path: "02luka/core/..." → GM trigger
5. Critical keyword in content → GM trigger
```

**TC4: Cursor Helper**
```
1. Generate task_spec with all fields → valid JSON
2. Generate minimal task_spec → valid JSON
3. Missing args → error message
4. Verify output format matches UPP schema
```

---

## Implementation Details

### File Locations

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

### Code Standards

- **Python 3.8+** required (type hints, dataclasses)
- **Type hints** on all functions
- **Docstrings** for all classes and public functions
- **Error handling** for file I/O and YAML parsing
- **No hardcoded paths** - use `os.path.expanduser()` and env vars
- **No hardcoded API keys** - document ENV variable usage

### Dependencies

- **Standard library only** for core modules
- **PyYAML** for policy_loader (document or add to requirements.txt if project has one)
- **No external API dependencies** (GM adapter and CLC are skeletons)

---

## Risk Mitigation

### Risk 1: Directory Creation Issues
**Mitigation:**
- Check existence before creating
- Use `os.makedirs(..., exist_ok=True)`
- Verify permissions

### Risk 2: YAML Parsing Errors
**Mitigation:**
- Use `yaml.safe_load()`
- Add try/except for parsing errors
- Validate structure after loading

### Risk 3: Path Resolution Issues
**Mitigation:**
- Always use `os.path.abspath()` and `os.path.expanduser()`
- Test with various path formats
- Handle both absolute and relative paths

### Risk 4: GM Adapter Not Implemented
**Mitigation:**
- Clearly document as skeleton
- Return None by default
- Add TODO comments
- Document future implementation path

---

## Success Criteria

- ✅ All 8 files created in correct locations
- ✅ Directory structure matches specification
- ✅ Policy loader can read and cache YAML configs
- ✅ Overseer makes decisions for shell/patch/UI actions
- ✅ GM adapter skeleton exists (returns None)
- ✅ CLC interface skeleton exists (NotImplementedError stubs)
- ✅ Cursor helper generates valid task_spec JSON
- ✅ No governance violations (all files in allowed zones)
- ✅ Code is readable, documented, and type-hinted
- ✅ No hardcoded API keys or absolute paths
- ✅ Test cases pass

---

## Deliverables

1. **Directory Structure** - All required directories created
2. **UPP Schema** - `task_spec_schema.yaml` with full specification
3. **Policy Configs** - `safe_zones.yaml` and `gm_policy_v4.yaml`
4. **Policy Loader** - `policy_loader.py` with caching
5. **Overseer Core** - `overseerd.py` with decision logic
6. **GM Adapter** - `gm_overseer_adapter.py` skeleton
7. **CLC Interface** - `clc_interface.py` skeleton
8. **Cursor Helper** - `cursor_task_spec_helper.py` executable script
9. **Documentation** - Comments and docstrings throughout

---

## Timeline

**Phase 1: Directory Setup** - 15 min
- Task 1.1: 5 min
- Task 1.2: 5 min
- Task 1.3: 5 min

**Phase 2: UPP Schema & Policies** - 30 min
- Task 2.1: 10 min
- Task 2.2: 10 min
- Task 2.3: 10 min

**Phase 3: Policy Loader** - 45 min
- Task 3.1: 30 min
- Task 3.2: 15 min

**Phase 4: Overseer Core** - 90 min
- Task 4.1: 20 min
- Task 4.2: 25 min
- Task 4.3: 30 min
- Task 4.4: 15 min

**Phase 5: GM Adapter** - 20 min
- Task 5.1: 20 min

**Phase 6: CLC Interface** - 30 min
- Task 6.1: 30 min

**Phase 7: Cursor Helper** - 30 min
- Task 7.1: 25 min
- Task 7.2: 5 min

**Phase 8: Integration & Verification** - 30 min
- Task 8.1: 10 min
- Task 8.2: 15 min
- Task 8.3: 5 min

**Total Estimated Time:** 3.5 hours

---

## Dependencies

1. **Python 3.8+** - For type hints and dataclasses
2. **PyYAML** - For YAML parsing (may need to document or add to requirements)
3. **File system write access** - For creating directories and files
4. **No external services** - All local, no API calls in Phase 1

---

## Next Steps

1. **Review SPEC and PLAN** - Boss approval
2. **Assign to Andy** - For implementation
3. **Create PR Contract** - If needed for Andy
4. **Execute Phase 1-8** - Implement all components
5. **Verify and test** - Ensure all success criteria met
6. **Document integration path** - For future phases

---

**Plan Status:** 📋 **READY FOR EXECUTION**  
**Priority:** High  
**Dependencies:** Python 3.8+, PyYAML (documented), file system access
