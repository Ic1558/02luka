const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

const DEFAULT_OPTIMIZER_MODEL = process.env.AI_GATEWAY_MODEL || 'gpt-4o-mini';
const AI_COMPLETIONS_PATH = process.env.AI_GATEWAY_COMPLETIONS_PATH || '/openai/v1/chat/completions';

function requireGlobalFetch() {
  if (typeof fetch === 'function') {
    return fetch;
  }

  try {
    // eslint-disable-next-line global-require, import/no-extraneous-dependencies
    return require('node-fetch');
  } catch (error) {
    throw new Error('Global fetch API is unavailable. Upgrade to Node 18+ or install node-fetch.');
  }
}

const runtimeFetch = requireGlobalFetch();

const app = express();
const PORT = process.env.PORT || 4000;

// Environment configuration
const AI_GATEWAY_URL = process.env.AI_GATEWAY_URL || '';
const AI_GATEWAY_KEY = process.env.AI_GATEWAY_KEY || '';
const AI_GATEWAY_BASE = AI_GATEWAY_URL.replace(/\/+$/, '');
const AGENTS_GATEWAY_URL = process.env.AGENTS_GATEWAY_URL || '';
const AGENTS_GATEWAY_KEY = process.env.AGENTS_GATEWAY_KEY || '';
const PUBLIC_API_BASE = process.env.PUBLIC_API_BASE || '';
const PUBLIC_AI_BASE = process.env.PUBLIC_AI_BASE || '';

function stripTrailingSlash(value = '') {
  return value.replace(/\/+$/, '');
}

const agentsGatewayBase = stripTrailingSlash(AGENTS_GATEWAY_URL || '');

function buildGatewayHeaders(key, extraHeaders = {}) {
  const headers = { ...extraHeaders };
  if (key) {
    headers.Authorization = `Bearer ${key}`;
  }
  return headers;
}

async function forwardJson(url, options = {}) {
  const requestInit = {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    body: JSON.stringify(options.body || {}),
    signal: options.signal
  };

  const response = await runtimeFetch(url, requestInit);
  const text = await response.text();

  let payload;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch (error) {
    const parseError = new Error(`Upstream returned invalid JSON from ${url}`);
    parseError.status = 502;
    parseError.detail = text?.slice(0, 256);
    throw parseError;
  }

  if (!response.ok) {
    const error = new Error(payload?.detail || payload?.error || `Upstream error (${response.status})`);
    error.status = response.status;
    error.detail = payload;
    throw error;
  }

  return payload;
}

async function dispatchAgentsGateway(requestBody) {
  if (!agentsGatewayBase) {
    const error = new Error('Agents gateway is not configured.');
    error.status = 503;
    error.detail = 'Set AGENTS_GATEWAY_URL (and optional AGENTS_GATEWAY_KEY) environment variables.';
    throw error;
  }

  const url = `${agentsGatewayBase}/chat`;
  const headers = buildGatewayHeaders(AGENTS_GATEWAY_KEY);

  return forwardJson(url, {
    body: requestBody,
    headers
  });
}

async function runPromptOptimizer(prompt, overrides = {}) {
  const aiGatewayBase = stripTrailingSlash(AI_GATEWAY_BASE);
  if (!aiGatewayBase) {
    const error = new Error('AI gateway is not configured.');
    error.status = 503;
    error.detail = 'Set AI_GATEWAY_URL and AI_GATEWAY_KEY environment variables.';
    throw error;
  }

  if (!AI_GATEWAY_KEY) {
    const error = new Error('AI gateway key missing.');
    error.status = 503;
    error.detail = 'Set AI_GATEWAY_KEY to authenticate with the AI gateway.';
    throw error;
  }

  const model = overrides.model || DEFAULT_OPTIMIZER_MODEL;
  const promptText = String(prompt || '').trim();

  const systemPrompt = overrides.systemPrompt || 'You are Luka, an elite prompt engineer. Refine user prompts into precise, structured instructions for autonomous coding agents. Preserve intent, add explicit success criteria, highlight constraints, and keep the response concise and actionable.';

  const body = {
    model,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: promptText }
    ],
    temperature: 0.2,
    max_tokens: overrides.maxTokens || 1024
  };

  const url = `${aiGatewayBase}${AI_COMPLETIONS_PATH}`;
  const headers = buildGatewayHeaders(AI_GATEWAY_KEY);

  return forwardJson(url, { body, headers });
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

app.post('/api/chat', async (req, res) => {
  const { message, target = 'auto', metadata = null, context = null } = req.body || {};

  if (typeof message !== 'string' || message.trim().length === 0) {
    return writeJson(res, 400, { error: 'message is required' });
  }

  const payload = {
    message: message.trim(),
    target,
    metadata,
    context,
    client: 'luka'
  };

  try {
    const data = await dispatchAgentsGateway(payload);
    writeJson(res, 200, data);
  } catch (error) {
    const status = error.status || 502;
    writeJson(res, status, {
      error: error.message,
      detail: error.detail || error.stack
    });
  }
});

app.post('/api/optimize', async (req, res) => {
  const { prompt, model, systemPrompt, maxTokens } = req.body || {};

  if (typeof prompt !== 'string' || prompt.trim().length === 0) {
    return writeJson(res, 400, { error: 'prompt is required' });
  }

  try {
    const response = await runPromptOptimizer(prompt, { model, systemPrompt, maxTokens });

    const optimized = response?.choices?.[0]?.message?.content?.trim?.() || '';
    writeJson(res, 200, {
      ok: true,
      optimized,
      raw: response
    });
  } catch (error) {
    const status = error.status || 502;
    writeJson(res, status, {
      error: error.message,
      detail: error.detail || error.stack
    });
  }
});

// Start server
app.listen(PORT, '127.0.0.1', () => {
  console.log(`boss-api listening on http://127.0.0.1:${PORT}`);
});
