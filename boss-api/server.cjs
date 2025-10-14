const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

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

const repoRoot = path.resolve(__dirname, '..'); // 02luka-repo root
const bossRoot = path.join(repoRoot, 'boss');
const reportsDir = path.join(repoRoot, 'g', 'reports');
const reportsProofDir = path.join(reportsDir, 'proof');

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

function evaluateReportStatus(latestReport) {
  if (!latestReport) {
    return { status: 'FAIL', message: 'No reports found in g/reports/' };
  }

  const modifiedTime = new Date(latestReport.modified).getTime();
  if (!Number.isFinite(modifiedTime)) {
    return { status: 'WARN', message: 'Unable to determine latest report timestamp' };
  }

  const ageHours = (Date.now() - modifiedTime) / (1000 * 60 * 60);
  if (ageHours >= 48) {
    return { status: 'FAIL', message: 'Latest report is older than 48 hours' };
  }
  if (ageHours >= 24) {
    return { status: 'WARN', message: 'Latest report is older than 24 hours' };
  }
  return { status: 'OK', message: 'Reports are fresh' };
}

async function safeReadDir(targetDir) {
  try {
    return await fs.readdir(targetDir, { withFileTypes: true });
  } catch (err) {
    if (err && err.code === 'ENOENT') {
      return [];
    }
    throw err;
  }
}

function toPosixPath(value) {
  return value.split(path.sep).join('/');
}

async function collectFiles(dir, type) {
  const entries = await safeReadDir(dir);
  const files = await Promise.all(
    entries
      .filter((entry) => entry.isFile())
      .map(async (entry) => {
        const absolutePath = path.join(dir, entry.name);
        const stats = await fs.stat(absolutePath);
        const relativePath = toPosixPath(path.relative(repoRoot, absolutePath));
        return {
          name: entry.name,
          type,
          size: stats.size,
          modified: stats.mtime.toISOString(),
          relativePath,
          webPath: `/${relativePath}`,
          absolutePath
        };
      })
  );
  files.sort((a, b) => new Date(b.modified).getTime() - new Date(a.modified).getTime());
  return files;
}

function sanitizeEntries(entries) {
  return entries.map(({ absolutePath, ...rest }) => rest);
}

async function loadReportCatalog() {
  const [reports, proof] = await Promise.all([
    collectFiles(reportsDir, 'report'),
    collectFiles(reportsProofDir, 'proof')
  ]);
  return { reports, proof };
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

app.get('/api/reports/list', async (req, res) => {
  try {
    const catalog = await loadReportCatalog();
    const payload = {
      generatedAt: new Date().toISOString(),
      reports: sanitizeEntries(catalog.reports.slice(0, 25)),
      proof: sanitizeEntries(catalog.proof.slice(0, 25))
    };
    writeJson(res, 200, payload);
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

app.get('/api/reports/latest', async (req, res) => {
  try {
    const catalog = await loadReportCatalog();
    const latestMarkdown = catalog.reports.find((file) => file.name.toLowerCase().endsWith('.md')) || catalog.reports[0] || null;
    const report = latestMarkdown
      ? {
          ...sanitizeEntries([latestMarkdown])[0],
          content: await fs.readFile(latestMarkdown.absolutePath, 'utf8')
        }
      : null;

    writeJson(res, 200, {
      generatedAt: new Date().toISOString(),
      report,
      message: report ? 'Latest report loaded' : 'No reports available'
    });
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

app.get('/api/reports/summary', async (req, res) => {
  try {
    const catalog = await loadReportCatalog();
    const latestReport = catalog.reports[0] || null;
    const latestProof = catalog.proof[0] || null;
    const statusInfo = evaluateReportStatus(latestReport);

    writeJson(res, 200, {
      generatedAt: new Date().toISOString(),
      status: statusInfo.status,
      message: statusInfo.message,
      totals: {
        reports: catalog.reports.length,
        proof: catalog.proof.length,
        combined: catalog.reports.length + catalog.proof.length
      },
      latestReport: latestReport ? sanitizeEntries([latestReport])[0] : null,
      latestProof: latestProof ? sanitizeEntries([latestProof])[0] : null
    });
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

// Start server
app.listen(PORT, '127.0.0.1', () => {
  console.log(`boss-api listening on http://127.0.0.1:${PORT}`);
});
