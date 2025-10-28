#!/usr/bin/env node
/**
 * Boss API - Real Implementation
 *
 * Boss workflow orchestration API
 * Phase 4 - Hardening
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

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

// Phase 9 Security: Relay key for Cloudflare Tunnel → Origin authentication
// Protects /api/ops/* endpoints from direct access
// Rotate every 90 days (last rotated: 2025-10-29)
const OPS_RELAY_KEY = process.env.OPS_RELAY_KEY || 'e3fc194816b2dfc1b1a74ef16bd40091a7941a9f2dbb0eba3cd8500ac514bfd1';

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

    // Phase 9 Security: Verify relay key for /api/ops/* endpoints (optional)
    // Primary security: Cloudflare Access (configure at https://one.dash.cloudflare.com)
    // Relay key provides defense-in-depth when Access is enabled
    if (pathname.startsWith('/api/ops/')) {
      const relayKey = req.headers['x-relay-key'];
      const cfAccessAuth = req.headers['cf-access-authenticated-user-email'];

      // Log access attempts for monitoring
      if (!relayKey && !cfAccessAuth) {
        console.warn(`[Boss API] Ops access without auth from ${req.socket.remoteAddress} - Consider enabling Cloudflare Access`);
      }

      // Block only if relay key is present but wrong (prevents misconfiguration)
      if (relayKey && relayKey !== OPS_RELAY_KEY) {
        console.error(`[Boss API] Invalid relay key from ${req.socket.remoteAddress}`);
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          error: 'Forbidden',
          message: 'Invalid X-Relay-Key header',
          timestamp: new Date().toISOString()
        }));
        return;
      }
    }

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

    } else if (pathname === '/api/ops/latest' && req.method === 'GET') {
      // Phase 9: Live Ops - Latest ops data
      const path = require('path');
      const opsRuntime = process.env.OPS_RUNTIME || path.join(process.env.HOME, 'Library', '02luka_runtime', 'ops');
      const opsFile = path.join(opsRuntime, 'ops_summary_parsed.json');

      try {
        if (!fs.existsSync(opsFile)) {
          res.writeHead(404, { 'Content-Type': 'application/json', 'Cache-Control': 'no-cache, no-store, must-revalidate' });
          res.end(JSON.stringify({
            ok: false,
            error: 'ops_summary_parsed.json not found',
            path: opsFile,
            timestamp: new Date().toISOString()
          }));
          return;
        }

        const data = fs.readFileSync(opsFile, 'utf8');
        const json = JSON.parse(data);

        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
          'Expires': '0',
          'X-Content-Type-Options': 'nosniff'
        });
        res.end(JSON.stringify(json, null, 2));
      } catch (err) {
        console.error('[Boss API] Error reading ops data:', err);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          ok: false,
          error: err.message,
          timestamp: new Date().toISOString()
        }));
      }

    } else if (pathname === '/api/ops/dashboard' && req.method === 'GET') {
      // Phase 9: Live Ops - Dashboard UI
      const path = require('path');
      const opsRuntime = process.env.OPS_RUNTIME || path.join(process.env.HOME, 'Library', '02luka_runtime', 'ops');
      const dashboardFile = path.join(opsRuntime, 'live_dashboard.html');

      try {
        if (!fs.existsSync(dashboardFile)) {
          res.writeHead(404, { 'Content-Type': 'text/plain' });
          res.end('Dashboard HTML not found at: ' + dashboardFile);
          return;
        }

        const html = fs.readFileSync(dashboardFile, 'utf8');
        res.writeHead(200, {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'public, max-age=60, must-revalidate',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'SAMEORIGIN'
        });
        res.end(html);
      } catch (err) {
        console.error('[Boss API] Error serving dashboard:', err);
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Dashboard error: ' + err.message);
      }


    } else if (pathname === '/api/ops/metrics.json' && req.method === 'GET') {
      // Phase 7.2: Live metrics endpoint
      const metricsFile = path.join(process.env.HOME, 'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/state/metrics_history.jsonl');

      try {
        let sample = null;
        if (fs.existsSync(metricsFile)) {
          const data = fs.readFileSync(metricsFile, 'utf8').trim();
          if (data) {
            const lastLine = data.split('\n').filter(Boolean).pop();
            sample = JSON.parse(lastLine);
          }
        }

        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0'
        });
        res.end(JSON.stringify({
          ok: !!sample,
          timestamp: new Date().toISOString(),
          sample: sample || { note: 'no metrics available yet', timestamp: new Date().toISOString() }
        }, null, 2));
      } catch (err) {
        console.error('[Boss API] Error serving metrics:', err);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          ok: false,
          error: err.message,
          timestamp: new Date().toISOString()
        }));
      }

    } else if (pathname === '/api/ops/ocr/approve' && req.method === 'POST') {
      // Phase 1.3: OCR Approval Endpoint
      // Human-in-the-loop approval for risky OCR text (WO-CLS-0005)
      try {
        const body = await parseBody(req);
        const { image_id, image_url, ocr_text_raw, risk, matches, proposed_action, approve_phrase } = body || {};

        // Basic validation
        if (!ocr_text_raw || typeof risk !== 'number' || !proposed_action) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            ok: false,
            error: 'bad_request',
            message: 'Missing required fields: ocr_text_raw, risk, proposed_action',
            timestamp: new Date().toISOString()
          }));
          return;
        }

        // Risk-based policy enforcement
        const mustReject = risk >= 0.8;
        const needsHuman = risk >= 0.6;

        // Auto-reject high-risk actions
        if (mustReject) {
          const telemetryDir = path.join(process.env.HOME, 'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/telemetry');
          fs.mkdirSync(telemetryDir, { recursive: true });
          const logEntry = JSON.stringify({
            ts: new Date().toISOString(),
            type: 'reject',
            risk,
            matches: matches || [],
            image_id: image_id || 'unknown',
            proposed_action
          }) + '\n';
          fs.appendFileSync(path.join(telemetryDir, 'secure_ocr.ndjson'), logEntry);

          res.writeHead(403, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            ok: false,
            error: 'high_risk_rejected',
            message: 'Risk score too high for approval',
            risk,
            timestamp: new Date().toISOString()
          }));
          return;
        }

        // Require explicit approval phrase for medium-risk actions
        if (needsHuman && approve_phrase !== 'CONFIRM SEND' && approve_phrase !== 'CONFIRM ACTION') {
          const telemetryDir = path.join(process.env.HOME, 'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/telemetry');
          fs.mkdirSync(telemetryDir, { recursive: true });
          const logEntry = JSON.stringify({
            ts: new Date().toISOString(),
            type: 'hold',
            risk,
            matches: matches || [],
            image_id: image_id || 'unknown',
            proposed_action
          }) + '\n';
          fs.appendFileSync(path.join(telemetryDir, 'secure_ocr.ndjson'), logEntry);

          res.writeHead(412, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            ok: false,
            error: 'approval_required',
            message: 'Please type exact phrase to confirm',
            approve_phrases: ['CONFIRM SEND', 'CONFIRM ACTION'],
            risk,
            timestamp: new Date().toISOString()
          }));
          return;
        }

        // Approval granted - log and queue for CLS
        const hash = crypto.createHash('sha256').update(String(ocr_text_raw)).digest('hex');
        const telemetryDir = path.join(process.env.HOME, 'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/telemetry');
        fs.mkdirSync(telemetryDir, { recursive: true });
        const logEntry = JSON.stringify({
          ts: new Date().toISOString(),
          type: 'approve',
          risk,
          matches: matches || [],
          image_id: image_id || 'unknown',
          image_url: image_url || null,
          action: proposed_action,
          ocr_sha256: hash
        }) + '\n';
        fs.appendFileSync(path.join(telemetryDir, 'secure_ocr.ndjson'), logEntry);

        // Drop approved task into CLS inbox for processing
        const inbox = path.join(process.env.HOME, 'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/bridge/inbox/CLC');
        fs.mkdirSync(inbox, { recursive: true });
        const taskPath = path.join(inbox, `OCR_APPROVED_${Date.now()}.json`);
        fs.writeFileSync(taskPath, JSON.stringify({
          kind: 'ocr/approved',
          risk,
          matches: matches || [],
          image_id: image_id || 'unknown',
          image_url: image_url || null,
          action: proposed_action,
          ocr_sha256: hash,
          timestamp: new Date().toISOString()
        }, null, 2));

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          ok: true,
          queued: path.basename(taskPath),
          message: 'OCR action approved and queued',
          risk,
          timestamp: new Date().toISOString()
        }));

      } catch (err) {
        console.error('[Boss API] OCR approval error:', err);
        const telemetryDir = path.join(process.env.HOME, 'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/telemetry');
        try {
          fs.mkdirSync(telemetryDir, { recursive: true });
          const logEntry = JSON.stringify({
            ts: new Date().toISOString(),
            type: 'error',
            msg: err?.message,
            stack: err?.stack
          }) + '\n';
          fs.appendFileSync(path.join(telemetryDir, 'secure_ocr.ndjson'), logEntry);
        } catch {}

        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          ok: false,
          error: 'server_error',
          message: err.message,
          timestamp: new Date().toISOString()
        }));
      }

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
  console.log(`[Boss API] Phase 4 - Real Implementation + Phase 9 Live Ops`);
  console.log(`[Boss API] Endpoints: /health, /healthz, /status, /workflow/:id/start, /metrics`);
  console.log(`[Boss API] Phase 9: /api/ops/latest, /api/ops/dashboard`);

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
