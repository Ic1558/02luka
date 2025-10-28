#!/usr/bin/env node
const http = require('http');
const port = process.env.HEALTH_PORT || 3002;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    ok: true,
    service: 'health-proxy-stub',
    port: port,
    timestamp: new Date().toISOString(),
    message: 'Stub service running - replace with full implementation'
  }));
});

server.listen(port, '127.0.0.1', () => {
  console.log(`[Health Proxy Stub] Listening on port ${port}`);
});
