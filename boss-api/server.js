const http = require('http');
const https = require('https');
const path = require('path');
const fs = require('fs/promises');
const { execFile } = require('child_process');

const HOST = process.env.HOST || '127.0.0.1';
const PORT = Number(process.env.PORT || 4000);
const repoRoot = path.resolve(__dirname, '..'); // 02luka-repo root

// ใช้ resolver ตามกติกา (ห้ามพาธฮาร์ดโค้ด)
function resolveKey(key) {
  return new Promise((resolve, reject) => {
    execFile(
      'bash',
      ['g/tools/path_resolver.sh', key],
      { cwd: repoRoot, encoding: 'utf8' },
      (err, stdout) => {
        if (err) return reject(err);
        resolve(stdout.trim());
      }
    );
  });
}

function json(res, code, payload) {
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
          const message = (payload.message || payload.prompt || payload.input || '').trim();
          if (!message) {
            return json(res, 400, { error: 'message is required' });
          }

          const targetId = typeof payload.target === 'string' && payload.target.trim()
            ? payload.target.trim()
            : 'auto';

          try {
            const result = await orchestrateChat(message, targetId);
            return json(res, 200, result);
          } catch (err) {
            console.error('[boss-api] chat orchestration failed', err);
            return json(res, 502, { error: 'Chat orchestration failed', detail: err.message });
          }
        } catch (err) {
          return json(res, 400, { error: 'Invalid JSON payload' });
        }
      });
      return;
    }

    // /api/list/:folder
    if (req.method === 'GET' && url.pathname.startsWith('/api/list/')) {
      const folder = url.pathname.slice('/api/list/'.length);
      if (!allowed.has(folder)) return json(res, 400, { error: 'Invalid folder' });

      const abs = await resolveKey(`human:${folder}`);
      const dirEntries = await fs.readdir(abs, { withFileTypes: true });
      const files = dirEntries.filter(e => e.isFile() && !e.name.startsWith('.'));

      const items = await Promise.all(files.map(async e => {
        const full = path.join(abs, e.name);
        const st = await fs.stat(full);
        return {
          id: e.name,
          name: e.name,
          path: path.relative(repoRoot, full),
          size: st.size,
          updatedAt: st.mtime.toISOString(),
        };
      }));

      return json(res, 200, { mailbox: folder, items });
    }

    // /api/file/:folder/:name
    if (req.method === 'GET' && url.pathname.startsWith('/api/file/')) {
      const parts = url.pathname.split('/').filter(Boolean); // ['api','file',folder, ...name]
      const folder = parts[2];
      const name = parts.slice(3).join('/'); // allow nested if any

      if (!folder || !name) return json(res, 400, { error: 'folder and name required' });
      if (!allowed.has(folder)) return json(res, 400, { error: 'Invalid folder' });

      const abs = await resolveKey(`human:${folder}`);
      const full = path.join(abs, name);

      // ป้องกัน path traversal
      if (!full.startsWith(abs)) return json(res, 400, { error: 'Invalid path' });

      try {
        const stat = await fs.stat(full);
        if (!stat.isFile()) return json(res, 404, { error: 'not found' });
        const data = await fs.readFile(full, 'utf8');
        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8',
          'Access-Control-Allow-Origin': '*'
        });
        return res.end(data);
      } catch {
        return json(res, 404, { error: 'not found' });
      }
    }

    return json(res, 404, { error: 'Not Found' });
  } catch (e) {
    console.error('[boss-api]', e.message || e);
    return json(res, 500, { error: 'Internal Server Error' });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`boss-api listening on http://${HOST}:${PORT}`);
});
