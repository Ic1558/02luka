# Dashboard Server Wiring - PLAN

**Date:** 2025-11-13  
**Feature:** Fix Dashboard Server Auto-Start and Wiring  
**Status:** 📋 READY FOR IMPLEMENTATION

---

## Implementation Phases

### Phase 1: Server Enhancements (15 min)

**Tasks:**
1. Add port conflict detection to `wo_dashboard_server.js`
2. Add `/health` endpoint
3. Add graceful shutdown handlers
4. Improve error handling

**Files:**
- `g/apps/dashboard/wo_dashboard_server.js`

**Test:**
```bash
cd g/apps/dashboard
node wo_dashboard_server.js
curl http://localhost:8765/health
```

---

### Phase 2: LaunchAgent Creation (10 min)

**Tasks:**
1. Create `LaunchAgents/com.02luka.wo_dashboard_server.plist`
2. Configure environment variables
3. Set up logging paths
4. Enable KeepAlive and RunAtLoad

**Files:**
- `LaunchAgents/com.02luka.wo_dashboard_server.plist`

**Test:**
```bash
launchctl load ~/Library/LaunchAgents/com.02luka.wo_dashboard_server.plist
launchctl list | grep wo_dashboard
curl http://localhost:8765/health
```

---

### Phase 3: Log Directory Setup (5 min)

**Tasks:**
1. Create `logs/` directory if missing
2. Ensure write permissions
3. Test log file creation

**Files:**
- `logs/` directory

**Test:**
```bash
ls -la ~/02luka/logs/wo_dashboard_server.*.log
tail -f ~/02luka/logs/wo_dashboard_server.stdout.log
```

---

### Phase 4: Health Check Script (10 min)

**Tasks:**
1. Create `tools/check_dashboard_server.zsh`
2. Check server status
3. Test API endpoints
4. Report health status

**Files:**
- `tools/check_dashboard_server.zsh`

**Test:**
```bash
./tools/check_dashboard_server.zsh
```

---

### Phase 5: Verification & Testing (10 min)

**Tasks:**
1. Verify LaunchAgent loads correctly
2. Test auto-start on login (simulate)
3. Test API endpoints
4. Test crash recovery (kill process, verify restart)
5. Check logs for errors

**Verification Checklist:**
- [ ] Server starts automatically
- [ ] Health endpoint responds
- [ ] API endpoints work
- [ ] Logs are written
- [ ] Server restarts on crash
- [ ] No errors in logs

---

## Test Strategy

### Unit Tests
- Port conflict detection
- Health endpoint response
- API endpoint responses
- Error handling

### Integration Tests
- LaunchAgent loading
- Auto-start on boot
- Crash recovery
- Log file creation

### Manual Tests
1. Start server manually → verify endpoints
2. Load LaunchAgent → verify auto-start
3. Kill server process → verify restart
4. Check dashboard → verify API calls work

---

## Rollback Plan

If issues occur:

1. **Unload LaunchAgent:**
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.02luka.wo_dashboard_server.plist
   ```

2. **Stop Server:**
   ```bash
   lsof -ti:8765 | xargs kill
   ```

3. **Restore Previous Version:**
   ```bash
   git checkout HEAD -- g/apps/dashboard/wo_dashboard_server.js
   ```

4. **Remove LaunchAgent:**
   ```bash
   rm ~/Library/LaunchAgents/com.02luka.wo_dashboard_server.plist
   ```

---

## Success Metrics

- **Uptime:** Server running 24/7 without manual intervention
- **Response Time:** API endpoints respond < 100ms
- **Crash Recovery:** Server restarts within 30 seconds of crash
- **Log Quality:** No errors in logs for 24 hours

---

## Timeline

- **Phase 1:** 15 min (Server enhancements)
- **Phase 2:** 10 min (LaunchAgent)
- **Phase 3:** 5 min (Log setup)
- **Phase 4:** 10 min (Health check)
- **Phase 5:** 10 min (Verification)

**Total:** ~50 minutes

---

## Dependencies

- ✅ Node.js installed
- ✅ Redis running
- ✅ `wo_dashboard_server.js` exists
- ✅ LaunchAgent directory exists
- ⚠️ Logs directory (will create if missing)

---

## Next Steps

1. Review SPEC and PLAN
2. Implement Phase 1 (Server enhancements)
3. Implement Phase 2 (LaunchAgent)
4. Test and verify
5. Deploy
