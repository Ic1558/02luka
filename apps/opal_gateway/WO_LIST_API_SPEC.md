# WO List API Specification

**Purpose:** API endpoint to list all Work Orders with status filtering  
**Version:** 1.0  
**Date:** 2025-12-05  
**Priority:** HIGH

---

## 📋 **ENDPOINT SPECIFICATION**

**Endpoint:** `GET /api/wo_list`

**Authentication:** `X-Relay-Key` header (same as other endpoints)

**Query Parameters:**
- `limit` (optional, default: 50, max: 200) - Number of WOs to return
- `status` (optional, default: "all") - Filter by status: `all|queued|running|done|error|stale`
- `offset` (optional, default: 0) - Pagination offset

**Response Format:**
```json
{
  "ok": true,
  "total": 123,
  "limit": 50,
  "offset": 0,
  "wos": [
    {
      "wo_id": "WO-20251205-EXP-0001",
      "objective": "Process expense entry",
      "status": "done",
      "lane": "dev_oss",
      "app_mode": "expense",
      "priority": "high",
      "created_at": "2025-12-05T06:30:00Z",
      "updated_at": "2025-12-05T06:35:00Z",
      "completed_at": "2025-12-05T06:35:00Z",
      "state_path": "followup/state/WO-20251205-EXP-0001.json",
      "inbox_path": null,
      "error": null,
      "is_stale": false
    }
  ],
  "timestamp": "2025-12-05T12:00:00Z"
}
```

---

## 🔧 **IMPLEMENTATION LOGIC**

### **Status Determination**

**QUEUED:**
- File exists in `bridge/inbox/LIAM/{wo_id}.json`
- No state file in `followup/state/{wo_id}.json`
- Status: `"queued"`

**RUNNING:**
- State file exists
- `status` field = `"running"` or `"pending"`
- `updated_at` < 24 hours ago
- Status: `"running"`

**DONE:**
- State file exists
- `status` field = `"done"` or `"completed"`
- Status: `"done"`

**ERROR:**
- State file exists
- `status` field = `"failed"` OR `last_error` field present
- Status: `"error"`

**STALE:**
- State file exists
- `status` field = `"running"` or `"pending"`
- `updated_at` > 24 hours ago
- Status: `"stale"`

---

### **Data Aggregation**

1. **Read State Files:**
   ```python
   state_dir = LUKA_HOME / "followup" / "state"
   state_files = list(state_dir.glob("*.json"))
   ```

2. **Read Queued Files:**
   ```python
   inbox_dir = LUKA_HOME / "bridge" / "inbox" / "LIAM"
   queued_files = list(inbox_dir.glob("*.json"))
   ```

3. **Merge and Deduplicate:**
   - If WO has both state file and queued file → Use state file (more recent)
   - If WO only has queued file → Status = QUEUED
   - If WO only has state file → Use state file status

4. **Sort:**
   - By `updated_at` descending (most recent first)
   - If no `updated_at`, use `created_at`

5. **Filter:**
   - Apply status filter if provided
   - Apply limit and offset

---

## 📝 **CODE IMPLEMENTATION**

### **Gateway Endpoint**

```python
@app.route("/api/wo_list", methods=["GET"])
def api_wo_list():
    """
    List all Work Orders with optional status filtering.
    
    Returns paginated list of WOs with status, timestamps, and paths.
    """
    if not require_relay_key():
        logger.warning(f"❌ Unauthorized wo_list request from {request.remote_addr}")
        return error_response("unauthorized", "Invalid relay key", 401)
    
    # Parse query parameters
    limit = min(int(request.args.get("limit", 50)), 200)  # Max 200
    offset = int(request.args.get("offset", 0))
    status_filter = request.args.get("status", "all")
    
    # Collect WOs
    wos = []
    
    # 1. Read state files
    state_dir = STATE_DIR
    if state_dir.exists():
        for state_file in state_dir.glob("*.json"):
            try:
                state_data = json.loads(state_file.read_text())
                wo_id = state_data.get("id") or state_file.stem
                
                # Determine status
                wo_status = determine_status_from_state(state_data)
                
                wos.append({
                    "wo_id": wo_id,
                    "objective": state_data.get("objective") or state_data.get("title") or "",
                    "status": wo_status,
                    "lane": state_data.get("lane", "unknown"),
                    "app_mode": state_data.get("app_mode", "unknown"),
                    "priority": state_data.get("priority", "medium"),
                    "created_at": state_data.get("created_at"),
                    "updated_at": state_data.get("updated_at") or state_data.get("updated_at"),
                    "completed_at": state_data.get("completed_at"),
                    "state_path": str(state_file.relative_to(LUKA_HOME)),
                    "inbox_path": None,
                    "error": state_data.get("last_error"),
                    "is_stale": is_stale(state_data)
                })
            except Exception as e:
                logger.error(f"❌ Error reading state file {state_file}: {e}")
                continue
    
    # 2. Read queued files (not yet processed)
    inbox_dir = BRIDGE_INBOX
    if inbox_dir.exists():
        for inbox_file in inbox_dir.glob("*.json"):
            wo_id = inbox_file.stem
            # Skip if already in wos (has state file)
            if any(w["wo_id"] == wo_id for w in wos):
                continue
            
            try:
                wo_data = json.loads(inbox_file.read_text())
                wos.append({
                    "wo_id": wo_id,
                    "objective": wo_data.get("objective", ""),
                    "status": "queued",
                    "lane": wo_data.get("lane", "unknown"),
                    "app_mode": wo_data.get("app_mode", "unknown"),
                    "priority": wo_data.get("priority", "medium"),
                    "created_at": wo_data.get("apio_log", {}).get("timestamp"),
                    "updated_at": wo_data.get("apio_log", {}).get("timestamp"),
                    "completed_at": None,
                    "state_path": None,
                    "inbox_path": str(inbox_file.relative_to(LUKA_HOME)),
                    "error": None,
                    "is_stale": False
                })
            except Exception as e:
                logger.error(f"❌ Error reading inbox file {inbox_file}: {e}")
                continue
    
    # 3. Filter by status
    if status_filter != "all":
        wos = [w for w in wos if w["status"] == status_filter]
    
    # 4. Sort by updated_at desc
    wos.sort(key=lambda x: x["updated_at"] or x["created_at"] or "", reverse=True)
    
    # 5. Apply pagination
    total = len(wos)
    wos = wos[offset:offset+limit]
    
    return jsonify({
        "ok": True,
        "total": total,
        "limit": limit,
        "offset": offset,
        "wos": wos,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200

def determine_status_from_state(state_data):
    """Determine WO status from state file data."""
    status = state_data.get("status", "").lower()
    last_error = state_data.get("last_error")
    updated_at = state_data.get("updated_at")
    
    if status in ["done", "completed"]:
        return "done"
    elif status in ["failed"] or last_error:
        return "error"
    elif status in ["running", "pending"]:
        # Check if stale
        if is_stale(state_data):
            return "stale"
        return "running"
    else:
        return "unknown"

def is_stale(state_data):
    """Check if WO is stale (running > 24h)."""
    updated_at_str = state_data.get("updated_at")
    if not updated_at_str:
        return False
    
    try:
        updated_at = datetime.fromisoformat(updated_at_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        age = (now - updated_at).total_seconds() / 3600  # hours
        return age > 24 and state_data.get("status", "").lower() in ["running", "pending"]
    except:
        return False
```

---

## ✅ **TESTING**

### **Test Cases**

1. **List All WOs:**
   ```bash
   curl -H "X-Relay-Key: $RELAY_KEY" \
        "http://localhost:5001/api/wo_list?limit=10"
   ```

2. **Filter by Status:**
   ```bash
   curl -H "X-Relay-Key: $RELAY_KEY" \
        "http://localhost:5001/api/wo_list?status=error"
   ```

3. **Pagination:**
   ```bash
   curl -H "X-Relay-Key: $RELAY_KEY" \
        "http://localhost:5001/api/wo_list?limit=10&offset=10"
   ```

---

**End of API Spec**
