#!/usr/bin/env node
// Boss API Server - Enhanced with error handling and port conflict handling
// Fallback to stub if full server not available

const http = require('http');
const fs = require('fs');
const path = require('path');
const net = require('net');

// Environment defaults
const PORT = parseInt(process.env.PORT || process.env.BOSS_PORT || '4000', 10);
let CURRENT_PORT = PORT; // Track actual port in use (may change if PORT is in use)
const REDIS_HOST = process.env.REDIS_HOST || '127.0.0.1';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);
const REDIS_PASSWORD = process.env.REDIS_PASSWORD || '';
const NODE_ENV = process.env.NODE_ENV || 'test';
const ROOT = path.resolve(__dirname, '..');
const MODELS_FILE = path.join(ROOT, 'config', 'ui_models.json');

// Global error handlers
process.on('unhandledRejection', (reason, promise) => {
  console.error('[boss-api] Unhandled Rejection:', reason);
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('[boss-api] Uncaught Exception:', error);
  process.exit(1);
});

// Port conflict handling
function findAvailablePort(startPort, maxAttempts = 10) {
  return new Promise((resolve, reject) => {
    let attempts = 0;
    
    function tryPort(port) {
      if (attempts >= maxAttempts) {
        return reject(new Error(`Could not find available port after ${maxAttempts} attempts`));
      }
      
      const server = net.createServer();
      server.listen(port, () => {
        server.once('close', () => resolve(port));
        server.close();
      });
      
      server.on('error', (err) => {
        if (err.code === 'EADDRINUSE') {
          attempts++;
          tryPort(port + 1);
        } else {
          reject(err);
        }
      });
    }
    
    tryPort(startPort);
  });
}

function loadModels() {
  try {
    if (fs.existsSync(MODELS_FILE)) {
      const raw = fs.readFileSync(MODELS_FILE, 'utf8');
      return JSON.parse(raw);
    }
    return [];
  } catch (error) {
    console.warn(`[boss-api] unable to load models: ${error.message}`);
    return [];
  }
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${CURRENT_PORT}`);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  // Health check endpoints (support both /healthz and /health)
  if (url.pathname === '/healthz' || url.pathname === '/health' || url.pathname === '/api/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      service: 'boss-api',
      timestamp: new Date().toISOString(),
      port: CURRENT_PORT,
      env: NODE_ENV
    }));
  }

  // Status endpoint
  if (url.pathname === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      status: 'running',
      services: {
        boss_api: 'running',
        redis: `${REDIS_HOST}:${REDIS_PORT}`
      }
    }));
  }

  // Capabilities endpoint
  if (url.pathname === '/api/capabilities') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      capabilities: ['health', 'status'],
      version: '1.0.0'
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

// Start server with port conflict handling
async function startServer() {
  try {
    const actualPort = await findAvailablePort(PORT);
    CURRENT_PORT = actualPort;
    
    server.listen(actualPort, () => {
      console.log(`[${new Date().toISOString()}] Boss API listening on port ${actualPort}`);
      console.log(`[${new Date().toISOString()}] Environment: ${NODE_ENV}`);
      console.log(`[${new Date().toISOString()}] Redis: ${REDIS_HOST}:${REDIS_PORT}`);
      
      if (actualPort !== PORT) {
        console.warn(`[boss-api] Port ${PORT} was in use, using ${actualPort} instead`);
      }
    });

    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.error(`[boss-api] Port ${actualPort} is already in use`);
        process.exit(1);
      } else {
        console.error('[boss-api] Server error:', err);
        process.exit(1);
      }
    });
  } catch (error) {
    console.error('[boss-api] Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log(`[${new Date().toISOString()}] Boss API shutting down`);
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log(`[${new Date().toISOString()}] Boss API shutting down`);
  server.close(() => process.exit(0));
});

// Start server
startServer();
