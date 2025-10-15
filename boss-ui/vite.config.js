import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';
import { existsSync, readdirSync } from 'node:fs';

const htmlInputs = {
  workspace: resolve(__dirname, 'workspace.html'),
  luka: resolve(__dirname, 'luka.html'),
  index: resolve(__dirname, 'index.html')
};

const appsDir = resolve(__dirname, 'apps');
if (existsSync(appsDir)) {
  for (const entry of readdirSync(appsDir)) {
    if (entry.endsWith('.html')) {
      const name = entry.slice(0, -5);
      htmlInputs[name] = resolve(appsDir, entry);
    }
  }
}

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    open: '/workspace.html'
  },
  build: {
    rollupOptions: {
      input: htmlInputs
    }
  }
});
