const DEFAULT_API_BASE = 'http://127.0.0.1:4000';

function sanitizeBaseValue(value) {
  if (typeof value !== 'string') return '';
  const trimmed = value.trim();
  if (!trimmed) return '';
  try {
    const direct = new URL(trimmed);
    return direct.toString().replace(/\/+$/, '');
  } catch (err) {
    try {
      const relative = new URL(trimmed, DEFAULT_API_BASE);
      return relative.toString().replace(/\/+$/, '');
    } catch (err2) {
      return '';
    }
  }
}

function normalizeBaseValue(value, fallback) {
  const fallbackBase = sanitizeBaseValue(
    typeof fallback === 'string' ? fallback : ''
  ) || DEFAULT_API_BASE;
  const sanitized = sanitizeBaseValue(value);
  return sanitized || fallbackBase;
}

function readWindowValue(key) {
  if (typeof window === 'undefined') return undefined;
  return window[key];
}

function hasHeader(headers, name) {
  const target = String(name || '').toLowerCase();
  return Object.keys(headers || {}).some((key) => key.toLowerCase() === target);
}

function getBaseValue(baseKey, fallback) {
  const fallbackValue = typeof fallback === 'function' ? fallback() : fallback;
  return normalizeBaseValue(readWindowValue(baseKey), fallbackValue);
}

function createJfetch(baseKey, fallback) {
  return async function jfetchWithBase(path, opts = {}) {
    const base = getBaseValue(baseKey, fallback);
    const url = new URL(path, base);
    const init = { ...(opts || {}) };
    const headers = { ...(init.headers || {}) };
    const method = (init.method || 'GET').toUpperCase();
    const hasBody = init.body !== undefined && init.body !== null;
    if (hasBody && !hasHeader(headers, 'content-type') && !(init.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
    }
    init.headers = headers;

    const response = await window.fetch(url.toString(), init);
    if (!response.ok) {
      const txt = await response.text().catch(() => '');
      throw new Error(`API ${response.status} ${response.statusText} @ ${url}: ${txt}`);
    }

    const contentType = response.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      return response.json();
    }
    if (method === 'HEAD') {
      return null;
    }
    return response.text();
  };
}

const normalizedDefaultApi = normalizeBaseValue(readWindowValue('API_BASE'), DEFAULT_API_BASE);
if (typeof window !== 'undefined') {
  window.API_BASE = normalizedDefaultApi;
  const currentAi = readWindowValue('AI_BASE');
  const sanitizedAi = sanitizeBaseValue(typeof currentAi === 'string' ? currentAi : '');
  window.AI_BASE = sanitizedAi;
  if (typeof window.AGENTS_BASE !== 'string') {
    window.AGENTS_BASE = '';
  }
}

export const jfetch = createJfetch('API_BASE', DEFAULT_API_BASE);
export const ajfetch = createJfetch('AI_BASE', () => getBaseValue('API_BASE', DEFAULT_API_BASE));

let configPromise = null;

function applyConfig(config) {
  if (!config || typeof config !== 'object') return;
  if (Object.prototype.hasOwnProperty.call(config, 'apiBase')) {
    const sanitized = sanitizeBaseValue(config.apiBase);
    if (sanitized) {
      window.API_BASE = sanitized;
    }
  }
  if (Object.prototype.hasOwnProperty.call(config, 'aiBase')) {
    const sanitizedAi = sanitizeBaseValue(config.aiBase);
    window.AI_BASE = sanitizedAi;
  }
  if (Object.prototype.hasOwnProperty.call(config, 'agentsBase')) {
    const base = config.agentsBase;
    if (typeof base === 'string') {
      window.AGENTS_BASE = base.trim();
    } else if (base == null) {
      window.AGENTS_BASE = '';
    }
  }
}

export async function loadConfig() {
  if (!configPromise) {
    configPromise = (async () => {
      try {
        const payload = await jfetch('/config.json', { method: 'GET' });
        applyConfig(payload);
        return payload;
      } catch (err) {
        console.warn('[ui] config load failed', err);
        return {};
      }
    })();
  }
  return configPromise;
}

export function getConfigSnapshot() {
  return {
    apiBase: window.API_BASE,
    aiBase: window.AI_BASE,
    agentsBase: window.AGENTS_BASE
  };
}

// API helper object with convenience methods
export const API = {
  plan: (payload) => jfetch('/api/plan', { method: 'POST', body: JSON.stringify(payload) }),
  patch: (payload) => jfetch('/api/patch', { method: 'POST', body: JSON.stringify(payload) }),
  smoke: (payload) => jfetch('/api/smoke', { method: 'POST', body: JSON.stringify(payload) }),
  chat: (payload) => jfetch('/api/chat', { method: 'POST', body: JSON.stringify(payload) }),
  caps: () => jfetch('/api/capabilities'),
  health: () => jfetch('/healthz'),
  aiComplete: (payload) => jfetch('/api/ai/complete', { method: 'POST', body: JSON.stringify(payload) }),
  aiChat: (payload) => jfetch('/api/ai/chat', { method: 'POST', body: JSON.stringify(payload) }),
  agentsRoute: (payload) => jfetch('/api/agents/route', { method: 'POST', body: JSON.stringify(payload) }),
  agentsHealth: () => jfetch('/api/agents/health')
};

export const Gateways = {
  fetchAi: (path, opts = {}) => ajfetch(path, opts),
  config: getConfigSnapshot
};
