const SERVICES_REFRESH_MS = 30000;
const MLS_REFRESH_MS = 30000;
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);

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

    const data = await fetchJSON(`/api/services${query ? `?${query}` : ''}`);
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
  }
}

function renderServicesSummary(summary) {
  const el = document.getElementById('services-summary');
  if (!el || !summary) return;
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
    const pid = svc.pid ?? '–';
    const exitCode = svc.exit_code ?? '–';

    const statusClass = statusLabel === 'running'
      ? 'status-running'
      : statusLabel === 'failed'
        ? 'status-failed'
        : statusLabel === 'stopped'
          ? 'status-stopped'
          : '';

    tr.innerHTML = `
      <td>${svc.label ?? ''}</td>
      <td>${svc.type ?? ''}</td>
      <td class="${statusClass}">${statusLabel}</td>
      <td>${pid}</td>
      <td>${exitCode}</td>
    `;

    tbody.appendChild(tr);
  });
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

    const data = await fetchJSON(`/api/mls${query ? `?${query}` : ''}`);
    let entries = Array.isArray(data?.entries) ? data.entries : [];

    if (verifiedOnly) {
      entries = entries.filter((entry) => Boolean(entry.verified));
    }

    renderMLSSummary(data?.summary);
    renderMLSTable(entries);
  } catch (error) {
    console.error('Failed to load MLS', error);
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="6">Failed to load MLS lessons.</td></tr>';
    }
  }
}

function renderMLSSummary(summary) {
  const el = document.getElementById('mls-summary');
  if (!el || !summary) return;

  el.textContent = `Total: ${summary.total ?? '–'} | Solutions: ${summary.solutions ?? '–'} | Failures: ${summary.failures ?? '–'} | Patterns: ${summary.patterns ?? '–'} | Improvements: ${summary.improvements ?? '–'}`;
}

function renderMLSTable(entries) {
  const tbody = document.getElementById('mls-tbody');
  if (!tbody) return;

  if (!entries.length) {
    tbody.innerHTML = '<tr><td colspan="6">No MLS entries found.</td></tr>';
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

    tr.innerHTML = `
      <td>${time}</td>
      <td>${entry.type ?? ''}</td>
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

  typeSelect?.addEventListener('change', loadMLS);
  verifiedCheckbox?.addEventListener('change', loadMLS);
  refreshBtn?.addEventListener('click', loadMLS);

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
