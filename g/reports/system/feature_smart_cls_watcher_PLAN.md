# Feature PLAN: Smart CLS Watcher

**Date:** 2025-11-15  
**Feature:** Smart CLS Watcher with Heartbeat Detection

---

## Phase 1: Create Main Watcher Script

### Tasks
1. Create `tools/watch_cls_alive.zsh` with:
   - Configuration via env vars
   - Heartbeat detection logic
   - macOS notification function
   - Auto-kill with cooldown
   - Logging function
   - Main loop

### File: `tools/watch_cls_alive.zsh`
- Full implementation as per user spec
- All configurable options
- Smart heartbeat detection
- Cooldown protection

---

## Phase 2: Create Entrypoint Wrapper

### Tasks
1. Create `tools/check-cls` wrapper
2. Make it executable
3. Optional: Add alias to `.zshrc` (if not exists)

### File: `tools/check-cls`
- Thin wrapper that calls `watch_cls_alive.zsh`
- Allows future extensibility

---

## Phase 3: Verify and Test

### Tasks
1. Syntax check both scripts
2. Verify file permissions
3. Test heartbeat detection logic
4. Test notification (if on macOS)
5. Test logging

### Commands
```bash
# Syntax check
zsh -n tools/watch_cls_alive.zsh
zsh -n tools/check-cls

# Test heartbeat file creation
mkdir -p ~/02luka/state
date +%s > ~/02luka/state/cls_last_activity

# Test watcher (run briefly)
timeout 10 tools/check-cls || true
```

---

## Phase 4: Documentation

### Tasks
1. Add usage comments in script
2. Document environment variables
3. Document CLS heartbeat requirement

---

## Phase 5: Commit and Push

### Tasks
1. Stage new files
2. Commit with descriptive message
3. Push to current branch

### Commit Message
```
feat(tools): add smart CLS watcher with heartbeat detection

- Add watch_cls_alive.zsh: smart monitoring with heartbeat detection
  * Waits for real heartbeat before alerting (no spam)
  * macOS notifications on freeze
  * Auto-kill with cooldown protection
  * Persistent logging
- Add check-cls: simple entrypoint wrapper
- Configurable via environment variables
- Requires CLS to write heartbeat to state file

Usage: check-cls
Config: ENABLE_AUTO_KILL, CLS_KILL_CMD, KILL_COOLDOWN, etc.
```

---

## Test Strategy

### Manual Testing
1. ✅ Syntax validation
2. ✅ File permissions check
3. ✅ Heartbeat detection (create test file)
4. ✅ Logging verification
5. ✅ Notification test (if on macOS)
6. ✅ Cooldown test (if auto-kill enabled)

### Integration Testing
- Run watcher for 30 seconds
- Create heartbeat file mid-run
- Verify it detects heartbeat
- Stop heartbeat (delete file)
- Verify freeze detection after timeout

---

## Rollback Plan

If issues found:
1. Remove files: `tools/watch_cls_alive.zsh`, `tools/check-cls`
2. Remove alias from `.zshrc` (if added)
3. No system impact (tool-only)

---

## Timeline

- **Phase 1:** 5 min (create watcher script)
- **Phase 2:** 2 min (create wrapper)
- **Phase 3:** 5 min (verification)
- **Phase 4:** 2 min (documentation)
- **Phase 5:** 2 min (commit & push)

**Total:** ~15 minutes

---

**Status:** ✅ PLAN Complete  
**Next:** Execute implementation

