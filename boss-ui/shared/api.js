// Shared API helpers for Luka UI
// Provides safe JSON fetch wrappers with runtime config discovery via /config.json

const DEFAULT_BASE = 'http://127.0.0.1:4000';

function sanitizeBase(input) {
  if (!input || typeof input !== 'string') {
    return undefined;
  }
  const trimmed = input.trim();
  if (!trimmed) {
    return undefined;
  }
  return trimmed.replace(/\/+$/, '');
}

const runtimeConfig = {
  apiBase: sanitizeBase(typeof window !== 'undefined' ? window.API_BASE : undefined) || DEFAULT_BASE,
  aiBase: sanitizeBase(typeof window !== 'undefined' ? window.AI_BASE : undefined)
    || sanitizeBase(typeof window !== 'undefined' ? window.API_BASE : undefined)
    || DEFAULT_BASE,
  agentsBase: sanitizeBase(typeof window !== 'undefined' ? window.AGENTS_BASE : undefined)
    || sanitizeBase(typeof window !== 'undefined' ? window.API_BASE : undefined)
    || DEFAULT_BASE,
  raw: null
};

let configPromise = null;

function snapshotConfig() {
  return {
    apiBase: runtimeConfig.apiBase,
    aiBase: runtimeConfig.aiBase,
    agentsBase: runtimeConfig.agentsBase,
    raw: runtimeConfig.raw ? JSON.parse(JSON.stringify(runtimeConfig.raw)) : null
  };
}

function applyWindowConfig() {
  if (typeof window === 'undefined') {
    return;
  }
  window.API_BASE = runtimeConfig.apiBase;
  window.AI_BASE = runtimeConfig.aiBase;
  window.AGENTS_BASE = runtimeConfig.agentsBase;
  window.LUKA_CONFIG = snapshotConfig();
}

function updateRuntimeConfig(partial) {
  if (partial && typeof partial === 'object') {
    if (partial.api && typeof partial.api.baseUrl === 'string') {
      const next = sanitizeBase(partial.api.baseUrl);
      if (next) {
        runtimeConfig.apiBase = next;
      }
    }
    if (partial.ai && typeof partial.ai.baseUrl === 'string') {
      const next = sanitizeBase(partial.ai.baseUrl);
      if (next) {
        runtimeConfig.aiBase = next;
      }
    }
    if (partial.agents && typeof partial.agents.baseUrl === 'string') {
      const next = sanitizeBase(partial.agents.baseUrl);
      if (next) {
        runtimeConfig.agentsBase = next;
      }
    }
    runtimeConfig.raw = partial;
  }

  if (!runtimeConfig.aiBase) {
    runtimeConfig.aiBase = runtimeConfig.apiBase;
  }
  if (!runtimeConfig.agentsBase) {
    runtimeConfig.agentsBase = runtimeConfig.apiBase;
  }

  applyWindowConfig();
  return snapshotConfig();
}

// ensure defaults are visible immediately
applyWindowConfig();

function hasHeaderCase(headers, name) {
  const target = String(name || '').toLowerCase();
  return Object.keys(headers || {}).some((key) => key.toLowerCase() === target);
}

function prepareInit(options = {}) {
  const { method, headers, body, ...rest } = options;
  const init = { ...rest };
  init.method = method || 'GET';
  const normalizedHeaders = { ...(headers || {}) };

  if (body !== undefined) {
    const isPlainObject = body && typeof body === 'object'
      && !(body instanceof FormData)
      && !(body instanceof Blob)
      && !(body instanceof ArrayBuffer)
      && !ArrayBuffer.isView(body);

    if (isPlainObject) {
      init.body = JSON.stringify(body);
      if (!hasHeaderCase(normalizedHeaders, 'content-type')) {
        normalizedHeaders['Content-Type'] = 'application/json';
      }
    } else {
      init.body = body;
    }
  }

  if (Object.keys(normalizedHeaders).length > 0) {
    init.headers = normalizedHeaders;
  }

  return init;
}

async function rawFetch(url, options = {}) {
  const { allowHttpError = false, raw = false, ...rest } = options;
  const init = prepareInit(rest);
  const response = await globalThis.fetch(url, init);
  if (!allowHttpError && !response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`API ${response.status} ${response.statusText} @ ${url}: ${text}`);
  }
  if (raw) {
    return response;
  }
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    return response.json();
  }
  return response.text();
}

async function ensureConfigLoaded() {
  if (configPromise) {
    return configPromise;
  }
  const base = runtimeConfig.apiBase || DEFAULT_BASE;
  const url = new URL('/config.json', base);
  configPromise = (async () => {
    try {
      const data = await rawFetch(url.toString(), {
        method: 'GET',
        headers: { Accept: 'application/json' },
        allowHttpError: true
      });
      if (data && typeof data === 'object') {
        updateRuntimeConfig(data);
      } else {
        applyWindowConfig();
      }
    } catch (err) {
      console.warn('[api] failed to load config.json', err);
      applyWindowConfig();
    }
    return snapshotConfig();
  })();
  return configPromise;
}

export async function jfetch(path, opts = {}) {
  const {
    base,
    skipConfig = false,
    allowHttpError = false,
    raw = false,
    ...rest
  } = opts || {};

  if (!skipConfig) {
    try {
      await ensureConfigLoaded();
    } catch (err) {
      console.warn('[api] config bootstrap failed', err);
    }
  }

  const baseUrl = sanitizeBase(base)
    || runtimeConfig.apiBase
    || DEFAULT_BASE;
  const url = new URL(path, baseUrl);
  return rawFetch(url.toString(), { ...rest, allowHttpError, raw });
}

const readyPromise = ensureConfigLoaded();

export const API = {
  ready: readyPromise,
  reloadConfig: () => {
    configPromise = null;
    return ensureConfigLoaded();
  },
  config: () => ensureConfigLoaded().then(() => snapshotConfig()),
  plan: (payload, options = {}) => jfetch('/api/plan', {
    method: 'POST',
    body: payload,
    ...options
  }),
  patch: (payload, options = {}) => jfetch('/api/patch', {
    method: 'POST',
    body: payload,
    ...options
  }),
  smoke: (payload, options = {}) => jfetch('/api/smoke', {
    method: 'POST',
    body: payload,
    ...options
  }),
  chat: (payload, options = {}) => jfetch('/api/chat', {
    method: 'POST',
    body: payload,
    ...options
  }),
  caps: (options = {}) => jfetch('/api/capabilities', options),
  health: (options = {}) => jfetch('/healthz', options),
  aiComplete: (payload, options = {}) => jfetch('/api/ai/complete', {
    method: 'POST',
    body: payload,
    base: runtimeConfig.aiBase,
    ...options
  }),
  aiChat: (payload, options = {}) => jfetch('/api/ai/chat', {
    method: 'POST',
    body: payload,
    base: runtimeConfig.aiBase,
    ...options
  }),
  agentRoute: (payload, options = {}) => jfetch('/api/agents/route', {
    method: 'POST',
    body: payload,
    base: runtimeConfig.agentsBase,
    ...options
  }),
  agentHealth: (options = {}) => jfetch('/api/agents/health', {
    method: 'GET',
    base: runtimeConfig.agentsBase,
    ...options
  })
};

export default API;
