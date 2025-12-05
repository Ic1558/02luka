# Quick Fix: Sort Key Improvement

**Priority:** MEDIUM (Boss flagged)  
**Issue:** String sorting may be incorrect if timestamps are malformed  
**Fix Time:** 10 minutes

---

## 🔧 **FIX**

**File:** `apps/opal_gateway/gateway.py`  
**Location:** Line 423 (in `api_wo_status_list()` function)

**Current:**
```python
# 3. Sort by last_update desc (most recent first)
items.sort(key=lambda x: x["last_update"] or x["created_at"] or "", reverse=True)
```

**Option 1: Simple Improvement (Recommended for v1.0)**

```python
# 3. Sort by last_update desc (most recent first)
# Use ISO8601 string comparison (works if all timestamps are valid ISO8601)
items.sort(key=lambda x: (
    x["last_update"] or x["created_at"] or "1970-01-01T00:00:00Z"
), reverse=True)
```

**Option 2: Robust Parsing (Better, but more complex)**

Add helper function before `api_wo_status_list()`:

```python
def safe_timestamp_sort_key(item):
    """
    Extract sortable timestamp, handling None/empty/invalid values.
    
    Returns datetime object for proper sorting, or datetime.min for invalid.
    """
    timestamp_str = item.get("last_update") or item.get("created_at") or ""
    if not timestamp_str:
        return datetime.min.replace(tzinfo=timezone.utc)
    
    try:
        # Parse ISO8601 with timezone handling
        if timestamp_str.endswith("Z"):
            timestamp_str = timestamp_str.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(timestamp_str)
        # Ensure timezone-aware
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except (ValueError, AttributeError) as e:
        # Invalid timestamp - put at end
        wo_id = item.get("wo_id", "unknown")
        logger.warning(f"⚠️ [WO_STATUS] Invalid timestamp in WO {wo_id}: {timestamp_str} ({e})")
        return datetime.min.replace(tzinfo=timezone.utc)
```

Then in `api_wo_status_list()`:

```python
# 3. Sort by last_update desc (most recent first)
items.sort(key=safe_timestamp_sort_key, reverse=True)
```

---

## 📊 **RECOMMENDATION**

**For v1.0:** Use Option 1 (simple improvement)  
**For v1.1+:** Use Option 2 (robust parsing) if dashboard shows sorting issues

---

## ✅ **TEST**

```bash
# Test with valid timestamps
curl -H "X-Relay-Key: $RELAY_KEY" \
     "http://localhost:5001/api/wo_status?limit=10" | \
     jq '.items | sort_by(.last_update) | reverse | .[0:3] | .[] | {wo_id, last_update}'

# Verify items are sorted correctly (newest first)
```

---

## ⚠️ **BOSS NOTE**

**If dashboard shows items in wrong order:**
1. Check if timestamps are valid ISO8601 format
2. Check if there are many None/empty values
3. Apply Option 2 fix (robust parsing)

---

**End of Quick Fix**
