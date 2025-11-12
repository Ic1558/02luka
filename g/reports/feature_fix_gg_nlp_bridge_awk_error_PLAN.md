# Feature PLAN: Fix gg_nlp_bridge AWK Syntax Error

**Feature ID:** `fix_gg_nlp_bridge_awk_error`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Task Breakdown

- [ ] **Task 1:** Locate the script causing the error
  - Search for `gg_nlp_bridge` references
  - Check LaunchAgents (`com.02luka.gg.nlp-bridge`)
  - Check `agents/` directory for Python scripts
  - Check `tools/` directory for shell scripts
  - Identify exact file and line number

- [ ] **Task 2:** Analyze the AWK code
  - Read the problematic AWK section
  - Understand the intended pattern matching
  - Identify all syntax issues
  - Document the correct pattern

- [ ] **Task 3:** Fix AWK syntax
  - Remove `>>>` and `<<<` debug markers
  - Fix regex pattern syntax
  - Ensure proper `match()` function usage
  - Add proper error handling

- [ ] **Task 4:** Test the fix
  - Create test input (sample key-value pairs)
  - Run script with test input
  - Verify no AWK errors
  - Verify parsing works correctly

- [ ] **Task 5:** Validate in production
  - Check log files for errors
  - Verify NLP bridge functionality
  - Monitor for 24 hours
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

