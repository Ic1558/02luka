# Copy-Paste Snippets - Ready to Use

**Date:** 2025-12-05  
**Last Updated:** 2025-12-05  
**Purpose:** Ready-to-use code snippets for immediate implementation  
**Status:** ✅ **PRODUCTION READY**

**Version Control:** Each snippet has version header for tracking

---

## 📋 **SNIPPET 1: WO Generator Prompt Patch**

**Version:** v1.0 (2025-12-05)  
**File:** Update `apps/opal_gateway/OPAL_CONFIG.md` - "Generate JSON Work Order" node  
**Backward Compatible:** ✅ Yes - Works with or without ReviewedPlan

**File:** Update `apps/opal_gateway/OPAL_CONFIG.md` - "Generate JSON Work Order" node

**Location:** Add this section **BEFORE** the JSON OUTPUT section

```text
## Planning Integration (NEW)

If `{{ReviewedPlan}}` is available from Senior Reviewer node:

1. Extract lane from: `{{ReviewedPlan}}.lane_selection.primary_lane`
2. Extract execution strategy from: `{{ReviewedPlan}}.execution_strategy`
3. Extract steps from: `{{ReviewedPlan}}.plan.steps`
4. Add `planning_metadata` field to WO JSON

If `{{ReviewedPlan}}` is missing or invalid:
- Use default lane from `{{LaneSelection}}`
- Use default execution mode from app_mode
- Set `planning_metadata` to null

## Planning Metadata Structure:

{
  "planning_metadata": {
    "architect_version": "1.0",
    "review_status": "{{ReviewedPlan.review_status}}",
    "confidence": "{{ReviewedPlan.final_recommendation.confidence}}",
    "lane_selected": "{{ReviewedPlan.lane_selection.primary_lane}}",
    "execution_mode": "{{ReviewedPlan.execution_strategy.mode}}",
    "total_steps": "{{ReviewedPlan.plan.total_steps}}",
    "estimated_time": "{{ReviewedPlan.plan.estimated_total_time}}"
  }
}
```

**Then, in JSON OUTPUT section, add:**

```json
{
  "wo_id": "WO-{{AppMode}}-{{WO_SUFFIX_FROM_SYSTEM_DATA}}",
  "app_mode": "<Expense|Trade|GuiAuto|Progress|DevTask|Estimation>",
  "objective": "<Summary of user intent>",
  "priority": "{{Priority}}",
  "lane": "{{#if ReviewedPlan}}{{ReviewedPlan.lane_selection.primary_lane}}{{else}}{{LaneSelection}}{{/if}}",
  
  "execution": {
    "mode": "{{#if ReviewedPlan}}{{ReviewedPlan.execution_strategy.mode}}{{else}}<inferred from app_mode>{{/if}}",
    "requires_hybrid": {{#if ReviewedPlan}}{{ReviewedPlan.execution_strategy.requires_hybrid}}{{else}}false{{/if}},
    "target_app": "{{#if ReviewedPlan}}{{ReviewedPlan.execution_strategy.target_app}}{{else}}null{{/if}}",
    "target_system": "{{#if ReviewedPlan}}{{ReviewedPlan.execution_strategy.target_system}}{{else}}null{{/if}}",
    "steps": {{#if ReviewedPlan}}{{ReviewedPlan.plan.steps}}{{else}}[]{{/if}}
  },
  
  "planning_metadata": {{#if ReviewedPlan}}{
    "architect_version": "1.0",
    "review_status": "{{ReviewedPlan.review_status}}",
    "confidence": "{{ReviewedPlan.final_recommendation.confidence}}",
    "lane_selected": "{{ReviewedPlan.lane_selection.primary_lane}}",
    "execution_mode": "{{ReviewedPlan.execution_strategy.mode}}",
    "total_steps": {{ReviewedPlan.plan.total_steps}},
    "estimated_time": "{{ReviewedPlan.plan.estimated_total_time}}"
  }{{else}}null{{/if}},
  
  // ... rest of existing fields
}
```

**Note:** Adjust template syntax based on Opal's template engine (Handlebars/Mustache/etc.)

**Backward Compatibility:**
- If `{{ReviewedPlan}}` is missing/null → Use default behavior (existing logic)
- If `{{ReviewedPlan}}` is invalid JSON → Set `planning_metadata` to null, continue with defaults
- Never fail WO generation due to planning layer issues

---

## 📋 **SNIPPET 2: /api/wo_status Endpoint Spec**

**Version:** v1.0 (2025-12-05)  
**File:** `apps/opal_gateway/gateway.py`  
**Status Enum:** `QUEUED | RUNNING | DONE | ERROR | STALE` (strict, no variants)  
**Source of Truth:** `followup/state/*.json` (primary), JSONL cache (optional)

**Add this endpoint:**

```python
@app.route("/api/wo_status", methods=["GET"])
def api_wo_status():
    """
    List all Work Orders with optional status filtering.
    
    Query params:
    - limit: Number of items (default: 50, max: 200)
    - status: Filter by status (all|queued|running|done|error|stale)
    - offset: Pagination offset (default: 0)
    
    Returns paginated list of WOs with status, timestamps, and paths.
    """
    if not require_relay_key():
        logger.warning(f"❌ Unauthorized wo_status request from {request.remote_addr}")
        return error_response("unauthorized", "Invalid relay key", 401)
    
    # Parse query parameters
    limit = min(int(request.args.get("limit", 50)), 200)
    offset = int(request.args.get("offset", 0))
    status_filter = request.args.get("status", "all")
    
    items = []
    
    # 1. Read state files (source of truth)
    if STATE_DIR.exists():
        for state_file in STATE_DIR.glob("*.json"):
            try:
                state_data = json.loads(state_file.read_text())
                wo_id = state_data.get("id") or state_file.stem
                
                # Determine status
                wo_status = determine_wo_status(state_data)
                
                # Skip if filtered
                if status_filter != "all" and wo_status != status_filter:
                    continue
                
                items.append({
                    "wo_id": wo_id,
                    "status": wo_status,
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
            if status_filter != "all" and status_filter != "queued":
                continue
            
            try:
                wo_data = json.loads(inbox_file.read_text())
                items.append({
                    "wo_id": wo_id,
                    "status": "queued",
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
    
    # 3. Sort by last_update desc
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

def determine_wo_status(state_data):
    """
    Determine WO status from state file data.
    
    Returns strict enum: QUEUED | RUNNING | DONE | ERROR | STALE
    Maps from state file status values to standardized enum.
    """
    status = state_data.get("status", "").lower()
    last_error = state_data.get("last_error")
    updated_at = state_data.get("updated_at")
    
    # Map to strict enum (no variants)
    if status in ["done", "completed"]:
        return "DONE"
    elif status in ["failed"] or last_error:
        return "ERROR"
    elif status in ["running", "pending"]:
        # Check if stale (>24h)
        if is_wo_stale(state_data):
            return "STALE"
        return "RUNNING"
    else:
        # Default to RUNNING if unknown (assume in progress)
        return "RUNNING"

def is_wo_stale(state_data):
    """Check if WO is stale (running > 24h)."""
    updated_at_str = state_data.get("updated_at")
    if not updated_at_str:
        return False
    
    try:
        updated_at = datetime.fromisoformat(updated_at_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        age_hours = (now - updated_at).total_seconds() / 3600
        return age_hours > 24 and state_data.get("status", "").lower() in ["running", "pending"]
    except:
        return False
```

---

## 📋 **SNIPPET 3: Draft Storage JSON Schema**

**Version:** v1.0 (2025-12-05)  
**File:** Opal JavaScript / Local Storage  
**Storage Limit:** Max 50 drafts (auto-delete oldest)  
**TTL:** Recommended cleanup after 7 days

**Schema:**

```json
{
  "drafts": [
    {
      "draft_id": "local-20251205-083500-01",
      "wo_payload": {
        "wo_id": "WO-20251205-EXP-0001",
        "app_mode": "expense",
        "objective": "บันทึกค่าใช้จ่าย...",
        "priority": "high",
        "lane": "dev_oss",
        // ... full WO JSON
      },
      "created_at": "2025-12-05T08:35:00Z",
      "last_attempt_at": "2025-12-05T08:35:01Z",
      "last_error": "Network error: ECONNREFUSED",
      "error_reason": "network_error",
      "status": "pending",
      "retry_count": 0
    }
  ],
  "version": "1.0",
  "last_updated": "2025-12-05T08:35:01Z"
}
```

**JavaScript Functions:**

```javascript
// Save draft
function saveDraft(woPayload, errorReason, errorMessage) {
  const drafts = loadDrafts();
  const draftId = `local-${new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5)}-${String(drafts.drafts.length + 1).padStart(2, '0')}`;
  
  const draft = {
    draft_id: draftId,
    wo_payload: woPayload,
    created_at: new Date().toISOString(),
    last_attempt_at: new Date().toISOString(),
    last_error: errorMessage,
    error_reason: errorReason,
    status: "pending",
    retry_count: 0
  };
  
  drafts.drafts.push(draft);
  drafts.last_updated = new Date().toISOString();
  saveDrafts(drafts);
  
  return draftId;
}

// Load drafts
function loadDrafts() {
  const stored = localStorage.getItem('02luka_drafts');
  if (stored) {
    try {
      return JSON.parse(stored);
    } catch (e) {
      console.error('Error parsing drafts:', e);
    }
  }
  return { drafts: [], version: "1.0", last_updated: new Date().toISOString() };
}

// Save drafts
function saveDrafts(drafts) {
  // Limit to 50 drafts max (auto-delete oldest)
  const MAX_DRAFTS = 50;
  if (drafts.drafts.length > MAX_DRAFTS) {
    // Sort by created_at, keep newest
    drafts.drafts.sort((a, b) => 
      new Date(b.created_at) - new Date(a.created_at)
    );
    drafts.drafts = drafts.drafts.slice(0, MAX_DRAFTS);
  }
  
  // Cleanup drafts older than 7 days
  const now = new Date();
  const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days
  drafts.drafts = drafts.drafts.filter(draft => {
    const draftAge = now - new Date(draft.created_at);
    return draftAge < maxAge;
  });
  
  localStorage.setItem('02luka_drafts', JSON.stringify(drafts));
}

// Retry draft
async function retryDraft(draftId) {
  const drafts = loadDrafts();
  const draft = drafts.drafts.find(d => d.draft_id === draftId);
  
  if (!draft) {
    throw new Error('Draft not found');
  }
  
  // Update retry info
  draft.retry_count += 1;
  draft.last_attempt_at = new Date().toISOString();
  draft.status = "retrying";
  saveDrafts(drafts);
  
  try {
    const response = await fetch('https://gateway.theedges.work/api/wo', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Relay-Key': RELAY_KEY
      },
      body: JSON.stringify(draft.wo_payload)
    });
    
    if (response.ok) {
      // Success - mark as sent
      draft.status = "sent";
      saveDrafts(drafts);
      return { success: true };
    } else {
      // Still failed
      const errorText = await response.text();
      draft.last_error = `HTTP ${response.status}: ${errorText}`;
      draft.error_reason = 'gateway_5xx';
      draft.status = "pending";
      saveDrafts(drafts);
      return { success: false, error: draft.last_error };
    }
  } catch (error) {
    // Network error
    draft.last_error = error.message;
    draft.error_reason = 'network_error';
    draft.status = "pending";
    saveDrafts(drafts);
    return { success: false, error: error.message };
  }
}

// Delete draft
function deleteDraft(draftId) {
  const drafts = loadDrafts();
  drafts.drafts = drafts.drafts.filter(d => d.draft_id !== draftId);
  saveDrafts(drafts);
}
```

---

## 📋 **SNIPPET 4: Status Tracking in Gateway**

**Version:** v1.0 (2025-12-05)  
**File:** `apps/opal_gateway/gateway.py`  
**Note:** Optional cache - Source of truth remains state files

**Add to `/api/wo` endpoint (after successful write):**

```python
# After atomic write to BRIDGE_INBOX
# Write status to JSONL cache (optional, for performance)

STATUS_CACHE_FILE = LUKA_HOME / "g" / "state" / "wo_status_index.jsonl"
STATUS_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)

status_entry = {
    "wo_id": wo_id,
    "status": "queued",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "source": "opal",
    "lane": app_mode,
    "app_mode": app_mode
}

# Append to JSONL
with open(STATUS_CACHE_FILE, "a") as f:
    f.write(json.dumps(status_entry) + "\n")

logger.info(f"📝 [STATUS] {wo_id} → QUEUED (cached)")
```

**Note:** This is optional cache. Primary source of truth remains state files.

---

## 📋 **SNIPPET 5: Expense Mode Form Structure**

**Version:** v1.0 (2025-12-05)  
**File:** Opal Flow - Expense Mode Form

**Form Fields (HTML/Opal UI):**

```html
<form id="expense-form">
  <label>Date:</label>
  <input type="date" id="expense-date" value="{{today}}" required>
  
  <label>Description:</label>
  <input type="text" id="expense-description" required>
  
  <label>Category:</label>
  <select id="expense-category" required>
    <option value="Food">Food</option>
    <option value="Transport">Transport</option>
    <option value="Office">Office</option>
    <option value="Other">Other</option>
  </select>
  
  <label>Amount:</label>
  <input type="number" id="expense-amount" step="0.01" min="0" required>
  
  <label>VAT Rate (%):</label>
  <input type="number" id="expense-vat" value="7" min="0" max="100">
  
  <label>Payment Method:</label>
  <select id="expense-payment" required>
    <option value="Cash">Cash</option>
    <option value="PromptPay">PromptPay</option>
    <option value="Credit Card">Credit Card</option>
    <option value="Bybit">Bybit</option>
  </select>
  
  <label>Project (optional):</label>
  <input type="text" id="expense-project">
  
  <label>Note (optional):</label>
  <textarea id="expense-note"></textarea>
  
  <label>Receipt (optional):</label>
  <input type="file" id="expense-receipt" accept="image/*,application/pdf">
</form>
```

**JavaScript to build prepared_input_json:**

```javascript
function buildExpenseInput() {
  const form = document.getElementById('expense-form');
  const amount = parseFloat(form.querySelector('#expense-amount').value);
  const vatRate = parseFloat(form.querySelector('#expense-vat').value) || 0;
  const vatAmount = (amount * vatRate) / 100;
  const totalAmount = amount + vatAmount;
  
  return {
    "objective": `บันทึกค่าใช้จ่าย: ${form.querySelector('#expense-description').value}`,
    "app_mode": "expense",
    "priority": "medium",
    "files": [], // Handle file upload separately
    "context": {
      "expense": {
        "date": form.querySelector('#expense-date').value,
        "description": form.querySelector('#expense-description').value,
        "category": form.querySelector('#expense-category').value,
        "amount": amount,
        "vat_rate": vatRate,
        "vat_amount": vatAmount,
        "total_amount": totalAmount,
        "payment_method": form.querySelector('#expense-payment').value,
        "project": form.querySelector('#expense-project').value || null,
        "note": form.querySelector('#expense-note').value || null
      }
    }
  };
}
```

---

## ✅ **USAGE INSTRUCTIONS**

1. **WO Generator Patch:** Copy to Opal "Generate JSON Work Order" node prompt
2. **API Endpoint:** Add to `gateway.py` (replace existing `/api/wo_list` if exists)
3. **Draft Schema:** Use in Opal JavaScript for draft storage
4. **Status Tracking:** Add to `/api/wo` endpoint after file write
5. **Expense Form:** Use in Opal Expense Mode UI

---

**End of Snippets**
