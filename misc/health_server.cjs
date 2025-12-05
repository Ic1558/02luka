#!/usr/bin/env node
/**
 * Simple Health Server for ops.theedges.work
 * Exposes basic health/metrics endpoints on port 4000
 */

const http = require('http');

// Relay key for origin validation (must be provided via environment)
const RELAY_KEY = process.env.RELAY_KEY;

const isLocalHost = (host) =>
  host === 'localhost:4000' || host === '127.0.0.1:4000';

const server = http.createServer((req, res) => {
  const host = req.headers.host || '';
  const relayKeyHeader = req.headers['x-relay-key'];

  // For non-local requests, require valid relay key
  if (!isLocalHost(host)) {
    if (!RELAY_KEY) {
      console.error('[health_server] RELAY_KEY is not set in environment');
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Server misconfigured: RELAY_KEY missing' }));
      return;
    }

    if (!relayKeyHeader || relayKeyHeader !== RELAY_KEY) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Unauthorized - Invalid relay key' }));
      return;
    }
  }

  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname === '/ping') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }));
  } else if (url.pathname === '/state') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      state: 'healthy',
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      timestamp: new Date().toISOString()
    }));
  } else if (url.pathname === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(`# HELP process_uptime_seconds Process uptime in seconds
# TYPE process_uptime_seconds gauge
process_uptime_seconds ${process.uptime()}

# HELP process_memory_bytes Process memory usage in bytes
# TYPE process_memory_bytes gauge
process_memory_bytes{type="rss"} ${process.memoryUsage().rss}
process_memory_bytes{type="heapTotal"} ${process.memoryUsage().heapTotal}
process_memory_bytes{type="heapUsed"} ${process.memoryUsage().heapUsed}
`);
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

const PORT = parseInt(process.env.HEALTH_PORT || process.env.PORT || '4000', 10);
const HOST = process.env.HEALTH_HOST || '127.0.0.1';
server.listen(PORT, HOST, () => {
  console.log(`✅ Health server running on http://${HOST}:${PORT}`);
  console.log(`   /ping    - Health check`);
  console.log(`   /state   - System state`);
  console.log(`   /metrics - Prometheus metrics`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  server.close(() => process.exit(0));
});
