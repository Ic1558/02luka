export async function jfetch(path, opts = {}) {
  const url = new URL(path, location.origin);
  const init = Object.assign({
    headers: { 'Content-Type': 'application/json' }
  }, opts || {});
  const response = await fetch(url.toString(), init);
  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    const error = new Error(detail || `Request failed: ${response.status}`);
    error.status = response.status;
    throw error;
  }
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('json')) {
    return response.json();
  }
  return response.text();
}

export const API = {
  plan: (payload) => jfetch('/api/plan', { method: 'POST', body: JSON.stringify(payload) }),
  patch: (payload) => jfetch('/api/patch', { method: 'POST', body: JSON.stringify(payload) }),
  smoke: (payload) => jfetch('/api/smoke', { method: 'POST', body: JSON.stringify(payload) }),
  chat: (payload) => jfetch('/api/chat', { method: 'POST', body: JSON.stringify(payload) }),
  caps: () => jfetch('/api/capabilities'),
  health: () => jfetch('/healthz')
};
