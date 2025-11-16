const SERVICES_REFRESH_MS = 20000;
const MLS_REFRESH_MS = 60000;
const API_BASE = 'http://127.0.0.1:8767';
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);
const SERVICE_STATUS_CLASS = {
  running: 'status-running',
  stopped: 'status-stopped',
  failed: 'status-failed',
};
const MLS_TYPE_META = {
  solution: { label: 'Solution', className: 'mls-type-solution' },
  failure: { label: 'Failure', className: 'mls-type-failure' },
  pattern: { label: 'Pattern', className: 'mls-type-pattern' },
  improvement: { label: 'Improvement', className: 'mls-type-improvement' },
};

let servicesIntervalId;
let mlsIntervalId;

async function fetchJSON(url) {
  const response = await fetch(url, {
    headers: {
      'Accept': 'application/json'
    }
  });

  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }

  return response.json();
}

function initTabs() {
  const tabLinks = document.querySelectorAll('.tabs a[data-panel]');
  const panels = document.querySelectorAll('.panel');

  function showPanel(targetId) {
    panels.forEach((panel) => {
      const shouldShow = panel.id === targetId;
      panel.classList.toggle('hidden', !shouldShow);
    });

    tabLinks.forEach((link) => {
      const isActive = link.dataset.panel === targetId;
      link.classList.toggle('active', isActive);
      if (isActive) {
        link.setAttribute('aria-current', 'page');
      } else {
        link.removeAttribute('aria-current');
      }
    });
  }

  tabLinks.forEach((link) => {
    link.addEventListener('click', (event) => {
      event.preventDefault();
      showPanel(link.dataset.panel);
    });
  });

  if (tabLinks.length) {
    const defaultPanel = tabLinks[0].dataset.panel;
    showPanel(defaultPanel);
  }
}

// --- Services ---

async function loadServices() {
  const tbody = document.getElementById('services-tbody');
  if (!tbody) return;

  const statusFilter = document.getElementById('services-status-filter')?.value || '';
  const typeFilter = document.getElementById('services-type-filter')?.value || '';

  try {
    const params = new URLSearchParams();
    if (statusFilter) params.set('status', statusFilter);
    const query = params.toString();

    const data = await fetchJSON(`${API_BASE}/api/services${query ? `?${query}` : ''}`);
    let services = Array.isArray(data?.services) ? data.services : [];

    if (typeFilter) {
      services = services.filter((svc) => {
        const svcType = (svc.type || '').toLowerCase();
        if (typeFilter === 'other') {
          return !KNOWN_SERVICE_TYPES.has(svcType);
        }
        return svcType === typeFilter;
      });
    }

    renderServicesSummary(data?.summary);
    renderServicesTable(services);
  } catch (error) {
    console.error('Failed to load services', error);
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="5">Failed to load services.</td></tr>';
    }
    const summaryEl = document.getElementById('services-summary');
    if (summaryEl) {
      summaryEl.textContent = 'Failed to load services.';
    }
  }
}

function renderServicesSummary(summary) {
  const el = document.getElementById('services-summary');
  if (!el) return;
  if (!summary) {
    el.textContent = 'Summary unavailable.';
    return;
  }

  el.textContent = `Total: ${summary.total ?? '–'} | Running: ${summary.running ?? '–'} | Stopped: ${summary.stopped ?? '–'} | Failed: ${summary.failed ?? '–'}`;
}

function renderServicesTable(services) {
  const tbody = document.getElementById('services-tbody');
  if (!tbody) return;

  if (!services.length) {
    tbody.innerHTML = '<tr><td colspan="5">No services found.</td></tr>';
    return;
  }

  tbody.innerHTML = '';

  services.forEach((svc) => {
    const tr = document.createElement('tr');
    const statusLabel = (svc.status || 'unknown').toLowerCase();
    const displayStatus = statusLabel.charAt(0).toUpperCase() + statusLabel.slice(1);
    const statusClass = SERVICE_STATUS_CLASS[statusLabel] || 'status-unknown';
    const normalizedType = normalizeServiceType(svc.type);
    const pid = statusLabel === 'running' && svc.pid ? svc.pid : '–';
    const hasExitCode = svc.exit_code !== undefined && svc.exit_code !== null && `${svc.exit_code}` !== '';
    const exitCode = statusLabel === 'failed' && hasExitCode ? svc.exit_code : '–';

    tr.innerHTML = `
      <td>${svc.label ?? ''}</td>
      <td><span class="type-pill type-${normalizedType}">${formatServiceTypeLabel(svc.type)}</span></td>
      <td><span class="status-badge ${statusClass}">${displayStatus}</span></td>
      <td>${pid}</td>
      <td>${exitCode}</td>
    `;

    tbody.appendChild(tr);
  });
}

function normalizeServiceType(type) {
  const normalized = (type || '').toLowerCase();
  if (!normalized) {
    return 'other';
  }

  return KNOWN_SERVICE_TYPES.has(normalized) ? normalized : 'other';
}

function formatServiceTypeLabel(type) {
  if (!type) return 'Other';
  return type.charAt(0).toUpperCase() + type.slice(1);
}

function initServicesPanel() {
  const panel = document.getElementById('services-panel');
  if (!panel) return;

  const statusSelect = document.getElementById('services-status-filter');
  const typeSelect = document.getElementById('services-type-filter');
  const refreshBtn = document.getElementById('services-refresh-btn');

  statusSelect?.addEventListener('change', loadServices);
  typeSelect?.addEventListener('change', loadServices);
  refreshBtn?.addEventListener('click', loadServices);

  loadServices();

  if (!servicesIntervalId) {
    servicesIntervalId = setInterval(loadServices, SERVICES_REFRESH_MS);
  }
}

// --- MLS ---

async function loadMLS() {
  const tbody = document.getElementById('mls-tbody');
  if (!tbody) return;

  const typeFilter = document.getElementById('mls-type-filter')?.value || '';
  const verifiedOnly = document.getElementById('mls-verified-only')?.checked || false;

  try {
    const params = new URLSearchParams();
    if (typeFilter) params.set('type', typeFilter);
    const query = params.toString();

    const data = await fetchJSON(`${API_BASE}/api/mls${query ? `?${query}` : ''}`);
    let entries = Array.isArray(data?.entries) ? data.entries : [];

    if (verifiedOnly) {
      entries = entries.filter((entry) => Boolean(entry.verified));
    }

    const searchTerm = (document.getElementById('mls-search')?.value || '').trim().toLowerCase();
    if (searchTerm) {
      entries = entries.filter((entry) => {
        const haystack = [
          entry.title || '',
          entry.details || '',
          entry.context || '',
          Array.isArray(entry.tags) ? entry.tags.join(' ') : '',
        ].join(' ').toLowerCase();
        return haystack.includes(searchTerm);
      });
    }

    renderMLSSummary(data?.summary);
    renderMLSTable(entries);
  } catch (error) {
    console.error('Failed to load MLS', error);
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="6">Failed to load MLS lessons.</td></tr>';
    }
    const summaryEl = document.getElementById('mls-summary');
    if (summaryEl) {
      summaryEl.textContent = 'Failed to load MLS lessons.';
    }
  }
}

function renderMLSSummary(summary) {
  const el = document.getElementById('mls-summary');
  if (!el) return;

  if (!summary) {
    el.textContent = 'Summary unavailable.';
    return;
  }

  el.textContent = `Total: ${summary.total ?? '–'} | Solutions: ${summary.solutions ?? '–'} | Failures: ${summary.failures ?? '–'} | Patterns: ${summary.patterns ?? '–'} | Improvements: ${summary.improvements ?? '–'}`;
}

function renderMLSTable(entries) {
  const tbody = document.getElementById('mls-tbody');
  if (!tbody) return;

  if (!entries.length) {
    tbody.innerHTML = '<tr><td colspan="6">No lessons recorded yet.</td></tr>';
    hideMLSDetail();
    return;
  }

  tbody.innerHTML = '';

  entries.forEach((entry) => {
    const tr = document.createElement('tr');
    const time = entry.time ? new Date(entry.time).toLocaleString() : '';
    const score = typeof entry.score === 'number' ? entry.score.toFixed(2) : entry.score ?? '–';
    const tags = Array.isArray(entry.tags) ? entry.tags.join(', ') : '';
    const verifiedLabel = entry.verified ? '✅' : '❌';
    const typeMeta = MLS_TYPE_META[(entry.type || '').toLowerCase()] || {
      label: entry.type || 'Other',
      className: 'mls-type-other',
    };

    tr.innerHTML = `
      <td>${time}</td>
      <td><span class="mls-type-pill ${typeMeta.className}">${typeMeta.label}</span></td>
      <td class="mls-title-cell">${entry.title ?? ''}</td>
      <td>${score}</td>
      <td>${tags}</td>
      <td>${verifiedLabel}</td>
    `;

    tr.addEventListener('click', () => showMLSDetail(entry));
    tbody.appendChild(tr);
  });
}

function showMLSDetail(entry) {
  const panel = document.getElementById('mls-detail');
  if (!panel) return;

  document.getElementById('mls-detail-title').textContent = entry.title || '';
  document.getElementById('mls-detail-details').textContent = entry.details || '';
  document.getElementById('mls-detail-context').textContent = entry.context || '';
  document.getElementById('mls-detail-wo').textContent = entry.related_wo || '';
  document.getElementById('mls-detail-session').textContent = entry.related_session || '';
  const tagsEl = document.getElementById('mls-detail-tags');
  if (tagsEl) {
    const tags = Array.isArray(entry.tags) ? entry.tags.join(', ') : '–';
    tagsEl.textContent = tags || '–';
  }

  panel.classList.remove('hidden');
}

function hideMLSDetail() {
  const panel = document.getElementById('mls-detail');
  panel?.classList.add('hidden');
}

function initMLSPanel() {
  const panel = document.getElementById('mls-panel');
  if (!panel) return;

  const typeSelect = document.getElementById('mls-type-filter');
  const verifiedCheckbox = document.getElementById('mls-verified-only');
  const refreshBtn = document.getElementById('mls-refresh-btn');
  const searchInput = document.getElementById('mls-search');
  const closeDetailBtn = document.getElementById('mls-detail-close');

  typeSelect?.addEventListener('change', loadMLS);
  verifiedCheckbox?.addEventListener('change', loadMLS);
  refreshBtn?.addEventListener('click', loadMLS);
  searchInput?.addEventListener('input', () => {
    // Trim filtering only once per event loop to keep keypress responsive.
    window.requestAnimationFrame(() => loadMLS());
  });
  closeDetailBtn?.addEventListener('click', hideMLSDetail);

  loadMLS();

  if (!mlsIntervalId) {
    mlsIntervalId = setInterval(loadMLS, MLS_REFRESH_MS);
  }
}

function cleanupIntervals() {
  if (servicesIntervalId) {
    clearInterval(servicesIntervalId);
    servicesIntervalId = null;
  }

  if (mlsIntervalId) {
    clearInterval(mlsIntervalId);
    mlsIntervalId = null;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  initServicesPanel();
  initMLSPanel();
});

window.addEventListener('beforeunload', () => {
  cleanupIntervals();
});
