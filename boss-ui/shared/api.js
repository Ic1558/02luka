const DEFAULT_BASES = {
  apiBase: 'http://127.0.0.1:4000',
  aiBase: 'http://127.0.0.1:4000'
};

let configPromise;

function normalizeBase(value, fallback) {
  if (typeof value !== 'string') {
    return fallback;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : fallback;
}

async function fetchConfig() {
  if (configPromise) {
    return configPromise;
  }

  const trySources = [];
  if (typeof window !== 'undefined') {
    if (window.__LUKA_CONFIG__ && typeof window.__LUKA_CONFIG__ === 'object') {
      const merged = finalizeConfig(window.__LUKA_CONFIG__);
      configPromise = Promise.resolve(merged);
      return configPromise;
    }
    if (typeof window.CONFIG_URL === 'string' && window.CONFIG_URL) {
      trySources.push(window.CONFIG_URL);
    }
    trySources.push('/config.json');
  }
  trySources.push('http://127.0.0.1:4000/config.json');

  configPromise = (async () => {
    for (const source of trySources) {
      try {
        const res = await fetch(source, { cache: 'no-store' });
        if (!res.ok) {
          continue;
        }
        const data = await res.json();
        return finalizeConfig(data);
      } catch (err) {
        console.warn('[api] config fetch failed', source, err);
      }
    }
    return finalizeConfig({});
  })();

  return configPromise;
}

function finalizeConfig(raw) {
  const apiBase = normalizeBase(raw.apiBase, DEFAULT_BASES.apiBase);
  const aiBase = normalizeBase(raw.aiBase, raw.apiBase ? normalizeBase(raw.apiBase, DEFAULT_BASES.apiBase) : DEFAULT_BASES.aiBase);
  if (typeof window !== 'undefined') {
    window.API_BASE = apiBase;
    window.AI_BASE = aiBase;
  }
  return { apiBase, aiBase };
}

export async function getBases() {
  return fetchConfig();
}

export async function safeJfetch(base, path, opts = {}) {
  const normalizedBase = normalizeBase(base, DEFAULT_BASES.apiBase);
  const targetPath = typeof path === 'string' ? path : '';
  const url = new URL(targetPath, normalizedBase.endsWith('/') ? normalizedBase : `${normalizedBase}/`);
  const init = { ...(opts || {}) };
  const headers = new Headers(init.headers || {});

  if (!headers.has('Accept')) {
    headers.set('Accept', 'application/json, text/plain;q=0.8, */*;q=0.2');
  }

  const hasBody = init.body !== undefined && init.body !== null && init.body !== '';
  if (hasBody && !(init.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  init.headers = headers;

  let response;
  try {
    response = await fetch(url.toString(), init);
  } catch (err) {
    const reason = err && err.message ? err.message : String(err);
    throw new Error(`Network error @ ${url.toString()}: ${reason}`);
  }

  let text = '';
  try {
    text = await response.text();
  } catch (err) {
    text = '';
  }

  if (!response.ok) {
    const snippet = text ? text.slice(0, 400) : '';
    throw new Error(`API ${response.status} ${response.statusText} @ ${url.toString()}${snippet ? `: ${snippet}` : ''}`);
  }

  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    try {
      return text ? JSON.parse(text) : null;
    } catch (err) {
      console.warn('[api] JSON parse failed', url.toString(), err);
      return text;
    }
  }
  return text;
}

export async function jfetch(path, opts = {}) {
  const bases = await fetchConfig();
  const base = typeof path === 'string' && path.startsWith('/api/ai') ? bases.aiBase : bases.apiBase;
  return safeJfetch(base, path, opts);
}

// API helper object with convenience methods
export const API = {
  plan: (payload) => jfetch('/api/plan', { method: 'POST', body: JSON.stringify(payload) }),
  patch: (payload) => jfetch('/api/patch', { method: 'POST', body: JSON.stringify(payload) }),
  smoke: (payload) => jfetch('/api/smoke', { method: 'POST', body: JSON.stringify(payload) }),
  chat: (payload) => jfetch('/api/chat', { method: 'POST', body: JSON.stringify(payload) }),
  aiComplete: (payload) => jfetch('/api/ai/complete', { method: 'POST', body: JSON.stringify(payload) }),
  aiChat: (payload) => jfetch('/api/ai/chat', { method: 'POST', body: JSON.stringify(payload) }),
  agentRoute: (payload) => jfetch('/api/agents/route', { method: 'POST', body: JSON.stringify(payload) }),
  agentHealth: () => jfetch('/api/agents/health'),
  caps: () => jfetch('/api/capabilities'),
  reportsList: () => jfetch('/api/reports/list'),
  reportsLatest: () => jfetch('/api/reports/latest'),
  reportsSummary: () => jfetch('/api/reports/summary'),
  health: () => jfetch('/healthz')
};
