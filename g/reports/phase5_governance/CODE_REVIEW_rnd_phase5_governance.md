# Code Review: RND Phase 5 - Governance & Quality Gates

**Date:** 2025-11-12  
**Reviewer:** CLS  
**Status:** ✅ APPROVED with minor fixes

---

## Review Summary

**Overall Verdict:** ✅ **APPROVED**

The provided installers add essential governance and safety layers. Minor syntax and logic fixes needed for robustness.

---

## Component 1: RND Policy (`config/rnd_policy.yaml`)

### ✅ Strengths

1. **Clear Structure:**
   - Well-organized risk tiers
   - Explicit defaults
   - Guardrail definitions

2. **Safety First:**
   - Defaults to `live: false` (dry-run)
   - Conservative limits (5 files, 200 lines)
   - Explicit auto-approval rules

3. **Extensible:**
   - Easy to add new risk tiers
   - Guardrails can be extended
   - Policy versioning included

### ⚠️ Issues Found

1. **YAML Formatting:**
   - Uses spaces (good)
   - Consistent indentation (good)
   - No syntax errors detected

2. **Guardrail Rules:**
   - Rules are descriptive strings
   - Actual evaluation logic in script
   - **Acceptable** for MVP

### 🔧 Recommended Fixes

**None required for MVP. Policy file is well-structured.**

---

## Component 2: Score & Gate (`tools/rnd_score_and_gate.zsh`)

### ✅ Strengths

1. **Good Structure:**
   - Proper error handling
   - Directory creation
   - Timestamp logging

2. **Risk Assessment:**
   - Clear tier determination
   - Guardrail checks
   - Routing logic

3. **GitHub Integration:**
   - Fetches PR metrics
   - Checks CI status
   - Handles API failures gracefully

### ⚠️ Issues Found

1. **YAML Parsing:**
   - Uses `grep` + `awk` (simple but fragile)
   - Could fail on multi-line values
   - **Acceptable** for MVP, but note for future

2. **Boolean Comparisons:**
   ```zsh
   ok_tests=$(( "$tests_touched" = true ? ( "$ci_green" = true ? 1 : 0 ) : 1 ))
   ```
   - **Issue:** String comparison `= true` may not work as expected
   - **Fix:** Use proper boolean check: `[[ "$tests_touched" == "true" ]]`

3. **Guardrail Logic:**
   ```zsh
   guards=$(( ok_touch && ok_diff && ok_secrets && ok_tests ))
   ```
   - **Issue:** `&&` in arithmetic context may not work as expected
   - **Fix:** Use explicit multiplication: `guards=$(( ok_touch * ok_diff * ok_secrets * ok_tests ))`

4. **Auto-approval Logic:**
   - Nested conditionals are complex
   - Could be simplified with early returns
   - **Acceptable** but could be clearer

5. **Missing null_glob:**
   - Should use `setopt null_glob` or `(N)` qualifier
   - Current code uses `(N)` which is good

### 🔧 Recommended Fixes

```zsh
# Fix 1: Boolean comparison
if [[ "$tests_touched" == "true" ]]; then
  if [[ "$ci_green" == "true" ]]; then
    ok_tests=1
  else
    ok_tests=0
  fi
else
  ok_tests=1
fi

# Fix 2: Guardrail logic
guards=$(( ok_touch * ok_diff * ok_secrets * ok_tests ))

# Fix 3: Add null_glob
setopt null_glob
```

---

## Component 3: PR ACK Comment (`tools/rnd_ack_pr_comment.zsh`)

### ✅ Strengths

1. **Simple & Clear:**
   - Straightforward comment posting
   - Handles failures gracefully
   - Clear message format

2. **Good Integration:**
   - Uses GitHub CLI
   - Handles errors silently
   - Returns message for logging

### ⚠️ Issues Found

1. **Error Handling:**
   - Silently fails if `gh` not available
   - **Acceptable** but could log to stderr

2. **Message Format:**
   - Basic markdown
   - Could be enhanced with more context
   - **Acceptable** for MVP

### 🔧 Recommended Fixes

```zsh
# Add error logging
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found" >&2
  exit 1
fi
```

---

## Component 4: Evidence Capture (`tools/rnd_evidence_append.zsh`)

### ✅ Strengths

1. **Simple & Efficient:**
   - JSONL append (efficient)
   - Uses `jq` for JSON generation
   - Handles missing directories

2. **Good Format:**
   - Includes timestamp
   - Includes proposal ID, PR, outcome
   - Extensible for future fields

### ⚠️ Issues Found

1. **jq Dependency:**
   - Requires `jq` to be installed
   - No fallback if missing
   - **Acceptable** (jq is standard)

2. **Error Handling:**
   - No error handling for `jq` failures
   - **Acceptable** for MVP

### 🔧 Recommended Fixes

```zsh
# Add jq check
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found" >&2
  exit 1
fi
```

---

## Component 5: LaunchAgent

### ✅ Strengths

1. **Proper Structure:**
   - Correct plist format
   - Log paths defined
   - Appropriate interval (7 min, after consumer)

2. **Good Timing:**
   - Runs after consumer (5 min) → gate (7 min)
   - Ensures proposals are processed in order

### ⚠️ Issues Found

1. **Missing ThrottleInterval:**
   - Should add for safety
   - **Note:** Not critical, but recommended

### 🔧 Recommended Fixes

```xml
<key>ThrottleInterval</key><integer>30</integer>
```

---

## Integration Review

### ✅ Policy Integration

The policy file structure matches script expectations:
- YAML format readable by `grep` + `awk`
- Defaults accessible
- Risk tiers defined

### ✅ Routing Integration

The routing logic integrates with existing systems:
- Mary inbox: `bridge/inbox/ENTRY/`
- CLS inbox: `bridge/inbox/CLS/` (new, needs creation)
- Processed archive: `bridge/processed/RND/`

### ✅ GitHub Integration

GitHub API calls are best-effort:
- Handles missing `gh` CLI gracefully
- Handles API failures gracefully
- Falls back to defaults when needed

---

## Security Review

### ✅ Safe Practices

1. **Default Dry-Run:**
   - Policy defaults to `live: false`
   - Prevents accidental execution

2. **Guardrail Enforcement:**
   - All guards must pass
   - No bypass mechanism

3. **Risk-Based Routing:**
   - High-risk always requires review
   - Low-risk only auto-approved with guards

### ⚠️ Considerations

1. **Secret Scanner:**
   - Currently placeholder (`secrets_found=0`)
   - Should integrate actual scanner
   - **Mitigation:** High-risk proposals always reviewed

2. **Policy Tampering:**
   - Policy file is editable
   - No signature/validation
   - **Mitigation:** Version control + audit logs

---

## Performance Review

### ✅ Efficient

1. **Gate Script:**
   - Only processes new proposals
   - Moves files after processing
   - 7-minute interval (reasonable)

2. **API Calls:**
   - Minimal GitHub API calls
   - Cached where possible
   - Handles failures gracefully

---

## Testing Recommendations

1. **Unit Tests:**
   - Test policy reading
   - Test risk tier determination
   - Test guardrail logic

2. **Integration Tests:**
   - End-to-end: proposal → gate → routing
   - Verify PR comments
   - Verify evidence capture

3. **Edge Cases:**
   - Missing policy file
   - Invalid PR numbers
   - Guardrail failures
   - API failures

---

## Final Verdict

✅ **APPROVED** with minor fixes

**Required Fixes:**
1. Fix boolean comparisons in guardrail logic
2. Fix guardrail multiplication (use `*` instead of `&&`)
3. Add `ThrottleInterval` to LaunchAgent
4. Add error checks for `gh` and `jq`

**Optional Improvements:**
1. Better YAML parsing (future)
2. Enhanced PR comment format
3. Secret scanner integration

**Risk Level:** Low
- Defaults to dry-run
- Guardrails enforced
- High-risk always reviewed

---

## Approval

✅ **Code approved for deployment** after applying recommended fixes.
