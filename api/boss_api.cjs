#!/usr/bin/env node
/**
 * Boss API - Real Implementation
 *
 * Boss workflow orchestration API
 * Phase 4 - Hardening
 */

const http = require('http');
const fs = require('fs');

const PORT = process.env.BOSS_PORT || 4000;
const STATE_FILE = 'g/state/boss_workflows.json';

// Phase 3 integrations
let HealthHistory, MetricsCollector;
try {
  HealthHistory = require('../run/lib/health_history.cjs');
  MetricsCollector = require('../run/lib/metrics_collector.cjs');
} catch (err) {
  console.warn('[Boss API] Phase 3 libs not available:', err.message);
}

const healthHistory = HealthHistory ? new HealthHistory() : null;
const metrics = MetricsCollector ? new MetricsCollector() : null;

// Workflow state (in-memory for now, persisted to disk)
let workflows = {};

// Load workflows from disk
function loadWorkflows() {
  try {
    if (fs.existsSync(STATE_FILE)) {
      const data = fs.readFileSync(STATE_FILE, 'utf8');
      workflows = JSON.parse(data);
      console.log(`[Boss API] Loaded ${Object.keys(workflows).length} workflows`);
    }
  } catch (err) {
    console.warn('[Boss API] Error loading workflows:', err.message);
    workflows = {};
  }
}

// Save workflows to disk
function saveWorkflows() {
  try {
    const dir = require('path').dirname(STATE_FILE);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(STATE_FILE, JSON.stringify(workflows, null, 2));
  } catch (err) {
    console.error('[Boss API] Error saving workflows:', err.message);
  }
}

// Parse request body
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
      if (body.length > 1e6) {
        req.connection.destroy();
        reject(new Error('Request too large'));
      }
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : null);
      } catch (err) {
        reject(new Error('Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

// Prometheus metrics
function generatePrometheusMetrics() {
  const lines = [];

  lines.push('# HELP boss_api_up Boss API service status');
  lines.push('# TYPE boss_api_up gauge');
  lines.push('boss_api_up 1');

  lines.push('');
  lines.push('# HELP boss_workflows_total Total workflows');
  lines.push('# TYPE boss_workflows_total gauge');
  lines.push(`boss_workflows_total ${Object.keys(workflows).length}`);

  lines.push('');
  lines.push('# HELP boss_workflows_active Active workflows');
  lines.push('# TYPE boss_workflows_active gauge');
  const active = Object.values(workflows).filter(w => w.status === 'running').length;
  lines.push(`boss_workflows_active ${active}`);

  return lines.join('\n');
}

// Request handler
async function handleRequest(req, res) {
  const start = Date.now();

  try {
    const url = new URL(req.url, `http://localhost:${PORT}`);
    const pathname = url.pathname;

    if ((pathname === '/health' || pathname === '/healthz') && req.method === 'GET') {
      // Health check
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        service: 'boss-api',
        port: PORT,
        uptime: process.uptime(),
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        phase: 4,
        workflows: Object.keys(workflows).length
      }));

    } else if (pathname === '/status' && req.method === 'GET') {
      // System status
      const activeWorkflows = Object.values(workflows).filter(w => w.status === 'running');
      const completedWorkflows = Object.values(workflows).filter(w => w.status === 'completed');

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        status: 'operational',
        workflows: {
          total: Object.keys(workflows).length,
          active: activeWorkflows.length,
          completed: completedWorkflows.length
        },
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
      }));

    } else if (pathname.startsWith('/workflow/') && pathname.endsWith('/start') && req.method === 'POST') {
      // Start workflow
      const parts = pathname.split('/');
      const workflowId = parts[2];
      const body = await parseBody(req);

      workflows[workflowId] = {
        id: workflowId,
        status: 'running',
        startedAt: new Date().toISOString(),
        params: body || {},
        steps: []
      };

      saveWorkflows();

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        ok: true,
        workflow: workflows[workflowId],
        message: 'Workflow started (stub implementation)',
        timestamp: new Date().toISOString()
      }));

    } else if (pathname.startsWith('/workflow/') && pathname.endsWith('/status') && req.method === 'GET') {
      // Get workflow status
      const parts = pathname.split('/');
      const workflowId = parts[2];

      if (workflows[workflowId]) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          ok: true,
          workflow: workflows[workflowId],
          timestamp: new Date().toISOString()
        }));
      } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          ok: false,
          error: 'Workflow not found',
          workflowId,
          timestamp: new Date().toISOString()
        }));
      }

    } else if (pathname === '/metrics' && req.method === 'GET') {
      // Prometheus metrics
      const metricsText = generatePrometheusMetrics();
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(metricsText);

    } else {
      // 404
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        error: 'Not found',
        path: pathname,
        method: req.method,
        timestamp: new Date().toISOString()
      }));
    }

    if (metrics) {
      const latency = Date.now() - start;
      metrics.record('boss_api.latency', latency, { type: 'timer', endpoint: pathname });
      metrics.increment('boss_api.requests', 1, { endpoint: pathname });
    }

  } catch (err) {
    console.error('[Boss API] Error:', err);

    if (metrics) {
      metrics.increment('boss_api.errors', 1);
    }

    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: false,
      error: err.message,
      timestamp: new Date().toISOString()
    }));
  }
}

// Server startup
const server = http.createServer(handleRequest);

server.on('error', (err) => {
  console.error('[Boss API] Server error:', err);
  process.exit(1);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[Boss API] Listening on port ${PORT}`);
  console.log(`[Boss API] Phase 4 - Real Implementation`);
  console.log(`[Boss API] Endpoints: /health, /healthz, /status, /workflow/:id/start, /metrics`);

  loadWorkflows();

  if (healthHistory) {
    healthHistory.record('boss_api', { ok: true, latency: 0, error: null });
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[Boss API] SIGTERM received, shutting down gracefully');
  saveWorkflows();
  server.close(() => {
    console.log('[Boss API] Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('[Boss API] SIGINT received, shutting down gracefully');
  saveWorkflows();
  server.close(() => {
    console.log('[Boss API] Server closed');
    process.exit(0);
  });
});
