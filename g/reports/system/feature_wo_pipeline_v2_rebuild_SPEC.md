# Feature SPEC: WO Pipeline v2 Rebuild (CLS-Only)

**Created:** 2025-11-14 00:00  
**Priority:** P0 (Critical - System Reliability)  
**Owner:** CLS (Cursor AI Agent)  
**Status:** Ready for Implementation  
**Dependencies:** None (CLS-only, no CLC required)

---

## Problem Statement

### Current State

**WO Pipeline is Broken:**
- WOs dropped into `bridge/inbox/CLC/` are not processed
- No state files created in `followup/state/`
- Dashboard `apps/dashboard/followup.html` shows empty
- All processors missing or non-functional

**Root Cause:**
- Previous pipeline (CLC's Nov 13 01:50 work) was lost/rolled back
- No persistence guarantee existed
- Components vanished silently

### Required State

**Working WO Pipeline:**
- WOs in `bridge/inbox/CLC/*.yaml` or `*.json` are discovered
- Processors parse and normalize WOs
- State JSON files written to `followup/state/*.json`
- `tools/claude_tools/generate_followup_data.zsh` reads state files
- Dashboard shows correct WO list and status

---

## Objectives

### Primary Goal

**Rebuild complete WO processing pipeline v2 with:**
1. **Discovery:** Find new WOs in inbox
2. **Parsing:** Extract structured data from YAML/JSON
3. **Execution:** Process or delegate WOs
4. **State Tracking:** Write/update state JSON files
5. **Guardrail:** Monitor pipeline health
6. **Testing:** End-to-end verification

### Success Criteria

✅ **Functional:**
- Drop WO → State file created → Dashboard shows WO
- All processors run without errors
- Guardrail detects missing components

✅ **Technical:**
- All scripts use `#!/usr/bin/env zsh`
- Absolute paths only (LaunchAgent compatibility)
- No dependencies on non-existent tools
- State schema matches existing dashboard expectations

✅ **Documentation:**
- Complete flow documented
- State schema documented
- Installation instructions provided

---

## Scope

### In Scope

**New Components:**
1. `tools/wo_pipeline/lib_wo_common.zsh` - Shared utilities
2. `tools/wo_pipeline/apply_patch_processor.zsh` - Initial state creation
3. `tools/wo_pipeline/json_wo_processor.zsh` - WO parsing & enrichment
4. `tools/wo_pipeline/wo_executor.zsh` - WO execution
5. `tools/wo_pipeline/followup_tracker.zsh` - State maintenance
6. `tools/wo_pipeline/wo_pipeline_guardrail.zsh` - Health monitoring
7. `tools/wo_pipeline/test_wo_pipeline_e2e.zsh` - End-to-end test

**Infrastructure:**
- `followup/state/` directory (with optional `.gitkeep`)
- 5 LaunchAgent plist templates in `launchd/`
- Documentation: `docs/WO_PIPELINE_V2.md`

**Integration Points:**
- Must work with existing `tools/claude_tools/generate_followup_data.zsh`
- Must produce state files readable by dashboard
- Must not break existing workflows

### Out of Scope

- CLC integration (CLS-only implementation)
- Multi-agent routing (future work)
- Advanced WO scheduling (future work)
- Rollback protection (covered in separate feature)

---

## Technical Design

### Architecture

```
bridge/inbox/CLC/*.yaml / *.json   # Raw WO files
              │
              ▼
apply_patch_processor.zsh
  - Normalizes file names
  - Creates initial state: status = "pending"
              │
              ▼
json_wo_processor.zsh
  - Parses YAML/JSON
  - Extracts: id, title, owner, category, priority
  - Enriches state JSON
              │
              ▼
wo_executor.zsh
  - Executes or delegates WO
  - Updates: status = "running" → "done"/"failed"
              │
              ▼
followup/state/*.json              # Per-WO state files
              │
              ▼
generate_followup_data.zsh         # Existing script
              │
              ▼
apps/dashboard/followup.html       # Dashboard
```

### File Structure

**In Git repo (root = `g/`):**
```
tools/wo_pipeline/
  lib_wo_common.zsh
  apply_patch_processor.zsh
  json_wo_processor.zsh
  wo_executor.zsh
  followup_tracker.zsh
  wo_pipeline_guardrail.zsh
  test_wo_pipeline_e2e.zsh

followup/state/
  .gitkeep (optional)

launchd/
  com.02luka.apply_patch_processor.plist
  com.02luka.json_wo_processor.plist
  com.02luka.wo_executor.plist
  com.02luka.followup_tracker.plist
  com.02luka.wo_pipeline_guardrail.plist

docs/
  WO_PIPELINE_V2.md
```

**Note:** Git repo root is `g/`, so paths in Git are relative to `g/`:
- On disk: `/Users/icmini/02luka/g/tools/wo_pipeline/`
- In Git: `tools/wo_pipeline/`

### State JSON Schema

**Default Schema (if no historical schema found):**
```json
{
  "id": "WO-20251114-EXAMPLE",
  "title": "Example Work Order",
  "owner": "clc",
  "status": "pending|running|done|failed",
  "created_at": "2025-11-14T00:00:00Z",
  "updated_at": "2025-11-14T00:00:00Z",
  "last_error": "",
  "category": "",
  "priority": "normal",
  "meta": {}
}
```

**TODO for CLS:**
- Inspect git history for existing `followup/state/*.json` samples
- If found → match that schema exactly
- If not found → use default above and verify `generate_followup_data.zsh` compatibility

### Common Library Functions

**`lib_wo_common.zsh` provides:**
- `resolve_repo_root()` - Get absolute path to `g/`
- `log_info/warn/error()` - Logging utilities
- `ensure_dir()` - Create directory if missing
- `normalize_wo_id()` - Extract WO ID from filename
- `write_state_json()` - Create initial state file
- `update_state_field()` - Update single field in state JSON
- `mark_status()` - Update status field

### Processor Responsibilities

**1. apply_patch_processor.zsh:**
- Scans `bridge/inbox/CLC/` for `*.yaml`, `*.yml`, `*.json`
- Creates initial state JSON (status="pending")
- Skips if state already exists

**2. json_wo_processor.zsh:**
- Parses YAML/JSON WO files
- Extracts structured fields (id, title, owner, category, priority)
- Updates corresponding state JSON
- Handles both JSON and YAML formats

**3. wo_executor.zsh:**
- Finds state files with status="pending"
- Marks as "running"
- Executes or delegates WO (stub initially, CLS fills logic)
- Updates to "done" or "failed" with error message

**4. followup_tracker.zsh:**
- Periodically scans `followup/state/`
- Optionally marks stale entries
- Computes derived fields (age, is_stale)

**5. wo_pipeline_guardrail.zsh:**
- Verifies all critical scripts exist
- Verifies `followup/state/` exists and is writable
- Exits non-zero if pipeline broken
- Emits health status

### LaunchAgent Configuration

**Template Pattern:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.02luka.{processor_name}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/icmini/02luka/g/tools/wo_pipeline/{script_name}.zsh</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>StandardOutPath</key>
  <string>/Users/icmini/02luka/logs/wo_pipeline/{script_name}.out.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/icmini/02luka/logs/wo_pipeline/{script_name}.err.log</string>
</dict>
</plist>
```

**Important:**
- Use absolute paths only
- Do NOT auto-load/unload from scripts
- Keep as templates only (manual installation)

---

## Dependencies

### Required Tools

- `zsh` (all scripts)
- `python3` (JSON/YAML parsing, state updates)
- `jq` (optional, for JSON manipulation)
- `yaml` Python module (for YAML parsing, or use minimal parser)

### Existing System

- `bridge/inbox/CLC/` directory (must exist or be created)
- `tools/claude_tools/generate_followup_data.zsh` (must read state files)
- `apps/dashboard/followup.html` (must display WOs)

### Integration Points

- State JSON schema must match what `generate_followup_data.zsh` expects
- If mismatch → adapt `lib_wo_common.zsh` to match existing schema
- Only modify `generate_followup_data.zsh` if absolutely necessary

---

## Risk Assessment

### High Risk

**R1: State schema mismatch**
- **Mitigation:** CLS must inspect git history for existing schema
- **Mitigation:** Test with `generate_followup_data.zsh` before PR

**R2: LaunchAgent path issues**
- **Mitigation:** Use absolute paths only
- **Mitigation:** Test LaunchAgent loading manually

### Medium Risk

**R3: YAML parsing dependency**
- **Mitigation:** Use `python3` with `yaml` module (or minimal parser)
- **Mitigation:** Fallback to JSON-only if YAML fails

**R4: WO execution logic incomplete**
- **Mitigation:** Stub initially, CLS fills based on WO schema
- **Mitigation:** Document execution patterns in docs

### Low Risk

**R5: Test WO pollutes real inbox**
- **Mitigation:** Use `WO-TEST-PIPELINE-E2E` prefix
- **Mitigation:** Auto-cleanup test WO after verification

---

## Success Metrics

### Functional

1. **E2E Test Passes:**
   - Drop test WO → State created → Status = "done"
   - `generate_followup_data.zsh` succeeds
   - Dashboard shows test WO

2. **Guardrail Works:**
   - Healthy case: exit 0
   - Missing script: exit non-zero
   - Missing directory: exit non-zero

3. **Real WO Processing:**
   - Drop real WO → Processors run → State created
   - Dashboard shows WO with correct status

### Technical

1. **All scripts executable and runnable**
2. **No hardcoded paths (use `resolve_repo_root`)**
3. **State schema matches dashboard expectations**
4. **LaunchAgent templates valid XML**

---

## Rollback Plan

### If PR Breaks System

1. **Revert PR:**
   ```bash
   git revert <pr-commit>
   ```

2. **Remove LaunchAgents:**
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.*.plist
   rm ~/Library/LaunchAgents/com.02luka.*.plist
   ```

3. **Remove scripts:**
   ```bash
   rm -rf ~/02luka/g/tools/wo_pipeline/
   ```

4. **Clear state:**
   ```bash
   rm -rf ~/02luka/g/followup/state/*.json
   ```

---

## Future Work

### Phase 2: Advanced Features
- Multi-agent routing (CLC, CLS, Codex)
- WO scheduling and prioritization
- Retry logic for failed WOs
- WO dependencies

### Phase 3: Persistence
- Guardrail integration (from separate feature)
- Protected rollback for pipeline components
- State file backup/restore

---

## References

- CLC Chat Archive: `02luka-memory/Boss/Chat archive/clc_251112.txt` (lines 362-540)
- CLS Analysis: `g/reports/ANALYSIS_CLS_vs_CLC_20251113.md`
- WO Pipeline Durability Spec: `g/reports/feature_wo_pipeline_durability_SPEC.md`
- Existing Dashboard: `apps/dashboard/followup.html`
- Existing Generator: `tools/claude_tools/generate_followup_data.zsh`

---

**Next:** Create detailed PLAN with task breakdown and PR template.
