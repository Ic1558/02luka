# Dashboard v2.1.0 - Quick Start Guide

## 🚀 What's New in v2.1.0

### Phase 3: Enhanced Work Order Detail Drawer

**Major improvements to how you view and interact with work orders.**

---

## 📍 Accessing Work Orders

### Method 1: Direct Click (Original)
1. Scroll to **Work Order History** section
2. Click any work order card
3. Drawer opens showing full details

### Method 2: MLS Card Auto-Select (NEW in v2.1)
1. Click any **MLS card** (Total, Solutions, Failures)
2. Dashboard automatically:
   - Scrolls to Work Order History
   - Selects first work order
   - Opens drawer with details

**Why this is useful:** Quick access to related work orders without manual scrolling and clicking.

---

## 📑 Drawer Tabs (NEW in v2.1)

The drawer now organizes information into 4 tabs:

### 1. 📋 Summary Tab (Default)
Shows at-a-glance information:
- **Status** badge (success/failed/pending)
- **Work Order ID**
- **Goal** description
- **Duration** in seconds
- **Exit Code** (color-coded)
- **Timestamps** (started, completed)
- **File Paths** (script, log)

**When to use:** Quick overview of WO status and metadata.

### 2. 📥 I-O Tab
Shows input/output streams:
- **Standard Output** (stdout)
- **Standard Error** (stderr)

**When to use:** Debugging, checking command output.

### 3. 📜 Logs Tab
Shows recent log entries:
- **Log Tail** (last 100 lines)
- Auto-formatted with timestamps

**When to use:** Detailed debugging, monitoring execution flow.

### 4. ⚡ Actions Tab (NEW in v2.1)
Interactive buttons for WO management:

#### 🔄 Retry Button
- **What it does:** Creates a new work order with same parameters
- **Use case:** Idempotent operations that failed due to temporary issues
- **Safety:** Shows confirmation dialog before creating

#### ❌ Cancel Button
- **What it does:** Sends cancellation signal to work order
- **Use case:** Stop long-running or stuck work orders
- **Limitation:** Only works if WO processor supports cancellation
- **Safety:** Shows confirmation dialog (destructive action)

#### 📡 Tail Button
- **What it does:** Opens live log streaming viewer
- **Use case:** Monitor long-running work orders in real-time
- **Status:** Placeholder (implementation pending)

---

## ✨ Enhanced Empty States (NEW in v2.1)

When no work orders match the current filter, you'll see helpful messages:

### Success Filter Empty
```
✨ No Successful Work Orders
No completed work orders in the last 24 hours.
Submit a new work order to get started.
```

### Failed Filter Empty
```
✅ All Clear!
No failed or blocked work orders.
Your system is running smoothly.
```

### Pending Filter Empty
```
📭 No Pending Work Orders
All work orders have been processed.
Drop a new .json file in bridge/inbox/LLM to create one.
```

**Why this is useful:** Clear guidance on what the empty state means and how to proceed.

---

## ⌨️ Keyboard Shortcuts

- **ESC** - Close drawer
- **Enter/Space** - Activate clickable cards

---

## 🎯 Common Workflows

### Workflow 1: Check Recent Failures
1. Click **MLS "Failures"** card
2. Dashboard scrolls and auto-opens first failed WO
3. Switch to **I-O tab** to see error output
4. Switch to **Logs tab** for detailed debugging
5. If retriable, switch to **Actions tab** → Click **Retry**

### Workflow 2: Monitor Long-Running Task
1. Find WO in Work Order History
2. Click to open drawer
3. Switch to **Logs tab** to see progress
4. (Future) Click **Tail** button for live streaming

### Workflow 3: Quick Status Check
1. Click **MLS "Total"** card
2. Drawer opens showing first WO summary
3. Check status badge and duration
4. Press **ESC** to close

---

## 🔍 Troubleshooting

### Drawer won't open
- **Check:** Is the API server running? `ps aux | grep api_server`
- **Fix:** Start server: `python ~/02luka/g/apps/dashboard/api_server.py &`

### Empty states always showing
- **Check:** Are there work orders in `~/02luka/bridge/outbox/RD/pending`?
- **Fix:** Move WOs from `RD/pending` to `inbox/LLM` for processing

### Tabs not switching
- **Check:** Browser console for JavaScript errors (F12)
- **Fix:** Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Win/Linux)

### Action buttons don't work
- **Status:** Placeholder implementation (shows dialogs only)
- **Future:** API endpoints will be added for actual Retry/Cancel functionality

---

## 📊 Version History

- **v2.1.0** (2025-01-05): Phase 3 - Drawer tabs, auto-select, action buttons
- **v2.0.2** (2025-01-04): Phase 2 - Interactive KPI cards
- **v2.0.0** (2025-01-03): Initial dashboard release

---

## 🚀 Future Roadmap

### Coming Soon
- Live log streaming (SSE or polling)
- WO filtering by MLS category
- Export WO details to JSON/CSV
- Keyboard shortcuts for tab navigation
- API endpoints for Retry/Cancel actions

### Under Consideration
- WO comparison view (diff two work orders)
- Bulk actions (retry multiple failed WOs)
- Custom filtering and search
- Performance metrics dashboard
- Integration with notification system

---

## 📚 Additional Resources

- **Full Changelog**: See `CHANGELOG.md` for detailed version history
- **Dashboard Location**: `~/02luka/g/apps/dashboard/`
- **API Server**: Listens on `http://127.0.0.1:8767`
- **API Endpoints**:
  - `GET /api/wos` - List all work orders
  - `GET /api/wos?status=success|failed|pending` - Filter by status
  - `GET /api/wos/{id}` - Get single work order details
  - `GET /api/wos/{id}?tail=N` - Include last N log lines

---

## 🤝 Feedback

Found a bug or have a feature request?

1. Check console logs (F12) for errors
2. Create a work order with details: `~/02luka/bridge/inbox/LLM/`
3. Or contact: CLC (Claude Code)

---

**Dashboard v2.1.0** - Built with ❤️ by the 02luka System
