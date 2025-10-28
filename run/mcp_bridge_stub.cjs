#!/usr/bin/env node
const http = require('http');
const port = process.env.MCP_PORT || 3003;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    ok: true,
    service: 'mcp-bridge-stub',
    port: port,
    timestamp: new Date().toISOString(),
    tools: [],
    servers: [],
    message: 'Stub service - MCP integration not implemented'
  }));
});

server.listen(port, '127.0.0.1', () => {
  console.log(`[MCP Bridge Stub] Listening on port ${port}`);
});
