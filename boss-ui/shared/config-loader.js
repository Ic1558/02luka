(function bootstrapLukaConfig() {
  if (typeof window === 'undefined') {
    return;
  }
  if (window.__lukaConfigPromise) {
    return;
  }

  const fallback = { API_BASE: 'http://127.0.0.1:4000', GATEWAYS: {} };

  window.__lukaConfigPromise = (async () => {
    try {
      const response = await fetch('/config.json', { cache: 'no-store' });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const payload = await response.json();
      window.LUKA_CONFIG = payload && typeof payload === 'object' ? payload : fallback;
    } catch (err) {
      console.error('[luka] failed to load runtime config', err);
      const existing = window.LUKA_CONFIG && typeof window.LUKA_CONFIG === 'object'
        ? window.LUKA_CONFIG
        : {};
      window.LUKA_CONFIG = Object.assign({}, fallback, existing);
    }

    if (window.LUKA_CONFIG && window.LUKA_CONFIG.API_BASE) {
      window.API_BASE = window.LUKA_CONFIG.API_BASE;
    }

    return window.LUKA_CONFIG;
  })();
})();
