# Phase 2C-Mini: Expected Behavior Guide

**Purpose:** Verify services are working correctly (not just exit 0)  
**Date:** 2025-12-07

---

## 1. `com.02luka.mary-coo` (Delegation Orchestrator)

### Purpose
- **Mary COO** = Chief Operating Officer
- Orchestrates task delegation
- Routes work orders to appropriate agents
- Monitors delegation pipeline

### Expected Behavior

**Exit Code:** `0` (success) or `1` (expected error - no work to process)

**Log Patterns (Success):**
```
✅ Mary COO started
📋 Checking inbox: ~/02luka/bridge/inbox/CLC
📦 Found 0 pending work orders
✅ No work to process, exiting cleanly
```

**Log Patterns (Processing):**
```
✅ Mary COO started
📋 Checking inbox: ~/02luka/bridge/inbox/CLC
📦 Found 2 pending work orders
🔄 Processing WO-20251207-XXXX
✅ Delegated to CLC executor
📦 Processing WO-20251207-YYYY
✅ Delegated to CLC executor
✅ All work orders processed
```

**Log Patterns (Error - Fix Needed):**
```
❌ FileNotFoundError: /Users/icmini/LocalProjects/02luka_local_g/agents/mary/mary.py
❌ ModuleNotFoundError: No module named 'agents.mary'
❌ ConnectionError: Redis connection failed
```

**Verification Commands:**
```bash
# Check exit code
launchctl list | grep "mary-coo"

# Check log for success patterns
tail -20 ~/02luka/logs/launchd_mary_coo.out | grep -E "✅|📋|📦|🔄"

# Check for errors
tail -20 ~/02luka/logs/launchd_mary_coo.err | grep -v "^$"
```

**Success Criteria:**
- Exit code: `0` or `1` (both acceptable)
- Log shows: "Mary COO started" or "No work to process"
- No `FileNotFoundError` or `ModuleNotFoundError`
- No `ConnectionError` (unless Redis is actually down)

---

## 2. `com.02luka.delegation-watchdog` (Stuck Task Monitor)

### Purpose
- Monitors delegation pipeline for stuck tasks
- Checks MCP health
- Monitors pending queue size
- Writes health report to `hub/delegation_watchdog.json`

### Expected Behavior

**Exit Code:** `0` (success)

**Log Patterns (Success):**
```
✅ Delegation watchdog started
📋 Reading config: ~/02luka/config/delegation_watchdog.yaml
🔍 Checking MCP health: ~/02luka/hub/mcp_health.json
📊 Checking pending queue: ~/02luka/hub/index.json
✅ All systems healthy
✅ wrote ~/02luka/hub/delegation_watchdog.json
```

**Log Patterns (Stuck Detection):**
```
✅ Delegation watchdog started
📋 Reading config: ~/02luka/config/delegation_watchdog.yaml
🔍 Checking MCP health: ~/02luka/hub/mcp_health.json
⚠️  MCP unhealthy detected
📊 Checking pending queue: ~/02luka/hub/index.json
⚠️  Pending queue overflow: 25 items (max: 20)
✅ wrote ~/02luka/hub/delegation_watchdog.json
```

**Log Patterns (Error - Fix Needed):**
```
❌ FileNotFoundError: /Users/icmini/LocalProjects/02luka_local_g/g/tools/delegation_watchdog.py
❌ ModuleNotFoundError: No module named 'yaml'
❌ PermissionError: Cannot write to hub/delegation_watchdog.json
```

**Verification Commands:**
```bash
# Check exit code
launchctl list | grep "delegation-watchdog"

# Check log for success patterns
tail -20 ~/02luka/logs/launchd_watchdog.out | grep -E "✅|📋|🔍|📊|⚠️"

# Check output file exists
test -f ~/02luka/hub/delegation_watchdog.json && echo "✅ Output file exists" || echo "❌ Output file missing"

# Check output file content
cat ~/02luka/hub/delegation_watchdog.json | jq '.'
```

**Success Criteria:**
- Exit code: `0`
- Log shows: "Delegation watchdog started" and "wrote .../delegation_watchdog.json"
- Output file exists: `~/02luka/hub/delegation_watchdog.json`
- Output file contains valid JSON with `_meta` and `items` fields
- No `FileNotFoundError` or `ModuleNotFoundError`

---

## 3. `com.02luka.clc-executor` (Work Order Executor)

### Purpose
- Executes work orders from CLC inbox
- Applies file operations (write, patch, replace)
- Respects Writer Policy V3.5
- Reports execution results

### Expected Behavior

**Exit Code:** `0` (success) or `1` (expected error - no work to process)

**Log Patterns (Success - No Work):**
```
✅ CLC Executor started
📋 Checking inbox: ~/02luka/bridge/inbox/CLC
📦 Found 0 pending work orders
✅ No work to process, exiting cleanly
```

**Log Patterns (Success - Processing):**
```
✅ CLC Executor started
📋 Checking inbox: ~/02luka/bridge/inbox/CLC
📦 Found 1 pending work order: WO-20251207-XXXX
🔍 Validating Writer Policy V3.5
✅ Policy check passed
📝 Applying operations: write_file, apply_patch
✅ Work order executed successfully
📤 Moving to processed: ~/02luka/bridge/processed/CLC
✅ All work orders processed
```

**Log Patterns (Error - Policy Blocked):**
```
✅ CLC Executor started
📋 Checking inbox: ~/02luka/bridge/inbox/CLC
📦 Found 1 pending work order: WO-20251207-XXXX
🔍 Validating Writer Policy V3.5
❌ Policy violation: Cannot write to governance file
📤 Moving to error: ~/02luka/bridge/error/CLC
✅ Work order blocked (expected behavior)
```

**Log Patterns (Error - Fix Needed):**
```
❌ FileNotFoundError: /Users/icmini/LocalProjects/02luka_local_g/g/tools/clc_executor.py
❌ ModuleNotFoundError: No module named 'g.core.fde'
❌ ImportError: Cannot import Writer Policy V3.5
```

**Verification Commands:**
```bash
# Check exit code
launchctl list | grep "clc-executor"

# Check log for success patterns
tail -20 ~/02luka/logs/launchd_clc_executor.out | grep -E "✅|📋|📦|🔍|📝|📤"

# Check for errors
tail -20 ~/02luka/logs/launchd_clc_executor.err | grep -v "^$"

# Check processed/error directories
ls -la ~/02luka/bridge/processed/CLC/ 2>/dev/null | head -5
ls -la ~/02luka/bridge/error/CLC/ 2>/dev/null | head -5
```

**Success Criteria:**
- Exit code: `0` or `1` (both acceptable)
- Log shows: "CLC Executor started" or "No work to process"
- No `FileNotFoundError` or `ModuleNotFoundError`
- No `ImportError` for Writer Policy V3.5
- Can process work orders when present (test with sample WO)

---

## Common Root Causes (All Services)

### 1. Path Issues
**Symptom:** `FileNotFoundError: /Users/icmini/LocalProjects/02luka_local_g/...`  
**Fix:** Update plist `ProgramArguments` and `EnvironmentVariables` to use `~/02luka` or `/Users/icmini/02luka`

### 2. Python Module Issues
**Symptom:** `ModuleNotFoundError: No module named '...'`  
**Fix:** Check PYTHONPATH, virtualenv, or install missing dependencies

### 3. Redis Connection Issues
**Symptom:** `ConnectionError: Redis connection failed`  
**Fix:** Check Redis is running (`redis-cli ping`), update connection URL in config

### 4. Permission Issues
**Symptom:** `PermissionError: Cannot write to ...`  
**Fix:** Check file/directory permissions, ensure log directories exist

---

## Quick Verification Script

```bash
#!/usr/bin/env zsh
# Quick verification for Phase 2C-Mini services

echo "🔍 Phase 2C-Mini Service Verification"
echo ""

for service in mary-coo delegation-watchdog clc-executor; do
  echo "=== $service ==="
  
  # Check exit code
  exit_code=$(launchctl list | grep "com.02luka.$service" | awk '{print $2}')
  if [[ "$exit_code" == "0" ]] || [[ "$exit_code" == "1" ]]; then
    echo "✅ Exit code: $exit_code (acceptable)"
  else
    echo "❌ Exit code: $exit_code (needs fix)"
  fi
  
  # Check log for errors
  log_file="$HOME/02luka/logs/launchd_${service//-/_}.err"
  if [[ -f "$log_file" ]]; then
    error_count=$(tail -20 "$log_file" | grep -c "FileNotFoundError\|ModuleNotFoundError\|ImportError" || echo "0")
    if [[ "$error_count" -eq 0 ]]; then
      echo "✅ No critical errors in log"
    else
      echo "❌ Found $error_count critical errors in log"
    fi
  else
    echo "⚠️  Log file not found: $log_file"
  fi
  
  echo ""
done
```

---

**Reference:**
- Quick Reference: `launchagent_repair_PHASE2C_MINI_QUICK_REF.md`
- Example Walkthrough: `launchagent_repair_PHASE2C_MINI_EXAMPLE.md`
