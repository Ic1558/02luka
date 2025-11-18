const SERVICES_REFRESH_MS = 30000;
const MLS_REFRESH_MS = 30000;
const WO_AUTOREFRESH_MS = 60000;
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);

let servicesIntervalId;
let mlsIntervalId;
let woAutorefreshIntervalId;
let currentMlsType = '';
let realityLoading = false;

let allWos = [];
let visibleWos = [];
let currentWos = [];
let currentWoFilter = 'all';
let woAutorefreshTimer = null;
let woAutorefreshEnabled = false;
let woAutorefreshIntervalMs = 30000;
let currentWoSearch = '';
let serviceData = [];
let currentWoStatusFilter = '';
let currentWoSortKey = 'started_at';
let currentWoSortDir = 'desc';
let currentTimelineWoId = null;
let woHistoryLoadedOnce = false;
const WO_STATUS_SORT_ORDER = {
  running: 4,
  pending: 3,
  completed: 2,
  failed: 1,
  unknown: 0
};

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

function toLocalDateString(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit'
  });
}

function computeDurationMs(wo) {
  const started = wo?.started_at ? new Date(wo.started_at) : null;
  const finished = wo?.finished_at ? new Date(wo.finished_at) : null;
  if (!started || Number.isNaN(started.getTime())) return null;
  if (!finished || Number.isNaN(finished.getTime())) return null;
  return finished - started;
}

function formatDuration(ms) {
  if (ms == null || Number.isNaN(ms) || ms < 0) return '';
  const sec = Math.round(ms / 1000);
  if (sec < 60) return `${sec}s`;
  const min = Math.floor(sec / 60);
  const rem = sec % 60;
  if (min < 60) {
    return `${min}m${rem ? ` ${rem}s` : ''}`;
  }
  const hr = Math.floor(min / 60);
  const remMin = min % 60;
  return `${hr}h${remMin ? ` ${remMin}m` : ''}`;
}

function groupWosByDay(wos) {
  const groups = {};
  wos.forEach((wo) => {
    const day = toLocalDateString(wo?.started_at || wo?.finished_at || wo?.id);
    const key = day || 'Unknown';
    if (!groups[key]) groups[key] = [];
    groups[key].push(wo);
  });

  const entries = Object.entries(groups).map(([day, list]) => {
    list.sort((a, b) => {
      const ta = a?.started_at || a?.finished_at || a?.id;
      const tb = b?.started_at || b?.finished_at || b?.id;
      return (tb || '').localeCompare(ta || '');
    });
    return { day, list };
  });

  entries.sort((a, b) => {
    if (a.day === 'Unknown') return 1;
    if (b.day === 'Unknown') return -1;
    return new Date(b.day) - new Date(a.day);
  });

  return entries;
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

    if (targetId === 'services-panel') {
      initServicesPanel();
    } else if (targetId === 'mls-panel') {
      initMLSPanel();
    }
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

  const tabOverview = document.getElementById('tab-overview');
  const tabWos = document.getElementById('tab-wos');
  const tabWoHistory = document.getElementById('tab-wo-history');
  const tabReality = document.getElementById('tab-reality');

  const viewOverview = document.getElementById('view-overview');
  const viewWos = document.getElementById('view-wos');
  const viewWoHistory = document.getElementById('view-wo-history');
  const viewReality = document.getElementById('view-reality');

  const tabConfigs = [
    { button: tabOverview, view: viewOverview },
    { button: tabWos, view: viewWos },
    { button: tabWoHistory, view: viewWoHistory, onShow: () => {
      if (!woHistoryLoadedOnce && typeof loadWoHistory === 'function') {
        loadWoHistory();
      }
    }},
  ];

  if (tabReality && viewReality) {
    tabConfigs.push({ button: tabReality, view: viewReality, onShow: loadRealitySnapshot });
  }

  const validConfigs = tabConfigs.filter((cfg) => cfg.button && cfg.view);

  if (validConfigs.length) {
    const activate = (targetCfg) => {
      validConfigs.forEach((cfg) => {
        cfg.button.classList.toggle('active', cfg === targetCfg);
        cfg.view.classList.toggle('hidden', cfg !== targetCfg);
      });
      if (typeof targetCfg.onShow === 'function') {
        targetCfg.onShow();
      }
    };

    validConfigs.forEach((cfg) => {
      cfg.button.addEventListener('click', () => activate(cfg));
    });

    activate(validConfigs[0]);
  }
}

function showErrorBanner(id, message) {
  const banner = document.getElementById(id);
  if (!banner) return;
  const textSpan = banner.querySelector('span');
  if (textSpan && message) {
    textSpan.textContent = message;
  }
  banner.classList.remove('hidden');
}

function hideErrorBanner(id) {
  const banner = document.getElementById(id);
  banner?.classList.add('hidden');
}

// --- Work Orders ---

function initWoFilters() {
  const filterGroup = document.getElementById('wo-status-filters');
  if (!filterGroup) return;

  const buttons = filterGroup.querySelectorAll('button[data-filter]');
  buttons.forEach((button) => {
    button.addEventListener('click', () => {
      const filter = button.dataset.filter || 'all';
      currentWoFilter = filter;
      buttons.forEach((btn) => btn.classList.toggle('active', btn === button));
      applyWoFilter();
    });
  });
}

function initWoSearch() {
  const input = document.getElementById('wo-search-input');
  if (!input) return;

  if (currentWoSearch) {
    input.value = currentWoSearch;
  }

  input.addEventListener('input', () => {
    currentWoSearch = input.value.trim().toLowerCase();
    applyWoFilter();
  });
}

function initWoSorting() {
  const headerCells = document.querySelectorAll('#wos-table th[data-sort-key]');
  if (!headerCells.length) return;

  headerCells.forEach((th) => {
    th.addEventListener('click', () => {
      const key = th.getAttribute('data-sort-key');
      if (!key) return;

      if (currentWoSortKey === key) {
        currentWoSortDir = currentWoSortDir === 'asc' ? 'desc' : 'asc';
      } else {
        currentWoSortKey = key;
        currentWoSortDir = key === 'id' ? 'asc' : 'desc';
      }

      updateWoSortHeaderStyles();
      applyWoFilter();
    });
  });

  updateWoSortHeaderStyles();
}

function updateWoSortHeaderStyles() {
  const headerCells = document.querySelectorAll('#wos-table th[data-sort-key]');
  headerCells.forEach((th) => {
    const key = th.getAttribute('data-sort-key');
    th.classList.remove('sort-asc', 'sort-desc');
    if (key === currentWoSortKey) {
      th.classList.add(currentWoSortDir === 'asc' ? 'sort-asc' : 'sort-desc');
    }
  });
}

function initWoAutorefreshControls() {
  const refreshBtn = document.getElementById('wo-refresh-btn');
  const retryBtn = document.getElementById('wos-error-retry');
  const toggle = document.getElementById('wo-autorefresh-toggle');
  const intervalInput = document.getElementById('wo-autorefresh-interval');

  refreshBtn?.addEventListener('click', () => loadWos());
  retryBtn?.addEventListener('click', () => loadWos());

  toggle?.addEventListener('change', () => {
    woAutorefreshEnabled = Boolean(toggle.checked);
    if (woAutorefreshEnabled) {
      startWoAutorefresh();
    } else {
      stopWoAutorefresh();
    }
  });

  intervalInput?.addEventListener('change', () => {
    const seconds = Number(intervalInput.value);
    if (!Number.isFinite(seconds) || seconds < 5) {
      return;
    }
    woAutorefreshIntervalMs = seconds * 1000;
    if (woAutorefreshEnabled) {
      startWoAutorefresh();
    }
  });
}

function startWoAutorefresh() {
  stopWoAutorefresh();
  woAutorefreshTimer = setInterval(() => loadWos(), woAutorefreshIntervalMs);
}

function stopWoAutorefresh() {
  if (woAutorefreshTimer) {
    clearInterval(woAutorefreshTimer);
    woAutorefreshTimer = null;
  }
}

function setWosLoading(message) {
  const tbody = document.getElementById('wos-table-body');
  if (!tbody) return;
  tbody.innerHTML = `<tr><td colspan="7">${message}</td></tr>`;
}

async function loadWos() {
  const tbody = document.getElementById('wos-table-body');
  if (!tbody) return;

  setWosLoading('Loading work orders…');
  hideErrorBanner('wos-error');

  try {
    const res = await fetch('/api/wos', {
      headers: { Accept: 'application/json' }
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    const data = await res.json();
    let wos = [];
    if (Array.isArray(data)) {
      wos = data;
    } else if (Array.isArray(data?.wos)) {
      wos = data.wos;
    } else if (Array.isArray(data?.results)) {
      wos = data.results;
    }

    allWos = wos;
    applyWoFilter();

    const ts = new Date().toLocaleTimeString();
    const refreshLabel = document.getElementById('wo-last-refresh');
    if (refreshLabel) {
      refreshLabel.textContent = `Last refresh: ${ts}`;
    }
  } catch (error) {
    console.error('Failed to load work orders', error);
    showErrorBanner('wos-error', 'Failed to load work orders.');
    setWosLoading('Failed to load work orders.');
  }
}

function applyWoFilter() {
  let filtered = allWos.slice();

  if (currentWoFilter !== 'all') {
    filtered = filtered.filter((wo) => normalizeWoStatus(wo.status || wo.state) === currentWoFilter);
  }

  if (currentWoSearch) {
    const q = currentWoSearch;
    filtered = filtered.filter((wo) => buildWoSearchHaystack(wo).includes(q));
  }

  filtered.sort((a, b) => compareWos(a, b, currentWoSortKey, currentWoSortDir));

  visibleWos = filtered;
  renderWosTable(filtered);
  renderWoSummary(filtered);
}

function renderWosTable(wos) {
  const tbody = document.getElementById('wos-table-body');
  if (!tbody) return;

  if (!wos.length) {
    tbody.innerHTML = '<tr><td colspan="7">No work orders match the current filters.</td></tr>';
    return;
  }

  tbody.innerHTML = '';
  wos.forEach((wo) => {
    const tr = document.createElement('tr');
    const status = normalizeWoStatus(wo.status || wo.state);
    const started = formatWoTimestamp(wo.started_at || wo.startedAt);
    const finished = formatWoTimestamp(getWoCompletedTime(wo));
    const updated = formatWoTimestamp(wo.updated_at || wo.updatedAt || wo.last_update || wo.lastUpdate);
    const actions = Array.isArray(wo.actions) ? wo.actions.join(', ') : wo.action || '—';
    const timeline = Array.isArray(wo.timeline) ? `${wo.timeline.length} events` : '—';

    tr.innerHTML = `
      <td><code>${escapeHtml(wo?.id ?? '')}</code></td>
      <td>${escapeHtml(status)}</td>
      <td>${escapeHtml(started)}</td>
      <td>${escapeHtml(finished)}</td>
      <td>${escapeHtml(updated)}</td>
      <td>${escapeHtml(actions || '—')}</td>
      <td>${escapeHtml(timeline)}</td>
    `;

    tbody.appendChild(tr);
  });
}

function renderWoSummary(wos) {
  const summary = document.getElementById('wos-summary');
  if (!summary) return;

  const totals = {
    running: 0,
    pending: 0,
    completed: 0,
    failed: 0
  };

  wos.forEach((wo) => {
    const status = normalizeWoStatus(wo.status || wo.state);
    if (status in totals) {
      totals[status] += 1;
    }
  });

  summary.innerHTML = `
    <span><strong>Total:</strong> ${allWos.length}</span>
    <span><strong>Visible:</strong> ${wos.length}</span>
    <span><span class="summary-dot running"></span>Running: ${totals.running}</span>
    <span><span class="summary-dot stopped"></span>Pending: ${totals.pending}</span>
    <span><span class="summary-dot failed"></span>Failed: ${totals.failed}</span>
    <span><span class="summary-dot completed"></span>Completed: ${totals.completed}</span>
  `;
}

function normalizeWoStatus(status) {
  if (!status) return 'unknown';
  const normalized = String(status).toLowerCase();
  if (['success', 'completed', 'complete', 'done'].includes(normalized)) {
    return 'completed';
  }
  if (['failed', 'failure', 'error', 'blocked', 'cancelled'].includes(normalized)) {
    return 'failed';
  }
  if (['running', 'in_progress', 'in-progress', 'active'].includes(normalized)) {
    return 'running';
  }
  if (['pending', 'queued', 'waiting'].includes(normalized)) {
    return 'pending';
  }
  return normalized;
}

function compareWos(a, b, sortKey, sortDir) {
  const dir = sortDir === 'asc' ? 1 : -1;

  if (sortKey === 'id') {
    return compareWoIds(a?.id, b?.id) * dir;
  }

  if (sortKey === 'status') {
    const va = getStatusSortValue(a?.status);
    const vb = getStatusSortValue(b?.status);
    if (va !== vb) {
      return (va - vb) * dir;
    }
    return compareWoIds(a?.id, b?.id) * dir;
  }

  const va = getWoSortValue(a, sortKey);
  const vb = getWoSortValue(b, sortKey);

  if (va < vb) return -1 * dir;
  if (va > vb) return 1 * dir;
  return compareWoIds(a?.id, b?.id) * dir;
}

function getWoSortValue(wo, sortKey) {
  switch (sortKey) {
    case 'started_at':
      return normalizeWoTimestamp(wo?.started_at || wo?.startedAt);
    case 'finished_at':
      return normalizeWoTimestamp(getWoCompletedTime(wo));
    case 'updated_at':
      return normalizeWoTimestamp(wo?.updated_at || wo?.updatedAt || wo?.last_update || wo?.lastUpdate);
    default:
      return 0;
  }
}

function getStatusSortValue(status) {
  const normalized = normalizeWoStatus(status);
  if (Object.prototype.hasOwnProperty.call(WO_STATUS_SORT_ORDER, normalized)) {
    return WO_STATUS_SORT_ORDER[normalized];
  }
  return 0;
}

function compareWoIds(aId, bId) {
  const aInfo = normalizeWoId(aId);
  const bInfo = normalizeWoId(bId);

  if (aInfo.numeric !== null && bInfo.numeric !== null && aInfo.numeric !== bInfo.numeric) {
    return aInfo.numeric - bInfo.numeric;
  }

  if (aInfo.numeric !== null && bInfo.numeric === null) {
    return -1;
  }
  if (aInfo.numeric === null && bInfo.numeric !== null) {
    return 1;
  }

  if (aInfo.text < bInfo.text) return -1;
  if (aInfo.text > bInfo.text) return 1;
  return 0;
}

function normalizeWoId(value) {
  if (value === undefined || value === null) {
    return { numeric: null, text: '' };
  }
  const text = String(value).toLowerCase();
  const match = text.match(/(\d+)/);
  const numeric = match ? Number(match[1]) : null;
  return { numeric: Number.isNaN(numeric) ? null : numeric, text };
}

function buildWoSearchHaystack(wo) {
  const haystacks = [];
  if (wo.id) haystacks.push(String(wo.id));
  if (wo.title) haystacks.push(String(wo.title));
  if (wo.context) haystacks.push(String(wo.context));
  if (wo.summary) haystacks.push(String(wo.summary));
  if (wo.description) haystacks.push(String(wo.description));
  if (wo.agent) haystacks.push(String(wo.agent));
  if (wo.worker) haystacks.push(String(wo.worker));
  if (wo.type) haystacks.push(String(wo.type));
  if (wo.action) haystacks.push(String(wo.action));
  if (Array.isArray(wo.actions) && wo.actions.length) {
    haystacks.push(wo.actions.join(' '));
  }
  if (Array.isArray(wo.tags) && wo.tags.length) {
    haystacks.push(wo.tags.join(' '));
  }
  if (wo.contextual_data) {
    haystacks.push(String(wo.contextual_data));
  }
  return haystacks.join(' ').toLowerCase();
}

function normalizeWoTimestamp(value) {
  if (!value) return 0;
  if (typeof value === 'number') return value;
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) return 0;
  return parsed;
}

function formatWoTimestamp(value) {
  const ts = normalizeWoTimestamp(value);
  if (!ts) return '—';
  const date = new Date(ts);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString();
}

// Helper to get completion time (checks completed_at first, then finished_at)
function getWoCompletedTime(wo) {
  return wo?.completed_at || wo?.finished_at || wo?.finishedAt || '';
}

// --- Services ---

function setServicesLoading() {
  const summary = document.getElementById('services-summary');
  const tbody = document.getElementById('services-tbody');
  if (summary) {
    summary.innerHTML = '<span>Loading services…</span>';
  }
  if (tbody) {
    tbody.innerHTML = '<tr><td colspan="5">Loading…</td></tr>';
  }
}

async function loadServices() {
  const tbody = document.getElementById('services-tbody');
  const summary = document.getElementById('services-summary');
  if (!tbody || !summary) return;

  setServicesLoading();
  hideErrorBanner('services-error');

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
    showErrorBanner('services-error', 'Failed to load services.');
    summary.innerHTML = '<span>Failed to load services.</span>';
    tbody.innerHTML = '<tr><td colspan="5">Failed to load services.</td></tr>';
  }
}

function renderServicesSummary(summary = {}) {
  const el = document.getElementById('services-summary');
  if (!el) return;
  const total = summary.total ?? '–';
  const running = summary.running ?? '–';
  const stopped = summary.stopped ?? '–';
  const failed = summary.failed ?? '–';

  el.innerHTML = `
    <span><strong>Total:</strong> ${total}</span>
    <span><span class="summary-dot running"></span>Running: ${running}</span>
    <span><span class="summary-dot stopped"></span>Stopped: ${stopped}</span>
    <span><span class="summary-dot failed"></span>Failed: ${failed}</span>
  `;
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
    const type = svc.type ?? '—';

    const labelCell = document.createElement('td');
    labelCell.textContent = svc.label ?? '';

    const statusCell = document.createElement('td');
    statusCell.appendChild(createStatusChip(statusLabel));

    const pidCell = document.createElement('td');
    pidCell.textContent = pid;

    const exitCell = document.createElement('td');
    exitCell.textContent = exitCode;

    const typeCell = document.createElement('td');
    typeCell.textContent = type;

    tr.append(labelCell, statusCell, pidCell, exitCell, typeCell);
    tbody.appendChild(tr);
  });
}

function createStatusChip(status) {
  const normalized = status || 'unknown';
  const span = document.createElement('span');
  span.className = `status-chip status-${normalized}`;
  span.textContent = normalized;
  return span;
}

function initServicesPanel() {
  if (servicesIntervalId) {
    return;
  }

  const statusSelect = document.getElementById('services-status-filter');
  const typeSelect = document.getElementById('services-type-filter');
  const refreshBtn = document.getElementById('services-refresh-btn');
  document.getElementById('services-error-retry')?.addEventListener('click', loadServices);

  statusSelect?.addEventListener('change', loadServices);
  typeSelect?.addEventListener('change', loadServices);
  refreshBtn?.addEventListener('click', loadServices);

  loadServices();
  servicesIntervalId = setInterval(loadServices, SERVICES_REFRESH_MS);
}

// --- MLS ---

function setMLSLoading() {
  const summary = document.getElementById('mls-summary');
  const list = document.getElementById('mls-list');
  if (summary) {
    summary.innerHTML = '<span>Loading lessons…</span>';
  }
  if (list) {
    list.textContent = 'Loading…';
  }
}

async function loadMLS(typeOverride) {
  const summary = document.getElementById('mls-summary');
  const list = document.getElementById('mls-list');
  if (!summary || !list) return;

  if (typeof typeOverride === 'string') {
    currentMlsType = typeOverride;
  }

  setMLSLoading();
  hideErrorBanner('mls-error');

  try {
    const params = new URLSearchParams();
    if (currentMlsType) params.set('type', currentMlsType);
    const query = params.toString();

    const data = await fetchJSON(`/api/mls${query ? `?${query}` : ''}`);
    const entries = Array.isArray(data?.entries) ? data.entries : [];

    renderMLSSummary(data?.summary);
    renderMLSList(entries);
  } catch (error) {
    console.error('Failed to load MLS lessons', error);
    showErrorBanner('mls-error', 'Failed to load MLS lessons.');
    summary.innerHTML = '<span>Failed to load MLS lessons.</span>';
    list.textContent = 'Failed to load MLS lessons.';
  }
}

function renderMLSSummary(summary = {}) {
  const el = document.getElementById('mls-summary');
  if (!el) return;

  el.innerHTML = `
    <span><strong>Total:</strong> ${summary.total ?? '–'}</span>
    <span>Solutions: ${summary.solutions ?? '–'}</span>
    <span>Failures: ${summary.failures ?? '–'}</span>
    <span>Patterns: ${summary.patterns ?? '–'}</span>
    <span>Improvements: ${summary.improvements ?? '–'}</span>
  `;
}

function renderMLSList(entries) {
  const list = document.getElementById('mls-list');
  if (!list) return;

  if (!entries.length) {
    list.textContent = 'No MLS lessons found.';
    return;
  }

  list.innerHTML = '';

  entries.forEach((entry) => {
    list.appendChild(createMLSCard(entry));
  });
}

function createMLSCard(entry) {
  const card = document.createElement('article');
  card.className = 'mls-card';

  const header = document.createElement('header');
  const badge = document.createElement('span');
  const badgeType = entry.type ? `badge-${entry.type}` : 'badge-pattern';
  badge.className = `badge ${badgeType}`;
  badge.textContent = entry.type ?? 'entry';
  const title = document.createElement('h3');
  title.textContent = entry.title ?? 'Untitled lesson';
  header.append(badge, title);
  card.appendChild(header);

  const score = typeof entry.score === 'number' ? entry.score.toFixed(2) : entry.score ?? '–';
  const tags = Array.isArray(entry.tags) ? entry.tags : [];
  const relativeTime = formatRelativeTime(entry.time);

  const meta = document.createElement('div');
  meta.className = 'mls-meta';
  if (relativeTime) {
    const timeSpan = document.createElement('span');
    timeSpan.textContent = relativeTime;
    meta.appendChild(timeSpan);
  }
  const scoreSpan = document.createElement('span');
  scoreSpan.textContent = `score ${score}`;
  meta.appendChild(scoreSpan);
  if (tags.length) {
    const tagsSpan = document.createElement('span');
    tagsSpan.textContent = `tags: ${tags.join(', ')}`;
    meta.appendChild(tagsSpan);
  }
  card.appendChild(meta);

  const detailsText = (entry.details || entry.context || '').trim();
  if (detailsText) {
    const detailParagraph = document.createElement('p');
    const truncated = detailsText.length > 280;
    detailParagraph.textContent = truncated ? `${detailsText.slice(0, 280)}…` : detailsText;
    card.appendChild(detailParagraph);

    if (truncated) {
      const toggleBtn = document.createElement('button');
      toggleBtn.type = 'button';
      toggleBtn.textContent = 'Show more';
      toggleBtn.addEventListener('click', () => {
        const isExpanded = toggleBtn.getAttribute('data-expanded') === 'true';
        if (isExpanded) {
          detailParagraph.textContent = `${detailsText.slice(0, 280)}…`;
          toggleBtn.textContent = 'Show more';
          toggleBtn.setAttribute('data-expanded', 'false');
        } else {
          detailParagraph.textContent = detailsText;
          toggleBtn.textContent = 'Show less';
          toggleBtn.setAttribute('data-expanded', 'true');
        }
      });
      card.appendChild(toggleBtn);
    }
  }

  const footer = document.createElement('div');
  footer.className = 'mls-footer';
  if (entry.related_wo) {
    const woSpan = document.createElement('span');
    woSpan.textContent = `WO: ${entry.related_wo}`;
    footer.appendChild(woSpan);
  }
  if (entry.related_session) {
    const sessionSpan = document.createElement('span');
    sessionSpan.textContent = `Session: ${entry.related_session}`;
    footer.appendChild(sessionSpan);
  }
  if (entry.verified) {
    const verifiedSpan = document.createElement('span');
    verifiedSpan.textContent = 'Verified';
    footer.appendChild(verifiedSpan);
  }
  if (footer.childNodes.length) {
    card.appendChild(footer);
  }

  return card;
}

// --- WO History ---

function renderWoHistoryTimeline(wos) {
  const container = document.getElementById('wo-history-timeline');
  const summaryEl = document.getElementById('wo-history-summary');
  if (!container || !summaryEl) return;

  container.innerHTML = '';

  if (!Array.isArray(wos) || !wos.length) {
    summaryEl.textContent = 'No work orders in this range.';
    return;
  }

  let completed = 0;
  let failed = 0;
  let totalDuration = 0;
  let countDuration = 0;

  wos.forEach((wo) => {
    const status = wo?.status || '';
    if (status === 'completed') completed += 1;
    if (status === 'failed' || status === 'error') failed += 1;
    const dur = computeDurationMs(wo);
    if (dur != null) {
      totalDuration += dur;
      countDuration += 1;
    }
  });

  const total = wos.length;
  const successRate = total > 0 ? Math.round((completed / total) * 100) : 0;
  const avgDuration = countDuration > 0 ? formatDuration(totalDuration / countDuration) : '—';

  summaryEl.textContent =
    `Total: ${total} | Completed: ${completed} | Failed: ${failed} | ` +
    `Success rate: ${successRate}% | Avg duration: ${avgDuration}`;

  const dayGroups = groupWosByDay(wos);
  dayGroups.forEach((group) => {
    const dayDiv = document.createElement('div');
    dayDiv.className = 'wo-history-day';

    const header = document.createElement('div');
    header.className = 'wo-history-day-header';
    header.textContent = group.day;
    dayDiv.appendChild(header);

    group.list.forEach((wo) => {
      const item = document.createElement('div');
      item.className = 'wo-history-item';

      const main = document.createElement('div');
      main.className = 'wo-history-item-main';

      const statusBadge = document.createElement('span');
      const status = wo?.status || 'unknown';
      statusBadge.className = 'wo-history-item-status';
      if (status === 'completed') {
        statusBadge.classList.add('wo-history-item-status--completed');
      } else if (status === 'failed' || status === 'error') {
        statusBadge.classList.add('wo-history-item-status--failed');
      }
      statusBadge.textContent = status;

      const title = document.createElement('span');
      title.className = 'wo-history-item-title';
      title.textContent = wo?.title || wo?.id || '(no title)';

      main.appendChild(statusBadge);
      main.appendChild(title);

      const meta = document.createElement('div');
      meta.className = 'wo-history-item-meta';

      const startedDate = wo?.started_at ? new Date(wo.started_at) : null;
      const finishedDate = wo?.finished_at ? new Date(wo.finished_at) : null;

      const started =
        startedDate && !Number.isNaN(startedDate.getTime())
          ? startedDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
          : '';
      const finished =
        finishedDate && !Number.isNaN(finishedDate.getTime())
          ? finishedDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
          : '';

      const duration = formatDuration(computeDurationMs(wo));

      meta.textContent =
        [
          started && finished ? `${started} → ${finished}` : started || finished,
          duration && `(${duration})`,
          wo?.id && `ID: ${wo.id}`
        ]
          .filter(Boolean)
          .join('  ·  ');

      item.appendChild(main);
      item.appendChild(meta);

      dayDiv.appendChild(item);
    });

    container.appendChild(dayDiv);
  });
}

async function loadWoHistory() {
  const rangeSelect = document.getElementById('wo-history-range');
  const statusSelect = document.getElementById('wo-history-status');

  const limit = rangeSelect ? parseInt(rangeSelect.value, 10) || 100 : 100;
  const statusValue = statusSelect ? statusSelect.value : 'completed,failed,error';

  const params = new URLSearchParams();
  if (statusValue) params.set('status', statusValue);

  const query = params.toString();
  const url = `/api/wos${query ? `?${query}` : ''}`;

  try {
    const res = await fetch(url, {
      headers: {
        Accept: 'application/json'
      }
    });
    if (!res.ok) {
      console.error('Failed to load WO history:', res.status, res.statusText);
      return;
    }
    let data = await res.json();
    let wos = [];
    if (Array.isArray(data)) {
      wos = data;
    } else if (Array.isArray(data?.wos)) {
      wos = data.wos;
    } else if (Array.isArray(data?.results)) {
      wos = data.results;
    }

    const sorted = wos
      .slice()
      .sort((a, b) => {
        const ta = a?.started_at || a?.finished_at || a?.id;
        const tb = b?.started_at || b?.finished_at || b?.id;
        return (tb || '').localeCompare(ta || '');
      })
      .slice(0, limit);

    renderWoHistoryTimeline(sorted);
    woHistoryLoadedOnce = true;
  } catch (error) {
    console.error('Error loading WO history', error);
  }
}

function initWoHistoryTab() {
  const rangeSelect = document.getElementById('wo-history-range');
  const statusSelect = document.getElementById('wo-history-status');

  rangeSelect?.addEventListener('change', () => {
    loadWoHistory();
  });
  statusSelect?.addEventListener('change', () => {
    loadWoHistory();
  });
}

// --- Work Orders (table + timeline) ---

function initWoFilters() {
  const statusSelect = document.getElementById('wo-status-filter');
  if (!statusSelect) return;

  currentWoStatusFilter = statusSelect.value || '';
  statusSelect.addEventListener('change', () => {
    currentWoStatusFilter = statusSelect.value || '';
    loadWos();
  });
}

function initWoSearch() {
  const searchInput = document.getElementById('wo-search-input');
  if (!searchInput) return;

  searchInput.addEventListener('input', () => {
    currentWoSearch = searchInput.value.trim().toLowerCase();
    renderWosTable(currentWos);
  });
}

function initWoSorting() {
  const headers = document.querySelectorAll('#wos-table thead th[data-sort-key]');
  headers.forEach((th) => {
    th.addEventListener('click', () => {
      const key = th.dataset.sortKey;
      if (!key) return;
      if (currentWoSortKey === key) {
        currentWoSortDir = currentWoSortDir === 'asc' ? 'desc' : 'asc';
      } else {
        currentWoSortKey = key;
        currentWoSortDir = 'desc';
      }
      renderWosTable(currentWos);
    });
  });
}

function initWoAutorefreshControls() {
  const toggle = document.getElementById('wo-autorefresh-toggle');
  const refreshBtn = document.getElementById('wo-refresh-btn');

  refreshBtn?.addEventListener('click', () => loadWos());

  const updateAutorefresh = () => {
    if (woAutorefreshIntervalId) {
      clearInterval(woAutorefreshIntervalId);
      woAutorefreshIntervalId = null;
    }
    if (toggle?.checked) {
      woAutorefreshIntervalId = setInterval(() => loadWos(), WO_AUTOREFRESH_MS);
    }
  };

  toggle?.addEventListener('change', updateAutorefresh);
  updateAutorefresh();
}

async function loadWos() {
  const tbody = document.getElementById('wos-table-body');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="7">Loading…</td></tr>';

  const params = new URLSearchParams();
  if (currentWoStatusFilter) params.set('status', currentWoStatusFilter);
  params.set('limit', '200');
  const query = params.toString();

  try {
    const res = await fetch(`/api/wos${query ? `?${query}` : ''}`, {
      headers: { Accept: 'application/json' }
    });
    if (!res.ok) {
      throw new Error(`Failed to fetch work orders: ${res.status}`);
    }
    const data = await res.json();
    let wos = [];
    if (Array.isArray(data)) {
      wos = data;
    } else if (Array.isArray(data?.wos)) {
      wos = data.wos;
    } else if (Array.isArray(data?.results)) {
      wos = data.results;
    }
    currentWos = wos;
    renderWosTable(currentWos);
  } catch (error) {
    console.error('Failed to load work orders', error);
    tbody.innerHTML = '<tr><td colspan="7">Failed to load work orders.</td></tr>';
  }
}

function renderWosTable(wos) {
  const tbody = document.getElementById('wos-table-body');
  if (!tbody) return;

  if (!Array.isArray(wos) || !wos.length) {
    tbody.innerHTML = '<tr><td colspan="7">No work orders found.</td></tr>';
    highlightActiveTimelineRow();
    return;
  }

  const searchTerm = currentWoSearch.trim().toLowerCase();

  const filtered = wos.filter((wo) => {
    if (currentWoStatusFilter) {
      const status = normalizeWoStatus(wo?.status || '').toLowerCase();
      if (status !== currentWoStatusFilter.toLowerCase()) {
        return false;
      }
    }
    if (!searchTerm) return true;
    return getWoSearchableText(wo).includes(searchTerm);
  });

  if (!filtered.length) {
    tbody.innerHTML = '<tr><td colspan="7">No work orders match your filters.</td></tr>';
    highlightActiveTimelineRow();
    return;
  }

  const sorted = [...filtered].sort((a, b) => {
    const aVal = getWoSortValue(a, currentWoSortKey);
    const bVal = getWoSortValue(b, currentWoSortKey);
    if (aVal === bVal) return 0;
    if (aVal > bVal) return currentWoSortDir === 'asc' ? 1 : -1;
    return currentWoSortDir === 'asc' ? -1 : 1;
  });

  tbody.innerHTML = '';

  sorted.forEach((wo) => {
    const tr = document.createElement('tr');
    const woId = wo?.id ? String(wo.id) : '';
    tr.dataset.woId = woId;

    const idTd = document.createElement('td');
    const idCode = document.createElement('code');
    idCode.textContent = wo?.id ?? '';
    idTd.appendChild(idCode);

    const statusTd = document.createElement('td');
    statusTd.textContent = normalizeWoStatus(wo?.status || '');

    const startedTd = document.createElement('td');
    startedTd.textContent = formatWoTime(wo?.started_at || wo?.startedAt || '');

    const finishedTd = document.createElement('td');
    finishedTd.textContent = formatWoTime(getWoCompletedTime(wo) || '');

    const updatedTd = document.createElement('td');
    updatedTd.textContent = formatWoTime(
      wo?.updated_at || wo?.updatedAt || wo?.last_update || wo?.lastUpdate || ''
    );

    const actionsTd = document.createElement('td');
    actionsTd.textContent = '—';

    const timelineTd = document.createElement('td');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = 'Timeline';
    btn.className = 'wo-timeline-button';
    btn.dataset.woId = woId;
    btn.setAttribute('aria-pressed', currentTimelineWoId && woId === currentTimelineWoId ? 'true' : 'false');
    btn.setAttribute('aria-label', woId ? `Open timeline for work order ${woId}` : 'Open work order timeline');
    btn.addEventListener('click', () => {
      const woId = wo?.id;
      if (!woId) return;
      openWoTimeline(woId);
    });
    timelineTd.appendChild(btn);

    tr.appendChild(idTd);
    tr.appendChild(statusTd);
    tr.appendChild(startedTd);
    tr.appendChild(finishedTd);
    tr.appendChild(updatedTd);
    tr.appendChild(actionsTd);
    tr.appendChild(timelineTd);

    if (currentTimelineWoId && woId === currentTimelineWoId) {
      tr.classList.add('wo-timeline-active-row');
    }
  }

  highlightActiveTimelineRow();
}

function getWoSearchableText(wo) {
  return [
    wo?.id,
    wo?.status,
    wo?.agent,
    wo?.worker,
    wo?.type,
    wo?.summary,
    wo?.description
  ]
    .map((value) => String(value || '').toLowerCase())
    .join(' ');
}

function getWoSortValue(wo, key) {
  if (!wo || !key) return '';
  const camelKey = key.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
  const value = wo[key] ?? wo[camelKey];
  if (value === undefined || value === null) {
    return '';
  }
  if (/_at$/i.test(key) || /At$/.test(key)) {
    const timestamp = Date.parse(value);
    if (!Number.isNaN(timestamp)) {
      return timestamp;
    }
  }
  if (typeof value === 'string') {
    return value.toLowerCase();
  }
  return value;
}

function normalizeWoStatus(status) {
  if (!status) return '';
  const str = String(status).trim();
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}

function formatWoTime(value) {
  if (!value) return '';
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    return String(value);
  }
  const date = new Date(timestamp);
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const mi = String(date.getMinutes()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd} ${hh}:${mi}`;
}

function initWoTimeline() {
  const closeBtn = document.getElementById('wo-timeline-close');
  const section = document.getElementById('wo-timeline-section');
  const subtitleEl = document.getElementById('wo-timeline-subtitle');
  const titleEl = document.getElementById('wo-timeline-title');
  const contentEl = document.getElementById('wo-timeline-content');
  if (!closeBtn || !section) return;

  closeBtn.addEventListener('click', () => {
    section.classList.add('hidden');
    currentTimelineWoId = null;
    if (titleEl) {
      titleEl.textContent = 'WO Timeline';
    }
    if (subtitleEl) {
      subtitleEl.textContent = 'Select a work order from the table to see its history.';
    }
    if (contentEl) {
      contentEl.innerHTML = '';
    }
    highlightActiveTimelineRow();
  });
}

async function openWoTimeline(woId) {
  const section = document.getElementById('wo-timeline-section');
  const titleEl = document.getElementById('wo-timeline-title');
  const subtitleEl = document.getElementById('wo-timeline-subtitle');
  const contentEl = document.getElementById('wo-timeline-content');

  if (!section || !titleEl || !subtitleEl || !contentEl) return;

  currentTimelineWoId = woId;
  highlightActiveTimelineRow();

  titleEl.textContent = `WO Timeline — ${woId}`;
  subtitleEl.textContent = 'Loading timeline and log tail…';
  section.classList.remove('hidden');
  contentEl.innerHTML = '';

  try {
    const res = await fetch(`/api/wos/${encodeURIComponent(woId)}?tail=200`, {
      headers: { Accept: 'application/json' }
    });
    if (!res.ok) {
      subtitleEl.textContent = `Failed to load WO ${woId} (status ${res.status})`;
      return;
    }
    const wo = await res.json();
    if (currentTimelineWoId !== woId) {
      return;
    }
    subtitleEl.textContent = buildTimelineSubtitle(wo);
    renderWoTimelineContent(wo);
  } catch (error) {
    console.error('Error loading WO timeline', error);
    subtitleEl.textContent = `Error loading timeline for WO ${woId}`;
  }
}

function buildTimelineSubtitle(wo) {
  const status = normalizeWoStatus(wo?.status || 'unknown');
  const started = formatWoTime(wo?.started_at || wo?.startedAt);
  const finished = formatWoTime(getWoCompletedTime(wo));
  const updated = formatWoTime(
    wo?.updated_at || wo?.updatedAt || wo?.last_update || wo?.lastUpdate
  );

  const parts = [`Status: ${status || 'Unknown'}`];
  if (started) parts.push(`Started: ${started}`);
  if (finished) parts.push(`Finished: ${finished}`);
  if (updated) parts.push(`Last update: ${updated}`);

  return parts.join(' • ');
}

function renderWoTimelineContent(wo) {
  const contentEl = document.getElementById('wo-timeline-content');
  if (!contentEl) return;

  const eventsColumn = document.createElement('div');
  eventsColumn.className = 'wo-timeline-events';
  const eventsTitle = document.createElement('h4');
  eventsTitle.textContent = 'Key Events';
  eventsColumn.appendChild(eventsTitle);

  const eventsList = document.createElement('ul');
  eventsList.className = 'wo-timeline-list';

  const events = buildWoEventsList(wo);
  if (!events.length) {
    const emptyItem = document.createElement('li');
    emptyItem.className = 'wo-timeline-item';
    emptyItem.textContent = 'No timeline events available.';
    eventsList.appendChild(emptyItem);
  } else {
    events.forEach((event) => {
      const item = document.createElement('li');
      item.className = 'wo-timeline-item';

      const timeEl = document.createElement('div');
      timeEl.className = 'wo-timeline-item-time';
      timeEl.textContent = event.time || '';

      const labelEl = document.createElement('div');
      labelEl.className = 'wo-timeline-item-label';
      labelEl.textContent = event.label;

      item.appendChild(timeEl);
      item.appendChild(labelEl);

      if (event.meta) {
        const metaEl = document.createElement('div');
        metaEl.className = 'wo-timeline-item-meta';
        metaEl.textContent = event.meta;
        item.appendChild(metaEl);
      }

      eventsList.appendChild(item);
    });
  }

  eventsColumn.appendChild(eventsList);

  const logsColumn = document.createElement('div');
  logsColumn.className = 'wo-timeline-logs';
  const logsTitle = document.createElement('h4');
  logsTitle.textContent = 'Log Tail';
  logsColumn.appendChild(logsTitle);

  const logContainer = document.createElement('div');
  let logLines = null;
  if (Array.isArray(wo?.log_tail)) {
    logLines = wo.log_tail;
  } else if (Array.isArray(wo?.logTail)) {
    logLines = wo.logTail;
  } else if (typeof wo?.log_tail === 'string') {
    logLines = wo.log_tail.split('\n');
  }

  if (logLines && logLines.length) {
    const pre = document.createElement('pre');
    pre.className = 'wo-log-lines';
    pre.textContent = logLines.join('\n');
    logContainer.appendChild(pre);
  } else {
    const emptyLog = document.createElement('div');
    emptyLog.className = 'wo-log-empty';
    emptyLog.textContent = 'No log tail available for this work order.';
    logContainer.appendChild(emptyLog);
  }

  logsColumn.appendChild(logContainer);

  contentEl.innerHTML = '';
  contentEl.appendChild(eventsColumn);
  contentEl.appendChild(logsColumn);
}

function highlightActiveTimelineRow() {
  const rows = document.querySelectorAll('#wos-table-body tr');
  const activeId = currentTimelineWoId ? String(currentTimelineWoId) : '';
  rows.forEach((row) => {
    const rowId = row.dataset.woId || '';
    const isActive = Boolean(activeId && rowId === activeId);
    row.classList.toggle('wo-timeline-active-row', isActive);
    const button = row.querySelector('.wo-timeline-button');
    if (button) {
      button.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    }
  });
}

function buildWoEventsList(wo) {
  const events = [];

  const addEvent = (timeValue, label, meta) => {
    if (!timeValue) return;
    events.push({
      rawTime: timeValue,
      time: formatWoTime(timeValue),
      label,
      meta: meta ? String(meta) : ''
    });
  };

  addEvent(wo?.created_at || wo?.createdAt, 'Created', wo?.created_by || wo?.createdBy);
  addEvent(wo?.started_at || wo?.startedAt, 'Started', wo?.worker || wo?.agent);
  addEvent(getWoCompletedTime(wo), 'Finished', wo?.result || wo?.outcome);
  addEvent(
    wo?.updated_at || wo?.updatedAt || wo?.last_update || wo?.lastUpdate,
    'Last updated',
    wo?.status ? normalizeWoStatus(wo.status) : ''
  );

  if (Array.isArray(wo?.events)) {
    wo.events.forEach((event) => {
      addEvent(event?.time || event?.timestamp, event?.label || event?.type || 'Event', event?.details || event?.message);
    });
  }

  events.sort((a, b) => {
    const aTime = Date.parse(a.rawTime || '') || 0;
    const bTime = Date.parse(b.rawTime || '') || 0;
    return aTime - bTime;
  });

  return events;
}

function escapeHtml(str) {
  if (str === null || str === undefined) {
    return '';
  }
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function initWoHistoryFilters() {
  const statusFilter = document.getElementById('wo-history-status-filter');
  const limitSelect = document.getElementById('wo-history-limit');

  statusFilter?.addEventListener('change', () => loadWoHistory());
  limitSelect?.addEventListener('change', () => loadWoHistory());
}

// --- Reality Snapshot ---

function setRealityLoading() {
  const meta = document.getElementById('reality-meta');
  const deployEl = document.getElementById('reality-deployment');
  const saveBody = document.getElementById('reality-save-body');
  const orchEl = document.getElementById('reality-orchestrator');

  if (meta) meta.textContent = 'Loading Reality snapshot…';
  if (deployEl) deployEl.textContent = 'Loading deployment data…';
  if (orchEl) orchEl.textContent = 'Loading orchestrator summary…';
  if (saveBody) {
    saveBody.innerHTML = '<tr><td colspan="7">Loading save.sh runs…</td></tr>';
  }

  updateRealityBadge(document.getElementById('reality-badge-deploy'), 'Deployment', null);
  updateRealityBadge(document.getElementById('reality-badge-save'), 'save.sh', null);
  updateRealityBadge(document.getElementById('reality-badge-orch'), 'Orchestrator', null);
}

async function loadRealitySnapshot() {
  const meta = document.getElementById('reality-meta');
  if (!meta) {
    return;
  }
  if (realityLoading) {
    return;
  }

  setRealityLoading();
  hideErrorBanner('reality-error');
  realityLoading = true;

  try {
    const res = await fetch('/api/reality/snapshot?advisory=1');
    if (!res.ok) {
      console.error('Failed to fetch Reality snapshot', res.status, await res.text());
      renderRealityError(`HTTP ${res.status}`);
      return;
    }

    const payload = await res.json();
    renderRealitySnapshot(payload);
  } catch (error) {
    console.error('Error loading Reality snapshot', error);
    renderRealityError('Failed to load Reality snapshot.');
  } finally {
    realityLoading = false;
  }
}

function renderRealitySnapshot(payload) {
  const meta = document.getElementById('reality-meta');
  const deployEl = document.getElementById('reality-deployment');
  const saveBody = document.getElementById('reality-save-body');
  const orchEl = document.getElementById('reality-orchestrator');
  const badgeDeploy = document.getElementById('reality-badge-deploy');
  const badgeSave = document.getElementById('reality-badge-save');
  const badgeOrch = document.getElementById('reality-badge-orch');

  if (!meta || !deployEl || !saveBody || !orchEl) {
    return;
  }

  hideErrorBanner('reality-error');
  updateRealityBadge(badgeDeploy, 'Deployment', null);
  updateRealityBadge(badgeSave, 'save.sh', null);
  updateRealityBadge(badgeOrch, 'Orchestrator', null);

  if (!payload || payload.status === 'no_snapshot') {
    meta.textContent = 'No Reality Hooks snapshot found yet. Run the Reality Hooks workflow first.';
    deployEl.textContent = '';
    saveBody.innerHTML = '<tr><td colspan="7">No save.sh runs recorded.</td></tr>';
    orchEl.textContent = '';

    if (payload?.advisory) {
      const adv = payload.advisory;
      updateRealityBadge(badgeDeploy, 'Deployment', adv.deployment?.status);
      updateRealityBadge(badgeSave, 'save.sh', adv.save_sh?.status);
      updateRealityBadge(badgeOrch, 'Orchestrator', adv.orchestrator?.status);
    }
    return;
  }

  if (payload.status === 'error') {
    renderRealityError(payload.error || 'Invalid Reality snapshot.');
    if (payload.advisory) {
      const adv = payload.advisory;
      updateRealityBadge(badgeDeploy, 'Deployment', adv.deployment?.status);
      updateRealityBadge(badgeSave, 'save.sh', adv.save_sh?.status);
      updateRealityBadge(badgeOrch, 'Orchestrator', adv.orchestrator?.status);
    }
    return;
  }

  const data = payload.data || {};
  const timestamp = data.timestamp || '';
  const deployment = data.deployment_report || null;
  const saveRuns = Array.isArray(data.save_sh_full_cycle) ? data.save_sh_full_cycle : [];
  const orchestrator = data.orchestrator_summary || null;

  meta.textContent = `Latest snapshot: ${timestamp || 'unknown'} (source: ${payload.snapshot_path || 'unknown'})`;

  if (deployment && deployment.path) {
    deployEl.textContent = `Report: ${deployment.path}`;
  } else {
    deployEl.textContent = 'No deployment report in snapshot.';
  }

  saveBody.innerHTML = '';
  if (!saveRuns.length) {
    saveBody.innerHTML = '<tr><td colspan="7">No save.sh runs captured.</td></tr>';
  } else {
    saveRuns.forEach((run) => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><code>${escapeHtml(run?.test_id || '')}</code></td>
        <td>${escapeHtml(run?.lane || '')}</td>
        <td>${escapeHtml(run?.layer1 || '')}</td>
        <td>${escapeHtml(run?.layer2 || '')}</td>
        <td>${escapeHtml(run?.layer3 || '')}</td>
        <td>${escapeHtml(run?.layer4 || '')}</td>
        <td>${escapeHtml(run?.git || '')}</td>
      `;
      saveBody.appendChild(tr);
    });
  }

  if (orchestrator) {
    try {
      orchEl.textContent = JSON.stringify(orchestrator, null, 2);
    } catch (err) {
      orchEl.textContent = String(orchestrator);
    }
  } else {
    orchEl.textContent = 'No orchestrator summary in snapshot.';
  }

  if (payload.advisory) {
    const adv = payload.advisory;
    updateRealityBadge(badgeDeploy, 'Deployment', adv.deployment?.status);
    updateRealityBadge(badgeSave, 'save.sh', adv.save_sh?.status);
    updateRealityBadge(badgeOrch, 'Orchestrator', adv.orchestrator?.status);
  }
}

function renderRealityError(message) {
  const msg = message || 'Failed to load Reality snapshot.';
  const meta = document.getElementById('reality-meta');
  if (meta) {
    meta.textContent = msg;
  }
  showErrorBanner('reality-error', msg);
}

function updateRealityBadge(el, label, status) {
  if (!el) return;
  el.className = 'reality-badge reality-badge-muted';
  el.textContent = label;

  if (!status) {
    return;
  }

  const normalized = String(status).toLowerCase().trim().replace(/\s+/g, '_');
  el.className = `reality-badge reality-badge-${normalized}`;
  el.textContent = `${label}: ${status}`;
}

function formatRelativeTime(isoString) {
  if (!isoString) return '';
  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) {
    return isoString;
  }

  const now = new Date();
  const diffMs = date.getTime() - now.getTime();
  const absDiffMs = Math.abs(diffMs);
  const thresholds = [
    { unit: 'day', value: 86400000 },
    { unit: 'hour', value: 3600000 },
    { unit: 'minute', value: 60000 }
  ];

  let unit = 'second';
  let value = diffMs / 1000;

  for (const threshold of thresholds) {
    if (absDiffMs >= threshold.value) {
      unit = threshold.unit;
      value = diffMs / threshold.value;
      break;
    }
  }

  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });
  return `${rtf.format(Math.round(value), unit)} · ${date.toLocaleString()}`;
}

function initMLSPanel() {
  if (mlsIntervalId) {
    return;
  }

  const refreshBtn = document.getElementById('mls-refresh-btn');
  const retryBtn = document.getElementById('mls-error-retry');
  const pills = document.querySelectorAll('#mls-type-pills .pill-button');

  pills.forEach((pill) => {
    pill.addEventListener('click', () => {
      pills.forEach((btn) => btn.classList.remove('active'));
      pill.classList.add('active');
      loadMLS(pill.dataset.type || '');
    });
  });

  refreshBtn?.addEventListener('click', () => loadMLS());
  retryBtn?.addEventListener('click', () => loadMLS());

  loadMLS('');
  mlsIntervalId = setInterval(() => loadMLS(), MLS_REFRESH_MS);
}

function initDashboard() {
  initTabs();
  initWorkOrderTabs();
  initWoHistoryTab();
  initWoFilters();
  initWoSearch();
  initWoSorting();
  initWoAutorefreshControls();
  initWoTimeline();
  loadWos();
  document.getElementById('reality-error-retry')?.addEventListener('click', () => loadRealitySnapshot());
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

  if (woAutorefreshIntervalId) {
    clearInterval(woAutorefreshIntervalId);
    woAutorefreshIntervalId = null;
  }
  if (woAutorefreshTimer) {
    clearInterval(woAutorefreshTimer);
    woAutorefreshTimer = null;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initDashboard();
});

window.addEventListener('beforeunload', () => {
  cleanupIntervals();
});
