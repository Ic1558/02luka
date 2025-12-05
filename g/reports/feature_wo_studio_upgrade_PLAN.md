# Feature Development Plan: 02luka Work Order Studio Upgrade

**Feature:** Enterprise UX Upgrade for Work Order System  
**Status:** 📋 **SPEC - Ready for Implementation**  
**Created:** 2025-12-05  
**Author:** CLS  
**Priority:** **HIGH** (B → A → C Priority Order)

---

## 🎯 **EXECUTIVE SUMMARY**

### **Problem Statement**

Current 02luka Work Order system lacks:
- ❌ **Visibility** - No real-time view of all WOs in system
- ❌ **Resilience** - Work lost when network fails or gateway offline
- ❌ **Structured Input** - Complex tasks require manual JSON editing
- ❌ **Planning** - No multi-agent reasoning before execution
- ❌ **UX Polish** - Not optimized for daily use

**Result:** Boss must use Terminal/logs, work gets lost, complex tasks fail.

---

### **Solution Overview**

Upgrade Work Order Studio with 5 key features:

1. **WO Status Dashboard** (HIGH) - Real-time view of all WOs
2. **Retry + Draft System** (HIGH) - Never lose work
3. **Specialized Modes** (MEDIUM) - Structured forms for complex tasks
4. **Architect + Senior Nodes** (MEDIUM-LOW) - Multi-agent planning
5. **UX Polishing** (Optional) - Daily-use optimizations

**Timeline:** 15-20 hours (4-5 days)

---

## 📋 **CURRENT STATE ANALYSIS**

### **Existing Components**

**Gateway (`apps/opal_gateway/gateway.py`):**
- ✅ `POST /api/wo` - Submit work order
- ✅ `POST /api/wo_status` - Query single WO status (returns 404 if no state file)
- ✅ `POST /api/notify` - Queue notifications
- ✅ Security: RELAY_KEY, atomic writes, CloudStorage blocking

**Dashboard (`apps/dashboard/`):**
- ✅ `followup.html` - Follow-up dashboard (reads `data/followup.json`)
- ✅ `wo_dashboard_server.js` - Dashboard server
- ✅ State files: `followup/state/{wo_id}.json`

**WO Pipeline:**
- ✅ Processes WOs from `bridge/inbox/LIAM/`
- ✅ Writes state files to `followup/state/`
- ✅ Status values: `pending`, `running`, `done`, `failed`

**Opal Integration:**
- ✅ Basic flow: User Input → Generate WO → Send to Gateway
- ✅ Architect/Senior prompts created (not yet integrated)

---

### **Gap Analysis**

**Missing Components:**
1. ❌ **List API** - No endpoint to get all WOs (only single WO query)
2. ❌ **Status Tracking** - Gateway doesn't write status to centralized location
3. ❌ **Draft System** - No local storage for failed submissions
4. ❌ **Structured Forms** - No specialized UI for expense/trade/etc.
5. ❌ **Planning Integration** - Architect/Senior nodes not wired
6. ❌ **UX Enhancements** - Missing retry, timestamps, autocomplete

---

## 🎯 **FEATURE OBJECTIVES**

### **Primary Goals**

1. **Real-Time Visibility**
   - See all WOs in system at once
   - Filter by status (QUEUED/RUNNING/DONE/ERROR/STALE)
   - Auto-refresh every 5-10 seconds
   - Highlight errors and long-running tasks

2. **Work Resilience**
   - Never lose work due to network failure
   - Local draft storage
   - Automatic retry on failure
   - Clear error messages

3. **Structured Input**
   - Specialized forms for complex tasks
   - Reduce AI hallucination
   - Better data validation
   - Preview before submission

4. **Intelligent Planning**
   - Multi-agent reasoning before execution
   - Plan validation
   - Error reduction (50%+ target)

5. **Daily-Use UX**
   - Quick actions (retry, view logs)
   - Timestamps and history
   - Autocomplete for WO names
   - Mobile-friendly

---

## 🏗️ **ARCHITECTURE DESIGN**

### **System Flow**

```
┌─────────────┐
│   Opal App   │
│  (Cloud UI)  │
└─────┬───────┘
      │
      ├─→ [Draft Storage] (Local)
      │
      ▼
┌─────────────────────┐
│ Architect Node       │ ← NEW
│ (Planning)           │
└─────┬───────────────┘
      │
      ▼
┌─────────────────────┐
│ Senior Reviewer      │ ← NEW
│ (Validation)          │
└─────┬───────────────┘
      │
      ▼
┌─────────────────────┐
│ Generate WO          │
│ (Enhanced)           │
└─────┬───────────────┘
      │
      ▼
┌─────────────────────┐
│ Gateway              │
│ /api/wo              │
│ /api/wo_status       │
│ /api/wo_list         │ ← NEW
└─────┬───────────────┘
      │
      ├─→ [Status Store] (Redis/File)
      │
      ▼
┌─────────────────────┐
│ WO Pipeline          │
│ (Processing)         │
└─────┬───────────────┘
      │
      ▼
┌─────────────────────┐
│ Status Dashboard      │ ← NEW
│ (Real-time View)      │
└─────────────────────┘
```

---

## 📝 **COMPONENT SPECIFICATIONS**

### **Component 1: WO Status Dashboard (Priority: HIGH)**

**File:** `apps/dashboard/wo_status.html`

**Features:**
- Real-time table of all WOs
- Status filters: QUEUED, RUNNING, DONE, ERROR, STALE
- Auto-refresh every 5-10 seconds
- Highlight ERROR and LONG-RUNNING tasks
- Links to raw logs
- Timestamps (created, updated, completed)

**API Endpoint:**
- `GET /api/wo_list?limit=50&status=all|queued|running|done|error|stale`

**Data Sources:**
- `followup/state/*.json` (primary)
- `bridge/inbox/LIAM/*.json` (for queued WOs)
- Gateway status cache (optional Redis)

**Status Mapping:**
- `QUEUED` - File in inbox, no state file yet
- `RUNNING` - State file exists, status=`running`
- `DONE` - State file exists, status=`done`
- `ERROR` - State file exists, status=`failed` or `last_error` present
- `STALE` - State file exists, `updated_at` > 24h ago, status=`running`

**UI Components:**
- Table with columns: WO ID, Objective, Status, Lane, Priority, Created, Updated, Actions
- Status badges (color-coded)
- Filter dropdown
- Refresh button (manual)
- Auto-refresh toggle
- "View Logs" link per row

---

### **Component 2: Opal Retry + Draft System (Priority: HIGH)**

**File:** `apps/opal_gateway/OPAL_DRAFT_SYSTEM.md` (spec)

**Features:**
- Local draft storage in Opal (browser localStorage or Opal storage)
- Auto-save on `/api/wo` failure
- Drafts tab in Opal UI
- Resend button per draft
- Delete draft on success
- Error reason display (network, 5xx, offline)

**Draft Storage Format:**
```json
{
  "drafts": [
    {
      "draft_id": "draft_20251205_123456",
      "created_at": "2025-12-05T12:34:56Z",
      "failed_at": "2025-12-05T12:35:01Z",
      "error_reason": "network_error|gateway_5xx|offline|timeout",
      "error_message": "Connection timeout after 10s",
      "wo_payload": { /* Original WO JSON */ },
      "retry_count": 0
    }
  ]
}
```

**Opal Flow Enhancement:**
```
User Input → Generate WO → Send to Gateway
                ↓ (on failure)
            Save to Drafts
                ↓
            Show Error + Draft Saved
                ↓
            User can Retry from Drafts Tab
```

**Error Handling:**
- Network error → Save draft, show "Network unavailable"
- 5xx error → Save draft, show "Gateway error: {message}"
- Offline → Save draft, show "Offline - saved to drafts"
- Timeout → Save draft, show "Request timeout"

---

### **Component 3: Specialized Modes (Priority: MEDIUM)**

**File:** `apps/opal_gateway/OPAL_EXPENSE_MODE.md` (spec for first mode)

**First Mode: Expense Entry**

**Form Fields:**
- Date (date picker)
- Description (text)
- Category (dropdown: Food, Transport, Office, etc.)
- Amount (number)
- VAT % (number, default 7%)
- Payment Method (dropdown: Cash, Credit Card, Transfer)
- Project (text, optional)
- Note (textarea, optional)
- Receipt (file upload)

**Output Schema:**
```json
{
  "wo_id": "WO-EXP-...",
  "app_mode": "expense",
  "expense": {
    "date": "2025-12-05",
    "description": "Lunch",
    "category": "Food",
    "amount": 350,
    "vat_percent": 7,
    "vat_amount": 24.5,
    "total_amount": 374.5,
    "pay_method": "Cash",
    "project": "Project A",
    "note": "Team lunch"
  },
  "attachments": {
    "receipt": "receipt_20251205.jpg"
  }
}
```

**Benefits:**
- Structured data (no AI guessing)
- Validation before submission
- Preview before sending
- Reduced errors

**Future Modes:**
- Trade Mode (chart analysis, entry/exit points)
- QS Mode (quantity survey, measurements)
- Progress Mode (site photos, updates)

---

### **Component 4: Architect + Senior Nodes Integration (Priority: MEDIUM-LOW)**

**Status:** Prompts created, need integration

**Files:**
- `apps/opal_gateway/OPAL_ARCHITECT_NODE_PROMPT.md` ✅
- `apps/opal_gateway/OPAL_SENIOR_REVIEWER_NODE_PROMPT.md` ✅

**Integration Tasks:**
1. Add Architect node to Opal flow
2. Add Senior Reviewer node to Opal flow
3. Wire: User Input → Architect → Senior → Generate WO
4. Enhance WO Generator to accept reviewed plan
5. Add `planning_metadata` to WO JSON
6. Add fallback JSON if input parsing fails

**Enhanced WO JSON:**
```json
{
  "wo_id": "...",
  "app_mode": "...",
  "objective": "...",
  "planning_metadata": {
    "architect_plan": { /* Architect output */ },
    "senior_review": { /* Senior reviewer output */ },
    "final_plan": { /* Merged plan */ }
  },
  // ... rest of fields
}
```

---

### **Component 5: UX Polishing (Priority: Optional)**

**Features:**
- "Send Again" button in WO History
- "Open in Gateway Log" link
- Timestamps (send time, completion time)
- WO name autocomplete (from history)
- Mobile-responsive layout
- Keyboard shortcuts

---

## 🔧 **IMPLEMENTATION TASKS**

### **Phase 1: WO Status Dashboard (Priority: HIGH)**

**Task 1.1: Create List API Endpoint**
- **File:** `apps/opal_gateway/gateway.py`
- **Endpoint:** `GET /api/wo_list?limit=50&status=all`
- **Logic:**
  - Read all state files from `followup/state/`
  - Read queued files from `bridge/inbox/LIAM/`
  - Merge and sort by `updated_at` desc
  - Filter by status if provided
  - Return paginated list
- **Time:** 2-3 hours

**Task 1.2: Create Status Dashboard HTML**
- **File:** `apps/dashboard/wo_status.html`
- **Features:**
  - Table with all WOs
  - Status filters
  - Auto-refresh (5-10s)
  - Highlight errors
  - Links to logs
- **Time:** 3-4 hours

**Task 1.3: Add Status Tracking**
- **Enhancement:** Gateway writes status to centralized location
- **Options:**
  - Redis (if available)
  - Status file (`bridge/status/wo_status.jsonl`)
- **Time:** 1-2 hours

---

### **Phase 2: Opal Retry + Draft System (Priority: HIGH)**

**Task 2.1: Implement Draft Storage**
- **File:** Opal flow enhancement
- **Logic:**
  - Catch `/api/wo` failures
  - Save payload to localStorage/Opal storage
  - Display error message
  - Show "Saved to Drafts" notification
- **Time:** 2-3 hours

**Task 2.2: Create Drafts Tab UI**
- **File:** Opal UI enhancement
- **Features:**
  - Drafts list
  - Resend button
  - Delete button
  - Error reason display
- **Time:** 2-3 hours

**Task 2.3: Implement Retry Logic**
- **Logic:**
  - Resend draft payload to `/api/wo`
  - On success: Delete draft
  - On failure: Update error, increment retry_count
- **Time:** 1-2 hours

---

### **Phase 3: Specialized Modes (Priority: MEDIUM)**

**Task 3.1: Create Expense Mode Form**
- **File:** Opal flow enhancement
- **Form:** Date, Description, Category, Amount, VAT, Payment, Project, Note, Receipt
- **Validation:** Client-side validation
- **Preview:** Show formatted preview before submission
- **Time:** 4-5 hours

**Task 3.2: Integrate with Architect Node**
- **Enhancement:** Send structured expense data to Architect
- **Benefit:** Better planning with structured input
- **Time:** 1-2 hours

---

### **Phase 4: Architect + Senior Integration (Priority: MEDIUM-LOW)**

**Task 4.1: Wire Nodes in Opal**
- **Action:** Add Architect and Senior nodes to flow
- **Wiring:** User Input → Architect → Senior → Generate WO
- **Time:** 1-2 hours

**Task 4.2: Enhance WO Generator**
- **Enhancement:** Accept reviewed plan, merge into WO JSON
- **Add:** `planning_metadata` field
- **Time:** 1-2 hours

**Task 4.3: Add Fallback Logic**
- **Enhancement:** If input parsing fails, use fallback JSON structure
- **Time:** 1 hour

---

### **Phase 5: UX Polishing (Priority: Optional)**

**Task 5.1: Add Quick Actions**
- **Features:** Send Again, View Logs, Copy WO ID
- **Time:** 2-3 hours

**Task 5.2: Add Timestamps**
- **Features:** Send time, completion time, duration
- **Time:** 1-2 hours

**Task 5.3: Add Autocomplete**
- **Feature:** WO name autocomplete from history
- **Time:** 2-3 hours

---

## 📊 **TESTING STRATEGY**

### **Unit Tests**

**Dashboard API:**
- ✅ List all WOs
- ✅ Filter by status
- ✅ Pagination works
- ✅ Handles missing state files

**Draft System:**
- ✅ Saves on failure
- ✅ Retry works
- ✅ Deletes on success
- ✅ Error messages clear

**Expense Mode:**
- ✅ Form validation
- ✅ Preview generation
- ✅ WO JSON structure correct

---

### **Integration Tests**

**End-to-End:**
1. Submit WO → Check dashboard appears
2. Network failure → Check draft saved
3. Retry draft → Check WO submitted
4. Expense form → Check structured data
5. Architect flow → Check plan in WO

---

## 🚀 **DEPLOYMENT PLAN**

### **Week 1: Core Features**

**Day 1-2: WO Status Dashboard**
- Task 1.1: List API
- Task 1.2: Dashboard HTML
- Task 1.3: Status tracking

**Day 3-4: Draft System**
- Task 2.1: Draft storage
- Task 2.2: Drafts UI
- Task 2.3: Retry logic

### **Week 2: Enhanced Features**

**Day 5-7: Specialized Modes**
- Task 3.1: Expense form
- Task 3.2: Architect integration

**Day 8-9: Planning Integration**
- Task 4.1: Wire nodes
- Task 4.2: Enhance WO generator
- Task 4.3: Fallback logic

**Day 10: UX Polish (Optional)**
- Task 5.1-5.3: Quick actions, timestamps, autocomplete

---

## ⚠️ **RISKS & MITIGATIONS**

### **Risk 1: Performance (List API)**

**Risk:** Reading all state files may be slow  
**Mitigation:**
- Cache results
- Use pagination
- Consider Redis for status cache

### **Risk 2: Draft Storage Limits**

**Risk:** localStorage has size limits  
**Mitigation:**
- Use Opal storage if available
- Implement draft cleanup (old drafts)
- Limit draft count

### **Risk 3: Status Sync Issues**

**Risk:** Dashboard shows stale data  
**Mitigation:**
- Auto-refresh
- Manual refresh button
- Clear cache indicators

---

## 📈 **SUCCESS METRICS**

### **Quantitative**

- ✅ Dashboard loads < 2 seconds
- ✅ Draft system saves 100% of failures
- ✅ Expense form reduces errors by 30%+
- ✅ Planning reduces execution errors by 50%+

### **Qualitative**

- ✅ Boss can see all WOs at a glance
- ✅ No work lost due to network issues
- ✅ Complex tasks have structured input
- ✅ System feels enterprise-ready

---

## ✅ **ACCEPTANCE CRITERIA**

**Feature is complete when:**

1. ✅ Dashboard shows all WOs with real-time updates
2. ✅ Draft system saves all failed submissions
3. ✅ Expense mode form works end-to-end
4. ✅ Architect/Senior nodes integrated
5. ✅ UX polish complete (if implemented)
6. ✅ All tests pass
7. ✅ Documentation complete
8. ✅ Production deployment successful

---

## 📅 **TIMELINE SUMMARY**

**Total Estimated Time:** 15-20 hours

**Phase 1 (HIGH):** 6-9 hours
- WO Status Dashboard

**Phase 2 (HIGH):** 5-8 hours
- Draft System

**Phase 3 (MEDIUM):** 5-7 hours
- Specialized Modes

**Phase 4 (MEDIUM-LOW):** 3-5 hours
- Planning Integration

**Phase 5 (Optional):** 5-8 hours
- UX Polish

---

## 🎯 **PRIORITY ORDER (Boss Request)**

1. **WO Status Dashboard** (HIGH) - Real-time visibility
2. **Retry + Draft System** (HIGH) - Never lose work
3. **Specialized Modes** (MEDIUM) - Structured input
4. **Architect + Senior Nodes** (MEDIUM-LOW) - Planning
5. **UX Polishing** (Optional) - Daily-use optimizations

---

**End of Feature Plan**
