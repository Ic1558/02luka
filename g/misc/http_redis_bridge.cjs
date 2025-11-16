const http = require('http');
const { createClient } = require('redis');
const path = require('path');
const fs = require('fs');

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const AUTH = process.env.BRIDGE_TOKEN;
const REPO = process.env.REPO_PATH || process.cwd();

if (!AUTH) {
  console.error('BRIDGE_TOKEN missing');
  process.exit(1);
}

(async () => {
  const r = createClient({ url: REDIS_URL });
  r.on('error', e => console.error('redis error', e));
  await r.connect();

  const srv = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    
    // Auth check
    if (req.headers['x-auth-token'] !== AUTH) {
      res.writeHead(401);
      return res.end('unauthorized');
    }

    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-auth-token');

    if (req.method === 'OPTIONS') {
      res.writeHead(200);
      return res.end();
    }

    // GET /ping
    if (req.method === 'GET' && url.pathname === '/ping') {
      res.writeHead(200, {'content-type': 'application/json'});
      return res.end(JSON.stringify({ok: true, ts: new Date().toISOString()}));
    }

    // GET /ops-health
    if (req.method === 'GET' && url.pathname === '/ops-health') {
      try {
        const healthFile = path.join(REPO, 'g/metrics/ops_health.json');
        if (fs.existsSync(healthFile)) {
          const data = fs.readFileSync(healthFile, 'utf8');
          res.writeHead(200, {'content-type': 'application/json'});
          return res.end(data);
        } else {
          res.writeHead(200, {'content-type': 'application/json'});
          return res.end(JSON.stringify({ok: false, error: 'no_health_data'}));
        }
      } catch (e) {
        res.writeHead(500, {'content-type': 'application/json'});
        return res.end(JSON.stringify({ok: false, error: 'health_error', detail: String(e)}));
      }
    }

    // GET /ops-verify
    if (req.method === 'GET' && url.pathname === '/ops-verify') {
      try {
        const statusFile = path.join(REPO, 'g/state/ops_verify_status.json');
        if (!fs.existsSync(statusFile)) {
          res.writeHead(200, {'content-type': 'application/json'});
          return res.end(JSON.stringify({ok: false, error: 'no_status'}));
        }
        const data = fs.readFileSync(statusFile, 'utf8');
        res.writeHead(200, {'content-type': 'application/json'});
        return res.end(data);
      } catch (e) {
        res.writeHead(500, {'content-type': 'application/json'});
        return res.end(JSON.stringify({ok: false, error: 'verify_error', detail: String(e)}));
      }
    }

    // GET /state
    if (req.method === 'GET' && url.pathname === '/state') {
      try {
        const stateFile = path.join(REPO, 'g/state/clc_export_mode.env');
        const state = fs.existsSync(stateFile) ? fs.readFileSync(stateFile, 'utf8') : '';
        res.writeHead(200, {'content-type': 'application/json'});
        return res.end(JSON.stringify({clc_export_mode: state.trim()}));
      } catch (e) {
        res.writeHead(500, {'content-type': 'application/json'});
        return res.end(JSON.stringify({ok: false, error: 'state_error', detail: String(e)}));
      }
    }

    // POST /pub
    if (req.method === 'POST' && url.pathname === '/pub') {
      try {
        let body = '';
        req.on('data', d => body += d);
        await new Promise(z => req.on('end', z));
        
        const { channel, payload } = JSON.parse(body || '{}');
        if (!channel || payload === undefined) {
          res.writeHead(400, {'content-type': 'application/json'});
          return res.end(JSON.stringify({ok: false, error: 'bad_request'}));
        }
        
        await r.publish(channel, typeof payload === 'string' ? payload : JSON.stringify(payload));
        res.writeHead(200, {'content-type': 'application/json'});
        return res.end(JSON.stringify({ok: true}));
      } catch (e) {
        console.error('bridge pub error', e);
        res.writeHead(500, {'content-type': 'application/json'});
        return res.end(JSON.stringify({ok: false, error: 'pub_error', detail: String(e)}));
      }
    }

    // 404
    res.writeHead(404, {'content-type': 'application/json'});
    res.end(JSON.stringify({ok: false, error: 'not_found'}));
  });

  const PORT = process.env.BRIDGE_PORT || 8788;
  srv.listen(PORT, () => console.log('bridge on :' + PORT));
})();
