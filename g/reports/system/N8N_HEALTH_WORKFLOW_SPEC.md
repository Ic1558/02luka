# n8n Health Workflow Specification

**Purpose:** Elevate n8n from L2 (Launchable) to L3 (Producing Value)  
**Target:** Prove n8n can execute workflows and integrate with 02luka system  
**Complexity:** Minimal - Single webhook → log write workflow

---

## Objective

Create a simple but verifiable workflow that demonstrates n8n is:
1. ✅ Receiving HTTP requests
2. ✅ Processing workflow logic
3. ✅ Writing to 02luka system (log file)
4. ✅ Responding with success

This provides **evidence** that n8n is not just running, but **actively processing work**.

---

## Workflow Design

### Workflow Name
`sys-n8n-health-probe`

### Workflow Structure

```
HTTP Webhook (Trigger)
  ↓
Set Node (Prepare response)
  ↓
Write Binary File (Log to 02luka)
  ↓
Respond to Webhook (Success response)
```

---

## Step-by-Step Implementation

### Step 1: Create Workflow

1. Open n8n UI: `http://localhost:5678`
2. Click **"Add workflow"** or **"New workflow"**
3. Name: `sys-n8n-health-probe`
4. Description: `Health check workflow - proves n8n is processing requests`

### Step 2: Add HTTP Webhook Trigger

1. Click **"+"** to add node
2. Search for **"Webhook"**
3. Select **"Webhook"** node
4. Configure:
   - **HTTP Method:** `POST`
   - **Path:** `sys/n8n-health-probe`
   - **Response Mode:** `Last Node`
   - **Authentication:** None (internal only)

**Expected Result:**
- Webhook URL: `http://localhost:5678/webhook/sys/n8n-health-probe`
- Node shows: "Waiting for you to test the workflow"

### Step 3: Add Set Node (Prepare Log Data)

1. Add **"Set"** node after Webhook
2. Configure to set:
   - **Field:** `timestamp`
   - **Value:** `{{ $now.toISO() }}`
   - **Field:** `source`
   - **Value:** `n8n-health-probe`
   - **Field:** `status`
   - **Value:** `healthy`

**Purpose:** Structure the log entry with metadata

### Step 4: Add Write Binary File Node

1. Add **"Write Binary File"** node after Set
2. Configure:
   - **File Name:** `/Users/icmini/02luka/logs/n8n_health_probe.log`
   - **File Content:** 
     ```
     {{ $json.timestamp }} | {{ $json.source }} | {{ $json.status }}
     ```
   - **Options:**
     - **Append:** `true` (append to file, don't overwrite)

**Purpose:** Write evidence to 02luka logs directory

### Step 5: Add Respond to Webhook Node

1. Add **"Respond to Webhook"** node after Write Binary File
2. Configure:
   - **Response Code:** `200`
   - **Response Body:**
     ```json
     {
       "status": "ok",
       "timestamp": "{{ $json.timestamp }}",
       "message": "n8n health probe successful"
     }
     ```

**Purpose:** Return success response to caller

### Step 6: Connect Nodes

Connect in sequence:
- Webhook → Set → Write Binary File → Respond to Webhook

### Step 7: Activate Workflow

1. Click **"Save"** (top right)
2. Toggle **"Active"** switch to ON
3. Verify workflow shows as **"Active"**

---

## Verification Steps

### Test 1: Manual HTTP Request

```bash
curl -X POST http://localhost:5678/webhook/sys/n8n-health-probe \
  -H "Content-Type: application/json" \
  -d '{"test": "health-check"}'
```

**Expected Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-11-17T12:45:00.000Z",
  "message": "n8n health probe successful"
}
```

### Test 2: Verify Log File Created

```bash
cat ~/02luka/logs/n8n_health_probe.log
```

**Expected Output:**
```
2025-11-17T12:45:00.000Z | n8n-health-probe | healthy
```

### Test 3: Multiple Probes

```bash
# Send 3 requests
for i in {1..3}; do
  curl -X POST http://localhost:5678/webhook/sys/n8n-health-probe
  sleep 1
done

# Verify 3 entries in log
wc -l ~/02luka/logs/n8n_health_probe.log
# Should show: 3 (or more if run multiple times)
```

---

## Integration with 02luka System

### Option A: Simple Log (Current Spec)

- ✅ Minimal complexity
- ✅ Easy to verify
- ✅ No external dependencies
- ✅ Proves n8n can write to 02luka filesystem

### Option B: Redis Integration (Future Enhancement)

If Redis integration is needed later:
1. Add **"Redis"** node after Set
2. Publish to channel: `n8n:health-probe`
3. Message: `{{ $json.timestamp }} | healthy`

### Option C: MLS Integration (Future Enhancement)

If MLS logging is needed:
1. Add **"HTTP Request"** node
2. POST to: `http://localhost:4000/api/mls` (if MLS API exists)
3. Body: MLS lesson entry format

---

## Success Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Workflow created | ⏳ | n8n UI shows workflow |
| Workflow active | ⏳ | Toggle shows "Active" |
| Webhook responds | ⏳ | HTTP 200 on POST |
| Log file created | ⏳ | File exists at `~/02luka/logs/n8n_health_probe.log` |
| Log entries written | ⏳ | File contains timestamp entries |
| Multiple requests work | ⏳ | Multiple log entries appear |

**All criteria PASS = L3 (Producing Value) achieved**

---

## Agent Implementation Notes

### For CLC/Liam (AI Agent)

**Prerequisites:**
- n8n UI accessible at `http://localhost:5678`
- n8n service running (verified by previous reactivation)

**Implementation Steps:**
1. Navigate to n8n UI (browser automation or manual)
2. Create workflow following Step 1-7 above
3. Test using verification steps
4. Document results in MLS or session report

**Verification Command:**
```bash
# Quick health check
curl -X POST http://localhost:5678/webhook/sys/n8n-health-probe && \
  tail -1 ~/02luka/logs/n8n_health_probe.log
```

**Expected Output:**
- HTTP 200 response
- New log entry with timestamp

---

## Maintenance

### Regular Health Checks

Add to system monitoring (optional):
```bash
# Cron or LaunchAgent script
*/5 * * * * curl -X POST http://localhost:5678/webhook/sys/n8n-health-probe > /dev/null 2>&1
```

### Log Rotation

Log file will grow over time. Consider:
- Log rotation (max 1000 lines)
- Or: Use date-based log files
- Or: Clear log weekly

---

## Troubleshooting

### Workflow Not Triggering

1. Check workflow is **Active** (toggle ON)
2. Verify webhook path: `sys/n8n-health-probe` (no leading slash)
3. Check n8n logs: `~/02luka/logs/n8n.out.log`

### Log File Not Created

1. Verify path: `/Users/icmini/02luka/logs/n8n_health_probe.log`
2. Check directory exists: `mkdir -p ~/02luka/logs`
3. Check permissions: `ls -la ~/02luka/logs/`

### HTTP 404 on Webhook

1. Verify workflow is saved and active
2. Check webhook path matches exactly: `sys/n8n-health-probe`
3. Restart n8n service if needed

---

## Next Steps After L3 Verification

Once this workflow is verified:

1. **Register in Worker Registry:**
   - Add n8n as verified L3 worker
   - Document health check endpoint
   - Mark as "producing value"

2. **Expand Workflows:**
   - Add Redis integration workflows
   - Add agent delegation workflows
   - Add MLS logging workflows

3. **Monitoring:**
   - Add to system health dashboard
   - Alert if health probe fails
   - Track workflow execution metrics

---

**Spec Created:** 2025-11-17  
**Status:** Ready for Implementation  
**Complexity:** Low  
**Estimated Time:** 10-15 minutes
