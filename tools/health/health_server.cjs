#!/usr/bin/env node
/**
 * Simple Health Server for ops.theedges.work
 * Exposes basic health/metrics endpoints on port 4000
 */

const http = require('http');

// Relay key for origin validation (matches cloudflared config)
const RELAY_KEY = 'e3fc194816b2dfc1b1a74ef16bd40091a7941a9f2dbb0eba3cd8500ac514bfd1';

const server = http.createServer((req, res) => {
  // Verify origin is from cloudflared tunnel (check Host header)
  const host = req.headers.host;
  if (host !== 'ops.theedges.work' && host !== 'localhost:4000' && host !== '127.0.0.1:4000') {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized - Invalid host' }));
    return;
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

const PORT = 4000;
server.listen(PORT, '127.0.0.1', () => {
  console.log(`✅ Health server running on http://127.0.0.1:${PORT}`);
  console.log(`   /ping    - Health check`);
  console.log(`   /state   - System state`);
  console.log(`   /metrics - Prometheus metrics`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  server.close(() => process.exit(0));
});
