const SERVICES_REFRESH_MS = 30000;
const MLS_REFRESH_MS = 30000;
const WO_REFRESH_MS = 30000;
const WO_TAIL_LINES = 200;
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);

let woIntervalId;
let servicesIntervalId;
let mlsIntervalId;
let cachedWos = [];
let selectedWoId = null;

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

function formatTimestamp(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
}

function formatDurationMs(ms) {
  if (typeof ms !== 'number' || !Number.isFinite(ms) || ms < 0) {
    return '';
  }

  const totalSeconds = Math.floor(ms / 1000);
  const seconds = totalSeconds % 60;
  const totalMinutes = Math.floor(totalSeconds / 60);
  const minutes = totalMinutes % 60;
  const hours = Math.floor(totalMinutes / 60);

  const parts = [];
  if (hours) parts.push(`${hours}h`);
  if (minutes || (hours && !minutes)) parts.push(`${minutes}m`);
  if (!parts.length || seconds) parts.push(`${seconds}s`);
  return parts.join(' ');
}

function getWoDurationMs(wo) {
  if (typeof wo?.duration_ms === 'number') {
    return wo.duration_ms;
  }

  const startTs = wo?.started_at;
  const finishTs = wo?.finished_at || wo?.completed_at;
  if (!startTs || !finishTs) {
    return undefined;
  }

  const startDate = new Date(startTs);
  const finishDate = new Date(finishTs);
  if (Number.isNaN(startDate.getTime()) || Number.isNaN(finishDate.getTime())) {
    return undefined;
  }

  return Math.max(0, finishDate.getTime() - startDate.getTime());
}

function describeWoTiming(wo) {
  const parts = [];
  if (wo.started_at) {
    parts.push(`Started ${formatTimestamp(wo.started_at)}`);
  }

  const finishedAt = wo.finished_at || wo.completed_at;
  if (finishedAt) {
    parts.push(`Finished ${formatTimestamp(finishedAt)}`);
  }

  const durationLabel = formatDurationMs(getWoDurationMs(wo));
  if (durationLabel) {
    parts.push(`Duration ${durationLabel}`);
  }

  return parts.join(' • ');
}

// --- Work Orders ---

async function loadWOs() {
  const tbody = document.getElementById('wo-tbody');
  if (!tbody) return;

  try {
    const data = await fetchJSON('http://127.0.0.1:8767/api/wos');
    cachedWos = Array.isArray(data) ? data : [];
    renderWOSummary(cachedWos);
    renderWOTable();
  } catch (error) {
    console.error('Failed to load work orders', error);
    cachedWos = [];
    renderWOSummary(cachedWos);
    tbody.innerHTML = '<tr><td colspan="5">Failed to load work orders.</td></tr>';
  }
}

function renderWOSummary(wos) {
  const el = document.getElementById('wo-summary');
  if (!el) return;

  if (!wos.length) {
    el.textContent = 'No work orders found.';
    return;
  }

  const counts = wos.reduce((acc, wo) => {
    const status = (wo.status || 'unknown').toLowerCase();
    acc[status] = (acc[status] || 0) + 1;
    return acc;
  }, {});

  const running = (counts.running || 0) + (counts.queued || 0) + (counts.processing || 0);
  const success = (counts.success || 0) + (counts.completed || 0);
  const pending = (counts.pending || 0) + (counts.awaiting_approval || 0);
  const failed = (counts.failed || 0) + (counts.error || 0);

  el.textContent = `Total: ${wos.length} | Running/Queued: ${running} | Success: ${success} | Failed: ${failed} | Pending: ${pending}`;
}

function renderWOTable() {
  const tbody = document.getElementById('wo-tbody');
  if (!tbody) return;

  if (!cachedWos.length) {
    tbody.innerHTML = '<tr><td colspan="5">No work orders available.</td></tr>';
    return;
  }

  const statusFilter = document.getElementById('wo-status-filter')?.value || '';
  let filtered = cachedWos;
  if (statusFilter) {
    filtered = cachedWos.filter((wo) => (wo.status || '').toLowerCase() === statusFilter);
  }

  filtered = filtered.slice().sort((a, b) => {
    const aKey = a.started_at || a.id || '';
    const bKey = b.started_at || b.id || '';
    return aKey < bKey ? 1 : aKey > bKey ? -1 : 0;
  });

  if (!filtered.length) {
    tbody.innerHTML = '<tr><td colspan="5">No work orders match the selected filter.</td></tr>';
    return;
  }

  tbody.innerHTML = '';

  filtered.forEach((wo) => {
    const tr = document.createElement('tr');
    tr.dataset.woId = wo.id || '';
    tr.classList.add('wo-row');
    if (wo.id === selectedWoId) {
      tr.classList.add('selected');
    }

    const started = formatTimestamp(wo.started_at);
    const finished = formatTimestamp(wo.finished_at || wo.completed_at);

    const cells = [
      wo.id ?? '',
      (wo.status || 'unknown').toLowerCase(),
      started,
      finished,
      wo.goal ?? wo.title ?? ''
    ];

    cells.forEach((value) => {
      const td = document.createElement('td');
      td.textContent = value;
      tr.appendChild(td);
    });

    tr.addEventListener('click', () => selectWorkOrder(wo.id));
    tbody.appendChild(tr);
  });
}

function selectWorkOrder(woId) {
  if (!woId) return;
  selectedWoId = woId;
  updateWoSelectionHighlight();
  loadWoDetail(woId);
}

function updateWoSelectionHighlight() {
  const rows = document.querySelectorAll('#wo-tbody tr');
  rows.forEach((row) => {
    row.classList.toggle('selected', row.dataset.woId === selectedWoId);
  });
}

async function loadWoDetail(woId) {
  showWoDetailPlaceholder('Loading work order details…');
  try {
    const wo = await fetchJSON(`http://127.0.0.1:8767/api/wos/${encodeURIComponent(woId)}?tail=${WO_TAIL_LINES}&timeline=1`);
    renderWoDetail(wo);
  } catch (error) {
    console.error('Failed to load work order detail', error);
    showWoDetailPlaceholder('Failed to load work order details.');
  }
}

function renderWoDetail(wo) {
  const detailPanel = document.getElementById('wo-detail');
  const placeholder = document.getElementById('wo-detail-placeholder');
  if (!detailPanel || !placeholder) return;

  placeholder.classList.add('hidden');
  detailPanel.classList.remove('hidden');

  document.getElementById('wo-detail-title').textContent = wo.id || wo.title || 'Work Order';
  document.getElementById('wo-detail-status').textContent = wo.status || 'unknown';
  document.getElementById('wo-detail-goal').textContent = wo.goal || wo.title || '';
  document.getElementById('wo-detail-meta').textContent = describeWoTiming(wo) || 'No timing data available.';

  renderWoTimeline(Array.isArray(wo.timeline) ? wo.timeline : []);
  renderWoLog(Array.isArray(wo.log_tail) ? wo.log_tail : []);
}

function showWoDetailPlaceholder(message) {
  const detailPanel = document.getElementById('wo-detail');
  const placeholder = document.getElementById('wo-detail-placeholder');
  if (!detailPanel || !placeholder) return;

  placeholder.textContent = message;
  placeholder.classList.remove('hidden');
  detailPanel.classList.add('hidden');
  const timelineList = document.getElementById('wo-timeline-list');
  if (timelineList) {
    timelineList.innerHTML = '';
  }
  const logEl = document.getElementById('wo-log-tail');
  if (logEl) {
    logEl.textContent = '';
    logEl.classList.add('empty');
  }
}

function renderWoTimeline(events) {
  const list = document.getElementById('wo-timeline-list');
  if (!list) return;
  list.innerHTML = '';

  if (!events.length) {
    const li = document.createElement('li');
    li.className = 'timeline-item empty';
    const content = document.createElement('div');
    content.className = 'timeline-content';
    content.textContent = 'No timeline data available.';
    li.appendChild(content);
    list.appendChild(li);
    return;
  }

  events.forEach((event) => {
    const li = document.createElement('li');
    const typeClass = event.type ? ` timeline-${event.type}` : '';
    li.className = `timeline-item${typeClass}`;

    const dot = document.createElement('div');
    dot.className = 'timeline-dot';
    const content = document.createElement('div');
    content.className = 'timeline-content';

    const header = document.createElement('div');
    header.className = 'timeline-header';
    const typeSpan = document.createElement('span');
    typeSpan.className = 'timeline-type';
    typeSpan.textContent = (event.type || '').toUpperCase();
    header.appendChild(typeSpan);

    if (event.ts) {
      const tsSpan = document.createElement('span');
      tsSpan.className = 'timeline-ts';
      tsSpan.textContent = formatTimestamp(event.ts);
      header.appendChild(tsSpan);
    }

    const label = document.createElement('p');
    label.className = 'timeline-label';
    label.textContent = event.label || event.type || 'event';

    content.appendChild(header);
    content.appendChild(label);

    li.appendChild(dot);
    li.appendChild(content);
    list.appendChild(li);
  });
}

function renderWoLog(logTail) {
  const el = document.getElementById('wo-log-tail');
  if (!el) return;

  if (!logTail.length) {
    el.textContent = 'No log entries available for this work order.';
    el.classList.add('empty');
    return;
  }

  el.textContent = logTail.join('\n');
  el.classList.remove('empty');
}

function initWOPanel() {
  const panel = document.getElementById('wos-panel');
  if (!panel) return;

  const statusSelect = document.getElementById('wo-status-filter');
  const refreshBtn = document.getElementById('wo-refresh-btn');

  statusSelect?.addEventListener('change', renderWOTable);
  refreshBtn?.addEventListener('click', loadWOs);

  loadWOs();

  if (!woIntervalId) {
    woIntervalId = setInterval(loadWOs, WO_REFRESH_MS);
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

    const data = await fetchJSON(`http://127.0.0.1:8767/api/services${query ? `?${query}` : ''}`);
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

    const data = await fetchJSON(`http://127.0.0.1:8767/api/mls${query ? `?${query}` : ''}`);
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
  if (woIntervalId) {
    clearInterval(woIntervalId);
    woIntervalId = null;
  }

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
  initWOPanel();
  initServicesPanel();
  initMLSPanel();
});

window.addEventListener('beforeunload', () => {
  cleanupIntervals();
});
