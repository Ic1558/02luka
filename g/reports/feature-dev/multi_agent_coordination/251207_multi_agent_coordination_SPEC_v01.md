# Multi-Agent Coordination System - Specification

**Feature:** Unified Agent Context & Save Gateway  
**Date:** 2025-12-07  
**Status:** Spec (Minimal Viable - Phase 1A)  
**Version:** 1.0

---

## Problem Statement

Multiple AI agents (CLC, CLS, codex, gmx, liam) operate in different environments with varying levels of system integration:

- **Current State:**
  - CLC: Direct `session_save.zsh` → ✅ Full MLS + telemetry
  - CLS: `save.sh` gateway → ✅ Full MLS + telemetry
  - codex/gmx: Unknown pattern → ⚠️ Partial MLS only
  - liam: No integration → ❌ No telemetry

- **Problems:**
  - ❌ No standardized agent registration
  - ❌ Inconsistent agent attribution in telemetry
  - ❌ `save-now` bypasses gateway (inconsistent metadata)
  - ❌ Agent detection defaults to "CLC" (may be wrong)

- **Goal:**
  - ✅ Standardized agent context detection
  - ✅ Unified save gateway with consistent metadata
  - ✅ Correct agent attribution in telemetry
  - ✅ Backward compatible (no breakage)

---

## Architecture (Phase 1A - Minimal Viable)

### Layer 1: Agent Context Detection

**File:** `tools/agent_context.zsh`

**Purpose:** Detect and validate agent identity and environment

**Functions:**
- `detect_agent()`: Returns agent ID (CLS, CLC, codex, gmx, liam, unknown)
- `detect_environment()`: Returns environment (cursor, terminal, ssh, antigravity)

**Detection Priority:**
1. Explicit `AGENT_ID` environment variable (highest priority)
2. `GG_AGENT_ID` (legacy support)
3. `SESSION_AGENT` (legacy support)
4. Environment heuristics (`TERM_PROGRAM`, etc.)
5. Return "unknown" (not default to "CLC")

**Validation:**
- Validate against known agents: `CLS|CLC|codex|gmx|liam|unknown`
- Return "unknown" if detection fails or invalid

**Exports:**
- `AGENT_ID`: Detected agent identifier
- `AGENT_ENV`: Detected environment

---

### Layer 2: Unified Save Gateway

**File:** `tools/save.sh` (enhance existing)

**Purpose:** Universal entry point for all agents with context injection

**Enhancements:**
1. Source `agent_context.zsh` at start
2. Set metadata:
   - `SAVE_AGENT="${AGENT_ID}"`
   - `SAVE_SOURCE="${SAVE_SOURCE:-${AGENT_ENV}}"`
   - `SAVE_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"`
3. Add `schema_version: 1` to telemetry (future-proofing)
4. Route to `session_save.zsh` (unchanged behavior)

**Backward Compatibility:**
- Existing callers continue to work
- No breaking changes
- Preserve current `SAVE_SOURCE` if already set

---

### Integration: save-now Alias

**File:** `tools/git_safety_aliases.zsh` (modify)

**Change:**
- Current: `save-now` → `session_save.zsh` (direct, bypasses gateway)
- New: `save-now` → `save.sh` → `session_save.zsh` (via gateway)

**Rationale:**
- Consistent metadata across all save operations
- Unified entry point
- Better telemetry attribution

---

## Telemetry Schema Enhancement

**File:** `g/telemetry/save_sessions.jsonl`

**Current Schema:**
```json
{
  "ts": "2025-12-07T02:10:28Z",
  "agent": "CLS",
  "source": "manual",
  "project_id": "null",
  "topic": "null",
  "files_written": 5,
  "save_mode": "full",
  "repo": "02luka",
  "branch": "main",
  "exit_code": 0,
  "duration_ms": 1250,
  "truncated": false
}
```

**Enhanced Schema (add fields):**
```json
{
  "ts": "2025-12-07T02:10:28Z",
  "agent": "CLS",
  "source": "cursor",
  "env": "cursor",
  "schema_version": 1,
  "project_id": "null",
  "topic": "null",
  "files_written": 5,
  "save_mode": "full",
  "repo": "02luka",
  "branch": "main",
  "exit_code": 0,
  "duration_ms": 1250,
  "truncated": false
}
```

**New Fields:**
- `env`: Environment identifier (cursor, terminal, ssh, antigravity)
- `schema_version`: Schema version (1) for future compatibility

---

## Agent Detection Logic

### Priority Order

1. **Explicit** (highest priority):
   ```bash
   AGENT_ID=CLS save.sh
   ```

2. **Legacy Environment Variables:**
   ```bash
   GG_AGENT_ID=CLS  # Legacy support
   SESSION_AGENT=CLS  # Legacy support
   ```

3. **Environment Heuristics:**
   ```bash
   TERM_PROGRAM=vscode → CLS (Cursor)
   CODEX_SESSION=1 → codex
   GEMINI_CLI=1 → gmx
   ```

4. **Default:**
   ```bash
   → "unknown" (not "CLC")
   ```

### Validation

```zsh
# Valid agents
KNOWN_AGENTS="CLS|CLC|codex|gmx|liam|unknown"

# Validate detected agent
if [[ ! "$detected_agent" =~ ^($KNOWN_AGENTS)$ ]]; then
    echo "unknown"
fi
```

---

## Success Criteria

### Phase 1A (Minimal Viable)

- ✅ Agent detection works reliably (no false positives)
- ✅ Gateway adds consistent metadata (`SAVE_AGENT`, `SAVE_SOURCE`, `env`)
- ✅ Telemetry includes `schema_version: 1`
- ✅ `save-now` uses gateway (not bypass)
- ✅ Backward compatible (no existing breakage)
- ✅ Unknown agents return "unknown" (not "CLC")

### Testing Requirements

- ✅ CLC detected correctly (via `GG_AGENT_ID` or default)
- ✅ CLS detected correctly (via `TERM_PROGRAM=vscode`)
- ✅ Explicit `AGENT_ID` takes precedence
- ✅ Unknown agents return "unknown"
- ✅ Telemetry format matches enhanced schema
- ✅ No git conflicts or lock issues

---

## Deferred (Not in Phase 1A)

### Layer 3: Split Writers
- ⏳ **Status:** DEFERRED
- **Rationale:** Current atomic write works, no need to split yet

### Layer 4: Aggregation
- ⏳ **Status:** DEFERRED
- **Rationale:** Add daily/manual script only if query patterns emerge

### Layer 5: Agent Adapters
- ⏳ **Status:** CREATE ONLY WHEN NEEDED
- **Liam:** Manual only (`AGENT_ID=liam save.sh`)
- **codex/gmx:** Create only if they actually use save

---

## Files to Create/Modify

### New Files
1. `tools/agent_context.zsh` - Agent detection with validation

### Modified Files
1. `tools/save.sh` - Add agent context sourcing + schema_version
2. `tools/git_safety_aliases.zsh` - Update `save-now` to use gateway

### Not Creating (Deferred)
- ❌ `tools/mls_session_writer.zsh`
- ❌ `tools/telemetry_session_writer.zsh`
- ❌ `tools/session_aggregator_*.zsh`
- ❌ `tools/adapters/*`
- ❌ LaunchAgent plist

---

## Rollback Plan

If issues occur:

```bash
# Restore original save.sh
git checkout HEAD -- tools/save.sh

# Remove agent context helper
rm -f tools/agent_context.zsh

# Restore save-now alias (if modified)
git checkout HEAD -- tools/git_safety_aliases.zsh
```

**Risk:** Low (3 commands to rollback)

---

## Multi-Agent Consensus

**Approved by:**
- ✅ GMX: Strategic alignment, minor refinements
- ✅ Codex: Minimal approach, defer complexity
- ✅ Liam: Manual only, no auto-detection
- ✅ CLS: Start simple, add when needed

**Consensus:** Implement Phase 1A only (40 min), defer Layers 3-5

---

**Last Updated:** 2025-12-07
