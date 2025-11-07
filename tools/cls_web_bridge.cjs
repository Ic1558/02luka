#!/usr/bin/env node
/**
 * Phase 20 — CLS Web Bridge
 * HTTP API for CLS operations
 * WO-ID: WO-251107-PHASE-20-CLS-WEB
 */

const http = require('http');
const { createClient } = require('redis');
const { spawn } = require('node:child_process');
const path = require('path');
const fs = require('fs');

const REDIS_URL = process.env.LUKA_REDIS_URL || 'redis://127.0.0.1:6379';
const PORT = parseInt(process.env.CLS_WEB_PORT || '8778', 10);
const BASE = process.env.LUKA_HOME || process.env.HOME + '/02luka';

// CLS tools paths
const BRIDGE_SCRIPT = path.join(BASE, 'tools/bridge_cls_clc.zsh');
const DASHBOARD_SCRIPT = path.join(BASE, 'tools/cls_dashboard.zsh');
const METRICS_SCRIPT = path.join(BASE, 'tools/cls_collect_metrics.zsh');
const STATUS_FILE = path.join(BASE, 'memory/cls/wo_status.jsonl');
const METRICS_FILE = path.join(BASE, 'g/metrics/cls/latest.json');

function sh(cmd, args = [], options = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, {
      stdio: options.capture ? 'pipe' : 'inherit',
      ...options
    });
    let stdout = '';
    let stderr = '';
    if (options.capture) {
      p.stdout.on('data', (d) => { stdout += d.toString(); });
      p.stderr.on('data', (d) => { stderr += d.toString(); });
    }
    p.on('close', (code) => {
      if (code === 0) {
        resolve({ stdout, stderr, code });
      } else {
        reject(new Error(`Command failed: ${cmd} exit ${code}\n${stderr}`));
      }
    });
  });
}

async function readJSONL(file) {
  if (!fs.existsSync(file)) return [];
  const lines = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean);
  return lines.map(l => {
    try { return JSON.parse(l); } catch { return null; }
  }).filter(Boolean);
}

(async () => {
  const redis = createClient({ url: REDIS_URL });
  redis.on('error', (e) => console.error('[cls-web] Redis error:', e));
  await redis.connect();

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
      res.writeHead(200);
      return res.end();
    }

    try {
      // GET /health
      if (req.method === 'GET' && url.pathname === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
          status: 'healthy',
          service: 'cls_web_bridge',
          version: '1.0.0',
          timestamp: new Date().toISOString()
        }));
      }

      // GET /status
      if (req.method === 'GET' && url.pathname === '/status') {
        const status = await readJSONL(STATUS_FILE);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
          status: 'ok',
          count: status.length,
          entries: status.slice(-20) // Last 20 entries
        }));
      }

      // GET /metrics
      if (req.method === 'GET' && url.pathname === '/metrics') {
        let metrics = {};
        if (fs.existsSync(METRICS_FILE)) {
          try {
            metrics = JSON.parse(fs.readFileSync(METRICS_FILE, 'utf8'));
          } catch (e) {
            console.error('[cls-web] Metrics parse error:', e);
          }
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
          status: 'ok',
          metrics
        }));
      }

      // GET /dashboard
      if (req.method === 'GET' && url.pathname === '/dashboard') {
        try {
          const result = await sh('zsh', [DASHBOARD_SCRIPT], { capture: true });
          res.writeHead(200, { 'Content-Type': 'text/plain' });
          return res.end(result.stdout);
        } catch (e) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: e.message }));
        }
      }

      // POST /wo (Work Order)
      if (req.method === 'POST' && url.pathname === '/wo') {
        let body = '';
        req.on('data', d => { body += d.toString(); });
        await new Promise(resolve => req.on('end', resolve));
        
        const payload = JSON.parse(body || '{}');
        const { title, priority, tags, body: woBody } = payload;
        
        if (!title) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'title required' }));
        }

        // Create temporary YAML file for body
        const tmpFile = path.join(BASE, '.tmp', `wo_${Date.now()}.yaml`);
        fs.mkdirSync(path.dirname(tmpFile), { recursive: true });
        fs.writeFileSync(tmpFile, woBody || `task: ${title}\n`);

        try {
          const args = ['--title', title];
          if (priority) args.push('--priority', priority);
          if (tags) args.push('--tags', tags);
          args.push('--body', tmpFile);
          if (payload.wait) args.push('--wait');

          const result = await sh('zsh', [BRIDGE_SCRIPT, ...args], { capture: true });
          
          // Cleanup
          fs.unlinkSync(tmpFile);
          
          res.writeHead(200, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({
            status: 'ok',
            message: 'Work Order submitted',
            output: result.stdout
          }));
        } catch (e) {
          if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
          res.writeHead(500, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: e.message }));
        }
      }

      // POST /pub (Publish to Redis)
      if (req.method === 'POST' && url.pathname === '/pub') {
        let body = '';
        req.on('data', d => { body += d.toString(); });
        await new Promise(resolve => req.on('end', resolve));
        
        const { channel, payload: payloadData } = JSON.parse(body || '{}');
        if (!channel || !payloadData) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'channel and payload required' }));
        }

        await redis.publish(channel, typeof payloadData === 'string' 
          ? payloadData 
          : JSON.stringify(payloadData));
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ status: 'ok', channel }));
      }

      // 404
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'not_found' }));
    } catch (e) {
      console.error('[cls-web] Request error:', e);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
  });

  server.listen(PORT, () => {
    console.log(`[cls-web-bridge] listening on http://127.0.0.1:${PORT}`);
    console.log(`[cls-web-bridge] Redis: ${REDIS_URL}`);
  });

  process.on('SIGINT', async () => {
    console.log('[cls-web-bridge] shutting down...');
    await redis.quit();
    server.close();
    process.exit(0);
  });
})();
