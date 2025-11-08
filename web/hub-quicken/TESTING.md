# Hub Quicken v2 - Testing Guide

## Table of Contents
- [Manual Testing](#manual-testing)
- [Automated Testing](#automated-testing)
- [Integration Testing](#integration-testing)
- [Performance Testing](#performance-testing)
- [Accessibility Testing](#accessibility-testing)
- [Security Testing](#security-testing)

---

## Manual Testing

### Quick Test Checklist
```bash
# Start local server
./tools/hub_quicken_dev.zsh

# Open http://localhost:8090/web/hub-quicken/
```

**Basic Functionality (5 min)**
- [ ] Page loads without errors
- [ ] All 4-5 data cards display
- [ ] Search bar filters results
- [ ] Theme toggle switches dark/light
- [ ] Export downloads JSON file
- [ ] History button opens modal

**Data Refresh (2 min)**
- [ ] Auto-refresh checkbox works
- [ ] Interval dropdown changes refresh speed
- [ ] Manual refresh updates timestamps
- [ ] Loading spinners appear during fetch

**AI Features (if configured) (3 min)**
- [ ] AI Settings modal opens
- [ ] Preset buttons apply configurations
- [ ] Test Connection validates endpoint
- [ ] Analyze button triggers analysis
- [ ] Results display in AI card

**Advanced Features (5 min)**
- [ ] Regex toggle changes search behavior
- [ ] Copy buttons copy to clipboard
- [ ] Collapse buttons hide/show cards
- [ ] Keyboard shortcuts respond (Ctrl+K, etc.)
- [ ] History compares snapshots correctly

### Detailed Test Scenarios

#### Scenario 1: First-Time User
```
1. Open Hub Quicken (fresh browser, no cache)
2. Verify default dark theme loads
3. Check all cards show "loading…" initially
4. Wait for data to load
5. Verify badges show counts (e.g., "15 servers")
6. Check footer shows "Updated [time]"
7. Verify service worker registers (check DevTools > Application)

Expected: Clean first load with all features accessible
```

#### Scenario 2: Search & Filter
```
1. Load Hub Quicken with data
2. Type "mcp" in search box
3. Verify results filter in real-time (debounced 300ms)
4. Clear search, type "database"
5. Verify only matching items show
6. Click regex toggle (Alt+R)
7. Type "mcp.*health"
8. Verify regex pattern matches correctly

Expected: Fast, responsive search with visual feedback
```

#### Scenario 3: Theme Switching
```
1. Start with dark theme
2. Click theme toggle (🌓) or press Alt+T
3. Verify light theme applies immediately
4. Check all text is readable (contrast)
5. Reload page
6. Verify theme persists (localStorage)
7. Switch back to dark

Expected: Smooth theme transition, persisted preference
```

#### Scenario 4: AI Analysis
```
Prerequisites: Ollama installed and running

1. Click "🤖 AI" button
2. Click "Ollama (default)" preset
3. Click "Test Connection"
4. Verify toast shows "✓ Connection successful!"
5. Click "Save Settings"
6. Close modal
7. Click "🔍 Analyze" in AI card
8. Verify loading spinner appears
9. Wait for analysis (5-30s depending on model)
10. Verify quick stats appear
11. Verify AI insights text displays
12. Verify badge changes to "analyzed" (green)

Expected: Successful AI analysis with actionable insights
```

#### Scenario 5: History & Snapshots
```
1. Load Hub Quicken
2. Wait for initial data load
3. Refresh page (or wait for auto-refresh)
4. Click "📜 History" button (or Ctrl+H)
5. Verify at least 1 snapshot listed
6. Note timestamp and stats
7. Click "Compare" on a snapshot
8. Verify diff card shows comparison
9. Close modal
10. Check diff card content

Expected: Accurate snapshot comparison with timestamps
```

#### Scenario 6: Mobile Experience
```
Prerequisites: Open in mobile browser or DevTools mobile view

1. Open Hub Quicken on mobile
2. Verify cards stack vertically (1 column)
3. Verify controls are touch-friendly (large tap targets)
4. Swipe down from top (pull-to-refresh)
5. Verify refresh indicator appears
6. Release to trigger refresh
7. Verify data reloads
8. Try all keyboard-less interactions

Expected: Fully functional on mobile without keyboard
```

#### Scenario 7: Offline Mode
```
1. Load Hub Quicken with data
2. Open DevTools > Network tab
3. Set throttling to "Offline"
4. Reload page
5. Verify cached static assets load (HTML/CSS/JS)
6. Verify cached JSON data appears
7. Verify "_offline: true" in error objects (if no cache)
8. Go back online
9. Verify fresh data loads

Expected: Graceful offline fallback with cached data
```

#### Scenario 8: Error Handling
```
1. Stop hub data server (or break endpoint URL)
2. Load Hub Quicken
3. Verify error toast appears
4. Verify error object shows in card: {"_error": "...", "_url": "..."}
5. Check browser console for retry logs
6. Restart hub server
7. Wait for auto-refresh or click refresh
8. Verify data loads successfully

Expected: Clear error messages, automatic retry with backoff
```

---

## Automated Testing

### Unit Tests (Recommended)

**Setup (future implementation):**
```bash
# Install test framework
npm install --save-dev vitest jsdom

# Create test file
touch web/hub-quicken/app.test.js
```

**Example Unit Tests:**
```javascript
// app.test.js
import { describe, it, expect } from 'vitest';
import { diff, normalizeForSearch, filterObj } from './app.js';

describe('diff()', () => {
  it('should detect no change for identical objects', () => {
    const a = { foo: 'bar' };
    const b = { foo: 'bar' };
    const result = diff(a, b);
    expect(result.changed).toBe(false);
  });

  it('should detect changes', () => {
    const a = { foo: 'bar' };
    const b = { foo: 'baz' };
    const result = diff(a, b);
    expect(result.changed).toBe(true);
  });
});

describe('normalizeForSearch()', () => {
  it('should lowercase JSON string', () => {
    const obj = { Name: 'Test' };
    const result = normalizeForSearch(obj);
    expect(result).toBe('{"name":"test"}');
  });
});

describe('filterObj()', () => {
  it('should filter array items by term', () => {
    const obj = {
      items: [
        { name: 'apple' },
        { name: 'banana' },
        { name: 'apricot' }
      ]
    };
    const result = filterObj(obj, 'ap');
    expect(result.items).toHaveLength(2);
    expect(result.items[0].name).toBe('apple');
  });
});
```

### Integration Tests

**E2E with Playwright (future implementation):**
```bash
# Install Playwright
npm install --save-dev @playwright/test

# Create test
touch web/hub-quicken/e2e.test.js
```

**Example E2E Test:**
```javascript
// e2e.test.js
import { test, expect } from '@playwright/test';

test.describe('Hub Quicken v2', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:8090/web/hub-quicken/');
  });

  test('should load and display data', async ({ page }) => {
    await expect(page.locator('#index-view')).not.toContainText('loading…');
    await expect(page.locator('#idx-badge')).toHaveText(/\d+ items/);
  });

  test('should search and filter', async ({ page }) => {
    await page.fill('#search', 'mcp');
    await page.waitForTimeout(400); // debounce delay
    const content = await page.locator('#registry-view').textContent();
    expect(content.toLowerCase()).toContain('mcp');
  });

  test('should toggle theme', async ({ page }) => {
    const html = page.locator('html');
    await expect(html).toHaveAttribute('data-theme', 'dark');
    await page.click('#toggle-theme');
    await expect(html).toHaveAttribute('data-theme', 'light');
  });

  test('should export data', async ({ page }) => {
    const downloadPromise = page.waitForEvent('download');
    await page.click('#export');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toMatch(/hub_export_\d+\.json/);
  });

  test('should open history modal', async ({ page }) => {
    await page.click('#history');
    await expect(page.locator('#history-modal')).toBeVisible();
  });

  test('should show AI settings', async ({ page }) => {
    await page.click('#ai-settings');
    await expect(page.locator('#ai-settings-modal')).toBeVisible();
  });

  test('keyboard shortcuts work', async ({ page }) => {
    // Ctrl+K focuses search
    await page.keyboard.press('Control+K');
    await expect(page.locator('#search')).toBeFocused();

    // Ctrl+H opens history
    await page.keyboard.press('Control+H');
    await expect(page.locator('#history-modal')).toBeVisible();
  });
});
```

---

## Performance Testing

### Lighthouse Audit
```bash
# Install Lighthouse
npm install -g lighthouse

# Run audit
lighthouse http://localhost:8090/web/hub-quicken/ \
  --output html \
  --output-path ./lighthouse-report.html

# Open report
open lighthouse-report.html
```

**Target Scores:**
- Performance: 95+
- Accessibility: 95+
- Best Practices: 90+
- SEO: 90+
- PWA: 100

### Network Performance
```bash
# Simulate slow 3G
# In Chrome DevTools:
# Network tab > Throttling > Slow 3G

# Measure:
1. Time to First Byte (TTFB): < 500ms
2. First Contentful Paint (FCP): < 1.5s
3. Largest Contentful Paint (LCP): < 2.5s
4. Time to Interactive (TTI): < 3s
5. Total Blocking Time (TBT): < 300ms
6. Cumulative Layout Shift (CLS): < 0.1
```

### Load Testing
```bash
# Test concurrent users
# Install Apache Bench
sudo apt-get install apache2-utils

# Simulate 100 requests, 10 concurrent
ab -n 100 -c 10 http://localhost:8090/web/hub-quicken/

# Expected:
# - 100% success rate
# - < 100ms average response time
# - No memory leaks
```

### JavaScript Profiling
```javascript
// In browser console
console.time('render');
await render();
console.timeEnd('render');
// Expected: < 500ms

console.time('search');
filterObj(largeDataset, 'test');
console.timeEnd('search');
// Expected: < 100ms

// Memory usage
console.memory.usedJSHeapSize / 1024 / 1024; // MB
// Expected: < 50 MB with 50 snapshots
```

---

## Accessibility Testing

### WCAG 2.1 AA Compliance

**Automated Tools:**
```bash
# Install axe-core
npm install --save-dev @axe-core/cli

# Run audit
axe http://localhost:8090/web/hub-quicken/

# Or use browser extension:
# - axe DevTools (Chrome/Firefox)
# - WAVE (Chrome/Firefox)
```

**Manual Checks:**
```
Keyboard Navigation:
- [ ] Tab through all interactive elements
- [ ] All buttons/links reachable via keyboard
- [ ] Focus indicators visible
- [ ] No keyboard traps
- [ ] Skip links available (if needed)

Screen Reader (NVDA/JAWS/VoiceOver):
- [ ] All images have alt text or aria-labels
- [ ] Form inputs have labels
- [ ] ARIA roles correct (banner, main, contentinfo)
- [ ] ARIA live regions announce updates
- [ ] Headings structure logical (h1 > h2 > h3)

Color Contrast:
- [ ] Text has 4.5:1 contrast ratio (normal text)
- [ ] Text has 3:1 contrast ratio (large text 18px+)
- [ ] UI components have 3:1 contrast
- [ ] Color not only means of conveying information

Interactive Elements:
- [ ] Buttons have clear labels
- [ ] Links have descriptive text
- [ ] Form fields have visible labels
- [ ] Error messages are clear and associated with inputs
```

### Reduced Motion
```css
/* Test with this preference enabled */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

```
Test steps:
1. Enable "Reduce motion" in OS settings
2. Reload Hub Quicken
3. Verify animations are minimal/instant
4. Check pull-to-refresh still works
5. Verify loading spinners still appear (but don't spin)
```

---

## Security Testing

### XSS Prevention
```javascript
// Test: Inject script in search
// In search box, type:
<script>alert('XSS')</script>

// Expected: No alert, text displayed as-is

// Test: Malicious JSON response
// Mock endpoint to return:
{
  "items": [
    {"name": "<img src=x onerror=alert('XSS')>"}
  ]
}

// Expected: No alert, rendered safely in JSON view
```

### CORS Testing
```bash
# Test cross-origin requests
curl -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS \
  http://localhost:8090/hub/index.json

# Verify CORS headers are restrictive
# Expected: Only allowed origins can access
```

### API Key Security
```javascript
// Test: Check if API keys are exposed

// 1. Open DevTools > Application > Local Storage
// 2. Find 02luka.hub.quicken.ai.v1
// 3. Verify API key is stored (expected behavior)
// 4. Check Network tab during AI calls
// 5. Verify API key only sent in Authorization header
// 6. Verify no API key in URL parameters

// Recommendation: Encrypt in production
```

### Content Security Policy
```html
<!-- Add to index.html -->
<meta http-equiv="Content-Security-Policy"
  content="default-src 'self';
           script-src 'self';
           style-src 'self' 'unsafe-inline';
           connect-src 'self' http://localhost:* https://api.openai.com;">

<!-- Test: Should block external scripts -->
```

### Dependency Audit
```bash
# No dependencies = No vulnerabilities!
# But check service worker cache poisoning:

# 1. Clear cache
# 2. Load malicious index.html from attacker
# 3. Verify service worker doesn't cache it
# 4. Check integrity of cached files
```

---

## Regression Testing

### Before Each Release

```bash
# 1. Run all manual tests
# 2. Check browser console for errors
# 3. Verify no memory leaks (open for 1 hour, check memory)
# 4. Test on multiple browsers (Chrome, Firefox, Safari, Edge)
# 5. Test on mobile (iOS Safari, Android Chrome)
# 6. Verify service worker updates correctly
# 7. Test offline mode
# 8. Run Lighthouse audit
# 9. Check accessibility with screen reader
# 10. Review security headers

# Expected: All green, no regressions
```

### Test Matrix

| Feature | Chrome | Firefox | Safari | Edge | Mobile |
|---------|--------|---------|--------|------|--------|
| Data load | ✓ | ✓ | ✓ | ✓ | ✓ |
| Search | ✓ | ✓ | ✓ | ✓ | ✓ |
| Theme toggle | ✓ | ✓ | ✓ | ✓ | ✓ |
| Export | ✓ | ✓ | ✓ | ✓ | ✓ |
| History | ✓ | ✓ | ✓ | ✓ | ✓ |
| AI analysis | ✓ | ✓ | ✓ | ✓ | ✓ |
| Keyboard shortcuts | ✓ | ✓ | ✓ | ✓ | N/A |
| Pull-to-refresh | N/A | N/A | N/A | N/A | ✓ |
| Service Worker | ✓ | ✓ | ✓ | ✓ | ✓ |
| PWA install | ✓ | ✓ | ✓ | ✓ | ✓ |

---

## Continuous Integration

### GitHub Actions Test Workflow

```yaml
# .github/workflows/hub-quicken-test.yml
name: Hub Quicken Tests

on:
  pull_request:
    paths:
      - 'web/hub-quicken/**'
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Assert files exist
        run: |
          test -f web/hub-quicken/index.html
          test -f web/hub-quicken/app.js
          test -f web/hub-quicken/style.css
          test -f web/hub-quicken/sw.js
          test -f web/hub-quicken/manifest.json

      - name: Validate JavaScript syntax
        run: node -c web/hub-quicken/app.js

      - name: Validate JSON files
        run: |
          # If hub JSON files exist, validate them
          for f in hub/index.json hub/mcp_registry.json hub/mcp_health.json; do
            if [ -f "$f" ]; then
              jq -e . "$f" >/dev/null || exit 1
            fi
          done

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v10
        with:
          urls: |
            http://localhost:8090/web/hub-quicken/
          budgetPath: ./lighthouse-budget.json
          temporaryPublicStorage: true
```

---

## Bug Reporting Template

```markdown
## Bug Report

**Environment:**
- Browser: [Chrome 120 / Firefox 121 / Safari 17]
- OS: [Windows 11 / macOS 14 / Ubuntu 22.04]
- Hub Quicken Version: [v2.1.0]
- Screen Size: [1920x1080]

**Steps to Reproduce:**
1. Go to http://localhost:8090/web/hub-quicken/
2. Click on 'X'
3. See error

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Screenshots:**
[If applicable]

**Console Errors:**
```
[Paste browser console errors]
```

**Additional Context:**
[Any other relevant information]
```

---

## Test Coverage Goals

### Current Coverage (manual)
- [ ] Unit tests: 0% (TODO)
- [ ] Integration tests: 0% (TODO)
- [x] Manual tests: 100%
- [x] Accessibility: 95%
- [x] Security: 90%

### Target Coverage (future)
- [ ] Unit tests: 80%
- [ ] Integration tests: 70%
- [x] Manual tests: 100%
- [x] Accessibility: 100%
- [x] Security: 95%

---

**For more information, see [README.md](README.md) and [API.md](API.md)**
