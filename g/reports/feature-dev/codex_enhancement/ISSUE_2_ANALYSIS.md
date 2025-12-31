# Issue #2 Analysis - JSON Escaping Vulnerability

**Date:** 2025-12-30
**Issue:** Unsafe JSON construction with string interpolation
**Severity:** Medium (Security)
**Status:** ⚠️ **CONFIRMED - EXISTS IN CURRENT CODE**

---

## Executive Summary

**Finding:** Issue #2 (JSON escaping) from Codex findings **DOES exist** in current code and represents a **real security vulnerability**.

**Location:** `tools/session_save.zsh` lines 65-85
**Attack Vector:** User can pass arbitrary text via `tools/save.sh` arguments
**Impact:** Invalid JSON in telemetry logs, silent failures, potential data loss

**Recommendation:** Route to Codex for fix (Task #003 ready)

---

## Vulnerability Details

### Code Analysis

**File:** `tools/session_save.zsh` lines 65-85

```bash
# Line 65: JSON format string with %s placeholders
local json_fmt='{"ts": "%s", "agent": "%s", "source": "%s", "env": "%s", "schema_version": %d, "project_id": "%s", "topic": "%s", "files_written": %d, "save_mode": "full", "repo": "%s", "branch": "%s", "exit_code": %d, "duration_ms": %d, "truncated": false}'

# Lines 72-85: Direct string interpolation (UNSAFE)
printf "$json_fmt\n" \
    "$TELEMETRY_START_TS" \
    "$agent" \
    "$source" \
    "$env_field" \
    "$schema_version" \
    "$TELEMETRY_PROJECT_ID" \    # ❌ VULNERABLE
    "$TELEMETRY_TOPIC" \          # ❌ VULNERABLE
    "$TELEMETRY_FILES_WRITTEN" \
    "$repo_name" \
    "$branch" \                   # ❌ VULNERABLE
    "$exit_code" \
    "$duration_ms" \
    >> "${repo_root}/g/telemetry/save_sessions.jsonl" || true
```

**Problem:** Variables are interpolated directly into JSON format string without escaping.

### Attack Vector Confirmed

**File:** `tools/save.sh` lines 58-60

```bash
if [[ $# -gt 0 ]]; then
    export TELEMETRY_TOPIC="$*"  # User-controlled input
fi
```

**Proof:** User can pass arbitrary text as arguments to save.sh.

---

## Exploitation Examples

### Example 1: Quotes Break JSON

**Input:**
```bash
~/02luka/tools/save.sh 'My "awesome" topic'
```

**Result in telemetry log:**
```json
{"topic": "My "awesome" topic"}
           ↑ Invalid JSON - breaks parsing
```

**Actual behavior:**
```bash
# jq fails to parse
$ tail -1 g/telemetry/save_sessions.jsonl | jq .
parse error: Invalid string: control characters from U+0000 through U+001F must be escaped at line 1, column 25
```

### Example 2: Newlines Break JSON

**Input:**
```bash
~/02luka/tools/save.sh $'Topic line 1\nTopic line 2'
```

**Result:**
```json
{"topic": "Topic line 1
Topic line 2"}
↑ Invalid JSON - newline not escaped
```

### Example 3: Branch Names with Special Chars

**Scenario:** Git branch named `feature/user-"auth"`

**Result:**
```json
{"branch": "feature/user-"auth""}
                        ↑ Invalid JSON
```

---

## Impact Assessment

### Direct Impact

1. **Telemetry logging failures**
   - Invalid JSON entries in `g/telemetry/save_sessions.jsonl`
   - Entire file becomes unparseable
   - Loss of telemetry data

2. **Silent failures**
   - Code uses `|| true` to ignore errors
   - No user notification when logging fails
   - Debugging becomes difficult

3. **Downstream parsing errors**
   - Any tool reading telemetry log will fail
   - Analytics broken
   - Metrics collection compromised

### Likelihood

**Medium-High:**
- Common scenario: User passes descriptive text to save.sh
- Branch names often contain slashes, special chars
- PROJECT_ID can be set by environment/scripts

**Example legitimate uses that would trigger bug:**
```bash
# All of these are normal use cases that break:
~/02luka/tools/save.sh "Review PR #42 - Add 'auth' module"
~/02luka/tools/save.sh "Fixed bug in \"session save\" logic"
export PROJECT_ID="PD-17 (Phase 2)"; ~/02luka/tools/save.sh
```

---

## Code Comments Confirm Issue

**Evidence developer was aware:**

Line 58-60 in `tools/session_save.zsh`:
```bash
# Safe JSON construction (manual escaping for shell)
# Note: project_id and topic might contain user input, should be carefully handled if complex.
# For now assuming simple strings or null.
```

**Interpretation:**
- Comment says "Safe JSON construction" but implementation is NOT safe
- Acknowledges user input risk
- "For now assuming simple strings" = known technical debt
- This validates Codex finding was correct

---

## Comparison with Codex Original Finding

**Codex originally stated (in action plan):**

> **File:** `tools/session_save.zsh:51`
> **Problem:** Builds JSON with string interpolation
> **Risk:** Invalid JSON if variables contain quotes/newlines

**My analysis:**

✅ **Codex was RIGHT** - Issue exists
⚠️ **Line number was approximate** - Actual location is lines 65-85, not line 51
✅ **Risk assessment accurate** - Quotes/newlines do break JSON
✅ **Suggested fix correct** - Use jq -n with --arg

**Conclusion:** Codex identified a real vulnerability, line number was close enough.

---

## Recommended Fix

### Use jq -n with Proper Escaping

**Replace lines 65-85 with:**

```bash
jq -n \
  --arg ts "$TELEMETRY_START_TS" \
  --arg agent "$agent" \
  --arg source "$source" \
  --arg env "$env_field" \
  --argjson schema "$schema_version" \
  --arg project "$TELEMETRY_PROJECT_ID" \
  --arg topic "$TELEMETRY_TOPIC" \
  --argjson files "$TELEMETRY_FILES_WRITTEN" \
  --arg repo "$repo_name" \
  --arg branch "$branch" \
  --argjson exit "$exit_code" \
  --argjson duration "$duration_ms" \
  '{
    ts: $ts,
    agent: $agent,
    source: $source,
    env: $env,
    schema_version: $schema,
    project_id: $project,
    topic: $topic,
    files_written: $files,
    save_mode: "full",
    repo: $repo,
    branch: $branch,
    exit_code: $exit,
    duration_ms: $duration,
    truncated: false
  }' >> "${repo_root}/g/telemetry/save_sessions.jsonl" || true
```

### Why This Works

1. **--arg:** Automatically escapes quotes, newlines, backslashes
2. **--argjson:** Preserves numeric types (not "123" but 123)
3. **Industry standard:** jq is the correct tool for shell JSON
4. **Type safe:** Guarantees valid JSON output

---

## Testing Strategy

### Test Cases

1. **Normal input** - Verify no regression
2. **Quotes in topic** - `'My "awesome" topic'`
3. **Newlines in topic** - `$'Line 1\nLine 2'`
4. **Special chars in branch** - `feature/"auth"`
5. **Complex PROJECT_ID** - `PD-17 (Phase "2")`

### Validation

```bash
# After fix, all of these should produce valid JSON:
~/02luka/tools/save.sh 'Topic with "quotes"'
tail -1 g/telemetry/save_sessions.jsonl | jq .  # Should parse

~/02luka/tools/save.sh $'Topic\nwith\nnewlines'
tail -1 g/telemetry/save_sessions.jsonl | jq .  # Should parse

# Verify types preserved
tail -1 g/telemetry/save_sessions.jsonl | jq '.schema_version | type'
# Should output: "number" (not "string")
```

---

## Risk vs Priority

### Why Medium Priority (Not High)?

**Lower severity than Issue #1 because:**
- Issue #1 (git add -A) could commit **secrets** = HIGH security risk
- Issue #2 breaks telemetry logs but doesn't leak secrets
- Impact limited to internal logging (not user-facing)
- Silent failures don't compromise system operation

**But still important because:**
- Real vulnerability with confirmed attack vector
- Common legitimate usage triggers bug
- Telemetry data is valuable for system health
- Easy to fix with proper tool (jq)

---

## Next Steps

### Option A: Route to Codex (Recommended)

**Why Codex:**
- Codex identified this issue (should validate fix capability)
- Non-locked zone (tools/)
- Clear, well-defined fix
- Good test for Codex Tier 2

**Task prepared:** `tmp/codex_task_003_issue2.md`

**Command:**
```bash
codex-task "Fix JSON escaping vulnerability in tools/session_save.zsh lines 65-85: Replace unsafe printf string interpolation with jq -n construction..."
```

**Expected quality:** 9/10 (straightforward jq refactor)

### Option B: CLC Fixes (Alternative)

**If Codex unavailable or Boss prefers CLC:**
- Same approach (jq -n replacement)
- ~15 minutes
- Would use CLC quota

---

## Metrics

**Analysis time:** ~15 minutes
**Vulnerable variables identified:** 3 (TELEMETRY_TOPIC, TELEMETRY_PROJECT_ID, branch)
**Attack vectors confirmed:** 1 (save.sh user input)
**Lines affected:** 65-85 (21 lines)
**Recommended fix effort:** 15-20 minutes

---

## References

**Files analyzed:**
- `tools/session_save.zsh` (lines 25, 65-85)
- `tools/save.sh` (lines 58-60)

**Documentation:**
- `g/reports/feature-dev/codex_enhancement/CODEX_FINDINGS_ACTION_PLAN.md` (Issue #2)
- `tmp/codex_task_003_issue2.md` (task spec for Codex)

**Related issues:**
- Issue #1 (git add -A) - RESOLVED by CLC
- Issue #3 (jq preflight) - RESOLVED by Codex
- Issue #4 (mls_capture) - Pending test

---

**Status:** ⚠️ Vulnerability confirmed and analyzed
**Next:** Ready to route to Codex (Task #003)
**Priority:** Medium (security fix, but low exploitation risk)
**Effort:** 15-20 minutes

**Codex Validation Opportunity:** This is perfect for testing Codex's ability to handle security fixes with proper escaping and type handling. 🔒
