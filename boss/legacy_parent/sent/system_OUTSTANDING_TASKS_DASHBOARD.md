---
project: general
tags: [legacy]
---
# Outstanding Tasks Dashboard

**Updated:** 2025-10-06T03:35:00Z
**Source:** Analysis of 3 frozen sessions (251003, 251002, 250928)

---

## 🎯 Quick Status

| Area | Status | Priority | ETA |
|------|--------|----------|-----|
| **Context Engineering v6.0** | ⚠️ 40% Complete (Phases 1.4-3.0 pending) | 🔴 Critical | 4-6h |
| **Docker Stability** | ⚠️ 90% Complete (deployment pending) | 🟡 High | 30min |
| **CORS Updates** | ✅ Ready (restart needed) | 🟡 High | 15min |
| **Disk Space** | 🔴 Critical (100% full) | 🟢 Medium | 1-2h |

---

## 🔴 Critical: Context Engineering v6.0

**What's Blocking:** Fork failure during Phase 1.4 testing (process limit exhaustion)

**Status Breakdown:**
```
✅ Phase 1.1-1.3: Core v6.0 features (DONE)
❌ Phase 1.4: Integration testing (BLOCKED - fork error)
⏳ Phase 1.5: Backward compatibility (NOT STARTED)
⏳ Phase 2.0: Multi-model routing (NOT STARTED)
⏳ Phase 3.0: Production deployment (NOT STARTED)
```

**To Resume:**
```bash
# 1. Fix process limits
ulimit -n 4096

# 2. Add subprocess pooling to context_engine.sh
# (prevent fork bomb during model_router.sh testing)

# 3. Complete Phase 1.4
cd ~/dev/02luka-repo
AUTO_PRUNE=1 ADVANCED_FEATURES=1 V6_LOGGING=1 \
  bash g/tools/context_engine.sh version

# Test model_router.sh integration
bash g/tools/model_router.sh --test

# 4. Execute remaining phases
# Phase 1.5: Backward compat tests
# Phase 2.0: Multi-model routing deployment
# Phase 3.0: Documentation + rollout
```

**Deliverables Needed:**
- [ ] `g/manuals/CONTEXT_ENGINEERING_V6_PRODUCTION.md`
- [ ] `g/runbooks/CONTEXT_ENGINE_V6_OPERATIONS.md`
- [ ] `g/reports/CONTEXT_ENGINE_V6_TESTING_RESULTS.md`

---

## 🟡 High: Docker Timeout Protection

**What's Ready:** Code written, just needs deployment

**Incomplete Patch Location:** Session clc_250928.txt (lines 29100-29250)

**To Deploy:**
```bash
# 1. Open verify_system.sh
vim ~/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My\ Drive/02luka/g/tools/verify_system.sh

# 2. Add timeout wrapper (near top of file):
DOCKER_BIN="${DOCKER_BIN:-docker}"
DOCKER_TIMEOUT="${DOCKER_TIMEOUT:-5}"
DOCKER_RETRIES="${DOCKER_RETRIES:-2}"
DOCKER_STATE="UNKNOWN"

d() { # Docker wrapper with timeout
  local n=0
  while (( n <= DOCKER_RETRIES )); do
    if /usr/bin/env timeout "${DOCKER_TIMEOUT}s" "$DOCKER_BIN" "$@" 2>/dev/null; then
      return 0
    fi
    n=$((n+1))
    sleep 0.5
  done
  return 1
}

check_docker_ready() {
  if d info >/dev/null; then
    DOCKER_STATE="READY"; return 0
  else
    DOCKER_STATE="UNRESPONSIVE"; return 1
  fi
}

# 3. Replace all `docker` calls with `d`
# Example: docker ps → d ps

# 4. Test
bash "$SOT_PATH/g/tools/verify_system.sh"
```

---

## 🟡 High: CORS Service Restart

**What's Ready:** Code committed, service restart needed

**To Apply:**
```bash
# Restart health_proxy with new CORS settings
launchctl bootout "gui/$(id -u)/com.02luka.health.proxy" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.02luka.health.proxy.plist"

# Verify CORS working
curl -X OPTIONS http://127.0.0.1:3002/chat \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" -v
```

**Expected:** HTTP 204 with `Access-Control-Allow-Methods: GET, POST, OPTIONS`

---

## 🟢 Medium: Disk Space Cleanup

**Current State:** System partition at 100% capacity

**Immediate Actions:**
```bash
# Check what's using space
du -sh ~/Library/CloudStorage/GoogleDrive-*/
du -sh ~/Library/Caches/
du -sh /tmp/*

# Safe cleanup (no user confirmation needed)
rm -rf /tmp/*
rm -rf ~/Library/Caches/com.anthropic.claude-code/*
rm -rf ~/Library/Caches/Claude/*

# Find large node_modules directories
find ~/Library/CloudStorage/GoogleDrive-* -name "node_modules" -type d -exec du -sh {} \;

# Verify freed space
df -h | grep /System/Volumes/Data
```

**Time Machine Cleanup (User Decision Required):**
```bash
# List all Time Machine backups
tmutil listbackups

# Delete specific backup (example)
# tmutil delete /path/to/backup

# Or thin all backups older than 30 days
# tmutil thinbackups / -d 30
```

---

## 📊 Priority Execution Order

**Recommended sequence to resume work:**

### Step 1: System Health (15 minutes)
```bash
# Free disk space first (prevent future ENOSPC errors)
rm -rf /tmp/*
rm -rf ~/Library/Caches/*

# Check ulimit
ulimit -a
ulimit -n 4096  # If needed
```

### Step 2: Quick Wins (45 minutes)
```bash
# Deploy Docker timeout protection
# Apply CORS restart
# Both are ready to deploy, just need execution
```

### Step 3: Context Engineering v6.0 (4-6 hours)
```bash
# Fix fork issue
# Complete Phase 1.4 testing
# Execute Phase 1.5 (backward compat)
# Execute Phase 2.0 (multi-model routing)
# Execute Phase 3.0 (production docs)
```

---

## 🚨 Blockers and Risks

### Active Blockers

1. **Fork Failure in context_engine.sh**
   - **Impact:** Cannot test v6.0 integration
   - **Root Cause:** Process limit or subprocess leak
   - **Solution:** Investigate ulimit + add subprocess pooling

2. **Disk Space at 100%**
   - **Impact:** Claude Code crashes, cannot save sessions
   - **Root Cause:** Time Machine backups + Drive mirror
   - **Solution:** Cleanup temp files + review TM retention

### Risks

1. **No backward compatibility testing yet**
   - v6.0 might break v5 consumers
   - Need Phase 1.5 tests before production

2. **Docker timeout patch not deployed**
   - verify_system.sh can still hang
   - Affects all health checks

---

## ✅ Today's Goal

**Minimum viable completion:**
- [ ] Disk space < 80%
- [ ] Docker timeout protection deployed
- [ ] CORS changes applied and verified
- [ ] Context Engine v6.0 Phase 1.4 unblocked (fork issue identified)

**Stretch goal:**
- [ ] Context Engine v6.0 Phase 1.4 complete
- [ ] Phase 1.5 backward compat verified
- [ ] All changes committed

---

## 📁 Reference Files

- **Full Analysis:** `g/reports/FROZEN_SESSIONS_ANALYSIS.md`
- **Session Archives:**
  - `f/boss/archive/cli_qa/clc_251003.txt` (fork failure)
  - `f/boss/archive/cli_qa/clc_251002.txt` (v6.0 upgrade)
  - `f/boss/archive/cli_qa/clc_250928.txt` (disk full)

---

**Next Command:**
```bash
# Start with disk cleanup
rm -rf /tmp/* && rm -rf ~/Library/Caches/* && df -h | grep Data
```
