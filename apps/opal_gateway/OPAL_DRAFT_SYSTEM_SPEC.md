# Opal Draft System Specification

**Purpose:** Local draft storage for failed Work Order submissions  
**Version:** 1.0  
**Date:** 2025-12-05  
**Priority:** HIGH

---

## 🎯 **OBJECTIVE**

Never lose work when:
- Network fails
- Gateway returns 5xx error
- Device goes offline
- Request times out

**Solution:** Save failed submissions to local drafts, allow retry.

---

## 📋 **DRAFT STORAGE**

### **Storage Location**

**Option 1: Browser localStorage (Recommended)**
- Key: `02luka_drafts`
- Persists across sessions
- Limited to ~5-10MB per domain

**Option 2: Opal Storage (If Available)**
- Use Opal's built-in storage API
- May have better persistence

### **Storage Format**

```json
{
  "drafts": [
    {
      "draft_id": "draft_20251205_123456",
      "created_at": "2025-12-05T12:34:56Z",
      "failed_at": "2025-12-05T12:35:01Z",
      "error_reason": "network_error|gateway_5xx|offline|timeout",
      "error_message": "Connection timeout after 10s",
      "wo_payload": {
        "wo_id": "WO-20251205-EXP-0001",
        "app_mode": "expense",
        "objective": "...",
        // ... full WO JSON
      },
      "retry_count": 0,
      "last_retry_at": null
    }
  ],
  "version": "1.0"
}
```

---

## 🔧 **IMPLEMENTATION**

### **Step 1: Catch Failures**

**In Opal "Send to Gateway" node:**

```javascript
// Pseudo-code for Opal HTTP node error handling
try {
  response = await fetch('https://gateway.theedges.work/api/wo', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Relay-Key': RELAY_KEY
    },
    body: JSON.stringify(woPayload)
  });
  
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  
  // Success - clear any draft for this WO
  clearDraft(woPayload.wo_id);
  
} catch (error) {
  // Determine error reason
  let errorReason = 'network_error';
  let errorMessage = error.message;
  
  if (error.message.includes('5')) {
    errorReason = 'gateway_5xx';
  } else if (!navigator.onLine) {
    errorReason = 'offline';
  } else if (error.message.includes('timeout')) {
    errorReason = 'timeout';
  }
  
  // Save to drafts
  saveDraft(woPayload, errorReason, errorMessage);
  
  // Show error to user
  showError(`Failed to submit: ${errorMessage}. Saved to drafts.`);
}
```

---

### **Step 2: Save Draft Function**

```javascript
function saveDraft(woPayload, errorReason, errorMessage) {
  const drafts = loadDrafts();
  
  const draft = {
    draft_id: `draft_${Date.now()}`,
    created_at: new Date().toISOString(),
    failed_at: new Date().toISOString(),
    error_reason: errorReason,
    error_message: errorMessage,
    wo_payload: woPayload,
    retry_count: 0,
    last_retry_at: null
  };
  
  drafts.drafts.push(draft);
  saveDrafts(drafts);
  
  // Show notification
  showNotification('Work Order saved to drafts');
}

function loadDrafts() {
  const stored = localStorage.getItem('02luka_drafts');
  if (stored) {
    return JSON.parse(stored);
  }
  return { drafts: [], version: '1.0' };
}

function saveDrafts(drafts) {
  localStorage.setItem('02luka_drafts', JSON.stringify(drafts));
}
```

---

### **Step 3: Drafts Tab UI**

**Add to Opal UI:**

```html
<!-- Drafts Tab -->
<div class="drafts-tab">
  <h2>Drafts</h2>
  <div id="drafts-list">
    <!-- Populated by JavaScript -->
  </div>
</div>
```

**JavaScript to render drafts:**

```javascript
function renderDrafts() {
  const drafts = loadDrafts();
  const listEl = document.getElementById('drafts-list');
  
  if (drafts.drafts.length === 0) {
    listEl.innerHTML = '<p>No drafts</p>';
    return;
  }
  
  listEl.innerHTML = drafts.drafts.map(draft => `
    <div class="draft-item">
      <div class="draft-header">
        <span class="draft-id">${draft.wo_payload.wo_id}</span>
        <span class="draft-time">${formatTime(draft.failed_at)}</span>
      </div>
      <div class="draft-objective">${draft.wo_payload.objective}</div>
      <div class="draft-error">
        <span class="error-badge ${draft.error_reason}">${draft.error_reason}</span>
        <span class="error-message">${draft.error_message}</span>
      </div>
      <div class="draft-actions">
        <button onclick="retryDraft('${draft.draft_id}')">Retry</button>
        <button onclick="deleteDraft('${draft.draft_id}')">Delete</button>
      </div>
    </div>
  `).join('');
}
```

---

### **Step 4: Retry Function**

```javascript
async function retryDraft(draftId) {
  const drafts = loadDrafts();
  const draft = drafts.drafts.find(d => d.draft_id === draftId);
  
  if (!draft) {
    showError('Draft not found');
    return;
  }
  
  // Update retry count
  draft.retry_count += 1;
  draft.last_retry_at = new Date().toISOString();
  saveDrafts(drafts);
  
  // Retry submission
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
      // Success - remove draft
      deleteDraft(draftId);
      showSuccess('Work Order submitted successfully');
    } else {
      // Still failed - update error
      const errorText = await response.text();
      draft.error_message = `HTTP ${response.status}: ${errorText}`;
      draft.error_reason = 'gateway_5xx';
      saveDrafts(drafts);
      renderDrafts();
      showError('Retry failed. Updated error message.');
    }
  } catch (error) {
    // Network error again
    draft.error_message = error.message;
    draft.error_reason = 'network_error';
    saveDrafts(drafts);
    renderDrafts();
    showError('Retry failed: ' + error.message);
  }
}
```

---

### **Step 5: Delete Draft**

```javascript
function deleteDraft(draftId) {
  const drafts = loadDrafts();
  drafts.drafts = drafts.drafts.filter(d => d.draft_id !== draftId);
  saveDrafts(drafts);
  renderDrafts();
}
```

---

## 🎨 **UI DESIGN**

### **Draft Item Card**

```
┌─────────────────────────────────────┐
│ WO-20251205-EXP-0001   12:35 PM    │
│ Process expense entry              │
│ [network_error] Connection timeout │
│ [Retry] [Delete]                    │
└─────────────────────────────────────┘
```

### **Error Badge Colors**

- `network_error` - Yellow
- `gateway_5xx` - Red
- `offline` - Orange
- `timeout` - Purple

---

## ✅ **TESTING**

### **Test Scenarios**

1. **Network Failure:**
   - Disconnect network
   - Submit WO
   - Verify draft saved
   - Reconnect
   - Retry draft
   - Verify success

2. **Gateway 5xx:**
   - Mock 500 response
   - Submit WO
   - Verify draft saved with correct error
   - Fix gateway
   - Retry draft
   - Verify success

3. **Offline:**
   - Go offline
   - Submit WO
   - Verify draft saved
   - Go online
   - Retry draft
   - Verify success

---

## 📊 **CLEANUP**

### **Auto-Cleanup Old Drafts**

```javascript
function cleanupOldDrafts() {
  const drafts = loadDrafts();
  const now = new Date();
  const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days
  
  drafts.drafts = drafts.drafts.filter(draft => {
    const draftAge = now - new Date(draft.failed_at);
    return draftAge < maxAge;
  });
  
  saveDrafts(drafts);
}

// Run cleanup on load
cleanupOldDrafts();
```

---

**End of Draft System Spec**
