# v5 Stack Enable Rollout Plan

**Date:** 2025-12-17  
**Config File:** `g/config/mary_router_gateway_v3.yaml`  
**Current State:** `use_v5_stack: false`  
**Target State:** `use_v5_stack: true` + lowercase paths

---

## Pre-Enable Checklist

- [x] Baseline docs v5 committed and pushed (`9638cb82`)
- [x] Branch synced with origin/main
- [x] Gateway process running (single process verified)
- [x] Monitor script updated (config-driven paths)
- [ ] **Ready to enable v5 stack**

---

## Rollout Steps (3-Phase)

### Phase 1: Backup & Prepare

```bash
cd ~/02luka

# 1. Backup current config
cp g/config/mary_router_gateway_v3.yaml \
   g/config/mary_router_gateway_v3.yaml.bak_$(date +%Y%m%d_%H%M%S)

# 2. Verify current state
echo "Current config:"
grep -E "(use_v5_stack|inbox|processed|error)" g/config/mary_router_gateway_v3.yaml
```

**Expected output:**
```
use_v5_stack: false
inbox: "bridge/inbox_local/MAIN"
processed: "bridge/processed_local/MAIN"
error: "bridge/error_local/MAIN"
```

---

### Phase 2: Enable v5 Stack

```bash
cd ~/02luka

# 1. Update config: enable v5 + lowercase paths
python3 << 'PYEOF'
import yaml
from pathlib import Path

config_path = Path("g/config/mary_router_gateway_v3.yaml")
with config_path.open("r") as f:
    config = yaml.safe_load(f)

# Enable v5 stack
config["use_v5_stack"] = True

# Normalize paths to lowercase
directories = config.get("directories", {})
if "inbox" in directories:
    directories["inbox"] = directories["inbox"].replace("/MAIN", "/main")
if "processed" in directories:
    directories["processed"] = directories["processed"].replace("/MAIN", "/main")
if "error" in directories:
    directories["error"] = directories["error"].replace("/MAIN", "/main")

with config_path.open("w") as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False)

print("✅ Config updated:")
print(f"  use_v5_stack: {config['use_v5_stack']}")
print(f"  inbox: {directories.get('inbox')}")
print(f"  processed: {directories.get('processed')}")
print(f"  error: {directories.get('error')}")
PYEOF

# 2. Restart gateway LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist 2>/dev/null || true
sleep 1
launchctl load ~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist

# 3. Wait for gateway to start
sleep 3

# 4. Verify gateway process
ps aux | grep -E "gateway_v3_router|mary-gateway" | grep -v grep
```

**Expected:**
- Single gateway process running
- Config shows `use_v5_stack: true`
- Paths normalized to lowercase

---

### Phase 3: Verify v5 Activity

```bash
cd ~/02luka

# 1. Check monitor output (should show v5 activity, not legacy)
zsh tools/monitor_v5_production.zsh json | jq -r '.v5_activity_24h, .lane_distribution'

# 2. Check telemetry log (should see action=process_v5, not action=route)
tail -5 ~/02luka_ws/g/telemetry/gateway_v3_router.jsonl | jq -r '.action' | sort -u

# 3. Verify no legacy fallback
zsh tools/monitor_v5_production.zsh json | jq -r '.status' | grep -q "operational" && echo "✅ Gateway operational" || echo "❌ Gateway not operational"
```

**Success Criteria:**
- `v5_activity_24h` shows activity (not "NO_LOG")
- `lane_distribution` shows lane counts (FAST/WARN/STRICT)
- Telemetry shows `action: "process_v5"` (not `action: "route"`)
- No legacy fallback errors

---

## Rollback (1-Command)

**If v5 enable causes issues, rollback immediately:**

```bash
cd ~/02luka && \
cp g/config/mary_router_gateway_v3.yaml.bak_* g/config/mary_router_gateway_v3.yaml && \
launchctl unload ~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist 2>/dev/null && \
sleep 1 && \
launchctl load ~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist && \
echo "✅ Rollback complete: v5 disabled, legacy routing restored"
```

**Or use latest backup:**
```bash
cd ~/02luka && \
LATEST_BACKUP=$(ls -t g/config/mary_router_gateway_v3.yaml.bak_* | head -1) && \
cp "$LATEST_BACKUP" g/config/mary_router_gateway_v3.yaml && \
launchctl unload ~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist 2>/dev/null && \
sleep 1 && \
launchctl load ~/Library/LaunchAgents/com.02luka.mary-gateway-v3.plist && \
echo "✅ Rollback complete from: $LATEST_BACKUP"
```

---

## Post-Enable Monitoring

**First 24 hours:**
- Monitor telemetry every hour: `zsh tools/monitor_v5_production.zsh json`
- Check for errors: `tail -20 ~/02luka_ws/g/telemetry/gateway_v3_router.jsonl | jq -r 'select(.error != null)'`
- Verify lane distribution: FAST/WARN/STRICT lanes routing correctly

**Success indicators:**
- ✅ No legacy fallback (`action: "route"` should not appear)
- ✅ Lane distribution matches expected patterns
- ✅ No critical errors in telemetry
- ✅ Gateway single-process stable

---

## Notes

- **Config SOT:** `g/config/mary_router_gateway_v3.yaml`
- **Telemetry:** `~/02luka_ws/g/telemetry/gateway_v3_router.jsonl`
- **Monitor:** `tools/monitor_v5_production.zsh`
- **LaunchAgent:** `com.02luka.mary-gateway-v3`

**After successful enable:**
- Update PR-11 status: v5 stack active
- Continue 7-day stability window monitoring
- Prepare PR-12 post-mortem after stability period

