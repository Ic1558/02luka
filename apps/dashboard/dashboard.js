const SERVICES_REFRESH_MS = 30000;
const MLS_REFRESH_MS = 30000;
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);

let realityPanelInitialized = false;

let servicesIntervalId;
let mlsIntervalId;
let currentMlsType = '';
let allWos = [];
let visibleWos = [];
let currentWoFilter = 'all';

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

// --- Work Orders list ---

async function loadWos() {
  try {
    const res = await fetch('/api/wos', {
      headers: {
        Accept: 'application/json'
      }
    });
    if (!res.ok) {
      console.error('Failed to fetch WOs', res.status);
      return;
    }
    const payload = await res.json();
    if (Array.isArray(payload)) {
      allWos = payload;
    } else if (Array.isArray(payload?.wos)) {
      allWos = payload.wos;
    } else if (Array.isArray(payload?.results)) {
      allWos = payload.results;
    } else {
      allWos = [];
    }
    applyWoFilter();
  } catch (error) {
    console.error('Error loading WOs', error);
  }
}

function initWoFilters() {
  const buttons = document.querySelectorAll('.wo-filter-button');
  if (!buttons.length) return;
  buttons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const status = btn.getAttribute('data-status') || 'all';
      setWoFilter(status);
    });
  });
}

function setWoFilter(statusKey) {
  currentWoFilter = statusKey;
  const buttons = document.querySelectorAll('.wo-filter-button');
  buttons.forEach((btn) => {
    const buttonStatus = btn.getAttribute('data-status') || 'all';
    btn.classList.toggle('active', buttonStatus === statusKey);
  });
  applyWoFilter();
}

function applyWoFilter() {
  let filtered = Array.isArray(allWos) ? allWos.slice() : [];
  if (currentWoFilter !== 'all') {
    filtered = filtered.filter((wo) => normalizeWoStatus(wo?.status) === currentWoFilter);
  }
  visibleWos = filtered;
  renderWosTable(filtered);
  renderWoSummary(filtered);
}

function normalizeWoStatus(raw) {
  const status = String(raw ?? '').toLowerCase();
  if (!status) return 'pending';
  if (['pending', 'queued', 'created'].includes(status)) return 'pending';
  if (['running', 'in_progress', 'in-progress', 'working'].includes(status)) return 'running';
  if (['completed', 'success', 'done'].includes(status)) return 'completed';
  if (['failed', 'error', 'errored'].includes(status)) return 'failed';
  return 'other';
}

function renderWosTable(wos) {
  const tbody = document.getElementById('wos-table-body');
  if (!tbody) return;

  if (!Array.isArray(wos) || !wos.length) {
    tbody.innerHTML = '<tr><td colspan="7">No work orders found.</td></tr>';
    return;
  }

  tbody.innerHTML = '';

  wos.forEach((wo) => {
    const tr = document.createElement('tr');

    const idCell = document.createElement('td');
    idCell.innerHTML = `<code>${escapeHtml(wo?.id ?? '')}</code>`;
    tr.appendChild(idCell);

    const statusCell = document.createElement('td');
    const statusChip = document.createElement('span');
    const norm = normalizeWoStatus(wo?.status);
    let chipClass = 'wo-status-other';
    if (norm === 'pending') chipClass = 'wo-status-pending';
    else if (norm === 'running') chipClass = 'wo-status-running';
    else if (norm === 'completed') chipClass = 'wo-status-completed';
    else if (norm === 'failed') chipClass = 'wo-status-failed';
    statusChip.className = `wo-status-chip ${chipClass}`;
    statusChip.textContent = wo?.status || norm;
    statusCell.appendChild(statusChip);
    tr.appendChild(statusCell);

    tr.appendChild(createTextCell(formatWoTimestamp(wo?.started_at || wo?.created_at)));
    tr.appendChild(createTextCell(formatWoTimestamp(wo?.finished_at || wo?.completed_at)));
    tr.appendChild(createTextCell(formatWoTimestamp(wo?.updated_at || wo?.last_update)));

    const actionsCell = document.createElement('td');
    const copyBtn = document.createElement('button');
    copyBtn.type = 'button';
    copyBtn.textContent = 'Copy ID';
    copyBtn.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(String(wo?.id ?? ''));
        copyBtn.textContent = 'Copied!';
        setTimeout(() => {
          copyBtn.textContent = 'Copy ID';
        }, 1200);
      } catch (error) {
        console.error('Failed to copy WO id', error);
      }
    });
    actionsCell.appendChild(copyBtn);
    tr.appendChild(actionsCell);

    tr.appendChild(createTextCell(buildTimelineSummary(wo)));

    tbody.appendChild(tr);
  });
}

function createTextCell(value) {
  const td = document.createElement('td');
  td.textContent = value || '—';
  return td;
}

function formatWoTimestamp(isoString) {
  if (!isoString) return '';
  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) {
    return isoString;
  }
  return date.toLocaleString();
}

function buildTimelineSummary(wo) {
  if (Array.isArray(wo?.timeline) && wo.timeline.length) {
    const labels = wo.timeline
      .map((event) => event?.label || event?.status || event?.state || event)
      .filter(Boolean);
    if (labels.length) {
      return labels.join(' → ');
    }
  }
  if (wo?.timeline_summary) return wo.timeline_summary;
  if (typeof wo?.duration === 'number') {
    return `${Math.round(wo.duration)}s`;
  }
  if (typeof wo?.duration_ms === 'number') {
    const seconds = Math.max(0, Math.round(wo.duration_ms / 1000));
    return `${seconds}s`;
  }
  return '—';
}

function renderWoSummary(filtered) {
  const summaryEl = document.getElementById('wos-summary');
  if (!summaryEl) return;

  const counts = {
    pending: 0,
    running: 0,
    completed: 0,
    failed: 0,
    other: 0
  };

  allWos.forEach((wo) => {
    const key = normalizeWoStatus(wo?.status);
    if (counts[key] !== undefined) {
      counts[key] += 1;
    } else {
      counts.other += 1;
    }
  });

  const total = allWos.length;
  const filteredCount = filtered.length;
  const parts = [];
  parts.push(`${total} WOs`);
  if (counts.running) parts.push(`${counts.running} running`);
  if (counts.failed) parts.push(`${counts.failed} failed`);
  if (currentWoFilter !== 'all') {
    parts.push(`filter: ${currentWoFilter} (${filteredCount} shown)`);
  }

  summaryEl.textContent = parts.join(' · ');
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
    tbody.innerHTML = '<tr><td colspan="7">No work orders found.</td></tr>';
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

    const timelineCell = document.createElement('td');
    const timelineButton = document.createElement('button');
    timelineButton.type = 'button';
    timelineButton.className = 'wo-timeline-button';
    timelineButton.textContent = 'View';
    if (wo?.id) {
      timelineButton.addEventListener('click', () => openWoTimeline(wo.id));
    } else {
      timelineButton.disabled = true;
    }
    timelineCell.appendChild(timelineButton);
    tr.appendChild(timelineCell);

    tbody.appendChild(tr);
  });
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

async function openWoTimeline(woId) {
  if (!woId) return;

  const modal = document.getElementById('wo-timeline-modal');
  const titleEl = document.getElementById('wo-timeline-title');
  const metaEl = document.getElementById('wo-timeline-meta');
  const eventsEl = document.getElementById('wo-timeline-events');
  const logEl = document.getElementById('wo-timeline-log-tail');

  if (!modal || !titleEl || !metaEl || !eventsEl || !logEl) {
    return;
  }

  titleEl.textContent = `WO Timeline: ${woId}`;
  metaEl.textContent = 'Loading…';
  eventsEl.innerHTML = '';
  logEl.textContent = '';

  modal.classList.remove('hidden');

  try {
    const res = await fetch(`/api/wos/${encodeURIComponent(woId)}?tail=200`, {
      headers: { Accept: 'application/json' }
    });
    if (!res.ok) {
      metaEl.textContent = `Failed to load WO: HTTP ${res.status}`;
      return;
    }
    const wo = await res.json();
    renderWoTimeline(wo);
  } catch (error) {
    metaEl.textContent = `Error loading WO: ${String(error)}`;
  }
}

function closeWoTimeline() {
  const modal = document.getElementById('wo-timeline-modal');
  if (!modal) return;
  modal.classList.add('hidden');
}

function renderWoTimeline(wo = {}) {
  const metaEl = document.getElementById('wo-timeline-meta');
  const eventsEl = document.getElementById('wo-timeline-events');
  const logEl = document.getElementById('wo-timeline-log-tail');

  if (!metaEl || !eventsEl || !logEl) {
    return;
  }

  const id = wo.id || 'UNKNOWN';
  const status = wo.status || 'unknown';
  const started = wo.started_at || wo.created_at || '';
  const finished = wo.finished_at || '';
  const updated = wo.updated_at || wo.last_update || '';

  let metaText = `ID: ${id} · Status: ${status}`;
  if (started) metaText += ` · Started: ${started}`;
  if (finished) metaText += ` · Finished: ${finished}`;
  if (updated) metaText += ` · Last update: ${updated}`;
  metaEl.textContent = metaText;

  const logLines = Array.isArray(wo.log_tail)
    ? wo.log_tail.map((line) => String(line || ''))
    : typeof wo.log_tail === 'string'
    ? wo.log_tail.split(/\r?\n/)
    : [];

  const events = buildTimelineEventsFromWo(wo, logLines);

  eventsEl.innerHTML = '';
  if (!events.length) {
    const placeholder = document.createElement('li');
    placeholder.textContent = 'No timeline events available yet.';
    eventsEl.appendChild(placeholder);
  } else {
    events.forEach((event) => {
      const li = document.createElement('li');
      if (event.level === 'error') {
        li.classList.add('wo-event-error');
      }
      li.innerHTML = `
        <div>${escapeHtml(event.label || '')}</div>
        <time>${escapeHtml(event.time || '')}</time>
        ${event.detail ? `<div class="wo-event-detail">${escapeHtml(event.detail)}</div>` : ''}
      `;
      eventsEl.appendChild(li);
    });
  }

  logEl.textContent = logLines.join('\n');
}

function buildTimelineEventsFromWo(wo = {}, logLines = []) {
  const events = [];

  if (wo.created_at) {
    events.push({
      time: wo.created_at,
      label: 'Created',
      detail: wo.created_by || '',
      level: 'info'
    });
  }

  if (wo.started_at) {
    events.push({
      time: wo.started_at,
      label: 'Started',
      detail: wo.worker || wo.agent || '',
      level: 'info'
    });
  }

  if (wo.finished_at) {
    events.push({
      time: wo.finished_at,
      label: 'Finished',
      detail: wo.result || '',
      level: wo.status === 'failed' ? 'error' : 'info'
    });
  }

  if (!wo.finished_at && wo.status) {
    events.push({
      time: wo.updated_at || wo.last_update || '',
      label: `Status: ${wo.status}`,
      detail: wo.last_error || '',
      level: wo.status === 'failed' ? 'error' : 'info'
    });
  }

  logLines.slice(-5).forEach((line) => {
    const trimmed = String(line || '').trim();
    if (!trimmed) return;
    events.push({
      time: '',
      label: 'Log tail',
      detail: trimmed,
      level: trimmed.toLowerCase().includes('error') ? 'error' : 'info'
    });
  });

  return events;
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
}

document.addEventListener('DOMContentLoaded', () => {
  initDashboard();
});

window.addEventListener('beforeunload', () => {
  cleanupIntervals();
});
