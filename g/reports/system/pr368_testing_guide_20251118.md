# PR #368 Testing Guide

**Date:** 2025-11-18  
**PR:** #368  
**Status:** 📋 **TESTING GUIDE**

---

## Testing Checklist

### 1. Setup

1. **Checkout PR Branch**
   ```bash
   git checkout feat/pr298-complete-migration
   ```

2. **Start Dashboard Server**
   ```bash
   cd g/apps/dashboard
   python3 -m http.server 8000
   ```

3. **Open Browser**
   - Navigate to: http://localhost:8000/index.html

---

### 2. Pipeline Metrics Testing

#### Visual Verification

- [ ] **Pipeline Metrics Section Visible**
  - Should appear after "Status Bar" section
  - Should show "Pipeline Metrics" label

- [ ] **Metrics Display**
  - [ ] Throughput shows "X WO/hr" or "-"
  - [ ] Avg Time shows "Xs" or "-"
  - [ ] Queue shows number or "-"
  - [ ] Success Rate shows "X%" with color coding

- [ ] **Stage Distribution**
  - [ ] Queued count displays
  - [ ] Running count displays
  - [ ] Success count displays
  - [ ] Failed count displays
  - [ ] Pending count displays

#### Functional Testing

- [ ] **Metrics Update on WO Load**
  - Load dashboard
  - Wait for WO data to load
  - Verify metrics update automatically

- [ ] **Color Coding**
  - Success rate ≥90% → Green (#48bb78)
  - Success rate ≥70% → Orange (#ed8936)
  - Success rate <70% → Red (#f56565)

- [ ] **Refresh Behavior**
  - Click refresh button
  - Verify metrics recalculate
  - Verify UI updates

- [ ] **Empty State**
  - Test with no WO data
  - Verify metrics show "-" or "0"
  - Verify no errors in console

---

### 3. Trading Importer Testing

#### File Verification

- [ ] **Script Exists**
  ```bash
  ls -la tools/trading_import.zsh
  ```

- [ ] **Schema Exists**
  ```bash
  ls -la g/schemas/trading_journal.schema.json
  ```

- [ ] **Documentation Exists**
  ```bash
  ls -la g/manuals/trading_import_manual.md
  ```

#### Functional Testing

- [ ] **Script Executable**
  ```bash
  chmod +x tools/trading_import.zsh
  tools/trading_import.zsh --help
  ```

- [ ] **Schema Valid**
  ```bash
  cat g/schemas/trading_journal.schema.json | jq .
  ```

---

### 4. Regression Testing

#### Existing Features

- [ ] **Dashboard Loads**
  - No console errors
  - All sections visible

- [ ] **WO List Works**
  - WOs display correctly
  - Filters work
  - Detail view works

- [ ] **Other Metrics**
  - Roadmap progress works
  - Services count works
  - Health indicator works

- [ ] **Auto-refresh**
  - Auto-refresh still works
  - Metrics update on refresh

---

### 5. Browser Console Checks

- [ ] **No JavaScript Errors**
  - Open browser console (F12)
  - Check for errors
  - Verify no undefined functions

- [ ] **DOM Elements Found**
  - Check for "pipeline-throughput" element
  - Check for "pipeline-avg-time" element
  - Verify all elements exist

---

### 6. Performance Testing

- [ ] **Metrics Calculation Speed**
  - Test with 100+ WOs
  - Verify calculation is fast (<100ms)
  - No UI lag

- [ ] **Memory Usage**
  - Check memory usage
  - Verify no memory leaks
  - Metrics object size reasonable

---

## Test Results Template

```
## Test Results

**Date:** 2025-11-18
**Tester:** [Your Name]
**Environment:** [Browser/OS]

### Pipeline Metrics
- [ ] Visual verification: PASS/FAIL
- [ ] Functional testing: PASS/FAIL
- [ ] Color coding: PASS/FAIL
- [ ] Refresh behavior: PASS/FAIL

### Trading Importer
- [ ] File verification: PASS/FAIL
- [ ] Functional testing: PASS/FAIL

### Regression Testing
- [ ] Dashboard loads: PASS/FAIL
- [ ] WO list works: PASS/FAIL
- [ ] Other metrics: PASS/FAIL

### Browser Console
- [ ] No errors: PASS/FAIL
- [ ] DOM elements: PASS/FAIL

### Performance
- [ ] Calculation speed: PASS/FAIL
- [ ] Memory usage: PASS/FAIL

### Issues Found
[List any issues found]

### Overall Status
✅ PASS / ❌ FAIL
```

---

## Quick Test Commands

```bash
# Checkout branch
git checkout feat/pr298-complete-migration

# Start server
cd g/apps/dashboard && python3 -m http.server 8000

# Verify HTML elements
grep -c "pipeline-throughput" g/apps/dashboard/index.html

# Verify JavaScript functions
grep -c "calculatePipelineMetrics" g/apps/dashboard/dashboard.js

# Check trading files
ls -la tools/trading_import.zsh g/schemas/trading_journal.schema.json
```

---

**Status:** Ready for testing  
**Next:** Run manual tests in browser

