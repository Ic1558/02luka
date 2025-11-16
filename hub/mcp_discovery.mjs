// @created_by: GG_Agent_02luka
// @phase: 20.1
// @file: mcp_discovery.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

// Try repository .cursor/mcp.json first (for CI)
const REPO_CURSOR_CFG = path.join(REPO_ROOT, '.cursor', 'mcp.json');
// Fallback to HOME for local development
const HOME_CURSOR_CFG = path.join(process.env.HOME || '', '.cursor', 'mcp.json');

// Use repository config if it exists, otherwise fallback to HOME
const CURSOR_CFG = fs.existsSync(REPO_CURSOR_CFG) ? REPO_CURSOR_CFG : HOME_CURSOR_CFG;
const REGISTRY_PATH = path.join(__dirname, 'mcp_registry.json');

function safeRead(p) {
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    return {};
  }
}

const cfg = safeRead(CURSOR_CFG);
const servers = Object.entries(cfg.mcpServers || {}).map(([name, data]) => ({
  name,
  command: data.command || '',
  args: data.args || [],
  env: data.env || {},
}));

const registry = {
  _meta: {
    created_by: 'GG_Agent_02luka',
    created_at: new Date().toISOString(),
    source: 'mcp_discovery.mjs',
    config_path: CURSOR_CFG,
    total: servers.length,
  },
  servers,
};

fs.writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2));
console.log(`[mcp:discovery] wrote → ${REGISTRY_PATH} (servers=${servers.length})`);
