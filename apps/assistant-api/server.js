#!/usr/bin/env node
const express = require('express');
const path = require('path');
const crypto = require('crypto');
const { buildContext, listSources } = require('../../packages/context');
const memory = require('../../packages/memory');

const app = express();
const PORT = Number(process.env.PORT || 4000);
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_REQUESTS = Number(process.env.RATE_LIMIT_MAX || 120);

app.use(express.json({ limit: '1mb' }));
app.use(requestLogger);
app.use(authStub);
app.use(rateLimiter);

const uiDir = path.resolve(__dirname, '../assistant-ui/public');
app.use('/', express.static(uiDir));

app.get('/healthz', (_req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.get('/capabilities', (req, res) => {
  res.json({
    name: 'assistant-core',
    version: '0.1.0',
    connectors: listSources(),
    memory: {
      stats: memory.stats()
    },
    tools: {
      rag: { endpoint: '/rag/query', offline: true },
      memory: { endpoints: ['/memory/remember', '/memory/recall', '/memory/stats'] }
    },
    auth: req.authContext,
    performance: {
      kpis: ['accuracy', 'latency', 'cost', 'task_completion_rate']
    }
  });
});

app.post('/rag/query', (req, res, next) => {
  try {
    const { query, limit, tokenBudget } = req.body || {};
    if (!query || typeof query !== 'string') {
      res.status(400).json({ error: 'Query is required.' });
      return;
    }

    const contextResult = buildContext(query, {
      limit: typeof limit === 'number' ? limit : undefined,
      tokenBudget: typeof tokenBudget === 'number' ? tokenBudget : undefined,
      includeDiagnostics: Boolean(req.query.debug)
    });

    const response = {
      query,
      answer: createMockAnswer(query, contextResult.snippets),
      context: contextResult.snippets,
      confidence: contextResult.confidence,
      tokenBudget: contextResult.tokenBudget,
      trace: [
        ...contextResult.trace,
        {
          step: 'llm-planning',
          what: 'Generated draft response using mock composer',
          why: 'Offline mode',
          details: { tokensReserved: contextResult.tokenBudget.remaining }
        }
      ],
      actions: [
        {
          id: 'context-assembly',
          what: 'Assembled retrieval context from local documents',
          why: 'Query similarity above threshold',
          sources: contextResult.snippets.map(snippet => snippet.sourceId)
        }
      ]
    };

    res.json(response);
  } catch (err) {
    next(err);
  }
});

app.post('/memory/remember', (req, res, next) => {
  try {
    const { text, kind, meta, importance } = req.body || {};
    if (!text) {
      res.status(400).json({ error: 'text is required' });
      return;
    }
    const result = memory.remember({ text, kind, meta, importance });
    res.json({ status: 'stored', result });
  } catch (err) {
    next(err);
  }
});

app.post('/memory/recall', (req, res, next) => {
  try {
    const { query, kind, topK } = req.body || {};
    if (!query) {
      res.status(400).json({ error: 'query is required' });
      return;
    }
    const result = memory.recall({ query, kind, topK });
    res.json({ status: 'ok', memories: result });
  } catch (err) {
    next(err);
  }
});

app.get('/memory/stats', (_req, res, next) => {
  try {
    res.json(memory.stats());
  } catch (err) {
    next(err);
  }
});

app.use(errorHandler);

const server = app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`assistant-api listening on http://localhost:${PORT}`);
});

process.on('SIGINT', () => {
  server.close(() => process.exit(0));
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});

/**
 * Express middleware that logs basic request information.
 */
function requestLogger(req, res, next) {
  const start = Date.now();
  const requestId = crypto.randomUUID();
  req.requestId = requestId;
  // eslint-disable-next-line no-console
  console.log(JSON.stringify({
    event: 'request:start',
    requestId,
    method: req.method,
    path: req.path
  }));
  resFinishHook(_res => {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({
      event: 'request:finish',
      requestId,
      durationMs: Date.now() - start,
      status: _res.statusCode
    }));
  }, res);
  next();
}

/**
 * Attach RBAC-ready auth context (stubbed).
 */
function authStub(req, _res, next) {
  const actor = req.header('x-actor') || 'local-dev';
  const roles = (req.header('x-roles') || 'workflow-automation').split(',').map(role => role.trim());
  req.authContext = {
    actor,
    roles,
    scopes: deriveScopes(roles)
  };
  next();
}

/**
 * Simple in-memory rate limiter keyed by actor.
 */
const rateBuckets = new Map();
function rateLimiter(req, res, next) {
  const key = req.authContext?.actor || req.ip;
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;
  const bucket = rateBuckets.get(key) || [];
  const recent = bucket.filter(timestamp => timestamp > windowStart);
  recent.push(now);
  rateBuckets.set(key, recent);
  if (recent.length > RATE_LIMIT_MAX_REQUESTS) {
    res.status(429).json({ error: 'Rate limit exceeded' });
    return;
  }
  next();
}

/**
 * Error handling middleware.
 */
function errorHandler(err, _req, res, _next) {
  // eslint-disable-next-line no-console
  console.error('API error', err);
  res.status(500).json({ error: err.message || 'Internal Server Error' });
}

/**
 * Derive RBAC scopes from role list.
 * @param {string[]} roles
 * @returns {string[]}
 */
function deriveScopes(roles) {
  const scopeSet = new Set();
  for (const role of roles) {
    switch (role) {
      case 'workflow-automation':
        scopeSet.add('context:read');
        scopeSet.add('memory:write');
        scopeSet.add('automation:execute');
        break;
      case 'knowledge-navigator':
        scopeSet.add('context:read');
        break;
      case 'operations-orchestrator':
        scopeSet.add('context:read');
        scopeSet.add('memory:write');
        scopeSet.add('ops:approve');
        break;
      default:
        scopeSet.add('context:read');
    }
  }
  return Array.from(scopeSet);
}

/**
 * Create a mock answer from context snippets.
 * @param {string} query
 * @param {Array<{summary: string, sourceId: string}>} snippets
 * @returns {string}
 */
function createMockAnswer(query, snippets) {
  if (!snippets.length) {
    return `Unable to find direct matches for: "${query}". Recommend escalating or adding new knowledge.`;
  }
  const bulletList = snippets
    .slice(0, 3)
    .map(snippet => `- Source ${snippet.sourceId}: ${snippet.summary}`)
    .join('\n');
  return `Summary for "${query}":\n${bulletList}\nConfidence derived from local docs.`;
}

/**
 * Attach finish hook to response.
 * @param {(res: import('express').Response) => void} cb
 * @param {import('express').Response} res
 */
function resFinishHook(cb, res) {
  const original = res.end;
  res.end = function patchedEnd(...args) {
    try {
      cb(res);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('Failed to execute response finish hook', err);
    }
    return original.apply(this, args);
  };
}

module.exports = app;
