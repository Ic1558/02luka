# Quick Fix: Query Parameter Validation

**Priority:** HIGH (Boss flagged)  
**Issue:** Invalid query params cause 500 errors  
**Fix Time:** 5 minutes

---

## 🔧 **FIX**

**File:** `apps/opal_gateway/gateway.py`  
**Location:** Lines 350-353 (in `api_wo_status_list()` function)

**Replace:**
```python
# Parse query parameters
limit = min(int(request.args.get("limit", 50)), 200)
offset = int(request.args.get("offset", 0))
status_filter = request.args.get("status", "all").upper()
```

**With:**
```python
# Parse query parameters with validation
try:
    limit = min(max(int(request.args.get("limit", 50)), 1), 200)
except (ValueError, TypeError):
    limit = 50
    logger.warning(f"⚠️ [WO_STATUS] Invalid limit parameter, using default: 50")

try:
    offset = max(int(request.args.get("offset", 0)), 0)
except (ValueError, TypeError):
    offset = 0
    logger.warning(f"⚠️ [WO_STATUS] Invalid offset parameter, using default: 0")

status_filter = request.args.get("status", "all").upper()
valid_statuses = ["ALL", "QUEUED", "RUNNING", "DONE", "ERROR", "STALE"]
if status_filter not in valid_statuses:
    logger.warning(f"⚠️ [WO_STATUS] Invalid status filter '{status_filter}', using 'ALL'")
    status_filter = "ALL"
```

---

## ✅ **TEST**

```bash
# Test invalid limit
curl -H "X-Relay-Key: $RELAY_KEY" \
     "http://localhost:5001/api/wo_status?limit=abc"
# Should return 200 (not 500), uses default limit=50

# Test invalid offset
curl -H "X-Relay-Key: $RELAY_KEY" \
     "http://localhost:5001/api/wo_status?offset=-5"
# Should return 200, uses offset=0

# Test invalid status
curl -H "X-Relay-Key: $RELAY_KEY" \
     "http://localhost:5001/api/wo_status?status=invalid"
# Should return 200, uses status=ALL
```

---

**End of Quick Fix**
