#!/usr/bin/env node
/**
 * Hub Dashboard Server
 * Live-updating dashboard via SSE from Redis event bus
 * Phase 20 - Hub Dashboard
 */

const http = require('http');
const { createClient } = require('redis');

const REDIS_URL = process.env.LUKA_REDIS_URL || 'redis://127.0.0.1:6379';
const PORT = parseInt(process.env.HUB_PORT || '8787', 10);

const channels = ['ci:events', 'ci:status', 'ocr:telemetry', 'hub:heartbeat'];
const clients = new Set();

(async () => {
  // Create Redis client for publishing (if needed)
  const r = createClient({ url: REDIS_URL });
  r.on('error', (e) => console.error('[hub] Redis error:', e));
  await r.connect();

  // Create subscribers for each channel
  const subscribers = channels.map(() => r.duplicate());
  await Promise.all(subscribers.map(s => s.connect()));

  // Subscribe to all channels
  await Promise.all(subscribers.map((s, i) => {
    return new Promise((resolve) => {
      s.subscribe(channels[i], (message) => {
        try {
          const payload = JSON.parse(message);
          const data = {
            channel: channels[i],
            payload,
            ts: new Date().toISOString()
          };
          const line = `data: ${JSON.stringify(data)}\n\n`;
          
          // Broadcast to all connected clients
          for (const res of clients) {
            try {
              res.write(line);
            } catch (err) {
              // Client disconnected, will be removed on close
            }
          }
        } catch (err) {
          console.error('[hub] Parse error:', err);
        }
      });
      resolve();
    });
  }));

  // HTTP server
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);

    // SSE endpoint
    if (url.pathname === '/hub/stream') {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*'
      });
      res.write('\n');
      clients.add(res);

      req.on('close', () => {
        clients.delete(res);
      });
    }
    // Dashboard HTML
    else if (url.pathname === '/' || url.pathname === '/hub') {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(`<!doctype html>
<meta charset="utf-8">
<title>02luka Hub</title>
<style>
  body { font: 14px/1.4 system-ui; margin: 16px; background: #f5f5f5; }
  .row { display: flex; gap: 12px; flex-wrap: wrap; }
  .card { border: 1px solid #ddd; border-radius: 8px; padding: 12px; min-width: 260px; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
  .card h3 { margin: 0 0 8px 0; font-size: 14px; font-weight: 600; }
  .badge { padding: 2px 6px; border-radius: 6px; border: 1px solid #ccc; font-size: 12px; display: inline-block; }
  .ok { background: #e7f7ec; color: #0e8a16; }
  .warn { background: #fff7e6; color: #b08800; }
  .err { background: #fdeceb; color: #d1242f; }
  ul { margin: 0; padding-left: 20px; }
  li { margin: 4px 0; }
  .status { font-weight: 500; }
</style>
<h1>02luka — Hub Dashboard</h1>
<div class="row">
  <div class="card" id="pr">
    <h3>PR Queue</h3>
    <ul id="pr-list"><li>Waiting for events...</li></ul>
  </div>
  <div class="card" id="ci">
    <h3>CI Health</h3>
    <ul id="ci-list"><li>Waiting for events...</li></ul>
  </div>
  <div class="card" id="hb">
    <h3>Agents</h3>
    <ul id="hb-list"><li>Waiting for events...</li></ul>
  </div>
  <div class="card" id="ocr">
    <h3>OCR Telemetry</h3>
    <ul id="ocr-list"><li>Waiting for events...</li></ul>
  </div>
</div>
<script>
  const prMap = {}, hb = {}, ocr = [];
  const es = new EventSource('/hub/stream');
  
  const el = id => document.getElementById(id);
  
  es.onmessage = (e) => {
    try {
      const { channel, payload, ts } = JSON.parse(e.data);
      
      if (payload.type?.startsWith('pr.')) {
        prMap[payload.pr] = { ...prMap[payload.pr], ...payload, ts };
        renderPR();
      } else if (payload.type?.startsWith('ci.')) {
        const pr = payload.pr || 'unknown';
        if (!prMap[pr]) prMap[pr] = { pr };
        prMap[pr].ci = payload;
        prMap[pr].ts = ts;
        renderCI();
      } else if (payload.type === 'watcher.heartbeat') {
        hb[payload.agent] = { ...payload, ts };
        renderHB();
      } else if (channel === 'ocr:telemetry') {
        ocr.unshift({ ...payload, ts });
        if (ocr.length > 20) ocr.pop();
        renderOCR();
      }
    } catch (err) {
      console.error('Parse error:', err);
    }
  };
  
  es.onerror = (e) => {
    console.error('SSE error:', e);
  };
  
  function renderPR() {
    const items = Object.values(prMap)
      .sort((a, b) => (a.pr || 0) - (b.pr || 0))
      .map(p => {
        const state = p.state || p.ci?.status || 'unknown';
        const cls = state === 'pass' || state === 'SUCCESS' ? 'ok' : 
                   state === 'pending' || state === 'PENDING' ? 'warn' : 'err';
        return \`<li>PR #\${p.pr || '?'} — <span class="badge \${cls}">\${state}</span></li>\`;
      });
    el('pr-list').innerHTML = items.length ? items.join('') : '<li>No PRs</li>';
  }
  
  function renderCI() {
    const items = Object.values(prMap)
      .filter(p => p.ci)
      .map(p => {
        const status = p.ci.status || 'unknown';
        const cls = status === 'pass' ? 'ok' : status === 'pending' ? 'warn' : 'err';
        return \`<li>PR #\${p.pr}: <span class="badge \${cls}">\${status}</span></li>\`;
      });
    el('ci-list').innerHTML = items.length ? items.join('') : '<li>No CI data</li>';
  }
  
  function renderHB() {
    const now = Date.now();
    const rows = Object.entries(hb).map(([k, v]) => {
      const age = v.when ? ((now - Date.parse(v.when)) / 1000) | 0 : 999;
      const cls = age < 120 ? 'ok' : age < 600 ? 'warn' : 'err';
      return \`<li><span class="badge \${cls}">\${age}s</span> \${k}</li>\`;
    });
    el('hb-list').innerHTML = rows.length ? rows.join('') : '<li>No agents</li>';
  }
  
  function renderOCR() {
    const items = ocr.map(o => {
      const icon = o.sha_ok === false ? '❌ ' : '';
      const msg = o.msg || o.path || 'unknown';
      return \`<li>\${icon}\${msg}</li>\`;
    });
    el('ocr-list').innerHTML = items.length ? items.join('') : '<li>No telemetry</li>';
  }
</script>
`);
    }
    // 404
    else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('not found');
    }
  });

  server.listen(PORT, () => {
    console.log(`[hub] Dashboard server listening on http://127.0.0.1:${PORT}`);
    console.log(`[hub] Redis: ${REDIS_URL}`);
    console.log(`[hub] Channels: ${channels.join(', ')}`);
  });

  process.on('SIGINT', async () => {
    console.log('[hub] Shutting down...');
    await r.quit();
    await Promise.all(subscribers.map(s => s.quit()));
    server.close();
    process.exit(0);
  });
})();

