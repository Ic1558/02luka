const http = require('http');
const https = require('https');
const path = require('path');
const fs = require('fs/promises');
const { execFile } = require('child_process');
const anthropicConnector = require('../g/connectors/mcp_anthropic');
const openaiConnector = require('../g/connectors/mcp_openai');

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

const CANONICAL_MAILBOXES = ['inbox', 'outbox', 'drafts', 'sent', 'deliverables'];
const MAILBOX_ALIASES = { dropbox: 'outbox' };
const MAILBOX_LABELS = {
  inbox: 'Inbox',
  outbox: 'Outbox',
  drafts: 'Drafts',
  sent: 'Sent',
  deliverables: 'Deliverables'
};
const MAILBOX_ROLES = {
  inbox: 'incoming',
  outbox: 'staging',
  drafts: 'revision',
  sent: 'dispatch',
  deliverables: 'final'
};
const canonicalMailboxSet = new Set(CANONICAL_MAILBOXES);
const allowed = new Set([...CANONICAL_MAILBOXES, ...Object.keys(MAILBOX_ALIASES)]);
const uploadTargets = new Set(['inbox', 'outbox', 'drafts']);
const goalTargets = new Set(['outbox', 'drafts']);
const MAX_UPLOAD_SIZE = 20 * 1024 * 1024; // 20MB safeguard

function normalizeMailbox(mailbox) {
  if (!mailbox) return '';
  const key = String(mailbox).toLowerCase();
  return MAILBOX_ALIASES[key] || key;
}

function resolveHumanPath(mailbox) {
  const canonical = normalizeMailbox(mailbox);
  return new Promise((resolve, reject) => {
    const child = execFile(
      'bash',
      ['g/tools/path_resolver.sh', `human:${canonical}`],
      { cwd: repoRoot },
      (err, stdout, stderr) => {
        if (err) {
          err.stderr = stderr;
          return reject(err);
        }
        resolve(stdout.trim());
      }
    );

  });
}

function runModelRouter(taskType, hints = '') {
  return new Promise((resolve) => {
    const args = ['g/tools/model_router.sh', taskType];
    if (hints) {
      args.push(hints);
    }

    execFile('bash', args, { cwd: repoRoot }, (err, stdout, stderr) => {
      if (err) {
        console.error('[boss-api] model_router failed', err, stderr);
        return resolve(null);
      }

      const text = (stdout || '').trim();
      if (!text) {
        return resolve(null);
      }

      try {
        const parsed = JSON.parse(text);
        resolve(parsed);
      } catch (parseErr) {
        console.error('[boss-api] model_router parse error', parseErr, text);
        resolve(null);
      }
    });
  });
}

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

const hasAnthropicKey = () => Boolean(process.env.ANTHROPIC_API_KEY);
const hasOpenAiKey = () => Boolean(process.env.OPENAI_API_KEY);

function localOptimizePrompt({ system, user, context }) {
  const sections = [];

  if (system && system.trim()) {
    const cleaned = system.trim().split(/\n+/).map((line) => line.trim()).filter(Boolean);
    if (cleaned.length) {
      sections.push(`System Directive:\n- ${cleaned.join('\n- ')}`);
    }
  }

  if (context && context.trim()) {
    const cleaned = context.trim().split(/\n+/).map((line) => line.trim()).filter(Boolean);
    if (cleaned.length) {
      sections.push(`Context:\n- ${cleaned.join('\n- ')}`);
    }
  }

  if (user && user.trim()) {
    const cleaned = user.trim().split(/\n+/).map((line) => line.trim()).filter(Boolean);
    if (cleaned.length) {
      sections.push(`Task:\n- ${cleaned.join('\n- ')}`);
    }
  }

  const draft = sections.join('\n\n').trim();
  return draft || String(user || '').trim();
}

async function optimizePromptWithOllama({ system, user, context, model, routerMeta }) {
  const blocks = [];
  if (system && system.trim()) {
    blocks.push(`System Directive:\n${system.trim()}`);
  }
  if (context && context.trim()) {
    blocks.push(`Context:\n${context.trim()}`);
  }
  if (user && user.trim()) {
    blocks.push(`Original Prompt:\n${user.trim()}`);
  }

  const guidance = [
    'Rewrite the prompt for a coding-focused assistant.',
    'Integrate important context and system directives succinctly.',
    'Respond with the improved prompt only—no explanations or bullet lists unless required by the task.'
  ].join('\n');

  const userPayload = blocks.length
    ? `${blocks.join('\n\n')}\n\n${guidance}`
    : guidance;

  const messages = [
    {
      role: 'system',
      content: 'You are a senior prompt engineer. When asked, return a single optimized prompt ready for execution. Do not add commentary.'
    },
    {
      role: 'user',
      content: userPayload
    }
  ];

  return callOllama('Optimize prompt', CHAT_TARGETS.ollama, {
    model,
    messages,
    router: routerMeta,
    reason: 'optimize_prompt'
  });
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

async function callOllama(message, target, options = {}) {
  const baseUrlSource = options.baseUrl || target.baseUrl;
  const baseUrl = baseUrlSource.replace(/\/+$/, '');
  const modelOverride = typeof options.model === 'string' && options.model.trim() ? options.model.trim() : null;
  const model = modelOverride || target.model || await detectOllamaModel(baseUrl) || 'llama3';

  const defaultSystem = options.system
    || 'You are part of the 02luka local ensemble. Provide concise, high-signal answers.';
  const defaultMessages = [
    { role: 'system', content: defaultSystem },
    { role: 'user', content: message }
  ];

  const messages = Array.isArray(options.messages) && options.messages.length
    ? options.messages
    : defaultMessages;

  const payload = JSON.stringify({
    model,
    messages
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
      const meta = { model, endpoint: '/v1/chat/completions', status: response.status };
      if (options.router) {
        meta.router = options.router;
      }
      if (options.reason) {
        meta.reason = options.reason;
      }
      return { text, meta };
    }
  }

  throw new Error(`${target.name} did not return a response`);
}

async function executeTarget(targetId, message, options = {}) {
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
    const result = await callOllama(message, target, options);
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

async function orchestrateChat(message, targetId = 'auto', options = {}) {
  const selected = CHAT_TARGETS[targetId] || CHAT_TARGETS.auto;
  const delegates = selected.type === 'aggregate' ? selected.delegates : [selected.id];

  const results = [];
  for (const id of delegates) {
    const startedAt = Date.now();
    try {
      const outcome = await executeTarget(id, message, options);
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

  // Fallback when no delegates are available
  if (!best && results.length > 0 && results.every(r => r.status === 'error')) {
    const fallbackResponse = {
      ok: true,
      target: targetId,
      summary: 'Local fallback response (delegates unavailable)',
      best: {
        id: 'fallback',
        name: 'Local Fallback',
        text: `I received your message: "${message}". The external delegates (MCP, Ollama) are not currently available, but I can still help you with basic tasks. Try asking me to "open inbox" or "list files" for local operations.`,
        status: 'ok',
        latencyMs: 1
      },
      results: results.concat([{
        id: 'fallback',
        name: 'Local Fallback',
        status: 'ok',
        text: 'Fallback response provided',
        latencyMs: 1
      }])
    };
    if (options.router) {
      fallbackResponse.router = options.router;
    }
    return fallbackResponse;
  }

  const payload = {
    ok: Boolean(best),
    target: targetId,
    summary: best ? `Selected ${best.name}` : 'No delegates returned a response',
    best: best || null,
    results
  };

  if (options.router) {
    payload.router = options.router;
    if (best) {
      best.meta = Object.assign({}, best.meta || {}, { router: options.router });
    }
  }

  return payload;
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
    // Capabilities endpoint to enable full UI features
    if (req.method === 'GET' && url.pathname === '/api/capabilities') {
      const hasServerModels = hasAnthropicKey() || hasOpenAiKey();
      const aliasList = Object.entries(MAILBOX_ALIASES).map(([alias, target]) => ({ alias, target }));
      const mailboxList = CANONICAL_MAILBOXES.map((id) => ({
        id,
        label: MAILBOX_LABELS[id] || id,
        role: MAILBOX_ROLES[id] || 'general',
        uploads: uploadTargets.has(id),
        goalTarget: goalTargets.has(id)
      }));

      return writeJson(res, 200, {
        ui: {
          inbox: true,
          preview: true,
          prompt_composer: true,
          connectors: true
        },
        mailboxes: {
          flow: CANONICAL_MAILBOXES,
          list: mailboxList,
          aliases: aliasList
        },
        features: {
          goal: true,
          optimize_prompt: true,
          chat: true,
          nlu: Boolean(process.env.NLU_ENABLED)
        },
        engine: {
          local: true,
          server_models: hasServerModels
        }
      });
    }

    if (req.method === 'GET' && url.pathname === '/api/connectors/status') {
      return writeJson(res, 200, {
        anthropic: { ready: hasAnthropicKey() },
        openai: { ready: hasOpenAiKey() },
        local: { ready: true }
      });
    }

    if (req.method === 'POST' && url.pathname === '/api/optimize_prompt') {
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
          const system = typeof payload.system === 'string' ? payload.system : '';
          const userPrompt = typeof payload.user === 'string'
            ? payload.user
            : (typeof payload.prompt === 'string' ? payload.prompt : '');
          const context = typeof payload.context === 'string' ? payload.context : '';
          const strategy = typeof payload.strategy === 'string' ? payload.strategy.toLowerCase() : 'auto';
          const requestedEngine = typeof payload.engine === 'string' ? payload.engine.toLowerCase() : 'local';
          const hints = typeof payload.hints === 'string' ? payload.hints : '';

          const normalizedStrategy = strategy === 'manual' ? 'manual' : 'auto';

          let engineUsed = 'local';
          let optimizedText = '';
          let meta = { strategy: normalizedStrategy };

          const wantsAnthropic = normalizedStrategy === 'manual'
            && requestedEngine === 'anthropic'
            && hasAnthropicKey();
          const wantsOpenAi = normalizedStrategy === 'manual'
            && requestedEngine === 'openai'
            && hasOpenAiKey();
          const shouldUseRouter = normalizedStrategy === 'auto'
            || requestedEngine === 'auto'
            || requestedEngine === 'local';

          try {
            if (wantsAnthropic) {
              const response = await anthropicConnector.optimizePrompt({ system, user: userPrompt, context });
              optimizedText = String(response.text || '').trim();
              engineUsed = 'anthropic';
              meta = Object.assign({}, meta, response.raw && typeof response.raw === 'object' ? {
                model: response.raw.model || null,
                id: response.raw.id || null
              } : {});
            } else if (wantsOpenAi) {
              const response = await openaiConnector.optimizePrompt({ system, user: userPrompt, context });
              optimizedText = String(response.text || '').trim();
              engineUsed = 'openai';
              meta = Object.assign({}, meta, response.raw && typeof response.raw === 'object' ? {
                model: response.raw.model || null,
                id: response.raw.id || null
              } : {});
            }
          } catch (err) {
            console.error('[boss-api] optimize connector failed', err);
            engineUsed = 'local';
            optimizedText = '';
            meta = Object.assign({}, meta, { fallback: true, error: err.message });
          }

          let routerDecision = null;

          if (!optimizedText && shouldUseRouter) {
            try {
              const routerHints = hints || (userPrompt ? userPrompt.slice(0, 240) : '');
              routerDecision = await runModelRouter('optimize', routerHints);
            } catch (err) {
              console.error('[boss-api] model_router optimize lookup failed', err);
            }

            if (routerDecision && routerDecision.model) {
              try {
                const result = await optimizePromptWithOllama({
                  system,
                  user: userPrompt,
                  context,
                  model: routerDecision.model,
                  routerMeta: routerDecision
                });
                const routedText = String(result?.text || '').trim();
                if (routedText) {
                  optimizedText = routedText;
                  engineUsed = 'ollama';
                  meta = Object.assign({}, meta, result.meta || {}, { router: routerDecision, source: 'ollama' });
                }
              } catch (err) {
                console.error('[boss-api] ollama optimize failed', err);
                meta = Object.assign({}, meta, { router: routerDecision, router_error: err.message });
              }
            }
          }

          if (routerDecision && !meta.router) {
            meta = Object.assign({}, meta, { router: routerDecision });
          }

          if (!optimizedText) {
            optimizedText = localOptimizePrompt({ system, user: userPrompt, context });
            engineUsed = 'local';
            meta = Object.assign({}, meta, { heuristic: true });
          }

          return writeJson(res, 200, {
            ok: Boolean(optimizedText),
            engine: engineUsed,
            prompt: optimizedText,
            meta
          });
        } catch (err) {
          console.error('[boss-api] optimize parsing failed', err);
          return writeJson(res, 400, { error: 'Invalid JSON payload' });
        }
      });
      return;
    }

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
          const message = (payload.message || payload.prompt || payload.input || '').trim();
          if (!message) {
            return writeJson(res, 400, { error: 'message is required' });
          }

          const requestedEngine = typeof payload.engine === 'string' ? payload.engine.toLowerCase() : 'local';
          const system = typeof payload.system === 'string' ? payload.system : '';
          const model = typeof payload.model === 'string' ? payload.model : undefined;
          const strategy = typeof payload.strategy === 'string' ? payload.strategy.toLowerCase() : 'auto';
          const hints = typeof payload.hints === 'string' ? payload.hints : '';

          const normalizedStrategy = strategy === 'manual' ? 'manual' : 'auto';
          const wantsAnthropic = normalizedStrategy === 'manual'
            && requestedEngine === 'anthropic'
            && hasAnthropicKey();
          const wantsOpenAi = normalizedStrategy === 'manual'
            && requestedEngine === 'openai'
            && hasOpenAiKey();
          const shouldUseRouter = normalizedStrategy === 'auto'
            || requestedEngine === 'auto'
            || requestedEngine === 'local';

          let routerDecision = null;
          if (shouldUseRouter) {
            try {
              const routerHints = hints || message.slice(0, 240);
              routerDecision = await runModelRouter('generate', routerHints);
            } catch (err) {
              console.error('[boss-api] model_router chat lookup failed', err);
            }
          }

          if (wantsAnthropic || wantsOpenAi) {
            try {
              const connector = wantsAnthropic ? anthropicConnector : openaiConnector;
              const engineUsed = wantsAnthropic ? 'anthropic' : 'openai';
              const response = await connector.chat({ input: message, system, model });
              const text = String(response.text || '').trim();
              return writeJson(res, 200, {
                ok: Boolean(text),
                engine: engineUsed,
                response: text,
                meta: Object.assign({ strategy: normalizedStrategy }, response.raw && typeof response.raw === 'object' ? {
                  model: response.raw.model || null,
                  id: response.raw.id || null
                } : {})
              });
            } catch (err) {
              console.error('[boss-api] chat connector failed', err);
              // fall through to local orchestration below
            }
          }

          const targetId = typeof payload.target === 'string' && payload.target.trim()
            ? payload.target.trim()
            : 'auto';

          const orchestrationOptions = {};
          if (routerDecision && routerDecision.model) {
            orchestrationOptions.model = routerDecision.model;
            orchestrationOptions.router = routerDecision;
          }

          try {
            const result = await orchestrateChat(message, targetId, orchestrationOptions);
            if (!result.router && routerDecision) {
              result.router = routerDecision;
            }
            result.strategy = normalizedStrategy;
            return writeJson(res, 200, result);
          } catch (err) {
            console.error('[boss-api] chat orchestration failed', err);
            return writeJson(res, 502, { error: 'Chat orchestration failed', detail: err.message });
          }
        } catch (err) {
          return writeJson(res, 400, { error: 'Invalid JSON payload' });
        }
      });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/goal') {
      const requestedTarget = (url.searchParams.get('target') || 'outbox').trim().toLowerCase();
      const mailbox = normalizeMailbox(requestedTarget);

      if (!mailbox || !goalTargets.has(mailbox)) {
        return writeJson(res, 400, { error: 'Invalid goal target' });
      }

      let raw = '';
      req.on('data', (chunk) => {
        raw += chunk;
        if (raw.length > 1_000_000) {
          req.destroy(new Error('Payload too large'));
        }
      });

      req.on('end', async () => {
        try {
          const payload = raw ? JSON.parse(raw) : {};
          const title = typeof payload.title === 'string' ? payload.title.trim() : '';
          const summary = typeof payload.summary === 'string' ? payload.summary.trim() : '';
          const body = typeof payload.body === 'string' ? payload.body.trim() : '';
          const system = typeof payload.system === 'string' ? payload.system.trim() : '';
          const context = typeof payload.context === 'string' ? payload.context.trim() : '';
          const prompt = typeof payload.prompt === 'string' ? payload.prompt.trim() : '';

          let targetDir = await resolveHumanPath(mailbox);
          if (!targetDir) {
            return writeJson(res, 500, { error: 'Failed to resolve goal target' });
          }

          await fs.mkdir(targetDir, { recursive: true });
          const stats = await fs.lstat(targetDir);
          if (!stats.isDirectory() || stats.isSymbolicLink()) {
            return writeJson(res, 500, { error: 'Goal target unavailable' });
          }

          const realDir = await fs.realpath(targetDir);
          const now = new Date();
          const stamp = now.toISOString().replace(/[-:]/g, '').replace('T', '').split('.')[0];
          const slug = title
            ? title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40)
            : '';
          const baseName = slug ? `goal_${stamp}_${slug}` : `goal_${stamp}`;

          let finalName = `${baseName}.md`;
          let counter = 1;
          while (counter < 100) {
            try {
              await fs.access(path.join(realDir, finalName));
              finalName = `${baseName}_${counter}.md`;
              counter += 1;
            } catch (err) {
              if (err.code === 'ENOENT') {
                break;
              }
              throw err;
            }
          }

          const lines = [];
          if (title) {
            lines.push(`# GOAL: ${title}`);
          } else {
            lines.push('# GOAL DRAFT');
          }

          lines.push('');
          lines.push(`- Created: ${now.toISOString()}`);
          lines.push(`- Mailbox: ${MAILBOX_LABELS[mailbox] || mailbox}`);
          if (summary) {
            lines.push(`- Summary: ${summary}`);
          }
          lines.push('');

          if (body) {
            lines.push(body);
            lines.push('');
          }

          if (system) {
            lines.push('## System Directive');
            lines.push('');
            lines.push(system);
            lines.push('');
          }

          if (context) {
            lines.push('## Context');
            lines.push('');
            lines.push(context);
            lines.push('');
          }

          if (prompt) {
            lines.push('## Prompt Draft');
            lines.push('');
            lines.push(prompt);
            lines.push('');
          }

          const finalPath = path.join(realDir, finalName);
          await fs.writeFile(finalPath, lines.join('\n'), 'utf8');

          return writeJson(res, 200, {
            ok: true,
            mailbox,
            name: finalName,
            path: path.relative(repoRoot, finalPath),
            createdAt: now.toISOString()
          });
        } catch (err) {
          console.error('[boss-api] goal creation failed', err);
          return writeJson(res, 500, { error: 'Failed to create goal' });
        }
      });

      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/upload') {
      const requestedMailbox = (url.searchParams.get('mailbox') || '').trim().toLowerCase();
      const mailbox = normalizeMailbox(requestedMailbox);
      if (!mailbox || !uploadTargets.has(mailbox)) {
        return writeJson(res, 400, { error: 'Invalid mailbox' });
      }

      const contentType = req.headers['content-type'] || '';
      const boundaryMatch = contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/i);
      const boundaryToken = boundaryMatch ? boundaryMatch[1] || boundaryMatch[2] : '';
      if (!boundaryToken) {
        return writeJson(res, 400, { error: 'Missing multipart boundary' });
      }

      const boundaryBuffer = Buffer.from(`--${boundaryToken}`);
      const endBoundaryBuffer = Buffer.from(`\r\n--${boundaryToken}`);
      const chunks = [];
      let totalSize = 0;
      let responded = false;
      const safeWrite = (code, payload) => {
        if (responded) return;
        responded = true;
        writeJson(res, code, payload);
      };

      req.on('data', (chunk) => {
        if (responded) return;
        totalSize += chunk.length;
        if (totalSize > MAX_UPLOAD_SIZE) {
          safeWrite(413, { error: 'File too large' });
          req.destroy();
          return;
        }
        chunks.push(chunk);
      });

      req.on('error', (err) => {
        if (responded) return;
        console.error('[boss-api] upload stream error', err);
        safeWrite(500, { error: 'Upload failed' });
      });

      req.on('end', async () => {
        if (responded) return;
        try {
          const buffer = Buffer.concat(chunks);
          if (buffer.indexOf(boundaryBuffer) !== 0) {
            return safeWrite(400, { error: 'Malformed multipart payload' });
          }

          let offset = boundaryBuffer.length;
          if (buffer[offset] === 13 && buffer[offset + 1] === 10) {
            offset += 2; // skip CRLF
          }

          const headerEndToken = Buffer.from('\r\n\r\n');
          const headerEnd = buffer.indexOf(headerEndToken, offset);
          if (headerEnd === -1) {
            return safeWrite(400, { error: 'Malformed multipart headers' });
          }

          const headerText = buffer.slice(offset, headerEnd).toString('utf8');
          const dispositionLine = headerText
            .split(/\r?\n/)
            .find((line) => line.toLowerCase().startsWith('content-disposition'));
          if (!dispositionLine) {
            return safeWrite(400, { error: 'Missing content disposition' });
          }

          const fieldNameMatch = dispositionLine.match(/name="([^"]*)"/i) || dispositionLine.match(/name=([^;]+)/i);
          const fieldName = fieldNameMatch ? fieldNameMatch[1].trim().replace(/[\r\n\u0000]/g, '') : '';
          if (fieldName !== 'file') {
            return safeWrite(400, { error: 'Invalid field name' });
          }

          let filename = '';
          const quotedMatch = dispositionLine.match(/filename="([^"]*)"/i);
          if (quotedMatch) {
            filename = quotedMatch[1];
          } else {
            const bareMatch = dispositionLine.match(/filename=([^;]+)/i);
            if (bareMatch) {
              filename = bareMatch[1];
            }
          }

          filename = filename.trim().replace(/[\r\n\u0000]/g, '');
          if (!filename) {
            return safeWrite(400, { error: 'Filename is required' });
          }

          if (filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
            return safeWrite(400, { error: 'Invalid filename' });
          }

          if (path.isAbsolute(filename)) {
            return safeWrite(400, { error: 'Invalid filename' });
          }

          const dataStart = headerEnd + headerEndToken.length;
          const dataEnd = buffer.indexOf(endBoundaryBuffer, dataStart);
          if (dataEnd === -1) {
            return safeWrite(400, { error: 'Malformed multipart payload' });
          }

          const fileBuffer = buffer.slice(dataStart, dataEnd);

          let targetDir = await resolveHumanPath(mailbox);
          if (!targetDir) {
            return safeWrite(500, { error: 'Failed to resolve mailbox' });
          }

          const dirStat = await fs.lstat(targetDir);
          if (!dirStat.isDirectory() || dirStat.isSymbolicLink()) {
            return safeWrite(500, { error: 'Upload directory unavailable' });
          }

          const realDir = await fs.realpath(targetDir);
          const finalPath = path.join(realDir, filename);
          const finalReal = path.resolve(realDir, filename);
          if (finalReal !== finalPath) {
            return safeWrite(400, { error: 'Invalid filename' });
          }

          if (!finalReal.startsWith(realDir + path.sep) && finalReal !== realDir) {
            return safeWrite(400, { error: 'Invalid filename' });
          }

          await fs.writeFile(finalReal, fileBuffer);

          safeWrite(200, { ok: true, name: filename });
        } catch (err) {
          console.error('[boss-api] upload failed', err);
          safeWrite(500, { error: 'Upload failed' });
        }
      });

      return;
    }

    // /api/list/:folder
    if (req.method === 'GET' && url.pathname.startsWith('/api/list/')) {
      const requestedMailbox = decodeURIComponent(url.pathname.slice('/api/list/'.length));
      const mailboxKey = requestedMailbox.toLowerCase();
      const mailbox = normalizeMailbox(mailboxKey);

      if (!mailbox) {
        return writeJson(res, 400, { error: 'Mailbox is required' });
      }

      if (!canonicalMailboxSet.has(mailbox)) {
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

      const response = { mailbox, items };
      if (MAILBOX_ALIASES[mailboxKey]) {
        response.aliasOf = MAILBOX_ALIASES[mailboxKey];
      }

      return writeJson(res, 200, response);
    }

    // /api/file/:folder/:name
    if (req.method === 'GET' && url.pathname.startsWith('/api/file/')) {
      const segments = url.pathname.split('/').filter(Boolean); // ['api','file',mailbox,...name]
      const requestedMailbox = segments[2] ? decodeURIComponent(segments[2]) : '';
      const mailboxKey = requestedMailbox.toLowerCase();
      const mailbox = normalizeMailbox(mailboxKey);
      const nameParts = segments.slice(3).map((part) => decodeURIComponent(part));
      const name = nameParts.join('/');

      if (!mailbox || !name) {
        return writeJson(res, 400, { error: 'Mailbox and filename are required' });
      }

      if (!canonicalMailboxSet.has(mailbox)) {
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
