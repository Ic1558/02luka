# Phase 1.1: Bidirectional Bridge - Demo & Implementation

## What We Built

### 1. Result Polling Script ✅
**Location:** `~/tools/cls_poll_results.zsh`

**Usage:**
```bash
# CLS calls this after dropping a WO
~/tools/cls_poll_results.zsh WO-20251030-XXXXX
```

**How It Works:**
1. Polls Redis key `wo:result:WO-ID` every second
2. Timeout after 60 seconds
3. Returns JSON result when available
4. Exit 0 if success, exit 1 if timeout

### 2. Enhanced Bridge (Future)
Add `--wait` flag to automatically poll after drop:
```bash
~/tools/bridge_cls_clc.zsh \
  --title "Config Update" \
  --priority P2 \
  --body /path/to/payload.yaml \
  --wait  # ← NEW: Wait for result
```

## Full Workflow Example

### Current (One-Way)
```
CLS in Cursor
   ↓
   creates WO payload
   ↓
   calls bridge_cls_clc.zsh
   ↓
   WO dropped to inbox
   ↓
   (CLS has no idea what happened)
```

### Enhanced (Bidirectional)
```
CLS in Cursor
   ↓
   creates WO payload
   ↓
   calls bridge_cls_clc.zsh --wait
   ↓
   WO dropped to inbox
   ↓
   ┌─────────────────────┐
   │ CLC picks up WO     │
   │ Processes it        │
   │ Publishes result    │
   └─────────────────────┘
   ↓
   bridge polls Redis
   ↓
   receives result
   ↓
   CLS knows outcome!
   ↓
   CLS can act on result (retry, log, notify, etc.)
```

## Redis Result Schema

```json
{
  "wo_id": "WO-20251030-XXXXX",
  "status": "success" | "failure" | "in_progress",
  "duration_sec": 5,
  "completed_at": "2025-10-30T05:18:00Z",
  "message": "Configuration updated successfully",
  "evidence": {
    "sha256": "abc123...",
    "files_changed": ["config/app.yaml"],
    "git_commit": "def456..."
  },
  "error": null  // or error message if failed
}
```

## CLC Implementation (What CLC Needs to Do)

### After Processing WO
```zsh
# In CLC's WO processor
WO_ID="WO-20251030-XXXXX"
RESULT_JSON=$(cat <<JSON
{
  "wo_id": "$WO_ID",
  "status": "success",
  "duration_sec": $DURATION,
  "completed_at": "$(date -u +%FT%TZ)",
  "message": "Operation completed",
  "evidence": {
    "sha256": "$SHA256",
    "files_changed": ["$FILES"]
  }
}
JSON
)

# Publish to Redis
redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" \
  SET "wo:result:$WO_ID" "$RESULT_JSON" EX 3600  # expire after 1h

# Also publish to ACK channel for real-time notification
redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" \
  PUBLISH "cls:wo:completed" "$RESULT_JSON"
```

## Testing Without Full CLC Integration

### Simulate CLC Response
```bash
# 1. Create a WO
WO_ID=$(~/tools/bridge_cls_clc.zsh \
  --title "Test WO" \
  --priority P3 \
  --body /tmp/wo_test.yaml | \
  grep "Work Order:" | awk '{print $3}')

echo "Created: $WO_ID"

# 2. Simulate CLC publishing result (in another terminal or script)
sleep 5  # pretend CLC is working

redis-cli SET "wo:result:$WO_ID" \
'{
  "wo_id":"'$WO_ID'",
  "status":"success",
  "duration_sec":5,
  "message":"Test completed"
}'

# 3. Poll for result
~/tools/cls_poll_results.zsh "$WO_ID"
```

## Integration with Bridge Script

### Add --wait Flag
Edit `~/tools/bridge_cls_clc.zsh`:

```zsh
# After line 85 (arg parsing)
WAIT_FOR_RESULT=0
while (( $# )); do
  case "$1" in
    --title) shift; TITLE="${1:-}";;
    --priority) shift; PRI="${1:-}";;
    --tags) shift; TAGS="${1:-}";;
    --body) shift; BODY="${1:-}";;
    --id) shift; WO_ID="${1:-}";;
    --wait) WAIT_FOR_RESULT=1;;  # ← NEW
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
  shift || true
done

# After line 224 (after final report)
if (( WAIT_FOR_RESULT )); then
  echo ""
  echo "⏳ Waiting for result from CLC..."
  if ~/tools/cls_poll_results.zsh "$WO_ID"; then
    echo "✅ WO completed successfully"
    exit 0
  else
    echo "⏱️ No result received (timeout)"
    exit 2
  fi
fi
```

## Benefits

### For CLS
- **Knows outcomes:** Can see if WO succeeded/failed
- **Can retry:** Automatically retry failed operations
- **Can learn:** Record success/failure patterns
- **Better UX:** User sees completion status

### For System
- **Observability:** Complete audit trail with results
- **Reliability:** Failed ops can be retried automatically
- **Intelligence:** System learns from outcomes

## Next Steps

1. **This Week:**
   - Add `--wait` flag to bridge
   - Update CLC to publish results
   - Test full bidirectional flow

2. **Next Week:**
   - Add WO status tracking (pending → in_progress → completed)
   - Implement auto-retry for transient failures
   - Add result persistence to context DB

3. **Future:**
   - Real-time notifications (Redis PUB/SUB)
   - WebSocket dashboard for live status
   - ML-based outcome prediction

## Files Created

- ✅ `~/tools/cls_poll_results.zsh` - Result polling
- ✅ `~/02luka/CLS/CLS_ENHANCEMENT_ROADMAP.md` - Full roadmap
- ✅ `~/02luka/CLS/PHASE1_DEMO.md` - This file

## Quick Test

```bash
# Create test WO
~/tools/bridge_cls_clc.zsh \
  --title "Phase 1 Demo" \
  --priority P3 \
  --tags "demo" \
  --body /tmp/wo_test.yaml

# Note the WO-ID from output, then test polling
# (will timeout since CLC isn't publishing results yet)
~/tools/cls_poll_results.zsh WO-20251030-XXXXX
```

**Status:** Phase 1.1 proof-of-concept complete. Ready for CLC integration.
