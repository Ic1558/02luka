const SERVICES_REFRESH_MS = 30000;
const MLS_REFRESH_MS = 30000;
const WO_AUTOREFRESH_MS = 60000;
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);

let realityPanelInitialized = false;

let servicesIntervalId;
let mlsIntervalId;
let woAutorefreshIntervalId;
let currentMlsType = '';
let currentWos = [];
let currentWoSearch = '';
let currentWoStatusFilter = '';
let currentWoSortKey = 'started_at';
let currentWoSortDir = 'desc';
let currentTimelineWoId = null;

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

    if (targetId === 'services-panel') {
      initServicesPanel();
    } else if (targetId === 'mls-panel') {
      initMLSPanel();
    } else if (targetId === 'reality-panel') {
      initRealityPanel();
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

  const viewOverview = document.getElementById('view-overview');
  const viewWos = document.getElementById('view-wos');
  const viewWoHistory = document.getElementById('view-wo-history');

  if (tabOverview && tabWos && tabWoHistory && viewOverview && viewWos && viewWoHistory) {
    const buttons = [tabOverview, tabWos, tabWoHistory];
    const views = [viewOverview, viewWos, viewWoHistory];

    function setActiveButton(target) {
      buttons.forEach((btn) => btn.classList.toggle('active', btn === target));
    }

    function show(view) {
      views.forEach((v) => v.classList.add('hidden'));
      view.classList.remove('hidden');
    }

    tabOverview.addEventListener('click', () => {
      setActiveButton(tabOverview);
      show(viewOverview);
    });

    tabWos.addEventListener('click', () => {
      setActiveButton(tabWos);
      show(viewWos);
    });

    tabWoHistory.addEventListener('click', () => {
      setActiveButton(tabWoHistory);
      show(viewWoHistory);
      loadWoHistory();
    });

    setActiveButton(tabOverview);
    show(viewOverview);
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

async function loadWoHistory() {
  const statusFilter = document.getElementById('wo-history-status-filter');
  const limitSelect = document.getElementById('wo-history-limit');

  const status = statusFilter ? statusFilter.value : '';
  const limit = limitSelect ? parseInt(limitSelect.value, 10) : 100;

  const params = new URLSearchParams();
  if (status) params.set('status', status);

  const query = params.toString();
  const url = `/api/wos${query ? `?${query}` : ''}`;

  try {
    const res = await fetch(url, {
      headers: {
        Accept: 'application/json'
      }
    });
    if (!res.ok) {
      console.error('Failed to fetch WO history', res.status, await res.text());
      return;
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
    renderWoHistory(wos, limit);
  } catch (error) {
    console.error('Error loading WO history', error);
  }
}

function renderWoHistory(wos, limit) {
  const tbody = document.getElementById('wo-history-body');
  if (!tbody) return;

  const maxRows = Number.isFinite(limit) ? limit : 100;

  if (!Array.isArray(wos) || !wos.length) {
    tbody.innerHTML = '<tr><td colspan="6">No work orders found.</td></tr>';
    return;
  }

  const sorted = [...wos].sort((a, b) => {
    const aKey = a?.started_at || a?.id || 0;
    const bKey = b?.started_at || b?.id || 0;
    if (aKey > bKey) return -1;
    if (aKey < bKey) return 1;
    return 0;
  });

  const slice = sorted.slice(0, maxRows);
  tbody.innerHTML = '';

  slice.forEach((wo) => {
    const tr = document.createElement('tr');
    const started = wo?.started_at || '';
    const status = wo?.status || '';
    const agent = wo?.agent || wo?.worker || '';
    const type = wo?.type || '';
    const summary = wo?.summary || wo?.description || '';

    tr.innerHTML = `
      <td><code>${escapeHtml(wo?.id ?? '')}</code></td>
      <td>${escapeHtml(started)}</td>
      <td>${escapeHtml(status)}</td>
      <td>${escapeHtml(agent)}</td>
      <td>${escapeHtml(type)}</td>
      <td>${escapeHtml(summary)}</td>
    `;

    tbody.appendChild(tr);
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

    const idTd = document.createElement('td');
    const idCode = document.createElement('code');
    idCode.textContent = wo?.id ?? '';
    idTd.appendChild(idCode);

    const statusTd = document.createElement('td');
    statusTd.textContent = normalizeWoStatus(wo?.status || '');

    const startedTd = document.createElement('td');
    startedTd.textContent = formatWoTime(wo?.started_at || wo?.startedAt || '');

    const finishedTd = document.createElement('td');
    finishedTd.textContent = formatWoTime(wo?.finished_at || wo?.finishedAt || '');

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
    btn.dataset.woId = wo?.id || '';
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

    tbody.appendChild(tr);
  });
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
  if (!closeBtn || !section) return;

  closeBtn.addEventListener('click', () => {
    section.classList.add('hidden');
    currentTimelineWoId = null;
  });
}

async function openWoTimeline(woId) {
  const section = document.getElementById('wo-timeline-section');
  const titleEl = document.getElementById('wo-timeline-title');
  const subtitleEl = document.getElementById('wo-timeline-subtitle');
  const contentEl = document.getElementById('wo-timeline-content');

  if (!section || !titleEl || !subtitleEl || !contentEl) return;

  currentTimelineWoId = woId;

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
  const finished = formatWoTime(wo?.finished_at || wo?.finishedAt);
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
  addEvent(wo?.finished_at || wo?.finishedAt, 'Finished', wo?.result || wo?.outcome);
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

// --- Reality Snapshot ---

async function loadRealitySnapshot() {
  const meta = document.getElementById('reality-meta');
  if (meta) {
    meta.textContent = 'Loading Reality snapshot…';
  }
  hideErrorBanner('reality-error');

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
    renderRealityError(String(error));
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

  updateRealityBadge(badgeDeploy, 'Deployment', null);
  updateRealityBadge(badgeSave, 'save.sh', null);
  updateRealityBadge(badgeOrch, 'Orchestrator', null);

  if (!payload || payload.status === 'no_snapshot') {
    meta.textContent = 'No Reality Hooks snapshot found yet. Run the Reality Hooks workflow in CI first.';
    deployEl.textContent = '';
    saveBody.innerHTML = '<tr><td colspan="7">No save.sh runs in snapshot.</td></tr>';
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
    renderRealityError(payload.error || 'invalid snapshot');
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
    saveBody.innerHTML = '<tr><td colspan="7">No save.sh full-cycle runs in snapshot.</td></tr>';
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
    } catch (error) {
      console.error('Failed to stringify orchestrator summary', error);
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
  const meta = document.getElementById('reality-meta');
  if (meta) {
    meta.textContent = 'Reality snapshot unavailable.';
  }
  showErrorBanner('reality-error', message || 'Failed to load Reality snapshot.');
}

function updateRealityBadge(el, label, status) {
  if (!el) return;
  el.className = 'badge badge-muted';

  if (!status) {
    el.textContent = label;
    return;
  }

  const normalized = String(status).toLowerCase().replace(/\s+/g, '_');
  el.className = `badge badge-${normalized}`;
  el.textContent = `${label}: ${status}`;
}

function initRealityPanel() {
  if (realityPanelInitialized) {
    return;
  }

  const refreshBtn = document.getElementById('reality-refresh-btn');
  const retryBtn = document.getElementById('reality-error-retry');

  refreshBtn?.addEventListener('click', () => loadRealitySnapshot());
  retryBtn?.addEventListener('click', () => loadRealitySnapshot());

  loadRealitySnapshot();
  realityPanelInitialized = true;
}

function initDashboard() {
  initTabs();
  initWoHistoryFilters();
  initWoFilters();
  initWoSearch();
  initWoSorting();
  initWoAutorefreshControls();
  initWoTimeline();
  loadWos();
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
}

document.addEventListener('DOMContentLoaded', () => {
  initDashboard();
});

window.addEventListener('beforeunload', () => {
  cleanupIntervals();
});
