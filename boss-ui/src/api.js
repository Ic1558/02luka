const resolveApiBase = () => {
  const envBase = import.meta?.env?.VITE_API_BASE;
  if (envBase && typeof envBase === 'string' && envBase.trim()) {
    return envBase.trim().replace(/\/+$/, '');
  }

  if (typeof window !== 'undefined') {
    if (window.API_BASE && typeof window.API_BASE === 'string' && window.API_BASE.trim()) {
      return window.API_BASE.trim().replace(/\/+$/, '');
    }

    const { protocol = 'http:', hostname = '127.0.0.1' } = window.location || {};
    return `${protocol}//${hostname}:4000`;
  }

  return 'http://127.0.0.1:4000';
};

export const API_BASE = resolveApiBase();

async function request(path, { method = 'GET', body, headers } = {}) {
  const url = `${API_BASE}${path}`;
  const res = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(headers || {})
    },
    body: body ? JSON.stringify(body) : undefined
  });

  if (!res.ok) {
    let errorDetail = null;
    try {
      errorDetail = await res.json();
    } catch (error) {
      // ignore parse errors
    }
    const error = new Error(errorDetail?.error || `Request failed with status ${res.status}`);
    error.status = res.status;
    error.detail = errorDetail;
    throw error;
  }

  if (res.status === 204) {
    return null;
  }

  return res.json();
}

export async function fetchRuns(params = {}) {
  const query = new URLSearchParams();
  if (params.limit) query.set('limit', params.limit);
  if (params.status) query.set('status', params.status);
  if (params.agent) query.set('agent', params.agent);
  if (params.search) query.set('search', params.search);
  const suffix = query.toString() ? `?${query.toString()}` : '';
  const data = await request(`/api/v2/runs${suffix}`);
  return data.runs;
}

export async function fetchRun(runId, opts = {}) {
  const query = new URLSearchParams();
  if (opts.logs) {
    query.set('logs', opts.logs);
  }
  const suffix = query.toString() ? `?${query.toString()}` : '';
  const data = await request(`/api/v2/runs/${runId}${suffix}`);
  return data.run;
}

export async function updateRun(runId, payload) {
  const data = await request(`/api/v2/runs/${runId}/status`, { method: 'POST', body: payload });
  return data.run;
}

export async function requestApproval(runId, payload) {
  const data = await request(`/api/v2/runs/${runId}/approvals`, { method: 'POST', body: payload });
  return data.approval;
}

export async function decideApproval(approvalId, payload) {
  const data = await request(`/api/v2/approvals/${approvalId}/decision`, { method: 'POST', body: payload });
  return data.approval;
}

export async function fetchMemoryRecall(params = {}) {
  const query = new URLSearchParams();
  if (params.kind) query.set('kind', params.kind);
  if (params.search) query.set('search', params.search);
  if (params.limit) query.set('limit', params.limit);
  const suffix = query.toString() ? `?${query.toString()}` : '';
  const data = await request(`/api/v2/memory/recall${suffix}`);
  return data.items;
}

export async function fetchTelemetrySummary(params = {}) {
  const query = new URLSearchParams();
  if (params.window) query.set('window', params.window);
  const suffix = query.toString() ? `?${query.toString()}` : '';
  const data = await request(`/api/v2/telemetry/summary${suffix}`);
  return data.summary;
}

export function subscribeEvents(onEvent) {
  const source = new EventSource(`${API_BASE}/api/v2/events/stream`, { withCredentials: false });
  source.onmessage = (event) => {
    if (!event.data) return;
    try {
      const payload = JSON.parse(event.data);
      onEvent?.(payload);
    } catch (error) {
      console.warn('Failed to parse event payload', error);
    }
  };
  return () => {
    source.close();
  };
}

