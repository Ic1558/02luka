const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const { postDiscordWebhook } = require('../agents/discord/webhook_relay.cjs');

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
const DISCORD_WEBHOOK_DEFAULT = process.env.DISCORD_WEBHOOK_DEFAULT || '';
const DISCORD_WEBHOOK_MAP = process.env.DISCORD_WEBHOOK_MAP || '';

let discordWebhookMap = {};
if (DISCORD_WEBHOOK_MAP) {
  try {
    const parsed = JSON.parse(DISCORD_WEBHOOK_MAP);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      discordWebhookMap = Object.entries(parsed).reduce((acc, [key, value]) => {
        if (typeof value === 'string' && value.trim()) {
          acc[key] = value.trim();
        }
        return acc;
      }, {});
    } else {
      console.warn('DISCORD_WEBHOOK_MAP must be a JSON object. Ignoring value.');
    }
  } catch (error) {
    console.warn('DISCORD_WEBHOOK_MAP is not valid JSON and will be ignored.');
  }
}

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

function normalizeLevel(rawLevel) {
  const normalized = typeof rawLevel === 'string' ? rawLevel.trim().toLowerCase() : '';
  if (normalized === 'warn' || normalized === 'warning') {
    return 'warn';
  }
  if (normalized === 'error' || normalized === 'err' || normalized === 'fatal') {
    return 'error';
  }
  return 'info';
}

function resolveDiscordWebhook(channelName) {
  const normalized = typeof channelName === 'string' && channelName.trim() ? channelName.trim() : 'default';

  if (discordWebhookMap[normalized]) {
    return discordWebhookMap[normalized];
  }

  if (normalized !== 'default' && discordWebhookMap.default) {
    return discordWebhookMap.default;
  }

  return DISCORD_WEBHOOK_DEFAULT;
}

function formatDiscordPayload(level, content) {
  const trimmedContent = typeof content === 'string' ? content.trim() : '';
  const levelEmojis = {
    info: 'ℹ️',
    warn: '⚠️',
    error: '🚨'
  };

  const prefix = levelEmojis[level] || '';
  const finalContent = prefix ? `${prefix} ${trimmedContent}` : trimmedContent;

  return {
    content: finalContent,
    allowed_mentions: { parse: [] }
  };
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

app.post('/api/discord/notify', async (req, res) => {
  try {
    const body = req.body || {};
    const rawContent = body.content;
    if (!rawContent || typeof rawContent !== 'string' || !rawContent.trim()) {
      return writeJson(res, 400, { error: 'content is required' });
    }

    const level = normalizeLevel(body.level);
    const channel = typeof body.channel === 'string' ? body.channel.trim() : 'default';
    const webhookUrl = resolveDiscordWebhook(channel);

    if (!webhookUrl) {
      return writeJson(res, 503, { error: 'Discord webhook is not configured' });
    }

    const payload = formatDiscordPayload(level, rawContent);

    try {
      await postDiscordWebhook(webhookUrl, payload);
    } catch (error) {
      const statusSuffix = error && error.statusCode ? ` (status ${error.statusCode})` : '';
      console.error(`Failed to deliver Discord notification${statusSuffix}:`, error.message);
      return writeJson(res, 502, { error: 'Failed to send Discord notification' });
    }

    return writeJson(res, 200, { ok: true });
  } catch (error) {
    return writeJson(res, 500, { error: 'Unexpected error while processing request' });
  }
});

// Agent endpoints
app.post('/api/plan', async (req, res) => {
  try {
    const { goal, stub } = req.body;
    if (!goal) {
      return writeJson(res, 400, { error: 'Goal is required' });
    }

    // Stub mode for smoke tests
    if (stub === true || req.headers['x-smoke'] === '1') {
      return writeJson(res, 200, { plan: 'STUB: Plan endpoint operational', goal, mode: 'smoke' });
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

// Reports endpoints
const fssync = require('fs');
const reportDir = path.join(repoRoot, 'g', 'reports');

app.get('/api/reports/list', async (req, res) => {
  try {
    if (!fssync.existsSync(reportDir)) {
      return writeJson(res, 200, { files: [] });
    }
    const files = fssync.readdirSync(reportDir)
      .filter(f => /^OPS_ATOMIC_\d+_\d+\.md$/.test(f))
      .sort()
      .reverse()
      .slice(0, 20);
    writeJson(res, 200, { files });
  } catch (error) {
    console.error('[/api/reports/list]', error);
    writeJson(res, 500, { error: 'list_failed' });
  }
});

app.get('/api/reports/latest', async (req, res) => {
  try {
    if (!fssync.existsSync(reportDir)) {
      return writeJson(res, 404, { error: 'reports_directory_not_found' });
    }
    const files = fssync.readdirSync(reportDir)
      .filter(f => /^OPS_ATOMIC_\d+_\d+\.md$/.test(f))
      .sort()
      .reverse();
    if (!files.length) {
      return writeJson(res, 404, { error: 'no_reports' });
    }
    const md = fssync.readFileSync(path.join(reportDir, files[0]), 'utf8');
    res.setHeader('Content-Type', 'text/markdown; charset=utf-8');
    res.send(md);
  } catch (error) {
    console.error('[/api/reports/latest]', error);
    writeJson(res, 500, { error: 'read_failed' });
  }
});

app.get('/api/reports/summary', async (req, res) => {
  try {
    const sumPath = path.join(repoRoot, 'g', 'reports', 'OPS_SUMMARY.json');

    // Tolerant: missing file → return unknown status
    if (!fssync.existsSync(sumPath)) {
      return writeJson(res, 200, {
        status: 'unknown',
        note: 'summary_not_generated',
        hint: 'Run: node agents/reportbot/index.cjs /tmp/ops_summary.json'
      });
    }

    // Tolerant: unreadable file → return unknown status
    let content;
    try {
      content = fssync.readFileSync(sumPath, 'utf8');
    } catch (readError) {
      console.warn('[/api/reports/summary] File unreadable:', readError.message);
      return writeJson(res, 200, {
        status: 'unknown',
        note: 'summary_unreadable',
        hint: 'Check file permissions on g/reports/OPS_SUMMARY.json'
      });
    }

    // Tolerant: invalid JSON → return unknown status
    let json;
    try {
      json = JSON.parse(content);
    } catch (parseError) {
      console.warn('[/api/reports/summary] Invalid JSON:', parseError.message);
      return writeJson(res, 200, {
        status: 'unknown',
        note: 'summary_invalid_json',
        hint: 'OPS_SUMMARY.json contains invalid JSON'
      });
    }

    // Success: return parsed JSON
    writeJson(res, 200, json);
  } catch (error) {
    // Unexpected errors → still return 200 with unknown status
    console.error('[/api/reports/summary] Unexpected error:', error);
    writeJson(res, 200, {
      status: 'unknown',
      note: 'summary_error',
      error: error.message
    });
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

// ---- UI Static Serving (Linear-lite multipage) ----
const UI_APPS = path.join(repoRoot, 'boss-ui', 'apps');
const UI_SHARED = path.join(repoRoot, 'boss-ui', 'shared');

// Serve /shared as public static files (css/js/components)
app.use('/shared', express.static(UI_SHARED, { fallthrough: true }));

// Serve files in apps directly (e.g., /apps/chat.html)
app.use('/apps', express.static(UI_APPS, { fallthrough: true }));

// Helper: send page from apps/<name>.html
function sendPage(name, res) {
  res.sendFile(path.join(UI_APPS, `${name}.html`));
}

// Landing page as default
app.get('/', (_req, res) => sendPage('landing', res));

// Working mode pages
['chat', 'plan', 'build', 'ship'].forEach(p => {
  app.get(`/${p}`, (_req, res) => sendPage(p, res));
});

// (Optional) 404 fallback for non-API routes
app.use((req, res, next) => {
  if (req.path.startsWith('/api/')) return next();
  res.status(404).send('Not Found');
});
// ---- End UI Static Serving ----

// Start server
app.listen(PORT, '127.0.0.1', () => {
  console.log(`boss-api listening on http://127.0.0.1:${PORT}`);
});
