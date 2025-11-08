#!/usr/bin/env node
/**
 * Hub HTTP Server - Phase 20.5
 * Serve static files, API endpoints, and SSE bridge
 *
 * Endpoints:
 * - GET  /                       → index.html
 * - GET  /app.js                 → app.js
 * - GET  /style.css              → style.css
 * - GET  /health                 → health check
 * - GET  /api/mcp_health         → mcp_health.json
 * - GET  /api/telemetry          → telemetry_snapshot.json
 * - GET  /api/pr/:num/checks     → proxy gh pr checks (optional)
 * - GET  /events                 → SSE endpoint
 */

import http from 'http';
import fs from 'fs/promises';
import { existsSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import yaml from 'yaml';
import { createSSEBridge } from './sse_bridge.mjs';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, '..');

/**
 * Load configuration
 */
async function loadConfig() {
  const configPath = path.join(PROJECT_ROOT, 'config/hub_dashboard.yaml');
  const configContent = await fs.readFile(configPath, 'utf8');

  // Replace env vars
  const expandedContent = configContent.replace(/\$\{([^}]+)\}/g, (match, expr) => {
    // Parse ${VAR:-default} syntax
    const [varName, defaultValue] = expr.split(':-');
    return process.env[varName] || defaultValue || '';
  });

  return yaml.parse(expandedContent);
}

/**
 * Serve static file
 */
async function serveStatic(res, filePath, contentType) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    res.writeHead(200, {
      'Content-Type': contentType,
      'Cache-Control': 'no-cache',
    });
    res.end(content);
  } catch (err) {
    console.error(`[HTTP] Failed to serve ${filePath}:`, err.message);
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
}

/**
 * Serve JSON data file
 */
async function serveJSON(res, filePath) {
  try {
    const fullPath = path.join(PROJECT_ROOT, filePath);

    if (!existsSync(fullPath)) {
      // Return empty placeholder
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      });
      res.end(JSON.stringify({ error: 'File not found', path: filePath }));
      return;
    }

    const content = await fs.readFile(fullPath, 'utf8');
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache',
    });
    res.end(content);
  } catch (err) {
    console.error(`[HTTP] Failed to serve JSON ${filePath}:`, err.message);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message }));
  }
}

/**
 * Proxy PR checks (optional, requires GH_TOKEN)
 */
async function proxyPRChecks(res, prNumber) {
  try {
    if (!process.env.GH_TOKEN) {
      throw new Error('GH_TOKEN not set');
    }

    const output = execSync(`gh pr checks ${prNumber} --json name,state,conclusion`, {
      encoding: 'utf8',
      env: { ...process.env, GH_TOKEN: process.env.GH_TOKEN },
    });

    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(output);
  } catch (err) {
    console.error(`[HTTP] Failed to proxy PR checks:`, err.message);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message }));
  }
}

/**
 * Health check endpoint
 */
function healthCheck(res) {
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'hub-dashboard',
  }));
}

/**
 * Create and start HTTP server
 */
export async function startServer(argv = []) {
  const config = await loadConfig();
  const { host, port } = config.server;

  // Check mode
  const checkMode = argv.includes('--check');

  // Initialize SSE bridge
  let sseBridge = null;
  if (!checkMode) {
    sseBridge = await createSSEBridge(config);
    console.log('[HTTP] SSE bridge initialized');
  }

  // Create HTTP server
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);

    // CORS preflight
    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      });
      res.end();
      return;
    }

    // Route requests
    if (url.pathname === '/') {
      await serveStatic(res, path.join(__dirname, 'public/index.html'), 'text/html');
    } else if (url.pathname === '/app.js') {
      await serveStatic(res, path.join(__dirname, 'public/app.js'), 'application/javascript');
    } else if (url.pathname === '/style.css') {
      await serveStatic(res, path.join(__dirname, 'public/style.css'), 'text/css');
    } else if (url.pathname === '/health' || url.pathname === config.server.health_path) {
      healthCheck(res);
    } else if (url.pathname === '/api/mcp_health') {
      await serveJSON(res, config.data.mcp_health_path);
    } else if (url.pathname === '/api/telemetry') {
      await serveJSON(res, config.data.telemetry_path);
    } else if (url.pathname.startsWith('/api/pr/') && url.pathname.endsWith('/checks')) {
      if (config.security.enable_pr_proxy) {
        const prNumber = url.pathname.split('/')[3];
        await proxyPRChecks(res, prNumber);
      } else {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'PR proxy disabled' }));
      }
    } else if (url.pathname === '/events' || url.pathname === config.server.sse?.path) {
      if (!checkMode && sseBridge) {
        sseBridge.addClient(res);
      } else {
        res.writeHead(503, { 'Content-Type': 'text/plain' });
        res.end('SSE not available in check mode');
      }
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
    }
  });

  // Start server
  server.listen(port, host, () => {
    console.log(`[HTTP] Server running at http://${host}:${port}`);
    console.log(`[HTTP] SSE endpoint: http://${host}:${port}/events`);
    console.log(`[HTTP] Health check: http://${host}:${port}/health`);

    if (checkMode) {
      console.log('[HTTP] Check mode - shutting down');
      server.close();
      process.exit(0);
    }
  });

  // Graceful shutdown
  const shutdown = async () => {
    console.log('\n[HTTP] Shutting down...');
    server.close();
    if (sseBridge) {
      await sseBridge.close();
    }
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  return { server, sseBridge };
}

// Run if main module
if (import.meta.url === `file://${process.argv[1]}`) {
  startServer(process.argv.slice(2)).catch((err) => {
    console.error('[HTTP] Fatal error:', err);
    process.exit(1);
  });
}
