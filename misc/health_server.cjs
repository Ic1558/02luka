#!/usr/bin/env node
/**
 * Simple Health Server for ops.theedges.work
 * Exposes basic health/metrics endpoints on port 4000
 * 
 * Security: RELAY_KEY = master switch
 * - If RELAY_KEY is set: enforce on ALL requests (no localhost bypass)
 * - If RELAY_KEY is NOT set: dev mode, allow localhost only
 * 
 * Uses socket.remoteAddress (not Host header) for localhost detection
 */

const http = require('http');

// Relay key for origin validation (must be provided via environment)
// Empty string = dev mode (localhost only)
const RELAY_KEY = process.env.RELAY_KEY || '';

/**
 * Check if request is truly from localhost.
 * Uses remoteAddress + host header, but remoteAddress is the source of truth.
 * 
 * Security: Validates exact hostname (not startsWith) to prevent spoofing
 * attacks like "localhost.attacker.com" or "127.0.0.1.evil.com"
 */
const isTrueLocalhost = (req) => {
  const remote = req.socket?.remoteAddress || '';
  const hostHeader = req.headers.host || '';

  const isLoopbackIp =
    remote === '127.0.0.1' ||
    remote === '::1' ||
    remote === '::ffff:127.0.0.1';

  // Parse hostname from header (remove port if present)
  // Example: "localhost:4000" -> "localhost"
  //          "127.0.0.1:4000" -> "127.0.0.1"
  const hostname = hostHeader.split(':')[0].toLowerCase();

  // Validate exact hostname match (not startsWith to prevent spoofing)
  const isLocalHostHeader =
    hostname === 'localhost' || hostname === '127.0.0.1';

  return isLoopbackIp && isLocalHostHeader;
};

/**
 * Validate relay key from request
 * - If RELAY_KEY is NOT set → dev mode, allow only true localhost
 * - If RELAY_KEY is set → require valid key on ALL requests (no localhost bypass)
 */
const isRelayKeyValid = (req) => {
  // DEV MODE: no RELAY_KEY → allow only localhost
  if (!RELAY_KEY) {
    return isTrueLocalhost(req);
  }

  // PROD MODE: RELAY_KEY is set → enforce on ALL requests
  const fromHeader = req.headers['x-relay-key'];

  let fromQuery = null;
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    fromQuery = url.searchParams.get('relay_key');
  } catch {
    // If URL parsing fails, treat as no key
    fromQuery = null;
  }

  return fromHeader === RELAY_KEY || fromQuery === RELAY_KEY;
};

const server = http.createServer((req, res) => {
  // RELAY_KEY = master switch — no localhost bypass if key is set
  if (!isRelayKeyValid(req)) {
    if (RELAY_KEY) {
      // PROD: RELAY_KEY is set but request doesn't have valid key → 401
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Unauthorized - Invalid relay key' }));
      return;
    } else {
      // DEV: no RELAY_KEY but request is not from localhost → 403
      console.warn('[health_server] RELAY_KEY not set, but request is not from localhost');
      res.writeHead(403, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Forbidden - RELAY_KEY required in production' }));
      return;
    }
  }

  // At this point:
  // - dev mode + true localhost, OR
  // - prod mode + valid RELAY_KEY
  // → Process request normally

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
// Bind to loopback only - cloudflared connects locally, no need for external bind
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
