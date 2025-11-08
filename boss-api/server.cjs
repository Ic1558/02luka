#!/usr/bin/env node
// Boss API Server - Minimal stub for CI smoke tests
const http = require('http');
const PORT = process.env.PORT || 4000;

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  // Health check endpoints
  if (req.url === '/health' || req.url === '/healthz' || req.url === '/api/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      service: 'boss-api',
      timestamp: new Date().toISOString(),
      port: PORT
    }));
  }

  // Default 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ ok: false, error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] Boss API listening on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log(`[${new Date().toISOString()}] Boss API shutting down`);
  server.close(() => process.exit(0));
});
