# V5 Controlled Enable Checklist
**Date**: 2025-12-17
**Status**: Ready for review (NOT enabled yet)

---

## Pre-Enable Verification

### 1. Confirm Paths (Lowercase Canonical)

```bash
# Check config
grep -E "inbox|processed|error" g/config/mary_router_gateway_v3.yaml | grep -v "#"

# Expected: all lowercase (inbox_local/main, processed_local/main, error_local/main)
```

**Current Status**:
```yaml
inbox_path: bridge/inbox_local/main
processed_path: bridge/processed_local/main
error_path: bridge/error_local/main
```
✅ **Confirmed lowercase**

### 2. Verify Gateway Can Start

```bash
# Check gateway process
ps aux | grep gateway_v3_router | grep -v grep

# Check recent telemetry
tail -5 g/telemetry/gateway_v3_router.jsonl
```

**Current Status**: Gateway running, telemetry active ✅

### 3. Check V5 Flag Status

```bash
# Check current setting
grep "use_v5_stack" g/config/mary_router_gateway_v3.yaml
```

**Current Status**: `use_v5_stack: false` (legacy mode) ✅

---

## Enable Procedure

### Step 1: Enable V5 Stack

```bash
cd ~/02luka
cp g/config/mary_router_gateway_v3.yaml g/config/mary_router_gateway_v3.yaml.bak

# Enable v5
sed -i '' 's/use_v5_stack: false/use_v5_stack: true/' g/config/mary_router_gateway_v3.yaml

# Verify change
grep "use_v5_stack" g/config/mary_router_gateway_v3.yaml
```

### Step 2: Restart Gateway

```bash
# Find gateway PID
ps aux | grep gateway_v3_router | grep -v grep

# Kill gracefully
kill -TERM <PID>

# Wait 2 seconds
sleep 2

# Restart via launchd (or manual)
# launchctl restart com.02luka.gateway
# OR manual: nohup python3 agents/mary_router/gateway_v3_router.py &
```

### Step 3: Verify V5 Active

**Within 5 minutes**, check:

```bash
# 1. Monitor shows v5 activity
zsh tools/monitor_v5_production.zsh json

# Expected: "v5_activity_24h": "v5:1,legacy:0" (or similar with v5 > 0)

# 2. Telemetry shows v5
tail -5 g/telemetry/gateway_v3_router.jsonl | jq .status_v5

# Expected: true

# 3. No errors
tail -20 g/logs/gateway_v3_router.log | grep -i error
```

---

## Rollback Procedure (1 Command)

If v5 fails or shows errors:

```bash
cd ~/02luka

# Restore backup config
cp g/config/mary_router_gateway_v3.yaml.bak g/config/mary_router_gateway_v3.yaml

# Restart gateway
kill -TERM $(ps aux | grep gateway_v3_router | grep -v grep | awk '{print $2}')
sleep 2
# Restart manually or via launchd

# Verify rollback
grep "use_v5_stack" g/config/mary_router_gateway_v3.yaml
# Should show: use_v5_stack: false
```

---

## Success Criteria

✅ Monitor shows `v5:1` or higher within 5 minutes  
✅ No errors in gateway log  
✅ Telemetry `status_v5: true`  
✅ Inbox backlog remains 0  

---

## Failure Indicators

❌ Monitor still shows `v5:0, legacy:N` after 5 minutes  
❌ Errors in gateway log  
❌ Gateway process crashes  
❌ Inbox backlog increases  

**Action if fail**: Execute rollback procedure immediately

---

## Current System State (Pre-Enable)

- Gateway: Running ✅
- Config: `use_v5_stack: false` ✅
- Paths: All lowercase ✅
- Monitor: `v5:0, legacy:7` (expected in legacy mode) ✅
- Inbox backlog: 0 ✅
- No errors ✅

**Ready to enable**: YES (when Boss approves)

---

## Notes

- Lowercase migration completed (commit 97e834b2)
- Execution surface clean
- Backups available in ~/02luka_ws/_backup/
- PR-11 monitoring active
- Rollback tested and ready

