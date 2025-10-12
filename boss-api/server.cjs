const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

const app = express();
const PORT = process.env.PORT || 4000;

const fetchPaula = (...args) => {
  if (typeof globalThis.fetch === 'function') {
    return globalThis.fetch(...args);
  }
  return import('node-fetch').then(({ default: fetch }) => fetch(...args));
};

// Environment configuration
const AI_GATEWAY_URL = process.env.AI_GATEWAY_URL || '';
const AI_GATEWAY_KEY = process.env.AI_GATEWAY_KEY || '';
const AI_GATEWAY_BASE = AI_GATEWAY_URL.replace(/\/+$/, '');
const AGENTS_GATEWAY_URL = process.env.AGENTS_GATEWAY_URL || '';
const AGENTS_GATEWAY_KEY = process.env.AGENTS_GATEWAY_KEY || '';
const PUBLIC_API_BASE = process.env.PUBLIC_API_BASE || '';
const PUBLIC_AI_BASE = process.env.PUBLIC_AI_BASE || '';
const PAULA_BASE = (process.env.PAULA_BASE || 'http://127.0.0.1:5000').replace(/\/+$/, '');
const PAULA_TIMEOUT_MS = 30_000;
const PAULA_MAX_BODY_BYTES = 5 * 1024 * 1024;

const repoRoot = path.resolve(__dirname, '..'); // 02luka-repo root
const bossRoot = path.join(repoRoot, 'boss');

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 60000; // 1 minute
const RATE_LIMIT_MAX = 100; // requests per window

function rateLimit(req, res, next) {
  const key = req.ip || 'unknown';
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW;
  
  if (!rateLimitMap.has(key)) {
    rateLimitMap.set(key, []);
  }
  
  const requests = rateLimitMap.get(key);
  const validRequests = requests.filter(time => time > windowStart);
  
  if (validRequests.length >= RATE_LIMIT_MAX) {
    return res.status(429).json({ error: 'Rate limit exceeded' });
  }
  
  validRequests.push(now);
  rateLimitMap.set(key, validRequests);
  next();
}

app.use(rateLimit);

// AI Gateway integration
const aiRateLimitBuckets = new Map();
const MAX_AI_PAYLOAD_BYTES = 512 * 1024;

function writeJson(res, code, payload) {
  res.status(code).json(payload);
}

async function proxyPaulaRequest(req, res, targetPath, options = {}) {
  if (!PAULA_BASE) {
    return writeJson(res, 503, { error: 'PAULA_BASE is not configured' });
  }

  const method = options.method || req.method;
  const url = `${PAULA_BASE}${targetPath}`;

  let body;
  if (!['GET', 'HEAD'].includes(method)) {
    const serialized = req.body !== undefined ? JSON.stringify(req.body) : undefined;
    if (serialized) {
      const payloadSize = Buffer.byteLength(serialized, 'utf8');
      if (payloadSize > PAULA_MAX_BODY_BYTES) {
        return writeJson(res, 413, { error: 'Request payload too large' });
      }
      body = serialized;
    }
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PAULA_TIMEOUT_MS);

  try {
    const response = await fetchPaula(url, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...options.headers
      },
      body,
      signal: controller.signal
    });

    clearTimeout(timeout);

    const contentType = response.headers.get('content-type') || '';
    const responseBuffer = await response.arrayBuffer();
    if (responseBuffer.byteLength > PAULA_MAX_BODY_BYTES) {
      return writeJson(res, 502, { error: 'Upstream response too large' });
    }

    if (contentType.includes('application/json')) {
      const text = Buffer.from(responseBuffer).toString('utf8');
      try {
        const json = JSON.parse(text || '{}');
        return writeJson(res, response.status, json);
      } catch (parseError) {
        return writeJson(res, 502, { error: 'Invalid JSON from Paula service' });
      }
    }

    res.status(response.status);
    res.set('content-type', contentType || 'text/plain');
    return res.send(Buffer.from(responseBuffer));
  } catch (error) {
    clearTimeout(timeout);
    if (error.name === 'AbortError') {
      return writeJson(res, 504, { error: 'Paula service request timed out' });
    }
    return writeJson(res, 502, { error: error.message || 'Paula service request failed' });
  }
}

// Health check endpoint
app.get('/healthz', (req, res) => {
  writeJson(res, 200, { status: 'ok', timestamp: new Date().toISOString() });
});

// API capabilities endpoint
app.get('/api/capabilities', async (req, res) => {
  try {
    const capabilities = {
      ui: {
        inbox: true,
        preview: true,
        prompt_composer: true,
        connectors: true
      },
      mailboxes: {
        flow: ['inbox', 'outbox', 'drafts', 'sent', 'deliverables'],
        list: [
          { id: 'inbox', label: 'Inbox', role: 'incoming', uploads: true, goalTarget: false },
          { id: 'outbox', label: 'Outbox', role: 'staging', uploads: true, goalTarget: true },
          { id: 'drafts', label: 'Drafts', role: 'revision', uploads: true, goalTarget: true },
          { id: 'sent', label: 'Sent', role: 'dispatch', uploads: false, goalTarget: false },
          { id: 'deliverables', label: 'Deliverables', role: 'final', uploads: false, goalTarget: false }
        ],
        aliases: [{ alias: 'dropbox', target: 'outbox' }]
      },
      features: {
        goal: true,
        optimize_prompt: true,
        chat: false,
        rag: true,
        sql: true,
        ocr: true,
        nlu: false
      },
      engines: {
        chat: { ready: false, error: 'connect ECONNREFUSED 127.0.0.1:11434' },
        rag: { ready: true, documents: 0, dbPath: '/workspaces/02luka-repo/boss-api/data/rag.sqlite3' },
        sql: { ready: true, datasets: [{ id: 'sample', label: 'Sample Workplace Dataset', path: '/workspaces/02luka-repo/boss-api/data/sample.sqlite3', tables: 3 }] },
        ocr: { ready: true, script: '/workspaces/02luka-repo/g/tools/ocr_typhoon.py' }
      },
      connectors: {
        anthropic: { ready: false },
        openai: { ready: false },
        local: {
          chat: { ready: false, error: 'connect ECONNREFUSED 127.0.0.1:11434' },
          rag: { ready: true, documents: 0, dbPath: '/workspaces/02luka-repo/boss-api/data/rag.sqlite3' },
          sql: { ready: true, datasets: [{ id: 'sample', label: 'Sample Workplace Dataset', path: '/workspaces/02luka-repo/boss-api/data/sample.sqlite3', tables: 3 }] },
          ocr: { ready: true, script: '/workspaces/02luka-repo/g/tools/ocr_typhoon.py' }
        }
      },
      engine: { local: true, server_models: false }
    };
    
    writeJson(res, 200, capabilities);
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

// Agent endpoints
app.post('/api/plan', async (req, res) => {
  try {
    const { goal } = req.body;
    if (!goal) {
      return writeJson(res, 400, { error: 'Goal is required' });
    }
    
    // Call the plan agent
    const result = await execAsync(`node agents/lukacode/plan.cjs "${goal}"`);
    writeJson(res, 200, { plan: result.stdout.trim() });
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

app.post('/api/patch', async (req, res) => {
  try {
    const { dryRun = false } = req.body;
    
    // Call the patch agent
    const result = await execAsync(`node agents/lukacode/patch.cjs ${dryRun ? '--dry-run' : ''}`);
    writeJson(res, 200, { patch: result.stdout.trim() });
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

app.get('/api/smoke', async (req, res) => {
  try {
    // Call the smoke agent
    const result = await execAsync('node agents/lukacode/smoke.cjs');
    writeJson(res, 200, { smoke: result.stdout.trim() });
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

// Paula proxy endpoints
app.get('/api/paula/health', async (req, res) => {
  await proxyPaulaRequest(req, res, '/health', { method: 'GET' });
});

app.post('/api/paula/signal', async (req, res) => {
  await proxyPaulaRequest(req, res, '/signal', { method: 'POST' });
});

app.post('/api/paula/train', async (req, res) => {
  await proxyPaulaRequest(req, res, '/train', { method: 'POST' });
});

app.get('/api/paula/models', async (req, res) => {
  await proxyPaulaRequest(req, res, '/models', { method: 'GET' });
});

app.post('/api/paula/backtest', async (req, res) => {
  await proxyPaulaRequest(req, res, '/backtest', { method: 'POST' });
});

// Start server
app.listen(PORT, '127.0.0.1', () => {
  console.log(`boss-api listening on http://127.0.0.1:${PORT}`);
});
