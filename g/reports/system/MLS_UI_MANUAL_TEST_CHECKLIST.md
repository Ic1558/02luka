# MLS Live UI - Manual Test Checklist

**Date:** 2025-11-05
**Version:** v2.2.0 + Kim Chat
**URL:** file:///Users/icmini/02luka/g/reports/mls_report_20251105.html

---

## ✅ Pre-Test Setup

Before testing, ensure:

```bash
# 1. API Server running
ps aux | grep "[a]pi_server.py"
# Expected: PID 61837

# 2. Kim Shim running
ps aux | grep "[k]im_ui_shim.py"
# Expected: PID 66643

# 3. Redis responding
redis-cli -a gggclukaic PING
# Expected: PONG
```

---

## 🧪 Test Suite

### Test 1: Page Load & Data Display

**Steps:**
1. Open URL in browser
2. Check browser DevTools Console (F12 → Console tab)

**Expected Results:**
- ✅ Page loads without JavaScript errors
- ✅ Summary counters show: 14 Total, 9 Solutions, 1 Pattern, 2 Improvements, 2 Failures
- ✅ Table displays entries
- ✅ No red error messages in console

**Status:** _____

---

### Test 2: Filter Buttons

**Steps:**
1. Click "All" button → should show all 14 entries
2. Click "Solutions" button → should show 9 entries
3. Click "Patterns" button → should show 1 entry
4. Click "Improvements" button → should show 2 entries
5. Click "Failures" button → should show 2 entries

**Expected Results:**
- ✅ Active button highlighted in blue
- ✅ Table updates to show filtered entries
- ✅ Count matches filter

**Status:** _____

---

### Test 3: Search Functionality

**Steps:**
1. Type "Google Drive" in search box
2. Type "sync" in search box
3. Clear search box

**Expected Results:**
- ✅ Table filters to matching entries as you type
- ✅ Searches title, details, context, and ID fields
- ✅ Clearing search shows all entries again

**Status:** _____

---

### Test 4: Expandable Rows

**Steps:**
1. Click any entry row (not the Copy button)
2. Click the same row again

**Expected Results:**
- ✅ First click: Row expands, shows Description and Context
- ✅ Second click: Row collapses
- ✅ Row stays expanded after page refresh (localStorage)

**Status:** _____

---

### Test 5: Copy ID Button

**Steps:**
1. Click "Copy" button next to any MLS ID
2. Paste into a text editor (Cmd+V)

**Expected Results:**
- ✅ Button shows "✓ Copied" briefly
- ✅ Clipboard contains the MLS ID (e.g., "MLS-1762294970")

**Status:** _____

---

### Test 6: Deep Linking

**Steps:**
1. Open URL with hash: `file:///Users/icmini/02luka/g/reports/mls_report_20251105.html#MLS-1762294970`
2. Check if entry auto-expands and scrolls into view

**Expected Results:**
- ✅ Page loads with specified entry expanded
- ✅ Browser scrolls to that entry
- ✅ Entry is highlighted

**Status:** _____

---

### Test 7: Chat Widget - Open/Close

**Steps:**
1. Click "💬 Chat" button (bottom-right)
2. Click "💬 Chat" button again

**Expected Results:**
- ✅ First click: Chat panel slides in from right
- ✅ Second click: Chat panel closes
- ✅ Chat panel shows "💬 Chat with Kim (Local AI)" title

**Status:** _____

---

### Test 8: Chat Context Toggle

**Steps:**
1. Open chat widget
2. Expand one entry in the table
3. Click "Current" chip in chat
4. Click "All entries" chip in chat

**Expected Results:**
- ✅ "Current" chip is blue (active) by default
- ✅ Clicking "All entries" makes it blue
- ✅ Only one chip active at a time

**Status:** _____

---

### Test 9: Chat Message Send (Without Kim)

**Steps:**
1. Open chat widget
2. Type "Hello Kim" in textarea
3. Click "Send" button

**Expected Results:**
- ✅ Message appears in chat as "user" (right-aligned, blue background)
- ✅ After ~8 seconds, timeout message appears: "⏳ Queued to Kim..."
- ✅ Textarea clears after sending

**Note:** This is expected behavior when Kim agent is not connected.

**Status:** _____

---

### Test 10: Chat Intent Parsing

**Steps:**
Try these messages in chat:
1. `add solution: Test solution`
2. `add failure: Test failure`
3. `search: sync`

**Expected Results:**
- ✅ Messages send successfully
- ✅ All timeout after 8 seconds (Kim not connected)
- ✅ No JavaScript errors in console

**Status:** _____

---

### Test 11: Auto-Refresh (30 seconds)

**Steps:**
1. Leave page open for 30+ seconds
2. Watch network tab in DevTools

**Expected Results:**
- ✅ Every 30 seconds, page fetches `/api/mls`
- ✅ Summary counters update if data changed
- ✅ No errors in console

**Status:** _____

---

### Test 12: Console Errors Check

**Steps:**
1. Open DevTools Console (F12 → Console)
2. Refresh page
3. Interact with all features (filters, search, expand, chat)

**Expected Results:**
- ✅ No red error messages
- ✅ No "Uncaught" exceptions
- ✅ Only info/debug logs (if any)

**Common Issues to Look For:**
- ❌ `Uncaught SyntaxError` → JavaScript parse error
- ❌ `Uncaught TypeError` → Undefined variable/function
- ❌ `Failed to fetch` → API server not running
- ❌ Unmatched `}` or `)` → Syntax error

**Status:** _____

---

## 🔍 Troubleshooting

### Issue: Page blank or shows "Loading MLS data..."

**Cause:** API server not running or wrong port

**Fix:**
```bash
# Check if running
ps aux | grep "[a]pi_server.py"

# Start if needed
cd ~/02luka/g/apps/dashboard
nohup python3 api_server.py > ~/02luka/logs/api_server.out.log 2>&1 &

# Test endpoint
curl http://127.0.0.1:8767/api/mls | jq .summary
```

---

### Issue: Chat shows "❌ Error: Failed to fetch"

**Cause:** Kim UI shim not running

**Fix:**
```bash
# Check if running
ps aux | grep "[k]im_ui_shim.py"

# Start if needed
cd ~/02luka/tools
nohup python3 kim_ui_shim.py > ~/02luka/logs/kim_ui_shim.out.log 2>&1 &

# Test endpoint
curl http://127.0.0.1:8770/health
```

---

### Issue: JavaScript errors in console

**Cause:** Syntax error in HTML/JS

**Fix:**
1. Check console for line number
2. Read `/Users/icmini/02luka/g/reports/mls_report_20251105.html` at that line
3. Look for unmatched brackets, quotes, or parentheses

---

### Issue: Filters don't work

**Cause:** JavaScript event listeners not attached

**Fix:**
1. Open console, type: `console.log(allData)`
2. Should show array of 14 entries
3. If undefined, data didn't load → check API server

---

## 📋 Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| 1. Page Load | ⬜ | |
| 2. Filters | ⬜ | |
| 3. Search | ⬜ | |
| 4. Expand Rows | ⬜ | |
| 5. Copy ID | ⬜ | |
| 6. Deep Link | ⬜ | |
| 7. Chat Open/Close | ⬜ | |
| 8. Context Toggle | ⬜ | |
| 9. Chat Send | ⬜ | |
| 10. Intent Parse | ⬜ | |
| 11. Auto-Refresh | ⬜ | |
| 12. Console Clean | ⬜ | |

**Legend:** ✅ Pass | ❌ Fail | ⬜ Not Tested

---

## ✅ Sign-Off

**Tested By:** __________________
**Date:** __________________
**Overall Status:** ⬜ Pass | ⬜ Fail

**Notes:**

---

**Next:** Once all tests pass, proceed to `/Users/icmini/02luka/g/reports/MLS_CHAT_SETUP.md` for Kim agent integration.
