// NOTE: explicit API base so UI (5173) can talk to API (4000)
window.API_BASE = window.API_BASE || "http://127.0.0.1:4000";

export async function jfetch(path, opts = {}) {
  const base = window.API_BASE || "http://127.0.0.1:4000";
  const url = new URL(path, base);
  const init = { headers: { 'Content-Type': 'application/json' }, ...(opts || {}) };
  const res = await fetch(url.toString(), init);
  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    throw new Error(`API ${res.status} ${res.statusText} @ ${url}: ${txt}`);
  }
  // try JSON first; fall back to text
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return res.json();
  return res.text();
}

// API helper object with convenience methods
export const API = {
  plan: (payload) => jfetch('/api/plan', { method: 'POST', body: JSON.stringify(payload) }),
  patch: (payload) => jfetch('/api/patch', { method: 'POST', body: JSON.stringify(payload) }),
  smoke: (payload) => jfetch('/api/smoke', { method: 'POST', body: JSON.stringify(payload) }),
  chat: (payload) => jfetch('/api/chat', { method: 'POST', body: JSON.stringify(payload) }),
  agentsRoute: (payload) => jfetch('/api/agents/route', { method: 'POST', body: JSON.stringify(payload) }),
  agentsHealth: () => jfetch('/api/agents/health'),
  caps: () => jfetch('/api/capabilities'),
  health: () => jfetch('/healthz')
};
