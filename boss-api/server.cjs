const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

const app = express();
const PORT = process.env.PORT || 4000;

const openaiConnector = require('../g/connectors/mcp_openai');

const OPENAI_MODEL = process.env.OPENAI_MODEL || 'o4-mini';
const OPENAI_CHAT_MODEL = process.env.OPENAI_CHAT_MODEL || OPENAI_MODEL;
const OPENAI_OPTIMIZE_MODEL = process.env.OPENAI_OPTIMIZE_MODEL || OPENAI_MODEL;
const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL || 'claude-3-sonnet-20240229';

// Environment configuration
const AI_GATEWAY_URL = process.env.AI_GATEWAY_URL || '';
const AI_GATEWAY_KEY = process.env.AI_GATEWAY_KEY || '';
const AI_GATEWAY_BASE = AI_GATEWAY_URL.replace(/\/+$/, '');
const AGENTS_GATEWAY_URL = process.env.AGENTS_GATEWAY_URL || '';
const AGENTS_GATEWAY_KEY = process.env.AGENTS_GATEWAY_KEY || '';
const PUBLIC_API_BASE = process.env.PUBLIC_API_BASE || '';
const PUBLIC_AI_BASE = process.env.PUBLIC_AI_BASE || '';
const HAS_OPENAI_KEY = Boolean(process.env.OPENAI_API_KEY);
const HAS_ANTHROPIC_KEY = Boolean(process.env.ANTHROPIC_API_KEY);

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

function trimText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function formatAsBullets(text, fallback) {
  const trimmed = trimText(text);
  if (!trimmed) {
    return fallback || '- Probe for missing context and reference recent repo updates.';
  }
  return trimmed
    .split(/\r?\n+/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => (line.startsWith('-') ? line : `- ${line}`))
    .join('\n');
}

function buildHeuristicVariants({ system, prompt, context }) {
  const systemText = trimText(system) || 'You coordinate a team of expert AI delegates. Keep outputs structured, actionable, and testable.';
  const objective = trimText(prompt);
  if (!objective) {
    return [];
  }
  const contextBullets = formatAsBullets(context, '- Use current project knowledge and any linked documents.');

  const deliverables = [
    '- Clear objective recap and assumptions',
    '- Step-by-step plan or code strategy',
    '- Validation or test plan before completion'
  ].join('\n');

  const checklist = [
    '1. Clarify unknowns or missing data',
    '2. Outline approach and delegate responsibilities',
    '3. Produce the requested artifact',
    '4. Validate, critique, and note follow-ups'
  ].join('\n');

  const structured = [
    `# Role\n${systemText}`,
    `# Objective\n${objective}`,
    `# Context\n${contextBullets}`,
    `# Deliverables\n${deliverables}`,
    `# Execution Plan\n${checklist}`,
    '# Quality Gates\n- Provide explicit acceptance criteria\n- Flag blockers or risks early\n- Document follow-up actions'
  ].join('\n\n');

  const delegation = [
    `# Delegation Brief\n${systemText}`,
    `# Mission\n${objective}`,
    `# Shared Context\n${contextBullets}`,
    '# Delegate Tracks\n- Lead delegate drafts solution or plan\n- Reviewer critiques and strengthens output\n- Verifier designs validation/tests',
    '# Coordination Notes\n- Record decisions and open questions\n- Keep messages concise with numbered tasks\n- Escalate blockers immediately'
  ].join('\n\n');

  const riskAudit = [
    `# Role\n${systemText}`,
    `# Objective\n${objective}`,
    `# Context Signals\n${contextBullets}`,
    '# Risk & Safeguards\n- Identify failure modes or unknowns\n- Add mitigation or fallback paths\n- Specify monitoring/validation hooks',
    '# Delivery Checklist\n1. Summarize objective and constraints\n2. Provide implementation or decision path\n3. List validation/tests and owners\n4. Capture follow-up items with owners'
  ].join('\n\n');

  return [
    {
      id: 'structured_blueprint',
      title: 'Structured Execution Blueprint',
      score: 0.74,
      prompt: structured,
      rationale: 'Organizes the request into role, objective, context, deliverables, execution, and QA gates for immediate handoff.'
    },
    {
      id: 'delegate_sync',
      title: 'Delegate Synchronization Brief',
      score: 0.7,
      prompt: delegation,
      rationale: 'Provides a delegate-ready handoff with tracks for drafter, reviewer, and verifier to stay coordinated.'
    },
    {
      id: 'risk_review',
      title: 'Risk & Validation Checklist',
      score: 0.66,
      prompt: riskAudit,
      rationale: 'Surfaces risk analysis, mitigations, and a validation checklist to keep outputs production-ready.'
    }
  ];
}

function assembleOptimizeResponse({ heuristics, openaiResult, openaiError, model, openaiConfigured }) {
  const variants = [];
  const openaiText = trimText(openaiResult?.text);
  if (openaiText) {
    variants.push({
      id: `openai:${openaiResult.model || model}`,
      title: `OpenAI ${openaiResult.model || model}`,
      score: 0.92,
      prompt: openaiText,
      rationale: openaiResult.reasoning || 'Optimized via OpenAI Responses API with reasoning traces.',
      source: 'openai'
    });
  }

  heuristics.forEach((variant) => {
    variants.push({ ...variant, source: 'heuristic' });
  });

  const best = variants[0] || null;
  const payload = {
    ok: Boolean(best && trimText(best.prompt)),
    prompt: best?.prompt || '',
    variants,
    best: best?.id || null,
    engine: openaiText ? `openai:${openaiResult.model || model}` : 'heuristic:rule_based',
    meta: openaiText
      ? {
          provider: 'openai',
          model: openaiResult.model || model,
          endpoint: 'responses',
          response_id: openaiResult.raw?.id || null,
          status: openaiResult.raw?.status || null
        }
      : {
          provider: 'heuristic',
          model: 'rule-based',
          reason: openaiConfigured
            ? 'OpenAI Responses unavailable; using rule-based fallback.'
            : 'OPENAI_API_KEY not configured.'
        }
  };

  if (openaiResult?.reasoning) {
    payload.reasoning = openaiResult.reasoning;
  }
  if (openaiResult?.raw?.usage && openaiText) {
    payload.usage = openaiResult.raw.usage;
    payload.meta.usage = openaiResult.raw.usage;
  }

  if (openaiError) {
    payload.warnings = [openaiError.message || 'OpenAI request failed'];
  }

  if (!payload.reasoning && heuristics[0]?.rationale) {
    payload.reasoning = heuristics[0].rationale;
  }

  return payload;
}

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
        optimize_prompt_sources: HAS_OPENAI_KEY ? ['heuristic', 'openai'] : ['heuristic'],
        chat: HAS_OPENAI_KEY,
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
        anthropic: { ready: HAS_ANTHROPIC_KEY, model: ANTHROPIC_MODEL },
        openai: {
          ready: HAS_OPENAI_KEY,
          model: OPENAI_MODEL,
          endpoint: process.env.OPENAI_RESPONSES_URL || 'https://api.openai.com/v1/responses',
          capabilities: {
            responses_api: true,
            reasoning: true,
            optimize_prompt: true,
            chat: true
          }
        },
        local: {
          chat: { ready: false, error: 'connect ECONNREFUSED 127.0.0.1:11434' },
          rag: { ready: true, documents: 0, dbPath: '/workspaces/02luka-repo/boss-api/data/rag.sqlite3' },
          sql: { ready: true, datasets: [{ id: 'sample', label: 'Sample Workplace Dataset', path: '/workspaces/02luka-repo/boss-api/data/sample.sqlite3', tables: 3 }] },
          ocr: { ready: true, script: '/workspaces/02luka-repo/g/tools/ocr_typhoon.py' },
          optimize: { ready: true, source: 'heuristic' }
        }
      },
      engine: { local: true, server_models: false }
    };
    
    writeJson(res, 200, capabilities);
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

app.get('/api/connectors/status', (req, res) => {
  try {
    const payload = {
      anthropic: {
        ready: HAS_ANTHROPIC_KEY,
        model: ANTHROPIC_MODEL,
        reason: HAS_ANTHROPIC_KEY ? null : 'ANTHROPIC_API_KEY not configured.'
      },
      openai: {
        ready: HAS_OPENAI_KEY,
        model: OPENAI_MODEL,
        endpoint: process.env.OPENAI_RESPONSES_URL || 'https://api.openai.com/v1/responses',
        reason: HAS_OPENAI_KEY ? null : 'OPENAI_API_KEY not configured.'
      },
      local: {
        ready: true,
        optimize: { source: 'heuristic', variants: 3 },
        rag: true,
        sql: true
      }
    };
    writeJson(res, 200, payload);
  } catch (error) {
    writeJson(res, 500, { error: error.message });
  }
});

function mapOpenAIResult(result, fallbackModel) {
  const model = result?.model || fallbackModel || OPENAI_MODEL;
  const payload = {
    ok: Boolean(result?.text?.trim()),
    engine: `openai:${model}`,
    meta: {
      provider: 'openai',
      model,
      usage: result?.raw?.usage || null,
      response_id: result?.raw?.id || null,
      endpoint: 'responses',
      status: result?.raw?.status || null
    }
  };
  if (result?.raw?.usage) {
    payload.usage = result.raw.usage;
  }
  if (result?.text) {
    payload.text = result.text;
  }
  if (result?.reasoning) {
    payload.reasoning = result.reasoning;
  }
  return payload;
}

function handleOpenAIError(res, error) {
  if (error?.code === 'NO_KEY' || /api key/i.test(error?.message || '')) {
    return writeJson(res, 503, { error: 'OpenAI connector not configured.' });
  }
  console.error('[boss-api] OpenAI request failed', error);
  return writeJson(res, 502, { error: error.message || 'OpenAI request failed' });
}

app.post('/api/optimize_prompt', async (req, res) => {
  try {
    const { prompt, system = '', context = '', model } = req.body || {};
    const userPrompt = trimText(prompt);
    if (!userPrompt) {
      return writeJson(res, 400, { error: 'Prompt is required' });
    }

    const heuristics = buildHeuristicVariants({ system, prompt: userPrompt, context });
    let openaiResult = null;
    let openaiError = null;
    const targetModel = model || OPENAI_OPTIMIZE_MODEL;

    if (HAS_OPENAI_KEY) {
      try {
        openaiResult = await openaiConnector.optimizePrompt({
          system,
          user: userPrompt,
          context,
          model: targetModel
        });
      } catch (error) {
        openaiError = error;
        console.warn('[boss-api] OpenAI optimize_prompt fallback to heuristics', error);
      }
    }

    const payload = assembleOptimizeResponse({
      heuristics,
      openaiResult,
      openaiError,
      model: targetModel,
      openaiConfigured: HAS_OPENAI_KEY
    });

    writeJson(res, payload.ok ? 200 : 502, payload);
  } catch (error) {
    console.error('[boss-api] optimize_prompt failed', error);
    writeJson(res, 500, { error: error.message || 'Optimization failed' });
  }
});

app.post('/api/chat', async (req, res) => {
  try {
    if (!HAS_OPENAI_KEY) {
      return writeJson(res, 503, { error: 'OpenAI connector not configured.' });
    }
    const { message, system = '', model } = req.body || {};
    const prompt = message ?? req.body?.prompt;
    if (!prompt || !String(prompt).trim()) {
      return writeJson(res, 400, { error: 'Message is required' });
    }

    const result = await openaiConnector.chat({
      input: prompt,
      system,
      model: model || OPENAI_CHAT_MODEL
    });

    const payload = mapOpenAIResult(result, model || OPENAI_CHAT_MODEL);
    payload.response = result?.text || '';
    delete payload.text;
    writeJson(res, 200, payload);
  } catch (error) {
    handleOpenAIError(res, error);
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
