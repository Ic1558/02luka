#!/usr/bin/env node
// MCP Bridge Stub - Model Context Protocol bridge
const http = require('http');
const PORT = process.env.MCP_PORT || 3003;

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
  if (url.pathname === '/health' || url.pathname === '/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      service: 'mcp-bridge-stub',
      timestamp: new Date().toISOString(),
      port: PORT
    }));
  }

  // MCP endpoints
  if (url.pathname === '/mcp/tools') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      tools: [
        { name: 'docker', available: true },
        { name: 'git', available: true },
        { name: 'filesystem', available: true }
      ]
    }));
  }

  if (url.pathname === '/mcp/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      ok: true,
      connected: true,
      servers: ['docker', 'filesystem']
    }));
  }

  // Default 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ ok: false, error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] MCP Bridge stub listening on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] MCP servers available`);
});

process.on('SIGTERM', () => {
  console.log(`[${new Date().toISOString()}] MCP Bridge stub shutting down`);
  server.close(() => process.exit(0));
});
