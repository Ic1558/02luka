# Resolve Dashboard Conflict: WO Pipeline Metrics

**Branch:** `codex/add-wo-pipeline-metrics-to-dashboard`  
**Conflict File:** `g/apps/dashboard/dashboard.js`  
**Date:** 2025-11-16

---

## Conflict Resolution Guide

Since the conflict exists on GitHub and cannot be accessed directly via terminal, follow these steps:

### Step 1: Access the Conflict

1. Go to: https://github.com/Ic1558/02luka/pull/296/conflicts
2. Or use GitHub CLI:
   ```bash
   gh pr checkout 296
   git status
   ```

### Step 2: Understand the Changes

**Current Branch (`codex/add-wo-pipeline-metrics-to-dashboard`):**
- Likely adds WO pipeline metrics visualization
- May add new metrics tracking for:
  - WO throughput (WOs/hour)
  - Average processing time
  - Queue depth
  - Pipeline stage distribution (queued/running/success/failed)
  - Success rate trends

**Base Branch (main):**
- Has existing metrics system (lines 149-194)
- Has health monitoring UI (lines 210-254)
- Has WO status tracking (queued, running, success, failed)

### Step 3: Resolution Strategy

#### Option A: Merge Both Changes
If the conflict is in different sections:
1. Keep both sets of changes
2. Ensure no duplicate code
3. Integrate new metrics into existing `metrics` object

#### Option B: Integrate New Metrics
If adding pipeline-specific metrics:
1. Add to existing `metrics` object:
   ```javascript
   const metrics = {
     wos: { ok: 0, err: 0, ms: [], consecutiveErrors: 0 },
     // ... existing ...
     pipeline: {
       throughput: 0,        // WOs per hour
       avgProcessingTime: 0, // Average duration
       queueDepth: 0,        // Pending WOs
       stageDistribution: {   // Count by stage
         queued: 0,
         running: 0,
         success: 0,
         failed: 0
       }
     }
   };
   ```

2. Add pipeline metrics calculation function
3. Add UI display for pipeline metrics

#### Option C: Resolve Line-by-Line
If conflict markers exist:
1. Identify `<<<<<<<`, `=======`, `>>>>>>>` markers
2. Review each section
3. Keep the version that:
   - Maintains existing functionality
   - Adds new pipeline metrics
   - Doesn't break existing code

### Step 4: Manual Resolution Steps

1. **Checkout the branch:**
   ```bash
   git fetch origin
   git checkout codex/add-wo-pipeline-metrics-to-dashboard
   git merge origin/main
   ```

2. **Open the conflicted file:**
   ```bash
   code g/apps/dashboard/dashboard.js
   # or
   vim g/apps/dashboard/dashboard.js
   ```

3. **Find conflict markers:**
   - Search for `<<<<<<<`
   - Review both versions
   - Choose the correct resolution

4. **Resolve conflicts:**
   - Remove conflict markers
   - Keep desired code
   - Ensure syntax is correct

5. **Test the resolution:**
   ```bash
   # Check syntax
   node -c g/apps/dashboard/dashboard.js
   
   # Test in browser (if possible)
   # Open dashboard and verify metrics display
   ```

6. **Commit the resolution:**
   ```bash
   git add g/apps/dashboard/dashboard.js
   git commit -m "Resolve conflict: Merge WO pipeline metrics"
   ```

### Step 5: Verify Integration

After resolving:
1. ✅ Metrics object includes pipeline data
2. ✅ UI displays pipeline metrics (if added)
3. ✅ No JavaScript syntax errors
4. ✅ Existing functionality still works
5. ✅ New metrics are calculated correctly

---

## Expected Changes

Based on the branch name, the new code likely adds:

1. **Pipeline Metrics Calculation:**
   - Calculate WO throughput from recent WOs
   - Track average processing time
   - Monitor queue depth

2. **UI Components:**
   - New metrics cards or sections
   - Pipeline visualization (if any)
   - Real-time updates

3. **Data Fetching:**
   - May add new API endpoints
   - May enhance existing WO data fetching

---

## Common Conflict Patterns

### Pattern 1: Metrics Object Extension
```javascript
// CONFLICT: Both branches modify metrics object
const metrics = {
  wos: { ... },
  // <<<<<<< HEAD (main)
  logs: { ... }
  // =======
  pipeline: { ... }
  // >>>>>>> codex/add-wo-pipeline-metrics-to-dashboard
};

// RESOLUTION: Merge both
const metrics = {
  wos: { ... },
  logs: { ... },
  pipeline: { ... }
};
```

### Pattern 2: Function Addition
```javascript
// CONFLICT: Both branches add functions in same area
// <<<<<<< HEAD (main)
function updateHealthPill() { ... }
// =======
function calculatePipelineMetrics() { ... }
// >>>>>>> codex/add-wo-pipeline-metrics-to-dashboard

// RESOLUTION: Keep both functions
function updateHealthPill() { ... }
function calculatePipelineMetrics() { ... }
```

### Pattern 3: State Object Extension
```javascript
// CONFLICT: Both branches extend state object
const state = {
  wos: { ... },
  // <<<<<<< HEAD (main)
  services: { ... }
  // =======
  pipeline: { ... }
  // >>>>>>> codex/add-wo-pipeline-metrics-to-dashboard
};

// RESOLUTION: Merge both
const state = {
  wos: { ... },
  services: { ... },
  pipeline: { ... }
};
```

---

## Next Steps After Resolution

1. ✅ Test dashboard loads correctly
2. ✅ Verify metrics display
3. ✅ Check browser console for errors
4. ✅ Push resolved branch
5. ✅ Request review on PR

---

**Note:** If you need help with specific conflict markers, share the conflicted section and I can provide exact resolution code.
