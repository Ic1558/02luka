# Architect/Senior Fallback Telemetry

**Version:** v1.0 (2025-12-05)  
**Purpose:** Log fallback events for monitoring and debugging  
**Status:** ✅ **REQUIRED** - Critical for production monitoring

---

## 🎯 **OBJECTIVE**

When Architect or Senior Reviewer nodes hit fallback (no-op plan or ERROR object), log to telemetry so:
- Dashboard can identify planning layer failures
- We can track error rates
- We can debug issues without breaking flow

---

## 📋 **TELEMETRY LOGGING**

### **Architect Node Fallback**

**When:** Input JSON parse fails or invalid

**Log Entry:**
```json
{
  "timestamp": "2025-12-05T12:34:56Z",
  "event": "architect_plan_error",
  "wo_id": "WO-20251205-EXP-0001",
  "reason": "invalid_json_or_parse_failure",
  "error_type": "parse_error",
  "input_preview": "{{first_100_chars_of_input}}",
  "fallback_used": "no_op_plan"
}
```

**Location:** `g/telemetry/architect_errors.jsonl`

**In Architect Prompt (add to fallback section):**

```text
If prepared_input_json is invalid or cannot be parsed:

1. Generate no-op plan (as specified)
2. Add error metadata to plan output:

{
  "plan": { /* no-op plan */ },
  "error_metadata": {
    "fallback_used": true,
    "error_type": "parse_error",
    "error_reason": "invalid_json_or_parse_failure",
    "telemetry_logged": true
  }
}
```

---

### **Senior Reviewer Node Fallback**

**When:** Architect plan JSON parse fails

**Log Entry:**
```json
{
  "timestamp": "2025-12-05T12:34:56Z",
  "event": "senior_review_error",
  "wo_id": "WO-20251205-EXP-0001",
  "reason": "architect_plan_parse_failure",
  "error_type": "parse_error",
  "architect_output_preview": "{{first_100_chars}}",
  "fallback_used": "error_object"
}
```

**Location:** `g/telemetry/senior_review_errors.jsonl`

**In Senior Reviewer Prompt (add to fallback section):**

```text
If ArchitectPlan cannot be parsed as JSON:

1. Return ERROR object (as specified)
2. Include error metadata:

{
  "review_status": "rejected",
  "error_metadata": {
    "fallback_used": true,
    "error_type": "parse_error",
    "error_reason": "architect_plan_parse_failure",
    "telemetry_logged": true
  }
}
```

---

## 🔧 **IMPLEMENTATION**

### **Option 1: Log in Gateway (Recommended)**

**When WO Generator sends to Gateway, check for error_metadata:**

```python
# In /api/wo endpoint, after receiving WO JSON
planning_metadata = wo_data.get("planning_metadata", {})
error_metadata = planning_metadata.get("error_metadata")

if error_metadata and error_metadata.get("fallback_used"):
    # Log to telemetry
    telemetry_file = LUKA_HOME / "g" / "telemetry" / "planning_errors.jsonl"
    telemetry_file.parent.mkdir(parents=True, exist_ok=True)
    
    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": error_metadata.get("error_type", "unknown"),
        "wo_id": wo_id,
        "reason": error_metadata.get("error_reason", "unknown"),
        "fallback_used": error_metadata.get("fallback_used", False)
    }
    
    with open(telemetry_file, "a") as f:
        f.write(json.dumps(log_entry) + "\n")
    
    logger.warning(f"⚠️ [PLANNING] {wo_id} used fallback: {error_metadata.get('error_reason')}")
```

### **Option 2: Log in Opal (If Gateway Not Available)**

**In Opal, after Architect/Senior nodes:**

```javascript
function logPlanningError(woId, node, errorType, errorReason) {
  // Store in localStorage for later sync
  const errors = JSON.parse(localStorage.getItem('02luka_planning_errors') || '[]');
  errors.push({
    timestamp: new Date().toISOString(),
    event: `${node}_error`,
    wo_id: woId,
    reason: errorReason,
    error_type: errorType,
    fallback_used: true
  });
  localStorage.setItem('02luka_planning_errors', JSON.stringify(errors));
}
```

---

## 📊 **DASHBOARD INTEGRATION**

**Future: Add to Status Dashboard:**

```html
<!-- Planning Error Indicator -->
<div class="planning-error-badge" v-if="wo.planning_metadata?.error_metadata?.fallback_used">
  ⚠️ Planning Fallback Used
</div>
```

**Filter by planning errors:**
- Show all WOs that used fallback
- Help identify systematic issues

---

## ✅ **VERIFICATION**

**Test Cases:**

1. **Invalid Input to Architect:**
   - Send malformed JSON
   - Verify no-op plan generated
   - Verify telemetry logged

2. **Invalid Architect Output to Senior:**
   - Mock non-JSON response from Architect
   - Verify ERROR object from Senior
   - Verify telemetry logged

3. **Normal Flow:**
   - Send valid input
   - Verify no telemetry logged
   - Verify normal plan generated

---

**End of Telemetry Spec**
