# Feature PLAN: Fix gg_nlp_bridge AWK Syntax Error

**Feature ID:** `fix_gg_nlp_bridge_awk_error`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Task Breakdown

- [x] **Task 1:** Locate the script causing the error
  - ✅ Found: `tools/gg_nlp_bridge.zsh` (line 35)
  - ✅ LaunchAgent: `com.02luka.gg.nlp-bridge` (loaded)
  - ✅ Script exists and is executable

- [x] **Task 2:** Analyze the AWK code
  - ✅ Read AWK section (line 30-39)
  - ✅ Pattern is correct: `/^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/`
  - ✅ AWK `match()` syntax is correct
  - ✅ No `>>>` or `<<<` in current file

- [ ] **Task 3:** Fix the issue
  - Verify script is clean (no hidden characters)
  - Reload LaunchAgent to pick up current version
  - Add error handling to AWK call
  - Test with sample input

- [ ] **Task 4:** Reload LaunchAgent
  - Unload current LaunchAgent
  - Load LaunchAgent again (picks up current script)
  - Verify process restarts
  - Check logs for errors

- [ ] **Task 5:** Test the fix
  - Create test input (sample key-value pairs)
  - Publish to `gg:nlp` channel
  - Verify no AWK errors in logs
  - Verify parsing works correctly

- [ ] **Task 6:** Validate in production
  - Monitor log files for 24 hours
  - Verify NLP bridge functionality
  - Confirm no regressions

---

## Test Strategy

### Unit Tests

**Test AWK Pattern:**
```bash
# Test with sample input
echo '"key": value' | awk 'match($0, /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, arr) {print arr[1], arr[2]}'
# Expected: key value

echo 'key: value123' | awk 'match($0, /^"?([^"]+)"?[[:space:]]*:[[:space:]]*([a-zA-Z0-9_.-]+)$/, arr) {print arr[1], arr[2]}'
# Expected: key value123
```

**Test Script Execution:**
```bash
# Run the fixed script
# Verify no AWK errors
# Verify output is correct
```

### Integration Tests

**Test NLP Bridge:**
```bash
# Test NLP bridge functionality
# Send test input
# Verify processing works
# Check logs for errors
```

---

## Deployment Checklist

- [ ] **Pre-Deployment:**
  - [ ] Locate script file
  - [ ] Backup original script
  - [ ] Understand current functionality

- [ ] **Deployment:**
  - [ ] Fix AWK syntax
  - [ ] Test with sample input
  - [ ] Verify no syntax errors
  - [ ] Test NLP bridge functionality

- [ ] **Post-Deployment:**
  - [ ] Monitor log files
  - [ ] Verify no errors
  - [ ] Test NLP bridge end-to-end
  - [ ] Monitor for 24 hours

---

## Rollback Plan

```bash
# Restore original script
git checkout HEAD~1 <script_file>

# Reload LaunchAgent (if applicable)
launchctl unload ~/Library/LaunchAgents/com.02luka.gg.nlp-bridge.plist
launchctl load ~/Library/LaunchAgents/com.02luka.gg.nlp-bridge.plist
```

---

## Success Metrics

- ✅ No AWK syntax errors in logs
- ✅ NLP bridge processes input correctly
- ✅ Key-value parsing works
- ✅ No regressions in functionality

---

## Timeline

- **Task 1-2:** 30 minutes (locate and analyze)
- **Task 3:** 30 minutes (fix syntax)
- **Task 4:** 30 minutes (test)
- **Task 5:** 24 hours (monitor)

**Total:** ~2 hours active work + 24h monitoring

---

## References

- **SPEC:** `g/reports/feature_fix_gg_nlp_bridge_awk_error_SPEC.md`
- **Error Log:** `logs/gg_nlp_bridge.20251112_052244.log`

