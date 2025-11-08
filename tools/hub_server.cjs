#!/usr/bin/env node
/**
 * Hub Dashboard Server
 * Live-updating dashboard via SSE from Redis event bus
 * Phase 20 - Hub Dashboard
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { createClient } = require('redis');

const fsp = fs.promises;
const PROJECT_ROOT = path.resolve(process.env.LUKA_HOME || path.join(__dirname, '..'));
const DASHBOARD_ROOT = path.resolve(
  process.env.HUB_DASHBOARD_ROOT || path.join(PROJECT_ROOT, 'g', 'apps', 'dashboard')
);
const DASHBOARD_PREFIX = '/hub/apps';
const SOURCE_LABEL = path.relative(PROJECT_ROOT, DASHBOARD_ROOT) || DASHBOARD_ROOT;
const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.webp': 'image/webp'
};

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatSize(bytes) {
  if (!Number.isFinite(bytes)) return '';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

function formatDisplayDate(isoString) {
  if (!isoString) return '';
  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) {
    return isoString;
  }
  return date.toISOString().replace('T', ' ').replace('Z', ' UTC');
}

async function listDashboards() {
  let entries;
  try {
    entries = await fsp.readdir(DASHBOARD_ROOT, { withFileTypes: true });
  } catch (err) {
    if (err.code !== 'ENOENT') {
      console.error('[hub] Failed to read dashboard directory:', err);
    }
    return [];
  }

  const dashboards = [];

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.toLowerCase().endsWith('.html')) {
      continue;
    }

    const filePath = path.join(DASHBOARD_ROOT, entry.name);

    let title = entry.name;
    let description = '';

    try {
      const source = await fsp.readFile(filePath, 'utf8');
      const titleMatch = source.match(/<title>([^<]+)<\/title>/i);
      if (titleMatch) {
        title = titleMatch[1].trim();
      }
      const descMatch = source.match(/<meta\s+name=["']description["']\s+content=["']([^"']+)["']/i);
      if (descMatch) {
        description = descMatch[1].trim();
      }
    } catch (err) {
      console.warn(`[hub] Unable to parse metadata for ${entry.name}: ${err.message}`);
    }

    let stat;
    try {
      stat = await fsp.stat(filePath);
    } catch (err) {
      console.error('[hub] Failed to stat dashboard file:', filePath, err);
      continue;
    }

    dashboards.push({
      id: entry.name.replace(/\.html$/i, ''),
      file: entry.name,
      title,
      description,
      href: `${DASHBOARD_PREFIX}/${encodeURIComponent(entry.name)}`,
      updatedAt: stat.mtime.toISOString(),
      size: stat.size
    });
  }

  dashboards.sort((a, b) => a.title.localeCompare(b.title, undefined, { sensitivity: 'base' }));
  return dashboards;
}

function renderAutoIndex(dashboards) {
  const items = dashboards.length
    ? dashboards
        .map((dash) => {
          const details = [];
          if (dash.updatedAt) {
            details.push(`Updated ${formatDisplayDate(dash.updatedAt)}`);
          }
          if (Number.isFinite(dash.size)) {
            details.push(formatSize(dash.size));
          }
          const meta = details.length
            ? `<div class="meta">${details.map(escapeHtml).join(' · ')}</div>`
            : '';
          const desc = dash.description
            ? `<div class="desc">${escapeHtml(dash.description)}</div>`
            : '';
          return `<li><a href="${escapeHtml(dash.href || '#')}" target="_blank" rel="noopener">${escapeHtml(
            dash.title || dash.file || dash.id || 'Dashboard'
          )}</a>${desc}${meta}</li>`;
        })
        .join('\n')
    : '<li>No dashboards found.</li>';

  return `<!doctype html>
<meta charset="utf-8">
<title>02luka Hub · Ops Dashboards</title>
<style>
  body { font: 15px/1.5 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; background: #f6f8fa; color: #1f2933; }
  h1 { margin-bottom: 0.25em; font-size: 1.75rem; }
  p { margin-top: 0; color: #4a5568; }
  ul { list-style: none; padding: 0; margin: 1.5rem 0; }
  li { margin: 0 0 1rem; padding: 1rem; background: white; border: 1px solid #e2e8f0; border-radius: 12px; box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06); }
  li a { color: #0f62fe; font-weight: 600; text-decoration: none; }
  li a:hover { text-decoration: underline; }
  .meta { margin-top: 0.5rem; color: #64748b; font-size: 0.85rem; }
  .desc { margin-top: 0.35rem; color: #475569; }
</style>
<h1>Operations Dashboards</h1>
<p>Auto-discovered from <strong>${escapeHtml(SOURCE_LABEL)}</strong></p>
<ul class="dashboards">
${items}
</ul>`;
}

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
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);

    try {
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
        return;
      }

      if (url.pathname === `${DASHBOARD_PREFIX}/manifest.json`) {
        const dashboards = await listDashboards();
        res.writeHead(200, {
          'Content-Type': 'application/json; charset=utf-8',
          'Cache-Control': 'no-store',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(JSON.stringify({
          updatedAt: new Date().toISOString(),
          dashboards
        }));
        return;
      }

      if (url.pathname === DASHBOARD_PREFIX || url.pathname === `${DASHBOARD_PREFIX}/`) {
        const dashboards = await listDashboards();
        res.writeHead(200, {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(renderAutoIndex(dashboards));
        return;
      }

      if (url.pathname.startsWith(`${DASHBOARD_PREFIX}/`)) {
        let relativePath = url.pathname.slice(DASHBOARD_PREFIX.length + 1);
        try {
          relativePath = decodeURIComponent(relativePath);
        } catch {
          res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
          res.end('bad request');
          return;
        }

        if (!relativePath) {
          const dashboards = await listDashboards();
          res.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'no-store',
            'Access-Control-Allow-Origin': '*'
          });
          res.end(renderAutoIndex(dashboards));
          return;
        }

        const filePath = path.resolve(DASHBOARD_ROOT, relativePath);
        if (!filePath.startsWith(DASHBOARD_ROOT)) {
          res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
          res.end('forbidden');
          return;
        }

        try {
          const stat = await fsp.stat(filePath);
          if (stat.isDirectory()) {
            const entries = await fsp.readdir(filePath);
            const listing = entries.length
              ? entries.map((entry) => `<li>${escapeHtml(entry)}</li>`).join('\n')
              : '<li>(empty)</li>';
            res.writeHead(200, {
              'Content-Type': 'text/html; charset=utf-8',
              'Cache-Control': 'no-store',
              'Access-Control-Allow-Origin': '*'
            });
            res.end(`<!doctype html>
<meta charset="utf-8">
<title>Index of ${escapeHtml(relativePath)}</title>
<style>
  body { font: 15px/1.5 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; background: #f8fafc; color: #1f2933; }
  h1 { margin-bottom: 0.5rem; font-size: 1.5rem; }
  ul { margin: 1.5rem 0; padding-left: 1.25rem; }
</style>
<h1>Index of ${escapeHtml(relativePath)}</h1>
<ul>
${listing}
</ul>`);
            return;
          }

          const ext = path.extname(filePath).toLowerCase();
          const type = MIME_TYPES[ext] || 'application/octet-stream';
          const data = await fsp.readFile(filePath);
          res.writeHead(200, {
            'Content-Type': type,
            'Cache-Control': 'no-store',
            'Access-Control-Allow-Origin': '*'
          });
          res.end(data);
        } catch (err) {
          if (err.code === 'ENOENT') {
            res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end('not found');
          } else {
            console.error('[hub] Static asset error:', err);
            res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end('internal error');
          }
        }
        return;
      }

      if (url.pathname === '/' || url.pathname === '/hub') {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
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
  .card ul li a { color: #0366d6; text-decoration: none; font-weight: 500; }
  .card ul li a:hover { text-decoration: underline; }
  .card ul li .meta { display: block; margin-top: 4px; color: #6b7280; font-size: 12px; }
  .card ul li .desc { margin-top: 4px; color: #4b5563; font-size: 13px; }
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
  <div class="card" id="ops">
    <h3>Ops Dashboards</h3>
    <ul id="ops-list"><li>Loading dashboards...</li></ul>
  </div>
</div>
<script>
  const prMap = {}, hb = {}, ocr = [];
  const es = new EventSource('/hub/stream');
  const DASHBOARD_MANIFEST = '${DASHBOARD_PREFIX}/manifest.json';

  const el = id => document.getElementById(id);
  const htmlEscape = (value) => String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

  const formatSize = (bytes) => {
    if (typeof bytes !== 'number' || !Number.isFinite(bytes)) return '';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  };

  const formatDate = (iso) => {
    if (!iso) return 'Unknown';
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return iso;
    return date.toLocaleString();
  };

  async function refreshDashboards() {
    const target = el('ops-list');
    if (!target) return;
    try {
      const response = await fetch(DASHBOARD_MANIFEST, { cache: 'no-store' });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const payload = await response.json();
      renderOps(payload.dashboards || []);
    } catch (err) {
      console.error('Failed to load dashboards:', err);
      target.innerHTML = '<li>Unable to load dashboards.</li>';
    }
  }

  function renderOps(dashboards) {
    const target = el('ops-list');
    if (!target) return;
    if (!Array.isArray(dashboards) || dashboards.length === 0) {
      target.innerHTML = '<li>No dashboards detected.</li>';
      return;
    }
    target.innerHTML = dashboards.map((dash) => {
      const title = htmlEscape(dash.title || dash.file || dash.id || 'Dashboard');
      const href = htmlEscape(dash.href || '#');
      const desc = dash.description ? '<div class="desc">' + htmlEscape(dash.description) + '</div>' : '';
      const metaParts = [];
      if (dash.updatedAt) metaParts.push('Updated ' + formatDate(dash.updatedAt));
      if (typeof dash.size === 'number') metaParts.push(formatSize(dash.size));
      const meta = metaParts.length ? '<div class="meta">' + metaParts.map(htmlEscape).join(' · ') + '</div>' : '';
      return '<li><a href="' + href + '" target="_blank" rel="noopener">' + title + '</a>' + desc + meta + '</li>';
    }).join('');
  }

  refreshDashboards();
  setInterval(refreshDashboards, 60000);

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
</script>`);
        return;
      }

      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('not found');
    } catch (err) {
      console.error('[hub] Request handling error:', err);
      if (!res.headersSent) {
        res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      }
      res.end('internal error');
    }
  });

  server.listen(PORT, () => {
    console.log(`[hub] Dashboard server listening on http://127.0.0.1:${PORT}`);
    console.log(`[hub] Redis: ${REDIS_URL}`);
    console.log(`[hub] Channels: ${channels.join(', ')}`);
    console.log(`[hub] Ops dashboards root: ${DASHBOARD_ROOT}`);
    console.log(`[hub] Ops dashboards index: http://127.0.0.1:${PORT}${DASHBOARD_PREFIX}`);
  });

  process.on('SIGINT', async () => {
    console.log('[hub] Shutting down...');
    await r.quit();
    await Promise.all(subscribers.map(s => s.quit()));
    server.close();
    process.exit(0);
  });
})();

