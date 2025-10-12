const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

const app = express();
const PORT = process.env.PORT || 4000;

// Environment configuration helpers
function resolveFirstEnv(keys = []) {
  for (const key of keys) {
    const raw = process.env[key];
    if (typeof raw === 'string') {
      const value = raw.trim();
      if (value) {
        return { value, source: key };
      }
    }
  }
  return { value: '', source: null };
}

function collectGatewayConfig(prefix) {
  const upper = String(prefix || '').toUpperCase();
  const urlInfo = resolveFirstEnv([
    `${upper}_GATEWAY_URL`,
    `${upper}_URL`,
    `${upper}_BASE_URL`,
    `${upper}_BASE`,
    `${upper}_API_URL`,
    `${upper}_API_BASE`
  ]);
  const keyInfo = resolveFirstEnv([
    `${upper}_GATEWAY_KEY`,
    `${upper}_KEY`,
    `${upper}_API_KEY`,
    `${upper}_TOKEN`,
    `${upper}_AUTH_TOKEN`
  ]);

  if (!urlInfo.value && !keyInfo.value) {
    return null;
  }

  return {
    url: urlInfo.value || null,
    urlSource: urlInfo.source,
    keyConfigured: Boolean(keyInfo.value),
    keySource: keyInfo.source
  };
}

function buildRuntimeConfig() {
  const internalApiBase = `http://127.0.0.1:${PORT}`;
  const publicApiInfo = resolveFirstEnv(['PUBLIC_API_BASE', 'VITE_PUBLIC_API_BASE']);
  const publicAiInfo = resolveFirstEnv(['PUBLIC_AI_BASE', 'VITE_PUBLIC_AI_BASE']);
  const aiGateway = collectGatewayConfig('AI');
  const agentsGateway = collectGatewayConfig('AGENTS');
  const paulaGateway = collectGatewayConfig('PAULA');

  const apiBase = publicApiInfo.value || internalApiBase;
  const aiBase = publicAiInfo.value || (aiGateway && aiGateway.url) || apiBase;

  const config = {
    apiBase,
    aiBase,
    generatedAt: new Date().toISOString(),
    sources: {
      apiBase: publicApiInfo.source || 'internal',
      aiBase: publicAiInfo.source || (aiGateway && aiGateway.urlSource) || 'apiBase'
    },
    gateways: {
      api: {
        internalUrl: internalApiBase,
        publicUrl: publicApiInfo.value || null
      }
    }
  };

  if (aiGateway) {
    config.gateways.ai = {
      url: aiGateway.url,
      source: aiGateway.urlSource,
      keyConfigured: aiGateway.keyConfigured,
      keySource: aiGateway.keySource
    };
  }

  if (agentsGateway) {
    config.gateways.agents = {
      url: agentsGateway.url,
      source: agentsGateway.urlSource,
      keyConfigured: agentsGateway.keyConfigured,
      keySource: agentsGateway.keySource
    };
  }

  if (paulaGateway) {
    config.gateways.paula = {
      url: paulaGateway.url,
      source: paulaGateway.urlSource,
      keyConfigured: paulaGateway.keyConfigured,
      keySource: paulaGateway.keySource
    };
  }

  return config;
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

// Runtime configuration endpoint
app.get('/config.json', (req, res) => {
  res.set('Cache-Control', 'no-store');
  const config = buildRuntimeConfig();
  writeJson(res, 200, config);
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

// Start server
app.listen(PORT, '127.0.0.1', () => {
  console.log(`boss-api listening on http://127.0.0.1:${PORT}`);
});
