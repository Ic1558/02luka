const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('node:path');
const fs = require('node:fs');

const app = express();

const PORT = Number.parseInt(process.env.PORT || process.env.BOSS_API_PORT || '7010', 10);
const HOST = process.env.HOST || '0.0.0.0';
const UI_ROOT = process.env.UI_ROOT || path.join(__dirname, '..', 'boss-ui');

const defaultGateways = {
  mcpDocker: process.env.MCP_DOCKER_URL || 'http://127.0.0.1:5012',
  mcpFs: process.env.MCP_FS_URL || 'http://127.0.0.1:8765',
  ollama: process.env.OLLAMA_URL || 'http://127.0.0.1:11434'
};

const gatewayAliases = new Map([
  ['mcpdocker', 'mcpDocker'],
  ['mcp-docker', 'mcpDocker'],
  ['mcp', 'mcpDocker'],
  ['docker', 'mcpDocker'],
  ['mcpfs', 'mcpFs'],
  ['fs', 'mcpFs'],
  ['fs-mcp', 'mcpFs'],
  ['ollama', 'ollama']
]);

const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

if (corsOrigins.length > 0) {
  app.use(
    cors({
      origin(origin, callback) {
        if (!origin || corsOrigins.includes(origin)) {
          callback(null, true);
        } else {
          callback(new Error('Not allowed by CORS'));
        }
      }
    })
  );
} else {
  app.use(cors());
}

app.use(express.json({ limit: '5mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

if (fs.existsSync(UI_ROOT)) {
  app.use(express.static(UI_ROOT));
}

function resolveGateway(input) {
  if (!input) {
    throw new Error('Gateway is required');
  }

  const key = gatewayAliases.get(input.toLowerCase()) || input;
  const target = defaultGateways[key];

  if (!target) {
    throw new Error(`Unknown gateway: ${input}`);
  }

  return { key, url: target };
}

function pickHeaders(headers) {
  if (!headers || typeof headers !== 'object') {
    return {};
  }

  const allowed = {};
  for (const [name, value] of Object.entries(headers)) {
    if (typeof value === 'string') {
      allowed[name.toLowerCase()] = value;
    }
  }
  return allowed;
}

function isJson(headers) {
  const contentType = headers.get('content-type');
  return contentType && contentType.includes('application/json');
}

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    gateways: defaultGateways
  });
});

app.get('/config', (req, res) => {
  res.json({
    gateways: defaultGateways,
    cors: corsOrigins,
    updatedAt: new Date().toISOString()
  });
});

app.post('/chat', async (req, res, next) => {
  try {
    const {
      gateway,
      path: gatewayPath,
      method = 'POST',
      payload,
      headers,
      timeoutMs = 90_000
    } = req.body || {};

    if (!gatewayPath || typeof gatewayPath !== 'string') {
      return res.status(400).json({ error: 'path is required' });
    }

    const { url: baseUrl, key } = resolveGateway(gateway);
    const target = new URL(gatewayPath, baseUrl);

    const upperMethod = method.toUpperCase();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    const outgoingHeaders = pickHeaders(headers);
    const fetchOptions = {
      method: upperMethod,
      headers: outgoingHeaders,
      signal: controller.signal
    };

    if (upperMethod !== 'GET' && upperMethod !== 'HEAD') {
      if (payload === undefined || payload === null) {
        fetchOptions.body = undefined;
      } else if (typeof payload === 'string') {
        fetchOptions.body = payload;
      } else {
        fetchOptions.body = JSON.stringify(payload);
        if (!outgoingHeaders['content-type']) {
          fetchOptions.headers['content-type'] = 'application/json';
        }
      }
    }

    let response;
    try {
      response = await fetch(target, fetchOptions);
    } finally {
      clearTimeout(timeout);
    }

    const responseHeaders = response.headers;
    let body;

    if (isJson(responseHeaders)) {
      body = await response.json();
    } else {
      body = await response.text();
    }

    res.status(response.status).json({
      gateway: key,
      url: target.toString(),
      status: response.status,
      ok: response.ok,
      headers: Object.fromEntries(responseHeaders.entries()),
      body
    });
  } catch (error) {
    if (error.name === 'AbortError') {
      return res.status(504).json({ error: 'Gateway timeout', details: 'Upstream did not respond in time' });
    }

    next(error);
  }
});

app.use((req, res, next) => {
  if (!fs.existsSync(UI_ROOT)) {
    return next();
  }

  if (req.method === 'GET' && req.accepts('html')) {
    const indexPath = path.join(UI_ROOT, 'index.html');
    if (fs.existsSync(indexPath)) {
      return res.sendFile(indexPath);
    }
  }

  return next();
});

app.use((err, req, res, _next) => {
  console.error('[boss-api] error', err);
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal Server Error'
  });
});

app.listen(PORT, HOST, () => {
  console.log(`boss-api listening on http://${HOST}:${PORT}`);
});
