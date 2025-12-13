# Multi-Agent Coordination System - Implementation Plan

**Feature:** Unified Agent Context & Save Gateway  
**Date:** 2025-12-07  
**Status:** Plan (Minimal Viable - Phase 1A)  
**Version:** 1.0

---

## Overview

Minimal viable implementation of multi-agent coordination:
- **Phase 1A:** Agent context + Gateway (30 min)
- **Phase 1B:** Testing & Validation (10 min)
- **Total:** 40 minutes

**Deferred:**
- Layer 3: Split writers (keep atomic)
- Layer 4: Aggregation (add if needed)
- Layer 5: Adapters (create when agent needs it)

---

## Phase 1A: Core Infrastructure (30 min)

### T1: Create Agent Context Detection

**File:** `tools/agent_context.zsh`

**Tasks:**
- [ ] Create `detect_agent()` function:
  - Priority: explicit `AGENT_ID` → `GG_AGENT_ID` → `SESSION_AGENT` → heuristics → "unknown"
  - Heuristics: `TERM_PROGRAM=vscode` → CLS, `CODEX_SESSION` → codex, `GEMINI_CLI` → gmx
  - Validation: Check against known agents, return "unknown" if invalid
  - **Critical:** Don't default to "CLC", return "unknown" instead

- [ ] Create `detect_environment()` function:
  - `TERM_PROGRAM=vscode` → "cursor"
  - `SSH_TTY` → "ssh"
  - Default → "terminal"
  - **Note:** No antigravity detection (Liam confirmed it doesn't work)

- [ ] Export variables:
  - `export AGENT_ID=$(detect_agent)`
  - `export AGENT_ENV=$(detect_environment)`

- [ ] Add usage comments and examples

**Validation:**
- Test with explicit `AGENT_ID=CLS`
- Test with `GG_AGENT_ID=CLS`
- Test with `TERM_PROGRAM=vscode`
- Test with no env vars (should return "unknown")

**Estimated Time:** 15 min

---

### T2: Enhance Save Gateway

**File:** `tools/save.sh` (modify existing)

**Tasks:**
- [ ] Source agent context at start:
  ```zsh
  source "$(dirname "$0")/agent_context.zsh"
  ```

- [ ] Set metadata (preserve existing if set):
  ```zsh
  export SAVE_AGENT="${AGENT_ID}"
  export SAVE_SOURCE="${SAVE_SOURCE:-${AGENT_ENV}}"
  export SAVE_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ```

- [ ] Add logging (optional, for debugging):
  ```zsh
  echo "🔹 Agent: ${AGENT_ID} | Env: ${AGENT_ENV} | Source: ${SAVE_SOURCE}"
  ```

- [ ] Ensure backward compatibility:
  - Preserve existing `SAVE_SOURCE` if already set
  - Don't break existing callers
  - Keep current behavior otherwise

**Validation:**
- Test with existing callers (should work unchanged)
- Test with new agent context (should set metadata)
- Verify telemetry includes new fields

**Estimated Time:** 10 min

---

### T3: Update Telemetry Schema

**File:** `tools/session_save.zsh` (modify `log_telemetry()` function)

**Tasks:**
- [ ] Add `schema_version: 1` to telemetry JSON
- [ ] Add `env` field (from `AGENT_ENV`)
- [ ] Update JSON format string:
  ```zsh
  local json_fmt='{"ts": "%s", "agent": "%s", "source": "%s", "env": "%s", "schema_version": 1, "project_id": "%s", "topic": "%s", "files_written": %d, "save_mode": "full", "repo": "%s", "branch": "%s", "exit_code": %d, "duration_ms": %d, "truncated": false}'
  ```

- [ ] Ensure backward compatibility:
  - Existing telemetry readers should still work
  - New fields are additive (not breaking)

**Validation:**
- Run `save-now` and check telemetry file
- Verify new fields are present
- Verify existing fields unchanged

**Estimated Time:** 5 min

---

### T4: Update save-now Alias

**File:** `tools/git_safety_aliases.zsh` (modify `dev_save()` function)

**Tasks:**
- [ ] Change `dev_save()` to call `save.sh` instead of `session_save.zsh`:
  ```zsh
  function dev_save() {
      (
          cd "${LUKA_MEM_REPO_ROOT:-$HOME/02luka}" || return 1
          if [[ -f "./tools/save.sh" ]]; then
              ./tools/save.sh "$@"
          else
              echo "❌ save.sh not found in $(pwd)/tools/"
              return 1
          fi
      )
  }
  ```

- [ ] Keep error handling and path resolution

**Validation:**
- Test `save-now` command
- Verify it routes through gateway
- Verify metadata is set correctly

**Estimated Time:** 5 min

---

## Phase 1B: Testing & Validation (10 min)

### T5: Test Agent Detection

**Tasks:**
- [ ] Test explicit `AGENT_ID`:
  ```bash
  AGENT_ID=CLS source tools/agent_context.zsh
  # Should output: AGENT_ID=CLS
  ```

- [ ] Test legacy `GG_AGENT_ID`:
  ```bash
  GG_AGENT_ID=CLS source tools/agent_context.zsh
  # Should output: AGENT_ID=CLS
  ```

- [ ] Test environment heuristic (CLS):
  ```bash
  TERM_PROGRAM=vscode source tools/agent_context.zsh
  # Should output: AGENT_ID=CLS, AGENT_ENV=cursor
  ```

- [ ] Test unknown (no env vars):
  ```bash
  unset AGENT_ID GG_AGENT_ID SESSION_AGENT TERM_PROGRAM
  source tools/agent_context.zsh
  # Should output: AGENT_ID=unknown
  ```

- [ ] Test validation (invalid agent):
  ```bash
  AGENT_ID=invalid_agent source tools/agent_context.zsh
  # Should output: AGENT_ID=unknown
  ```

**Estimated Time:** 5 min

---

### T6: Test Gateway Integration

**Tasks:**
- [ ] Test `save.sh` with agent context:
  ```bash
  AGENT_ID=CLS tools/save.sh
  # Should set SAVE_AGENT=CLS, SAVE_SOURCE=cursor
  ```

- [ ] Test `save-now` alias:
  ```bash
  save-now
  # Should route through save.sh, set metadata
  ```

- [ ] Test backward compatibility:
  ```bash
  SAVE_SOURCE=manual tools/save.sh
  # Should preserve SAVE_SOURCE=manual
  ```

- [ ] Verify telemetry output:
  ```bash
  # Check last line of g/telemetry/save_sessions.jsonl
  # Should have: agent, source, env, schema_version
  ```

**Estimated Time:** 5 min

---

## Success Criteria

### Phase 1A Complete When:

- ✅ `tools/agent_context.zsh` created and working
- ✅ `tools/save.sh` enhanced with context sourcing
- ✅ `tools/session_save.zsh` telemetry includes `schema_version` and `env`
- ✅ `save-now` alias routes through gateway
- ✅ Agent detection returns "unknown" (not "CLC") when uncertain
- ✅ All tests passing
- ✅ Backward compatible (no breakage)

---

## Deferred Phases

### Phase 2: Aggregation (DEFERRED)

**Status:** ⏳ Not implementing

**Rationale:**
- Codex: "too frequent, too complex"
- CLS: "start daily, not hourly"
- Current system works without aggregation

**If needed later:**
- Create `tools/session_aggregator_daily.zsh` (manual run)
- Test for 7 days
- If valuable, add LaunchAgent (daily, not hourly)

---

### Phase 3: Split Writers (DEFERRED)

**Status:** ⏳ Not implementing

**Rationale:**
- CLS: "current works, why split?"
- Codex: "atomicity risk"
- Current `session_save.zsh` handles both correctly

**Keep as-is unless:**
- MLS and telemetry need different update frequencies
- Separate maintenance teams
- Performance becomes an issue

---

### Phase 4: Agent Adapters (DEFERRED)

**Status:** ⏳ CREATE ONLY WHEN NEEDED

**Liam/Antigravity:**
- ❌ No auto-detection possible (Liam confirmed)
- ✅ Use manual: `AGENT_ID=liam save.sh` when Boss requests
- ❌ Don't create adapter (no use case)

**Codex/GMX:**
- ⏳ Wait to see if they actually call save
- ✅ If yes, create thin adapter: `export AGENT_ID=codex; exec save.sh`
- ❌ Don't create until proven need

---

## Timeline

**Total:** 40 minutes

- Phase 1A (Core): 30 min
  - T1: Agent context (15 min)
  - T2: Gateway enhancement (10 min)
  - T3: Telemetry schema (5 min)
  - T4: save-now update (5 min)

- Phase 1B (Testing): 10 min
  - T5: Agent detection tests (5 min)
  - T6: Gateway integration tests (5 min)

**NOT doing:**
- ❌ Phase 2 (Aggregation): DEFERRED
- ❌ Phase 3 (Split writers): DEFERRED
- ❌ Phase 4 (Adapters): CREATE ONLY WHEN NEEDED

---

## Rollback Plan

If issues occur (very low risk):

```bash
# Restore original save.sh
git checkout HEAD -- tools/save.sh

# Remove agent context helper
rm -f tools/agent_context.zsh

# Restore save-now alias (if modified)
git checkout HEAD -- tools/git_safety_aliases.zsh
```

**That's it!** No LaunchAgent to unload, no adapters to remove, no split writers to clean up.

---

## Expected Benefits

### Immediate (Phase 1A)

- ✅ Correct attribution: Know which agent created which save
- ✅ Consistent metadata: All saves have `SAVE_AGENT`, `SAVE_SOURCE`, `env`
- ✅ Better telemetry: `schema_version` enables future evolution
- ✅ No false defaults: "unknown" instead of "CLC" when uncertain

### Operational

- ✅ Low risk: Minimal changes, backward compatible
- ✅ Fast rollback: 3 commands to restore
- ✅ No new LaunchAgents: No cron job overhead
- ✅ No scope creep: Defer complexity until proven need

### Future Readiness

- ✅ Foundation laid: Easy to add aggregation later if needed
- ✅ Adapter pattern: Can add agent adapters when use case emerges
- ✅ Extensible: Split writers if separate maintenance needed

---

## Next Decision Point

**Monitor Usage (2-4 weeks):**

1. Watch telemetry: Are agents correctly identified?
2. Track patterns: Which agents actually use save?
3. Identify gaps: Do any agents need adapters?

**Add Complexity Only When Needed:**

- ⏳ If agents frequently ask "what did we do this week?" → Add daily aggregation
- ⏳ If codex/gmx actually call save → Create thin adapters
- ⏳ If MLS and telemetry maintenance diverges → Split writers
- ⏳ If hourly trends become important → Add hourly aggregation

**Don't Build Until Proven Need:**

- ❌ Don't create features speculatively
- ✅ Let real usage drive complexity
- ✅ Keep system simple until pain points emerge

---

**Last Updated:** 2025-12-07
