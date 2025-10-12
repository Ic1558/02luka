export const API_BASE = (window.LUKA_CONFIG?.API_BASE) || 'http://127.0.0.1:4000';
export const AI_BASE = (window.LUKA_CONFIG?.AI_BASE) || (API_BASE + '/api/ai');

export async function jfetch(path, init = {}) {
  const url = path.startsWith('http') ? path : `${API_BASE}${path}`;
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(init.headers || {}) },
    ...init
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.headers.get('content-type')?.includes('application/json') ? res.json() : res.text();
}

// API helper object with convenience methods
export const API = {
  plan: (payload) => jfetch('/api/plan', { method: 'POST', body: JSON.stringify(payload) }),
  patch: (payload) => jfetch('/api/patch', { method: 'POST', body: JSON.stringify(payload) }),
  smoke: (payload) => jfetch('/api/smoke', { method: 'POST', body: JSON.stringify(payload) }),
  chat: (payload) => jfetch('/api/chat', { method: 'POST', body: JSON.stringify(payload) }),
  caps: () => jfetch('/api/capabilities'),
  health: () => jfetch('/healthz')
};
