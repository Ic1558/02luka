const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const fsp = fs.promises;
const { exec, spawn } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

const repoRoot = path.resolve(__dirname, '..'); // 02luka-repo root

const MANAGED_PAYLOAD_LIMIT = 1024 * 1024; // 1MB
const BACKGROUND_TIMEOUT_MS = 60000;

const logsRoot = path.join(repoRoot, 'boss-api', 'logs');

async function ensureDirectory(dirPath) {
  await fsp.mkdir(dirPath, { recursive: true });
}

function sanitizeTimestamp(date = new Date()) {
  return date.toISOString().replace(/[:.]/g, '-');
}

function enforcePayloadLimit(req) {
  const headerLength = req.get('content-length');
  if (headerLength && Number(headerLength) > MANAGED_PAYLOAD_LIMIT) {
    const error = new Error('Payload exceeds 1MB limit');
    error.statusCode = 413;
    throw error;
  }

  if (req.body) {
    const jsonBody = JSON.stringify(req.body);
    if (Buffer.byteLength(jsonBody, 'utf8') > MANAGED_PAYLOAD_LIMIT) {
      const error = new Error('Payload exceeds 1MB limit');
      error.statusCode = 413;
      throw error;
    }
  }
}

async function launchBackgroundProcess({
  command,
  args = [],
  cwd = repoRoot,
  env = {},
  logLabel
}) {
  await ensureDirectory(logsRoot);
  const timestamp = sanitizeTimestamp();
  const logFileName = `${logLabel}-${timestamp}.log`;
  const logPath = path.join(logsRoot, logFileName);
  const logStream = fs.createWriteStream(logPath, { flags: 'a' });
  const commandLine = [command, ...args].join(' ');

  return new Promise((resolve, reject) => {
    let settled = false;
    const child = spawn(command, args, {
      cwd,
      env: { ...process.env, ...env },
      stdio: ['ignore', 'pipe', 'pipe']
    });

    const timeoutId = setTimeout(() => {
      if (!settled) {
        settled = true;
        child.kill();
        logStream.end();
        reject(new Error('Process start timeout exceeded'));
      }
    }, BACKGROUND_TIMEOUT_MS);

    const finalize = () => {
      clearTimeout(timeoutId);
    };

    if (child.stdout) {
      child.stdout.pipe(logStream, { end: false });
    }

    if (child.stderr) {
      child.stderr.pipe(logStream, { end: false });
    }

    child.once('error', error => {
      if (!settled) {
        settled = true;
        finalize();
        logStream.end();
        reject(error);
      }
    });

    child.once('spawn', () => {
      if (!settled) {
        settled = true;
        finalize();
        resolve({
          pid: child.pid,
          logPath,
          startedAt: new Date().toISOString(),
          command: commandLine
        });
      }
    });

    child.once('close', () => {
      logStream.end();
    });
  });
}

async function pathExists(targetPath, mode = fs.constants.F_OK) {
  try {
    await fsp.access(targetPath, mode);
    return true;
  } catch {
    return false;
  }
}

async function readCorpusStats() {
  const corpusDir = path.join(repoRoot, 'boss-api', 'data', 'paula');
  const statsPath = path.join(corpusDir, 'corpus-stats.json');

  try {
    const raw = await fsp.readFile(statsPath, 'utf8');
    const parsed = JSON.parse(raw);
    return {
      counts: parsed.counts || {},
      last_updated: parsed.last_updated || null,
      top_domains: parsed.top_domains || []
    };
  } catch (error) {
    if (error.code === 'ENOENT') {
      return {
        counts: { documents: 0, pages: 0, tokens: 0 },
        last_updated: null,
        top_domains: []
      };
    }

    throw error;
  }
}

function handleRouteError(res, error, defaultStatus = 500) {
  const statusCode = error.statusCode || defaultStatus;
  const message = error.message || 'Internal server error';

  if (statusCode >= 500) {
    console.error(error);
  }

  writeJson(res, statusCode, { error: message });
}

async function resolveTrainerScript() {
  if (process.env.PAULA_TRAINER_SCRIPT) {
    return process.env.PAULA_TRAINER_SCRIPT;
  }

  const candidates = ['run/auto_train.sh', 'run/train.sh', 'run/trainer.sh'];

  for (const candidate of candidates) {
    const candidatePath = path.join(repoRoot, candidate);
    if (await pathExists(candidatePath)) {
      return candidatePath;
    }
  }

  return null;
}

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

app.post('/api/paula/crawl', async (req, res) => {
  try {
    enforcePayloadLimit(req);

    const payload = req.body || {};
    const seeds = Array.isArray(payload.seeds) ? payload.seeds : [];
    const normalizedSeeds = seeds
      .filter(seed => typeof seed === 'string')
      .map(seed => seed.trim())
      .filter(seed => seed.length > 0);

    if (normalizedSeeds.length === 0) {
      const error = new Error('At least one seed URL is required');
      error.statusCode = 400;
      throw error;
    }

    let normalizedMaxPages;
    if (payload.max_pages !== undefined) {
      const parsed = Number(payload.max_pages);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        const error = new Error('max_pages must be a positive number');
        error.statusCode = 400;
        throw error;
      }

      normalizedMaxPages = Math.floor(parsed);
    }

    const crawlScript = path.join(repoRoot, 'run', 'crawl.sh');
    if (!(await pathExists(crawlScript))) {
      const error = new Error(`crawl script not found: ${crawlScript}`);
      error.statusCode = 500;
      throw error;
    }

    const env = {
      PAULA_CRAWL_SEEDS: JSON.stringify(normalizedSeeds)
    };

    if (normalizedMaxPages !== undefined) {
      env.PAULA_CRAWL_MAX_PAGES = String(normalizedMaxPages);
    }

    const result = await launchBackgroundProcess({
      command: 'bash',
      args: [crawlScript],
      cwd: repoRoot,
      env,
      logLabel: 'paula-crawl'
    });

    const { pid, logPath, startedAt, command } = result;

    writeJson(res, 202, {
      status: 'started',
      seeds: normalizedSeeds,
      max_pages: normalizedMaxPages ?? null,
      pid,
      log_path: logPath,
      started_at: startedAt,
      command
    });
  } catch (error) {
    handleRouteError(res, error);
  }
});

app.post('/api/paula/ingest', async (req, res) => {
  try {
    enforcePayloadLimit(req);

    const ingestScript = path.join(repoRoot, 'crawler', 'ingest.py');
    if (!(await pathExists(ingestScript))) {
      const error = new Error(`ingest script not found: ${ingestScript}`);
      error.statusCode = 500;
      throw error;
    }

    const pythonBinary = process.env.PAULA_PYTHON_BIN || 'python3';
    const payload = req.body && typeof req.body === 'object' ? req.body : {};
    const env = {};

    if (Object.keys(payload).length > 0) {
      env.PAULA_INGEST_OPTIONS = JSON.stringify(payload);
    }

    const result = await launchBackgroundProcess({
      command: pythonBinary,
      args: [ingestScript],
      cwd: repoRoot,
      env,
      logLabel: 'paula-ingest'
    });

    const { pid, logPath, startedAt, command } = result;

    writeJson(res, 202, {
      status: 'started',
      pid,
      log_path: logPath,
      started_at: startedAt,
      command
    });
  } catch (error) {
    handleRouteError(res, error);
  }
});

app.post('/api/paula/auto-train', async (req, res) => {
  try {
    enforcePayloadLimit(req);

    const payload = req.body || {};
    const strategy = typeof payload.strategy === 'string' ? payload.strategy.trim() : '';

    if (!strategy) {
      const error = new Error('strategy is required');
      error.statusCode = 400;
      throw error;
    }

    const trainerScript = await resolveTrainerScript();
    if (!trainerScript) {
      const error = new Error('Trainer script could not be located');
      error.statusCode = 500;
      throw error;
    }

    const result = await launchBackgroundProcess({
      command: 'bash',
      args: [trainerScript],
      cwd: repoRoot,
      env: { PAULA_TRAINING_STRATEGY: strategy },
      logLabel: 'paula-auto-train'
    });

    const { pid, logPath, startedAt, command } = result;

    writeJson(res, 202, {
      status: 'started',
      strategy,
      pid,
      log_path: logPath,
      started_at: startedAt,
      command
    });
  } catch (error) {
    handleRouteError(res, error);
  }
});

app.get('/api/paula/corpus/stats', async (req, res) => {
  try {
    const stats = await readCorpusStats();
    writeJson(res, 200, stats);
  } catch (error) {
    handleRouteError(res, error);
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
