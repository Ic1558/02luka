const DEFAULT_API_BASE = 'http://127.0.0.1:4000';
const DEFAULT_GATEWAYS = Object.freeze({
  ai: Object.freeze({ baseUrl: '', configured: false }),
  agents: Object.freeze({ baseUrl: '', configured: false })
});

const DEFAULT_CONFIG = Object.freeze({
  API_BASE: DEFAULT_API_BASE,
  AI_BASE: '',
  GATEWAYS: DEFAULT_GATEWAYS
});

let cachedConfig = null;
let configReady = false;
let pendingLoader = null;

function normalizeGateway(entry, fallback = DEFAULT_GATEWAYS.ai) {
  if (typeof entry === 'string') {
    const trimmed = entry.trim();
    return Object.freeze({
      baseUrl: trimmed,
      configured: Boolean(trimmed)
    });
  }

  if (entry && typeof entry === 'object') {
    const baseUrlCandidate = typeof entry.baseUrl === 'string'
      ? entry.baseUrl
      : typeof entry.url === 'string'
        ? entry.url
        : typeof entry.base === 'string'
          ? entry.base
          : '';

    const baseUrl = baseUrlCandidate.trim();
    const configured = typeof entry.configured === 'boolean'
      ? entry.configured
      : typeof entry.hasKey === 'boolean'
        ? entry.hasKey
        : typeof entry.keyConfigured === 'boolean'
          ? entry.keyConfigured
          : Boolean(entry.apiKey || entry.key || entry.token || baseUrl);

    return Object.freeze({ baseUrl, configured: Boolean(configured) });
  }

  return fallback;
}

function normalizeConfig(raw) {
  if (!raw || typeof raw !== 'object') {
    return DEFAULT_CONFIG;
  }

  const apiBase = typeof raw.API_BASE === 'string' && raw.API_BASE.trim()
    ? raw.API_BASE.trim()
    : DEFAULT_API_BASE;
  const aiBase = typeof raw.AI_BASE === 'string' ? raw.AI_BASE.trim() : '';

  const gateways = raw.GATEWAYS && typeof raw.GATEWAYS === 'object'
    ? raw.GATEWAYS
    : {};

  const aiGateway = normalizeGateway(gateways.ai || raw.AI_GATEWAY || aiBase, DEFAULT_GATEWAYS.ai);
  const agentsGateway = normalizeGateway(
    gateways.agents || raw.AGENTS_GATEWAY || gateways.agent,
    DEFAULT_GATEWAYS.agents
  );

  return Object.freeze({
    API_BASE: apiBase || DEFAULT_API_BASE,
    AI_BASE: aiBase,
    GATEWAYS: Object.freeze({
      ai: aiGateway,
      agents: agentsGateway
    })
  });
}

function readWindowConfig() {
  if (typeof window === 'undefined') {
    return DEFAULT_CONFIG;
  }
  const raw = window.LUKA_CONFIG || window.__LUKA_CONFIG || {};
  return normalizeConfig(raw);
}

export function ensureConfigReady() {
  if (configReady && cachedConfig) {
    return Promise.resolve(cachedConfig);
  }

  if (typeof window === 'undefined') {
    cachedConfig = DEFAULT_CONFIG;
    configReady = true;
    return Promise.resolve(cachedConfig);
  }

  const loader = window.__lukaConfigPromise;
  if (loader && typeof loader.then === 'function') {
    if (!pendingLoader) {
      pendingLoader = loader
        .catch((err) => {
          console.warn('[luka] runtime config load failed', err);
          return readWindowConfig();
        })
        .then(() => {
          cachedConfig = readWindowConfig();
          configReady = true;
          return cachedConfig;
        })
        .finally(() => {
          pendingLoader = null;
        });
    }
    return pendingLoader;
  }

  cachedConfig = readWindowConfig();
  configReady = true;
  return Promise.resolve(cachedConfig);
}

export function getConfig() {
  if (!cachedConfig) {
    cachedConfig = readWindowConfig();
  }
  return cachedConfig;
}

export function getApiBase() {
  const config = getConfig();
  return config.API_BASE || DEFAULT_API_BASE;
}

export function getAiBase() {
  const config = getConfig();
  return config.AI_BASE || '';
}

export function getGateway(name) {
  const config = getConfig();
  const gateways = config.GATEWAYS || DEFAULT_CONFIG.GATEWAYS;
  if (gateways[name]) {
    return gateways[name];
  }
  if (DEFAULT_GATEWAYS[name]) {
    return DEFAULT_GATEWAYS[name];
  }
  return DEFAULT_GATEWAYS.ai;
}

export function isGatewayConfigured(name) {
  const gateway = getGateway(name);
  return Boolean(gateway.configured && gateway.baseUrl);
}

export function resetCachedConfig() {
  cachedConfig = null;
  configReady = false;
  pendingLoader = null;
}
