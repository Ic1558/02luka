import { test, expect } from '@playwright/test';
const BASE = process.env.BASE_URL || 'http://127.0.0.1:5173';

test('Luka UI loads and shows key widgets', async ({ page }) => {
  await page.goto(`${BASE}/luka.html`, { waitUntil: 'domcontentloaded' });
  await expect(page).toHaveTitle(/02LUKA/i);
  await expect(page.locator('#promptlib-toolbar')).toBeVisible({ timeout: 5000 });
});
