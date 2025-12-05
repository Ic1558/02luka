# Step-by-Step Implementation: /api/wo_status Endpoint

**Version:** v1.0 (2025-12-05)  
**Priority:** HIGH (First implementation step)  
**Estimated Time:** 2-3 hours  
**Status:** ✅ **READY TO IMPLEMENT**

---

## 🎯 **OBJECTIVE**

Create `/api/wo_status` endpoint that returns list of all Work Orders with status filtering.

**Success Criteria:**
- ✅ Endpoint returns `{ "items": [...], "total": N }`
- ✅ Status enum: `QUEUED | RUNNING | DONE | ERROR | STALE` (strict)
- ✅ Source of truth: `followup/state/*.json` (primary)
- ✅ Supports filtering by status
- ✅ Supports pagination (limit/offset)

---

## 📋 **STEP 1: Add Status Enum Helper**

**File:** `apps/opal_gateway/gateway.py`

**Location:** Add after `is_wo_stale()` function (or create if doesn't exist)

**Code:**

```python
# Status Enum (strict - no variants)
WO_STATUS_QUEUED = "QUEUED"
WO_STATUS_RUNNING = "RUNNING"
WO_STATUS_DONE = "DONE"
WO_STATUS_ERROR = "ERROR"
WO_STATUS_STALE = "STALE"

def determine_wo_status(state_data):
    """
    Determine WO status from state file data.
    
    Returns strict enum: QUEUED | RUNNING | DONE | ERROR | STALE
    Maps from state file status values to standardized enum.
    
    Source of Truth: state_data from followup/state/*.json
    """
    status = state_data.get("status", "").lower()
    last_error = state_data.get("last_error")
    updated_at = state_data.get("updated_at")
    
    # Map to strict enum (no variants)
    if status in ["done", "completed"]:
        return WO_STATUS_DONE
    elif status in ["failed"] or last_error:
        return WO_STATUS_ERROR
    elif status in ["running", "pending"]:
        # Check if stale (>24h)
        if is_wo_stale(state_data):
            return WO_STATUS_STALE
        return WO_STATUS_RUNNING
    else:
        # Default to RUNNING if unknown (assume in progress)
        return WO_STATUS_RUNNING

def is_wo_stale(state_data):
    """
    Check if WO is stale (running > 24h).
    
    Returns True if:
    - Status is running/pending
    - updated_at > 24 hours ago
    """
    updated_at_str = state_data.get("updated_at")
    if not updated_at_str:
        return False
    
    try:
        updated_at = datetime.fromisoformat(updated_at_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        age_hours = (now - updated_at).total_seconds() / 3600
        return age_hours > 24 and state_data.get("status", "").lower() in ["running", "pending"]
    except Exception as e:
        logger.error(f"❌ Error parsing updated_at: {e}")
        return False
```

**Test:**
```python
# Quick test in Python shell
test_state = {"status": "running", "updated_at": "2025-12-04T12:00:00Z"}
assert determine_wo_status(test_state) == "STALE"  # If >24h old
```

---

## 📋 **STEP 2: Add /api/wo_status Endpoint**

**File:** `apps/opal_gateway/gateway.py`

**Location:** Add after `/api/wo_status` (single WO) endpoint, or replace if exists

**Code:**

```python
@app.route("/api/wo_status", methods=["GET"])
def api_wo_status_list():
    """
    List all Work Orders with optional status filtering.
    
    Query params:
    - limit: Number of items (default: 50, max: 200)
    - status: Filter by status (all|queued|running|done|error|stale)
    - offset: Pagination offset (default: 0)
    
    Returns: { "items": [...], "total": N, "limit": N, "offset": N }
    
    Source of Truth: followup/state/*.json (primary)
    """
    if not require_relay_key():
        logger.warning(f"❌ Unauthorized wo_status request from {request.remote_addr}")
        return error_response("unauthorized", "Invalid relay key", 401)
    
    # Parse query parameters
    limit = min(int(request.args.get("limit", 50)), 200)
    offset = int(request.args.get("offset", 0))
    status_filter = request.args.get("status", "all").upper()
    
    items = []
    
    # 1. Read state files (SOURCE OF TRUTH)
    if STATE_DIR.exists():
        for state_file in STATE_DIR.glob("*.json"):
            try:
                state_data = json.loads(state_file.read_text())
                wo_id = state_data.get("id") or state_file.stem
                
                # Determine status (strict enum)
                wo_status = determine_wo_status(state_data)
                
                # Skip if filtered
                if status_filter != "ALL" and wo_status != status_filter:
                    continue
                
                items.append({
                    "wo_id": wo_id,
                    "status": wo_status,  # Strict enum
                    "lane": state_data.get("lane", "unknown"),
                    "app_mode": state_data.get("app_mode", "unknown"),
                    "priority": state_data.get("priority", "medium"),
                    "objective": (state_data.get("objective") or 
                                 state_data.get("title") or 
                                 state_data.get("summary") or "")[:80],
                    "created_at": state_data.get("created_at"),
                    "started_at": state_data.get("meta", {}).get("started_at"),
                    "finished_at": state_data.get("meta", {}).get("finished_at"),
                    "last_update": state_data.get("updated_at") or state_data.get("created_at"),
                    "error_message": state_data.get("last_error"),
                    "source": state_data.get("meta", {}).get("source", "unknown")
                })
            except Exception as e:
                logger.error(f"❌ Error reading state file {state_file}: {e}")
                continue
    
    # 2. Read queued files (not yet processed)
    if BRIDGE_INBOX.exists():
        for inbox_file in BRIDGE_INBOX.glob("*.json"):
            wo_id = inbox_file.stem
            # Skip if already in items (has state file)
            if any(item["wo_id"] == wo_id for item in items):
                continue
            
            # Apply filter
            if status_filter != "ALL" and status_filter != WO_STATUS_QUEUED:
                continue
            
            try:
                wo_data = json.loads(inbox_file.read_text())
                items.append({
                    "wo_id": wo_id,
                    "status": WO_STATUS_QUEUED,  # Strict enum
                    "lane": wo_data.get("lane", "unknown"),
                    "app_mode": wo_data.get("app_mode", "unknown"),
                    "priority": wo_data.get("priority", "medium"),
                    "objective": wo_data.get("objective", "")[:80],
                    "created_at": wo_data.get("apio_log", {}).get("timestamp"),
                    "started_at": None,
                    "finished_at": None,
                    "last_update": wo_data.get("apio_log", {}).get("timestamp"),
                    "error_message": None,
                    "source": "opal"
                })
            except Exception as e:
                logger.error(f"❌ Error reading inbox file {inbox_file}: {e}")
                continue
    
    # 3. Sort by last_update desc (most recent first)
    items.sort(key=lambda x: x["last_update"] or x["created_at"] or "", reverse=True)
    
    # 4. Apply pagination
    total = len(items)
    items = items[offset:offset+limit]
    
    return jsonify({
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200
```

**Note:** If existing `/api/wo_status` (single WO) exists, rename this to `/api/wo_status_list` or merge logic.

---

## 📋 **STEP 3: Test Endpoint**

**Test Script:** `apps/opal_gateway/test_wo_status_api.zsh`

**Create file:**

```bash
#!/usr/bin/env zsh
# Test /api/wo_status endpoint

set -euo pipefail

GATEWAY_URL="http://localhost:5001"
RELAY_KEY=$(grep RELAY_KEY ~/02luka/.env.local | cut -d'=' -f2 | tr -d '"')

echo "🧪 Testing /api/wo_status endpoint"
echo "=================================="
echo ""

# Test 1: List all (default)
echo "Test 1: List all WOs (default)"
curl -s -H "X-Relay-Key: $RELAY_KEY" \
     "$GATEWAY_URL/api/wo_status?limit=10" | jq '.items | length'
echo ""

# Test 2: Filter by status
echo "Test 2: Filter by status=ERROR"
curl -s -H "X-Relay-Key: $RELAY_KEY" \
     "$GATEWAY_URL/api/wo_status?status=error" | jq '.items[].status'
echo ""

# Test 3: Pagination
echo "Test 3: Pagination (offset=5, limit=3)"
curl -s -H "X-Relay-Key: $RELAY_KEY" \
     "$GATEWAY_URL/api/wo_status?offset=5&limit=3" | jq '{total, limit, offset, items_count: (.items | length)}'
echo ""

# Test 4: Verify status enum
echo "Test 4: Verify status enum (should only be QUEUED|RUNNING|DONE|ERROR|STALE)"
curl -s -H "X-Relay-Key: $RELAY_KEY" \
     "$GATEWAY_URL/api/wo_status?limit=50" | \
     jq -r '.items[].status' | sort -u
echo ""

echo "✅ Tests complete"
```

**Run:**
```bash
chmod +x apps/opal_gateway/test_wo_status_api.zsh
./apps/opal_gateway/test_wo_status_api.zsh
```

---

## 📋 **STEP 4: Verify Response Format**

**Expected Response:**

```json
{
  "items": [
    {
      "wo_id": "WO-20251205-EXP-0001",
      "status": "DONE",
      "lane": "dev_oss",
      "app_mode": "expense",
      "priority": "high",
      "objective": "บันทึกค่าใช้จ่าย...",
      "created_at": "2025-12-05T06:30:00Z",
      "started_at": "2025-12-05T06:30:05Z",
      "finished_at": "2025-12-05T06:35:00Z",
      "last_update": "2025-12-05T06:35:00Z",
      "error_message": null,
      "source": "opal"
    }
  ],
  "total": 123,
  "limit": 50,
  "offset": 0,
  "timestamp": "2025-12-05T12:00:00Z"
}
```

**Verify:**
- ✅ Status values are strict enum (no lowercase/variants)
- ✅ `items` key (not `wos`)
- ✅ Pagination works
- ✅ Filtering works

---

## ✅ **CHECKLIST**

- [ ] Status enum helper functions added
- [ ] `/api/wo_status` endpoint added
- [ ] Source of truth: state files (primary)
- [ ] Status enum: Strict (QUEUED|RUNNING|DONE|ERROR|STALE)
- [ ] Response format: `{ "items": [...], "total": N }`
- [ ] Filtering by status works
- [ ] Pagination works
- [ ] Test script passes
- [ ] Gateway restarts successfully

---

## 🚀 **NEXT STEPS**

After this endpoint works:
1. Create simple dashboard HTML (Step 2 in Boss's plan)
2. Add auto-refresh
3. Add status filters UI

---

**End of Implementation Guide**
