# LaunchAgent P0 Minimal Set - Final Status
**Date:** 2025-12-18  
**Status:** ✅ **COMPLETE** - P0 set reduced from 16 → 4, reflecting actual execution surface

---

## ✅ Final P0 Set (4 agents)

1. **`com.02luka.mary-gateway-v3`** (conditional)
   - Gateway v3 router - Active routing system
   - Status: Running (pid=36016)
   - Evidence: Telemetry shows daily WO routing

2. **`com.02luka.clc-executor`**
   - Executes CLC work orders
   - Status: Running (pid=13817)
   - Evidence: Processing WOs from bridge/inbox/CLC/

3. **`com.02luka.rag.api`**
   - RAG API server (port 8765)
   - Status: Running (pid=10617)
   - Evidence: Responding, 250 docs indexed

4. **`com.02luka.memory.hub`** (conditional)
   - Memory hub for shared memory system
   - Status: Running (pid=2332)
   - Evidence: Plist exists, actively running

---

## 📊 Current Status

- **P0 Total:** 4
- **P0 Running:** 4
- **Overall:** YELLOW (P0 all running, some optional stopped)
- **Status Logic:** ✅ Correct - reflects actual system stability

---

## 🔄 Next Steps (Freeze & Observe)

### Monitor for 24+ hours:
1. **`monitor_v5_production`** - Verify v5 metrics increasing (work incoming)
2. **`launchagent_status`** - Must not drop to RED (P0 must stay running)

### If mcp.fs stderr spam becomes annoying:
- **Action:** Rotate/truncate logs (don't try to stabilize mcp.fs yet)
- **Reason:** stdio-server requires attached client; frequent exit/respawn is expected without client
- **Keep:** Optional until proven required by active client usage

---

## 📝 Key Decisions Made

1. **WO Pipeline → Optional**: Gateway v3 + CLC executor handle WO processing directly
2. **Mary-dispatch/bridge → Optional**: Gateway v3 replaces legacy routing
3. **MLS watchers → Optional**: No evidence of active recording
4. **mcp.fs → Optional**: stdio-server pattern, requires attached client
5. **clc_local → Optional**: Backup/alternative to clc-executor

---

## ✅ Verification

- ✅ Script logic correct
- ✅ Priority list updated
- ✅ Status reflects reality (not aspirational)
- ✅ Dashboard will show meaningful GREEN/YELLOW/RED

**Result:** System status now accurately reflects actual execution surface stability.
