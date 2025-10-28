#!/usr/bin/env node
/**
 * MCP WebBridge - Real Implementation
 *
 * Model Context Protocol bridge for cross-AI tool access
 * Phase 4 - Hardening
 */

const http = require('http');
const fs = require('fs');

const PORT = process.env.MCP_PORT || 3003;

// Phase 3 integrations
let HealthHistory, MetricsCollector;
try {
  HealthHistory = require('./lib/health_history.cjs');
  MetricsCollector = require('./lib/metrics_collector.cjs');
} catch (err) {
  console.warn('[MCP WebBridge] Phase 3 libs not available:', err.message);
}

// Initialize observability
const healthHistory = HealthHistory ? new HealthHistory() : null;
const metrics = MetricsCollector ? new MetricsCollector() : null;

// MCP server registry (placeholder for future implementation)
const mcpServers = [];
const mcpTools = [];

// Request logging
const requestLog = [];
const MAX_LOG_SIZE = 1000;

function logRequest(req, res, duration, error = null) {
  const entry = {
    timestamp: new Date().toISOString(),
    method: req.method,
    url: req.url,
    duration,
    statusCode: res.statusCode,
    error: error ? error.message : null
  };

  requestLog.push(entry);

  if (requestLog.length > MAX_LOG_SIZE) {
    requestLog.shift();
  }

  // Write to metrics
  if (metrics) {
    metrics.record('mcp_webbridge.latency', duration, {
      type: 'timer',
      endpoint: req.url,
      method: req.method
    });
    metrics.increment('mcp_webbridge.requests', 1, {
      endpoint: req.url,
      method: req.method
    });

    if (error) {
      metrics.increment('mcp_webbridge.errors', 1, {
        endpoint: req.url,
        errorType: error.constructor.name
      });
    }
  }
}

// Prometheus metrics
function generatePrometheusMetrics() {
  const lines = [];

  lines.push('# HELP mcp_webbridge_up MCP WebBridge service status');
  lines.push('# TYPE mcp_webbridge_up gauge');
  lines.push('mcp_webbridge_up 1');

  lines.push('');
  lines.push('# HELP mcp_servers_total Total number of registered MCP servers');
  lines.push('# TYPE mcp_servers_total gauge');
  lines.push(`mcp_servers_total ${mcpServers.length}`);

  lines.push('');
  lines.push('# HELP mcp_tools_total Total number of available MCP tools');
  lines.push('# TYPE mcp_tools_total gauge');
  lines.push(`mcp_tools_total ${mcpTools.length}`);

  lines.push('');
  lines.push('# HELP http_requests_total Total HTTP requests');
  lines.push('# TYPE http_requests_total counter');
  lines.push(`http_requests_total ${requestLog.length}`);

  lines.push('');
  lines.push('# HELP http_errors_total Total HTTP errors');
  lines.push('# TYPE http_errors_total counter');
  const errors = requestLog.filter(r => r.error !== null).length;
  lines.push(`http_errors_total ${errors}`);

  return lines.join('\n');
}

// Parse request body (for POST)
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';

    req.on('data', chunk => {
      body += chunk.toString();
      // Prevent memory attacks
      if (body.length > 1e6) {
        req.connection.destroy();
        reject(new Error('Request body too large'));
      }
    });

    req.on('end', () => {
      try {
        if (body) {
          resolve(JSON.parse(body));
        } else {
          resolve(null);
        }
      } catch (err) {
        reject(new Error('Invalid JSON'));
      }
    });

    req.on('error', reject);
  });
}

// Request handler
async function handleRequest(req, res) {
  const start = Date.now();
  let error = null;

  try {
    if (req.url === '/health' && req.method === 'GET') {
      // Health check
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        service: 'mcp-webbridge',
        port: PORT,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        phase: 4,
        servers: mcpServers.length,
        tools: mcpTools.length
      }));

    } else if (req.url === '/servers' && req.method === 'GET') {
      // List MCP servers
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        servers: mcpServers,
        count: mcpServers.length,
        timestamp: new Date().toISOString()
      }));

    } else if (req.url === '/tools' && req.method === 'GET') {
      // List available tools
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        tools: mcpTools,
        count: mcpTools.length,
        timestamp: new Date().toISOString()
      }));

    } else if (req.url.startsWith('/tools/') && req.method === 'POST') {
      // Execute tool (placeholder implementation)
      const toolName = req.url.split('/')[2];
      const body = await parseBody(req);

      // Stub implementation - tool execution not yet available
      res.writeHead(501, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: false,
        error: 'Tool execution not yet implemented',
        tool: toolName,
        message: 'MCP integration pending',
        timestamp: new Date().toISOString()
      }));

    } else if (req.url === '/metrics' && req.method === 'GET') {
      // Prometheus metrics
      const metricsText = generatePrometheusMetrics();
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(metricsText);

    } else if (req.url === '/logs' && req.method === 'GET') {
      // Recent request logs
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        logs: requestLog.slice(-100), // Last 100 requests
        count: requestLog.length,
        timestamp: new Date().toISOString()
      }));

    } else {
      // 404
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        error: 'Not found',
        path: req.url,
        method: req.method,
        timestamp: new Date().toISOString()
      }));
    }

  } catch (err) {
    error = err;
    console.error('[MCP WebBridge] Error:', err);

    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: false,
      error: err.message,
      timestamp: new Date().toISOString()
    }));
  } finally {
    const duration = Date.now() - start;
    logRequest(req, res, duration, error);
  }
}

// Server startup
const server = http.createServer(handleRequest);

server.on('error', (err) => {
  console.error('[MCP WebBridge] Server error:', err);
  process.exit(1);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[MCP WebBridge] Listening on port ${PORT}`);
  console.log(`[MCP WebBridge] Phase 4 - Real Implementation`);
  console.log(`[MCP WebBridge] Endpoints: /health, /tools, /servers, /metrics`);
  console.log(`[MCP WebBridge] Note: MCP integration pending - stub mode`);

  // Record startup in health history
  if (healthHistory) {
    healthHistory.record('mcp_webbridge', {
      ok: true,
      latency: 0,
      error: null
    });
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[MCP WebBridge] SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('[MCP WebBridge] Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('[MCP WebBridge] SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('[MCP WebBridge] Server closed');
    process.exit(0);
  });
});
