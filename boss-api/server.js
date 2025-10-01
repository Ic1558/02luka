const http = require('http');
const https = require('https');
const path = require('path');
const fs = require('fs/promises');

const HOST = process.env.HOST || '127.0.0.1';
const PORT = Number(process.env.PORT || 4000);
const repoRoot = path.resolve(__dirname, '..'); // 02luka-repo root
const bossRoot = path.join(repoRoot, 'boss');

function writeJson(res, code, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(body);
}

const allowed = new Set(['inbox','sent','deliverables','dropbox','drafts','documents']);

const CHAT_TARGETS = {
  auto: {
    id: 'auto',
    name: 'Smart Delegate',
    type: 'aggregate',
    delegates: ['mcp', 'mcp_fs', 'ollama']
  },
  mcp: {
    id: 'mcp',
    name: 'MCP Docker Gateway',
    type: 'mcp',
    baseUrl: process.env.MCP_GATEWAY_URL || 'http://127.0.0.1:5012'
  },
  mcp_fs: {
    id: 'mcp_fs',
    name: 'MCP FS Gateway',
    type: 'mcp',
    baseUrl: process.env.MCP_FS_URL || 'http://127.0.0.1:8765'
  },
  ollama: {
    id: 'ollama',
    name: 'Ollama',
    type: 'ollama',
    baseUrl: process.env.OLLAMA_URL || 'http://localhost:11434'
  }
};

const FALLBACK_PROVIDER_HINTS = ['openai', 'anthropic'];

function normalizeInput(text) {
  return (text || '').trim();
}

function normalizeForMatch(text) {
  return normalizeInput(text).toLowerCase();
}

function stripTrailingPunctuation(text) {
  return normalizeInput(text).replace(/[\s]+$/, '').replace(/[.!?]+$/, '').trim();
}

function cleanCaptured(value) {
  return stripTrailingPunctuation(String(value || '').replace(/^["'`]+|["'`]+$/g, ''));
}

function detectCreateGoal(original, lower) {
  const goalDirective = original.match(/^(?:please\s+)?(?:create|set|define|make)\s+(?:a\s+)?goal(?:\s+(?:to|for))?\s*(.+)$/i);
  if (goalDirective && goalDirective[1]) {
    const goal = cleanCaptured(goalDirective[1]);
    return goal
      ? { intent: 'create_goal', confidence: 0.92, data: { goal } }
      : { intent: 'create_goal', confidence: 0.7, data: { goal: stripTrailingPunctuation(original) } };
  }

  const goalPrefix = original.match(/^goal(?:s)?\s*[:\-]\s*(.+)$/i);
  if (goalPrefix && goalPrefix[1]) {
    const goal = cleanCaptured(goalPrefix[1]);
    if (goal) {
      return { intent: 'create_goal', confidence: 0.88, data: { goal } };
    }
  }

  if (lower.includes('create goal') || lower.startsWith('goal to ') || lower.includes('goal is to')) {
    return {
      intent: 'create_goal',
      confidence: 0.65,
      data: { goal: stripTrailingPunctuation(original.replace(/^(?:goal\s*(?:is\s*to|to)\s*)/i, '')) || stripTrailingPunctuation(original) }
    };
  }

  return null;
}

function detectOpen(original) {
  const match = original.match(/^(?:please\s+)?(?:open|show|view|launch|load|display)\s+(?:the\s+)?(.+)$/i);
  if (match && match[1]) {
    const target = cleanCaptured(match[1]);
    if (target) {
      return { intent: 'open', confidence: 0.85, data: { target } };
    }
  }

  const goTo = original.match(/^(?:go\s+to|navigate\s+to|switch\s+to)\s+(.+)$/i);
  if (goTo && goTo[1]) {
    const target = cleanCaptured(goTo[1]);
    if (target) {
      return { intent: 'open', confidence: 0.8, data: { target } };
    }
  }

  return null;
}

function detectLinkToCursor(original, lower) {
  if (!lower.includes('cursor') || !/(link|attach|connect)/.test(lower)) {
    return null;
  }

  const direct = original.match(/(?:link|attach|connect)\s+(?:this|the)?\s*(.+?)\s+(?:to|with)\s+cursor/i);
  if (direct && direct[1]) {
    const target = cleanCaptured(direct[1]);
    if (target) {
      return { intent: 'link_to_cursor', confidence: 0.86, data: { target } };
    }
  }

  const afterCursor = original.match(/cursor\s+(?:link|attach|connect)\s+(?:to\s+)?(.+)/i);
  if (afterCursor && afterCursor[1]) {
    const target = cleanCaptured(afterCursor[1]);
    if (target) {
      return { intent: 'link_to_cursor', confidence: 0.72, data: { target } };
    }
  }

  return { intent: 'link_to_cursor', confidence: 0.55, data: { target: stripTrailingPunctuation(original) } };
}

function detectSearch(original, lower) {
  const searchMatch = original.match(/(?:search|find|lookup|look\s*up|google|duckduckgo|bing)(?:\s+for)?\s+(.+)/i);
  if (searchMatch && searchMatch[1]) {
    const query = cleanCaptured(searchMatch[1]);
    if (query) {
      return { intent: 'search', confidence: 0.84, data: { query } };
    }
  }

  if (/^where|^who|^what|^when|^why|^how/.test(lower) && original.trim().endsWith('?')) {
    const query = stripTrailingPunctuation(original);
    return { intent: 'search', confidence: 0.6, data: { query } };
  }

  return null;
}

function detectIntent(message) {
  const original = normalizeInput(message);
  if (!original) return null;

  const lower = normalizeForMatch(original);
  const detectors = [detectCreateGoal, detectOpen, detectLinkToCursor, detectSearch];

  for (const detector of detectors) {
    const result = detector(original, lower);
    if (result && result.intent) {
      return result;
    }
  }

  return null;
}

function formatIntentMessage(result) {
  if (!result || !result.intent) return '';
  const { intent, data = {} } = result;

  switch (intent) {
    case 'create_goal': {
      const goal = data.goal ? `“${data.goal}”` : 'the requested objective';
      return `Create goal ${goal}.`;
    }
    case 'open': {
      const target = data.target ? `“${data.target}”` : 'the requested target';
      return `Open ${target}.`;
    }
    case 'link_to_cursor': {
      const target = data.target ? `Link ${data.target} to Cursor.` : 'Link the requested resource to Cursor.';
      return target;
    }
    case 'search': {
      const query = data.query ? `Search for “${data.query}”.` : 'Run a search for the requested query.';
      return query;
    }
    default:
      return '';
  }
}

function normalizeConfidence(value) {
  if (!Number.isFinite(value)) return undefined;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return Math.round(value * 100) / 100;
}

function safeJsonParse(value) {
  try {
    return value ? JSON.parse(value) : null;
  } catch (err) {
    return null;
  }
}

async function callFallbackProvider(message, hint) {
  const preferred = typeof hint === 'string' && hint.trim() ? hint.trim().toLowerCase() : null;
  const candidates = preferred ? [preferred, ...FALLBACK_PROVIDER_HINTS.filter((item) => item !== preferred)] : FALLBACK_PROVIDER_HINTS;

  for (const provider of candidates) {
    if (provider === 'openai' && process.env.OPENAI_API_KEY) {
      return callOpenAi(message);
    }
    if (provider === 'anthropic' && process.env.ANTHROPIC_API_KEY) {
      return callAnthropic(message);
    }
  }

  return null;
}

async function callOpenAi(message) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;

  const model = process.env.OPENAI_MODEL || 'gpt-4o-mini';
  const payload = JSON.stringify({
    model,
    messages: [
      {
        role: 'system',
        content: 'You are the Luka backend fallback assistant. Respond concisely with actionable insight when routing is unavailable.'
      },
      { role: 'user', content: message }
    ]
  });

  const response = await httpRequestJson('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`
    },
    body: payload,
    timeout: 20000
  });

  const parsed = safeJsonParse(response.body);
  if (response.status >= 200 && response.status < 300) {
    const text = extractTextFromPayload(parsed) || 'Provider did not return any content.';
    return { provider: 'openai', message: text, raw: parsed, status: response.status };
  }

  const detail = (parsed && (parsed.error?.message || parsed.message)) || response.body;
  const error = new Error(detail || `OpenAI request failed with status ${response.status}`);
  error.status = response.status;
  error.provider = 'openai';
  error.payload = parsed;
  throw error;
}

function extractAnthropicText(parsed) {
  if (!parsed || typeof parsed !== 'object') return '';
  if (Array.isArray(parsed.content)) {
    const texts = parsed.content
      .map((item) => (item && typeof item === 'object' && typeof item.text === 'string') ? item.text : '')
      .filter(Boolean);
    if (texts.length) return texts.join('\n');
  }
  if (parsed.output) {
    return extractAnthropicText(parsed.output);
  }
  return '';
}

async function callAnthropic(message) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) return null;

  const model = process.env.ANTHROPIC_MODEL || 'claude-3-5-sonnet-20241022';
  const payload = JSON.stringify({
    model,
    max_tokens: 512,
    messages: [
      { role: 'user', content: message }
    ]
  });

  const response = await httpRequestJson('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01'
    },
    body: payload,
    timeout: 20000
  });

  const parsed = safeJsonParse(response.body);
  if (response.status >= 200 && response.status < 300) {
    const direct = extractAnthropicText(parsed);
    const fallback = extractTextFromPayload(parsed);
    const text = direct || fallback || 'Provider did not return any content.';
    return { provider: 'anthropic', message: text, raw: parsed, status: response.status };
  }

  const detail = (parsed && (parsed.error?.message || parsed.message)) || response.body;
  const error = new Error(detail || `Anthropic request failed with status ${response.status}`);
  error.status = response.status;
  error.provider = 'anthropic';
  error.payload = parsed;
  throw error;
}

function httpRequestJson(targetUrl, options = {}) {
  const url = new URL(targetUrl);
  const isHttps = url.protocol === 'https:';
  const transport = isHttps ? https : http;
  const body = options.body || null;

  return new Promise((resolve, reject) => {
    const req = transport.request({
      protocol: url.protocol,
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: `${url.pathname}${url.search}`,
      method: options.method || 'GET',
      headers: Object.assign({}, options.headers || {}, body
        ? { 'Content-Length': Buffer.byteLength(body) }
        : {})
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        resolve({ status: res.statusCode, headers: res.headers, body: data });
      });
    });

    req.on('error', reject);
    req.setTimeout(options.timeout || 10000, () => {
      req.destroy(new Error('Request timed out'));
    });

    if (body) {
      req.write(body);
    }

    req.end();
  });
}

function extractTextFromPayload(payload) {
  if (payload == null) return '';
  if (typeof payload === 'string') return payload;
  if (Array.isArray(payload)) {
    return payload.map(extractTextFromPayload).filter(Boolean).join('\n');
  }

  if (payload.reply) return extractTextFromPayload(payload.reply);
  if (payload.response) return extractTextFromPayload(payload.response);
  if (payload.message) return extractTextFromPayload(payload.message);
  if (payload.output) return extractTextFromPayload(payload.output);
  if (payload.answer) return extractTextFromPayload(payload.answer);

  if (payload.choices && payload.choices.length) {
    const choice = payload.choices[0];
    if (choice && choice.message && typeof choice.message.content === 'string') {
      return choice.message.content;
    }
    if (typeof choice.text === 'string') {
      return choice.text;
    }
  }

  if (typeof payload.content === 'string') return payload.content;
  if (typeof payload.text === 'string') return payload.text;

  try {
    return JSON.stringify(payload);
  } catch (err) {
    return String(payload);
  }
}

function summarizeMcpHandshake(payload) {
  const lines = ['MCP handshake successful.'];
  if (!payload || typeof payload !== 'object') {
    lines.push('No additional metadata received from gateway.');
    return lines.join('\n');
  }

  const result = payload.result || {};
  const serverInfo = result.serverInfo || {};
  const capabilities = result.capabilities || {};

  if (serverInfo.name || serverInfo.version) {
    const label = [serverInfo.name, serverInfo.version].filter(Boolean).join(' ');
    if (label) lines.push(`Server: ${label}`);
  }

  if (Array.isArray(capabilities.tools) && capabilities.tools.length) {
    lines.push(`Tools: ${capabilities.tools.join(', ')}`);
  }

  if (Array.isArray(capabilities.resources) && capabilities.resources.length) {
    lines.push(`Resources: ${capabilities.resources.join(', ')}`);
  }

  lines.push('Note: Gateway exposes MCP protocol; use a compatible client for interactive chat.');
  return lines.join('\n');
}

async function callMcpGateway(message, target) {
  const baseUrl = target.baseUrl.replace(/\/+$/, '');
  const payloadVariants = [
    {
      endpoint: '/chat',
      body: JSON.stringify({ message, prompt: message, input: message }),
      headers: { 'Content-Type': 'application/json' }
    },
    {
      endpoint: '/api/chat',
      body: JSON.stringify({ message, prompt: message, input: message }),
      headers: { 'Content-Type': 'application/json' }
    },
    {
      endpoint: '/v1/chat/completions',
      body: JSON.stringify({
        model: target.model || 'default',
        messages: [{ role: 'user', content: message }]
      }),
      headers: { 'Content-Type': 'application/json' }
    }
  ];

  for (const variant of payloadVariants) {
    try {
      const response = await httpRequestJson(`${baseUrl}${variant.endpoint}`, {
        method: 'POST',
        headers: variant.headers,
        body: variant.body,
        timeout: 15000
      });

      if (response.status >= 200 && response.status < 300) {
        let parsed;
        try {
          parsed = response.body ? JSON.parse(response.body) : null;
        } catch (err) {
          parsed = response.body;
        }
        const text = extractTextFromPayload(parsed);
        if (text) {
          return { text, meta: { endpoint: variant.endpoint, status: response.status } };
        }
      }
    } catch (err) {
      continue;
    }
  }

  try {
    const handshakePayload = JSON.stringify({
      jsonrpc: '2.0',
      id: `codex-handshake-${Date.now()}`,
      method: 'initialize',
      params: {}
    });

    const response = await httpRequestJson(`${baseUrl}/mcp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: handshakePayload,
      timeout: 10000
    });

    if (response.status >= 200 && response.status < 300) {
      let parsed;
      try {
        parsed = response.body ? JSON.parse(response.body) : null;
      } catch (err) {
        parsed = null;
      }

      const text = summarizeMcpHandshake(parsed);
      if (text) {
        return { text, meta: { endpoint: '/mcp', status: response.status } };
      }
    }
  } catch (err) {
    // fall through to error throw
  }

  throw new Error(`${target.name} did not return a response`);
}

async function detectOllamaModel(baseUrl) {
  try {
    const response = await httpRequestJson(`${baseUrl}/api/tags`, { method: 'GET', timeout: 5000 });
    if (response.status >= 200 && response.status < 300) {
      const parsed = JSON.parse(response.body || '{}');
      const models = Array.isArray(parsed.models) ? parsed.models : [];
      if (models.length > 0) {
        const name = models[0].name || models[0].model;
        if (name) return name;
      }
    }
  } catch (err) {
    return null;
  }
  return null;
}

async function callOllama(message, target) {
  const baseUrl = target.baseUrl.replace(/\/+$/, '');
  const model = target.model || await detectOllamaModel(baseUrl) || 'llama3';

  const payload = JSON.stringify({
    model,
    messages: [
      { role: 'system', content: 'You are part of the 02luka local ensemble. Provide concise, high-signal answers.' },
      { role: 'user', content: message }
    ]
  });

  const response = await httpRequestJson(`${baseUrl}/v1/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: payload,
    timeout: 20000
  });

  if (response.status >= 200 && response.status < 300) {
    let parsed;
    try {
      parsed = response.body ? JSON.parse(response.body) : null;
    } catch (err) {
      parsed = response.body;
    }
    const text = extractTextFromPayload(parsed);
    if (text) {
      return { text, meta: { model, endpoint: '/v1/chat/completions', status: response.status } };
    }
  }

  throw new Error(`${target.name} did not return a response`);
}

async function executeTarget(targetId, message) {
  const target = CHAT_TARGETS[targetId];
  if (!target) {
    throw new Error(`Unknown target: ${targetId}`);
  }

  const startedAt = Date.now();

  if (target.type === 'mcp') {
    const result = await callMcpGateway(message, target);
    return {
      id: target.id,
      name: target.name,
      status: 'ok',
      text: result.text,
      latencyMs: Date.now() - startedAt,
      meta: result.meta
    };
  }

  if (target.type === 'ollama') {
    const result = await callOllama(message, target);
    return {
      id: target.id,
      name: target.name,
      status: 'ok',
      text: result.text,
      latencyMs: Date.now() - startedAt,
      meta: result.meta
    };
  }

  throw new Error(`Target ${target.name} is not actionable`);
}

async function orchestrateChat(message, targetId = 'auto') {
  const selected = CHAT_TARGETS[targetId] || CHAT_TARGETS.auto;
  const delegates = selected.type === 'aggregate' ? selected.delegates : [selected.id];

  const results = [];
  for (const id of delegates) {
    const startedAt = Date.now();
    try {
      const outcome = await executeTarget(id, message);
      results.push(outcome);
    } catch (err) {
      results.push({
        id,
        name: CHAT_TARGETS[id]?.name || id,
        status: 'error',
        error: err.message,
        latencyMs: Date.now() - startedAt
      });
    }
  }

  const successful = results.filter((item) => item.status === 'ok' && item.text);
  const best = successful.find((item) => item.meta?.endpoint !== '/mcp') || successful[0] || null;

  return {
    ok: Boolean(best),
    target: targetId,
    summary: best ? `Selected ${best.name}` : 'No delegates returned a response',
    best: best || null,
    results
  };
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    return res.end();
  }

  try {
    if (req.method === 'POST' && url.pathname === '/api/chat') {
      let raw = '';
      req.on('data', (chunk) => {
        raw += chunk;
        if (raw.length > 1_000_000) {
          req.destroy();
        }
      });

      req.on('end', async () => {
        try {
          const payload = raw ? JSON.parse(raw) : {};
          const message = normalizeInput(payload.message || payload.prompt || payload.input || '');
          if (!message) {
            return writeJson(res, 400, { ok: false, error: 'message is required' });
          }

          const intentResult = detectIntent(message);
          if (intentResult) {
            const responsePayload = {
              ok: true,
              intent: intentResult.intent,
              message: formatIntentMessage(intentResult) || null,
              data: intentResult.data || {}
            };

            const confidence = normalizeConfidence(intentResult.confidence);
            if (confidence !== undefined) {
              responsePayload.confidence = confidence;
            }

            return writeJson(res, 200, responsePayload);
          }

          const providerHint = typeof payload.provider === 'string' && payload.provider.trim()
            ? payload.provider.trim()
            : (typeof payload.target === 'string' && payload.target.trim() ? payload.target.trim() : null);

          try {
            const providerResult = await callFallbackProvider(message, providerHint);
            if (providerResult) {
              const responsePayload = {
                ok: true,
                intent: null,
                provider: providerResult.provider || 'unknown',
                message: providerResult.message || 'Provider returned no content.',
                meta: {}
              };

              if (providerResult.status) {
                responsePayload.meta.status = providerResult.status;
              }
              if (Object.keys(responsePayload.meta).length === 0) {
                delete responsePayload.meta;
              }
              if (providerResult.raw !== undefined) {
                responsePayload.raw = providerResult.raw;
              }

              return writeJson(res, 200, responsePayload);
            }

            return writeJson(res, 501, { ok: false, error: 'No AI provider configured on server' });
          } catch (err) {
            console.error('[boss-api] provider fallback failed', err);
            const status = err && Number.isInteger(err.status) && err.status >= 400 && err.status < 600
              ? err.status
              : 502;

            return writeJson(res, status, {
              ok: false,
              error: err && err.message ? err.message : 'Provider request failed',
              provider: err && err.provider ? err.provider : null,
              detail: err && err.payload ? err.payload : undefined
            });
          }
        } catch (err) {
          return writeJson(res, 400, { ok: false, error: 'Invalid JSON payload' });
        }
      });
      return;
    }

    // /api/list/:folder
    if (req.method === 'GET' && url.pathname.startsWith('/api/list/')) {
      const mailbox = decodeURIComponent(url.pathname.slice('/api/list/'.length));

      if (!mailbox) {
        return writeJson(res, 400, { error: 'Mailbox is required' });
      }

      if (!allowed.has(mailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox' });
      }

      const mailboxRoot = path.join(bossRoot, mailbox);
      const relMailbox = path.relative(bossRoot, mailboxRoot);
      if (relMailbox.startsWith('..') || path.isAbsolute(relMailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox path' });
      }

      let dirEntries;
      try {
        dirEntries = await fs.readdir(mailboxRoot, { withFileTypes: true });
      } catch (err) {
        if (err.code === 'ENOENT') {
          return writeJson(res, 404, { error: 'Mailbox not found' });
        }
        throw err;
      }

      const files = dirEntries.filter((entry) => entry.isFile() && !entry.name.startsWith('.'));
      const items = await Promise.all(files.map(async (entry) => {
        const filePath = path.join(mailboxRoot, entry.name);
        const stats = await fs.stat(filePath);
        return {
          id: entry.name,
          name: entry.name,
          path: path.relative(repoRoot, filePath),
          size: stats.size,
          updatedAt: stats.mtime.toISOString()
        };
      }));

      return writeJson(res, 200, { mailbox, items });
    }

    // /api/file/:folder/:name
    if (req.method === 'GET' && url.pathname.startsWith('/api/file/')) {
      const segments = url.pathname.split('/').filter(Boolean); // ['api','file',mailbox,...name]
      const mailbox = segments[2] ? decodeURIComponent(segments[2]) : '';
      const nameParts = segments.slice(3).map((part) => decodeURIComponent(part));
      const name = nameParts.join('/');

      if (!mailbox || !name) {
        return writeJson(res, 400, { error: 'Mailbox and filename are required' });
      }

      if (!allowed.has(mailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox' });
      }

      const mailboxRoot = path.join(bossRoot, mailbox);
      const relMailbox = path.relative(bossRoot, mailboxRoot);
      if (relMailbox.startsWith('..') || path.isAbsolute(relMailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox path' });
      }

      const targetFile = path.join(mailboxRoot, name);
      const relTarget = path.relative(mailboxRoot, targetFile);
      if (relTarget.startsWith('..') || path.isAbsolute(relTarget)) {
        return writeJson(res, 400, { error: 'Invalid filename' });
      }

      try {
        const data = await fs.readFile(targetFile, 'utf8');
        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(data);
      } catch (err) {
        if (err.code === 'ENOENT') {
          return writeJson(res, 404, { error: 'not found' });
        }
        return writeJson(res, 500, { error: 'Internal Server Error' });
      }
      return;
    }

    return writeJson(res, 404, { error: 'Not Found' });
  } catch (e) {
    console.error('[boss-api]', e.message || e);
    return writeJson(res, 500, { error: 'Internal Server Error' });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`boss-api listening on http://${HOST}:${PORT}`);
});
