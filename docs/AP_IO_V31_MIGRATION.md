# AP/IO v3.1 Migration Guide

**Version:** 3.1  
**Last Updated:** 2025-11-17

---

## Overview

This guide helps you migrate from AP/IO v1.0 to v3.1.

---

## Key Changes

### 1. Protocol Field

**v1.0:** No protocol field  
**v3.1:** Required `protocol: "AP/IO"` and `version: "3.1"`

### 2. Event Structure

**v1.0:**
```json
{
  "event": "task_start",
  "task_id": "wo-test",
  "source": "gg_orchestrator",
  "summary": "Test task"
}
```

**v3.1:**
```json
{
  "event": {
    "type": "task_start",
    "task_id": "wo-test",
    "source": "gg_orchestrator",
    "summary": "Test task"
  }
}
```

### 3. Timestamp Field

**v1.0:** `ts` or `timestamp`  
**v3.1:** `ts` (preferred), `timestamp` supported for backward compatibility

### 4. New Fields

**v3.1 adds:**
- `ledger_id`: Unique ledger entry identifier
- `parent_id`: Parent relationship tracking
- `execution_duration_ms`: Execution time tracking
- `correlation_id`: Event chain correlation
- `session_id`: Session tracking

---

## Migration Steps

### Step 1: Update Writer Calls

**v1.0:**
```bash
# Old format (if you had a custom writer)
echo '{"ts":"2025-11-17T12:00:00+07:00","agent":"cls","event":"task_start","task_id":"wo-test","source":"gg_orchestrator","summary":"Test"}' >> ledger.jsonl
```

**v3.1:**
```bash
# Use the new writer tool
tools/ap_io_v31/writer.zsh cls task_start "wo-test" "gg_orchestrator" "Test"
```

### Step 2: Update Integration Scripts

**v1.0:**
```bash
# Old integration
log_event() {
  local event="$1"
  local task_id="$2"
  echo "{\"ts\":\"$(date -Iseconds)\",\"agent\":\"cls\",\"event\":\"$event\",\"task_id\":\"$task_id\"}" >> ledger.jsonl
}
```

**v3.1:**
```bash
# New integration
source agents/cls/ap_io_v31_integration.zsh

# Use the integration function
ap_io_v31_log "task_start" "$TASK_ID" "$SOURCE" "Starting task"
```

### Step 3: Update Reader Calls

**v1.0:**
```bash
# Old reader (if custom)
grep "task_start" ledger.jsonl
```

**v3.1:**
```bash
# New reader with filtering
tools/ap_io_v31/reader.zsh ledger.jsonl --event-type task_start
```

---

## Backward Compatibility

AP/IO v3.1 reader supports reading v1.0 format entries:

```bash
# v1.0 entry
echo '{"ts":"2025-11-17T12:00:00+07:00","agent":"cls","event":"task_start","task_id":"wo-test"}' >> ledger.jsonl

# v3.1 reader can read it
tools/ap_io_v31/reader.zsh ledger.jsonl
```

The reader automatically:
- Detects v1.0 format
- Converts to v3.1 structure internally
- Returns normalized entries

---

## Migration Checklist

### Code Updates

- [ ] Update all writer calls to use `tools/ap_io_v31/writer.zsh`
- [ ] Update integration scripts to use `ap_io_v31_integration.zsh`
- [ ] Update reader calls to use `tools/ap_io_v31/reader.zsh`
- [ ] Update event structure from flat to nested `event` object
- [ ] Add `protocol` and `version` fields to all entries

### Data Migration

- [ ] Review existing ledger files
- [ ] Decide if old entries need conversion (optional)
- [ ] Test reader with v1.0 format entries
- [ ] Verify backward compatibility

### Testing

- [ ] Test writer with new format
- [ ] Test reader with both v1.0 and v3.1 formats
- [ ] Test validator with new format
- [ ] Test routing with new format
- [ ] Run full test suite

---

## Example Migration

### Before (v1.0)

```bash
#!/usr/bin/env zsh
# Old script

TASK_ID="wo-001"
TS=$(date -Iseconds)

# Write entry
echo "{\"ts\":\"$TS\",\"agent\":\"cls\",\"event\":\"task_start\",\"task_id\":\"$TASK_ID\",\"source\":\"gg_orchestrator\",\"summary\":\"Starting task\"}" >> g/ledger/cls/$(date +%Y-%m-%d).jsonl

# Do work
perform_task

# Write result
echo "{\"ts\":\"$(date -Iseconds)\",\"agent\":\"cls\",\"event\":\"task_result\",\"task_id\":\"$TASK_ID\",\"source\":\"gg_orchestrator\",\"summary\":\"Task completed\"}" >> g/ledger/cls/$(date +%Y-%m-%d).jsonl
```

### After (v3.1)

```bash
#!/usr/bin/env zsh
# New script

source agents/cls/ap_io_v31_integration.zsh

TASK_ID="wo-001"
START_TIME=$(date +%s%3N)

# Write entry
ap_io_v31_log "task_start" "$TASK_ID" "gg_orchestrator" "Starting task"

# Do work
perform_task

# Write result with duration
END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))
ap_io_v31_log "task_result" "$TASK_ID" "gg_orchestrator" "Task completed" '{"status":"success"}' "" "$DURATION"
```

---

## Benefits of Migration

### 1. Standardized Format

- Consistent structure across all agents
- Easier to parse and process
- Better validation

### 2. Enhanced Features

- Correlation ID tracking
- Parent relationship tracking
- Execution duration tracking
- Better routing support

### 3. Improved Tools

- Atomic writes with retry logic
- Better error handling
- Enhanced validation
- Test isolation support

### 4. Better Integration

- Standardized integration scripts
- Consistent API across agents
- Easier to extend

---

## Troubleshooting

### Issue: "Invalid version"

**Solution:** Ensure all entries include `"version": "3.1"`

### Issue: "Invalid event structure"

**Solution:** Update event structure from flat to nested:
```json
// Old
{"event": "task_start"}

// New
{"event": {"type": "task_start"}}
```

### Issue: Reader not finding old entries

**Solution:** The reader supports both formats. If issues occur, check:
- File permissions
- JSON syntax
- File encoding

---

## See Also

- `AP_IO_V31_PROTOCOL.md` - Protocol specification
- `AP_IO_V31_INTEGRATION_GUIDE.md` - Integration guide
- `AP_IO_V31_ROUTING_GUIDE.md` - Routing guide

