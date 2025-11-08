#!/usr/bin/env node
/**
 * Phase 20.3 - Health API HTTP Server
 *
 * Local HTTP server exposing health endpoints:
 * - GET /api/health → unified health_link.json
 * - GET /api/health/raw → raw source files
 * - GET /healthz → liveness probe
 *
 * Security: Local-only (127.0.0.1), optional Bearer token
 * Usage: node hub/http_server.mjs
 * Env: HUB_API_TOKEN (optional), PORT (default 8787)
 */

import { createServer } from 'http';
import { readFile } from 'fs/promises';
import { existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { linkHealth } from './health_link.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = join(__dirname, '..');

// Configuration
const PORT = parseInt(process.env.PORT || '8787', 10);
const HOST = '127.0.0.1'; // Local only
const API_TOKEN = process.env.HUB_API_TOKEN;

// Paths
const PATHS = {
  healthLink: join(ROOT, 'hub/health_link.json'),
  registry: join(ROOT, 'hub/mcp_registry.json'),
  health: join(ROOT, 'hub/mcp_health.json'),
  index: join(ROOT, 'hub/index.json'),
};

/**
 * Safely read JSON file
 */
async function readJsonSafe(path) {
  try {
    if (!existsSync(path)) return null;
    const content = await readFile(path, 'utf-8');
    return JSON.parse(content);
  } catch {
    return null;
  }
}

/**
 * Check authorization header
 */
function checkAuth(req) {
  if (!API_TOKEN) return true; // No token = open access

  const auth = req.headers.authorization;
  if (!auth) return false;

  const [type, token] = auth.split(' ');
  return type === 'Bearer' && token === API_TOKEN;
}

/**
 * Send JSON response
 */
function sendJson(res, data, status = 200) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  });
  res.end(JSON.stringify(data, null, 2));
}

/**
 * Send error response
 */
function sendError(res, message, status = 500) {
  sendJson(res, { error: message }, status);
}

/**
 * Handle GET /api/health
 */
async function handleHealth(req, res) {
  try {
    // Check if health_link.json exists
    let healthLink = await readJsonSafe(PATHS.healthLink);

    // If not exists or stale, regenerate
    if (!healthLink) {
      console.log('📝 Regenerating health_link.json...');
      healthLink = await linkHealth();
    }

    sendJson(res, healthLink);
  } catch (err) {
    console.error('Error in /api/health:', err);
    sendError(res, 'Failed to generate health link', 500);
  }
}

/**
 * Handle GET /api/health/raw
 */
async function handleHealthRaw(req, res) {
  try {
    const [health, registry, index] = await Promise.all([
      readJsonSafe(PATHS.health),
      readJsonSafe(PATHS.registry),
      readJsonSafe(PATHS.index),
    ]);

    sendJson(res, {
      health,
      registry,
      index,
    });
  } catch (err) {
    console.error('Error in /api/health/raw:', err);
    sendError(res, 'Failed to read raw health data', 500);
  }
}

/**
 * Handle GET /healthz
 */
function handleHealthz(req, res) {
  sendJson(res, {
    status: 'ok',
    ts: new Date().toISOString(),
  });
}

/**
 * Main request handler
 */
async function handleRequest(req, res) {
  const { url, method } = req;

  // Handle CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    });
    res.end();
    return;
  }

  // Only GET allowed
  if (method !== 'GET') {
    sendError(res, 'Method not allowed', 405);
    return;
  }

  // Check authorization
  if (!checkAuth(req)) {
    sendError(res, 'Unauthorized', 401);
    return;
  }

  // Route requests
  console.log(`${method} ${url}`);

  if (url === '/api/health') {
    await handleHealth(req, res);
  } else if (url === '/api/health/raw') {
    await handleHealthRaw(req, res);
  } else if (url === '/healthz') {
    handleHealthz(req, res);
  } else {
    sendError(res, 'Not found', 404);
  }
}

/**
 * Start server
 */
function startServer() {
  const server = createServer(handleRequest);

  server.listen(PORT, HOST, () => {
    console.log('🚀 Phase 20.3 - Health API Server');
    console.log('==================================');
    console.log(`📡 Listening on http://${HOST}:${PORT}`);
    console.log(`🔐 Auth: ${API_TOKEN ? 'Enabled (Bearer token)' : 'Disabled'}`);
    console.log('\n📍 Endpoints:');
    console.log(`   GET /api/health     - Unified health link`);
    console.log(`   GET /api/health/raw - Raw source files`);
    console.log(`   GET /healthz        - Liveness probe`);
    console.log('\n✅ Server ready!\n');
  });

  // Graceful shutdown
  const shutdown = () => {
    console.log('\n🛑 Shutting down...');
    server.close(() => {
      console.log('✅ Server stopped');
      process.exit(0);
    });
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);

  return server;
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  startServer();
}

export { startServer };
