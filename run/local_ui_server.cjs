#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = process.env.PORT || 5173;
const HOST = process.env.HOST || '0.0.0.0';
const ROOT = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT, 'public');
const MODELS_FILE = path.join(ROOT, 'config', 'ui_models.json');
const FUNCTIONS_FILE = path.join(ROOT, 'config', 'ui_functions.json');
const AGENT_ROUTER = path.join(ROOT, 'agent_router.py');
const STUB_URL = process.env.BOSS_STUB_URL || process.env.BOSS_API_URL || 'http://localhost:4000/api/status';

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

function readJSON(filePath, fallback) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(content);
  } catch (error) {
    console.warn(`[ui-server] Unable to read ${path.basename(filePath)}: ${error.message}`);
    return fallback;
  }
}

function serveStatic(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  let pathname = url.pathname;
  if (pathname === '/') {
    pathname = '/index.html';
  }
  const normalised = path.normalize(pathname).replace(/^([\\/])*|((\.\.\/)+)/g, '');
  const filePath = path.resolve(path.join(PUBLIC_DIR, normalised));

  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': MIME_TYPES[ext] || 'application/octet-stream' });
    fs.createReadStream(filePath).pipe(res);
  });
}

function sendJSON(res, statusCode, payload) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(payload));
}

function collectRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      try {
        const body = Buffer.concat(chunks).toString('utf8');
        resolve(body ? JSON.parse(body) : {});
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function queryStubStatus() {
  return new Promise((resolve) => {
    const url = new URL(STUB_URL);
    const request = http.request({
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: 'GET',
    }, (response) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => {
        try {
          const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
          resolve({ ok: true, payload });
        } catch (error) {
          resolve({ ok: false, error: error.message });
        }
      });
    });

    request.on('error', (error) => resolve({ ok: false, error: error.message }));
    request.setTimeout(1500, () => {
      request.destroy();
      resolve({ ok: false, error: 'timeout' });
    });
    request.end();
  });
}

function runAgentRouter(payload) {
  return new Promise((resolve, reject) => {
    const child = spawn('python3', [AGENT_ROUTER], {
      cwd: ROOT,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('error', (error) => {
      reject(error);
    });

    child.on('close', (code) => {
      if (!stdout) {
        reject(new Error(stderr || 'No response from agent router'));
        return;
      }
      try {
        const result = JSON.parse(stdout);
        if (code !== 0 && result.ok !== true) {
          const error = new Error(result.error || `Agent router exited with code ${code}`);
          error.payload = result;
          reject(error);
          return;
        }
        resolve(result);
      } catch (error) {
        const wrapped = new Error(`Unable to parse agent router output: ${error.message}`);
        wrapped.stdout = stdout;
        wrapped.stderr = stderr;
        reject(wrapped);
      }
    });

    child.stdin.end(JSON.stringify(payload));
  });
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') {
      res.writeHead(200, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      });
      res.end();
      return;
    }

    if (req.url.startsWith('/api/')) {
      res.setHeader('Access-Control-Allow-Origin', '*');
    }

    const url = new URL(req.url, `http://${req.headers.host}`);

    if (req.method === 'GET' && url.pathname === '/api/models') {
      const models = readJSON(MODELS_FILE, []);
      sendJSON(res, 200, models);
      return;
    }

    if (req.method === 'GET' && url.pathname === '/api/functions') {
      const functions = readJSON(FUNCTIONS_FILE, []);
      sendJSON(res, 200, functions);
      return;
    }

    if (req.method === 'GET' && url.pathname === '/api/status') {
      const status = await queryStubStatus();
      sendJSON(res, 200, { ok: status.ok, details: status.payload || status.error });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/execute') {
      const body = await collectRequestBody(req);
      const { model, intent, prompt, params } = body;

      if (!intent) {
        sendJSON(res, 400, { ok: false, error: 'Intent is required' });
        return;
      }

      const payload = {
        intent,
        params: {
          ...(params && typeof params === 'object' ? params : {}),
        }
      };

      if (model) {
        payload.params.model = model;
      }

      if (prompt) {
        payload.params.prompt = prompt;
      }

      try {
        const result = await runAgentRouter(payload);
        sendJSON(res, 200, result);
      } catch (error) {
        console.error('[ui-server] execute failed:', error);
        sendJSON(res, 500, { ok: false, error: error.message, details: error.payload || null });
      }
      return;
    }

    serveStatic(req, res);
  } catch (error) {
    console.error('[ui-server] unexpected error:', error);
    sendJSON(res, 500, { ok: false, error: 'Internal server error' });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[ui-server] listening on http://${HOST}:${PORT}`);
  console.log(`[ui-server] public dir: ${PUBLIC_DIR}`);
  console.log(`[ui-server] agent router: ${AGENT_ROUTER}`);
});

process.on('SIGINT', () => {
  console.log('\n[ui-server] shutting down');
  server.close(() => process.exit(0));
});
