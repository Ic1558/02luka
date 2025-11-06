#!/usr/bin/env node
// Boss API Stub - Minimal development server
const http = require('http');
const fs = require('fs');
const path = require('path');
const PORT = process.env.BOSS_PORT || 4000;
const ROOT = path.resolve(__dirname, '..');
const MODELS_FILE = path.join(ROOT, 'config', 'ui_models.json');

function loadModels() {
  try {
    const raw = fs.readFileSync(MODELS_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    console.warn(`[boss-api-stub] unable to load models: ${error.message}`);
    return [];
  }
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  // Health check
  if (url.pathname === '/health' || url.pathname === '/api/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      service: 'boss-api-stub',
      timestamp: new Date().toISOString(),
      port: PORT
    }));
  }

  // Status endpoint
  if (url.pathname === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      status: 'running',
      services: {
        boss_api: 'stub',
        redis: process.env.REDIS_HOST || 'not configured'
      }
    }));
  }

  // Capabilities endpoint
  if (url.pathname === '/api/capabilities') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      capabilities: ['health', 'status'],
      version: 'stub-1.0.0'
    }));
  }

  if (url.pathname === '/api/models') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      models: loadModels(),
      source: 'local-config'
    }));
  }

  // Default 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ ok: false, error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] Boss API stub listening on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`[${new Date().toISOString()}] Redis: ${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`);
});

process.on('SIGTERM', () => {
  console.log(`[${new Date().toISOString()}] Boss API stub shutting down`);
  server.close(() => process.exit(0));
});
