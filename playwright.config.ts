import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  reporter: 'line',
  timeout: 15000,
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:5173',
    headless: true,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
