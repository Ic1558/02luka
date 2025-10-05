import { test, expect } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://127.0.0.1:5173';

test.describe('Luka UI', () => {
  test('loads luka.html and shows key widgets', async ({ page }) => {
    await page.goto(`${BASE}/luka.html`, { waitUntil: 'domcontentloaded' });
    await expect(page).toHaveTitle(/Luka|Boss|02LUKA/i);
    // Prompt Optimizer panel (id injected earlier)
    const optPanel = page.locator('#optimize-panel');
    await expect(optPanel).toBeVisible({ timeout: 5000 });
    // Prompt Library toolbar (id injected earlier)
    const toolbar = page.locator('#promptlib-toolbar');
    await expect(toolbar).toBeVisible({ timeout: 5000 });
  });
});
