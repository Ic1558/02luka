#!/usr/bin/env node
const http = require('http');
const port = process.env.BOSS_PORT || 4000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    ok: true,
    service: 'boss-api-stub',
    port: port,
    timestamp: new Date().toISOString(),
    status: 'operational',
    message: 'Stub service - replace with full Boss API'
  }));
});

server.listen(port, '127.0.0.1', () => {
  console.log(`[Boss API Stub] Listening on port ${port}`);
});
