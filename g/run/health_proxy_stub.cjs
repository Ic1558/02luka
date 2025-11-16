#!/usr/bin/env node
// Health Proxy Stub - System health monitoring
const http = require('http');
const PORT = process.env.HEALTH_PORT || 3002;

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

  // Main status endpoint
  if (url.pathname === '/status' || url.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      service: 'health-proxy-stub',
      timestamp: new Date().toISOString(),
      containers: {
        total: 20,
        healthy: 13,
        unhealthy: 0
      },
      redis: {
        status: 'connected',
        host: process.env.REDIS_HOST || 'host.docker.internal',
        port: process.env.REDIS_PORT || 6379
      }
    }));
  }

  // Detailed metrics
  if (url.pathname === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      metrics: {
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        timestamp: new Date().toISOString()
      }
    }));
  }

  // Default 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ ok: false, error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] Health Proxy stub listening on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] Monitoring system health`);
});

process.on('SIGTERM', () => {
  console.log(`[${new Date().toISOString()}] Health Proxy stub shutting down`);
  server.close(() => process.exit(0));
});
