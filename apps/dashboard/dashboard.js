const SERVICES_REFRESH_MS = 30000;
const WO_TIMELINE_REFRESH_MS = 45000;
const SUMMARY_REFRESH_MS = 60000;
const SUMMARY_LOADING_FOOTER = 'Updated: —';
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);

let realityPanelInitialized = false;

let servicesIntervalId;
let woTimelineIntervalId;
let summaryIntervalId;
let mlsPanelInitialized = false;
let mlsAllEntries = [];
let mlsFilterType = '';
let mlsSearchQuery = '';
let currentWoId = null;
let cachedMlsEntries = null;
let allWos = [];
let currentWoStatusFilter = '';
let woTimelineAll = [];
let woTimelineFilterStatus = '';
let woTimelineSearchQuery = '';
let woTimelineInitialized = false;
let serviceData = [];
let serviceAutoRefreshTimer = null;

function formatBadgeLabel(text) {
  return String(text || '')
    .trim()
    .replace(/_/g, ' ');
}

function makeBadge(text, extraClass = '') {
  const label = formatBadgeLabel(text);
  if (!label) return null;
  const span = document.createElement('span');
  span.className = ['badge', extraClass].filter(Boolean).join(' ').trim();
  span.textContent = label;
  return span;
}

function woStatusBadge(statusRaw) {
  const raw = formatBadgeLabel(statusRaw);
  if (!raw) return null;
  const status = raw.toLowerCase();

  if (status === 'failed' || status === 'error') {
    return makeBadge(raw, 'badge-wo badge-wo-failed');
  }

  if (['done', 'completed', 'success'].includes(status)) {
    return makeBadge(raw, 'badge-wo badge-wo-done');
  }

  if (['pending', 'running', 'in progress', 'in-progress', 'in_progress', 'active', 'queued'].includes(status)) {
    return makeBadge(raw, 'badge-wo badge-wo-active');
  }

  return makeBadge(raw, 'badge-wo');
}

function mlsTypeBadge(typeRaw) {
  const raw = formatBadgeLabel(typeRaw);
  if (!raw) return null;
  const type = raw.toLowerCase();

  if (type === 'solution') {
    return makeBadge('solution', 'badge-mls badge-mls-solution');
  }
  if (type === 'failure') {
    return makeBadge('failure', 'badge-mls badge-mls-failure');
  }
  return makeBadge(raw, 'badge-mls');
}

function normalizeWoTimelineEntry(rawWo = {}) {
  const id = rawWo.id || rawWo.wo_id || 'UNKNOWN';
  const normalizedStatus = normalizeWoTimelineStatus(rawWo.status);
  const createdAt = rawWo.created_at || rawWo.queued_at || rawWo.timestamp || '';
  const startedAt = rawWo.started_at || '';
  const finishedAt = rawWo.finished_at || rawWo.completed_at || '';
  const updatedAt = rawWo.updated_at || rawWo.last_update || finishedAt || '';
  const title = rawWo.title || rawWo.summary || rawWo.name || '';
  const description = rawWo.description || rawWo.summary || rawWo.notes || '';

  return {
    id,
    status: normalizedStatus,
    createdAt,
    startedAt,
    finishedAt,
    updatedAt,
    title,
    description
  };
}

function normalizeWoTimelineStatus(status) {
  const raw = String(status || '').toLowerCase();
  if (!raw) return 'unknown';
  if (['pending', 'queued', 'created'].includes(raw)) return 'pending';
  if (['running', 'in_progress', 'in-progress', 'working'].includes(raw)) return 'running';
  if (['completed', 'done', 'success'].includes(raw)) return 'done';
  if (['failed', 'error'].includes(raw)) return 'failed';
  return raw;
}

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

function debounce(fn, delay = 200) {
  let timeoutId;
  return (...args) => {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
    timeoutId = setTimeout(() => fn(...args), delay);
  };
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

// --- MLS Lessons Panel ---

async function refreshMlsEntries() {
  const listEl = document.getElementById('mls-list');
  const summaryEl = document.getElementById('mls-summary');
  if (listEl) {
    listEl.innerHTML = '<div class="mls-item"><div class="mls-item-header"><span>Loading MLS lessons…</span></div></div>';
  }
  if (summaryEl) {
    summaryEl.textContent = 'Loading MLS lessons…';
  }

  try {
    const res = await fetch('/api/mls', { headers: { Accept: 'application/json' } });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }

    const data = await res.json();
    mlsAllEntries = Array.isArray(data.entries) ? data.entries.slice() : [];

    mlsAllEntries.sort((a, b) => {
      const aKey = a.time || a.id || '';
      const bKey = b.time || b.id || '';
      if (aKey === bKey) return 0;
      return aKey > bKey ? -1 : 1;
    });

    cachedMlsEntries = mlsAllEntries.slice();
    if (currentWoId) {
      refreshWoDetailMls();
    }

    renderMlsList();
  } catch (error) {
    console.error('Failed to refresh MLS entries:', error);
    if (listEl) {
      listEl.innerHTML = `
        <div class="mls-item">
          <div class="mls-item-header">
            <span>Failed to load MLS lessons.</span>
          </div>
          <div class="mls-item-meta">${escapeHtml(error.message || String(error))}</div>
        </div>
      `;
    }
    if (summaryEl) {
      summaryEl.textContent = 'Unable to load MLS summary.';
    }
  }
}

function initMLSPanel() {
  if (mlsPanelInitialized) {
    return;
  }

  const panel = document.getElementById('mls-panel');
  if (!panel) {
    return;
  }

  const filterButtons = panel.querySelectorAll('.mls-filter-btn[data-mls-type]');
  filterButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const type = btn.getAttribute('data-mls-type') || '';
      mlsFilterType = type;

      filterButtons.forEach((b) => b.classList.remove('mls-filter-btn-active'));
      btn.classList.add('mls-filter-btn-active');

      renderMlsList();
    });
  });

  const searchInput = document.getElementById('mls-search-input');
  if (searchInput) {
    searchInput.addEventListener('input', () => {
      mlsSearchQuery = searchInput.value || '';
      renderMlsList();
    });
  }

  refreshMlsEntries();
  mlsPanelInitialized = true;
}

function renderMlsList() {
  const listEl = document.getElementById('mls-list');
  const summaryEl = document.getElementById('mls-summary');
  if (!listEl || !summaryEl) {
    return;
  }

  let entries = mlsAllEntries.slice();

  if (mlsFilterType) {
    entries = entries.filter((entry) => (entry.type || '') === mlsFilterType);
  }

  if (mlsSearchQuery.trim()) {
    const needle = mlsSearchQuery.trim().toLowerCase();
    entries = entries.filter((entry) => {
      const haystack = [
        entry.id,
        entry.title,
        entry.details,
        entry.context,
        entry.related_wo,
        entry.related_session,
        Array.isArray(entry.tags) ? entry.tags.join(' ') : ''
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(needle);
    });
  }

  if (!entries.length) {
    listEl.innerHTML = `
      <div class="mls-item">
        <div class="mls-item-header">
          <span>No MLS lessons match this filter.</span>
        </div>
      </div>
    `;
  } else {
    listEl.innerHTML = entries.map((entry) => renderMlsItem(entry)).join('');
  }

  const total = mlsAllEntries.length;
  const solutions = mlsAllEntries.filter((entry) => entry.type === 'solution').length;
  const failures = mlsAllEntries.filter((entry) => entry.type === 'failure').length;
  const patterns = mlsAllEntries.filter((entry) => entry.type === 'pattern').length;
  const improvements = mlsAllEntries.filter((entry) => entry.type === 'improvement').length;
  const activeType = mlsFilterType || 'all';
  const searchLabel = mlsSearchQuery ? ` | search: "${mlsSearchQuery}"` : '';

  summaryEl.textContent = `Total: ${total} | solutions: ${solutions} | failures: ${failures} | patterns: ${patterns} | improvements: ${improvements} | type filter: ${activeType}${searchLabel}`;
}

function renderMlsItem(entry) {
  const id = entry.id || 'MLS-UNKNOWN';
  const title = entry.title || 'Untitled lesson';
  const type = entry.type || 'other';
  const details = entry.details || entry.context || '';
  const time = entry.time || '';
  const tags = Array.isArray(entry.tags) ? entry.tags : [];
  const verified = Boolean(entry.verified);
  const relatedWo = entry.related_wo || '';
  const relatedSession = entry.related_session || '';

  const typeClass = getMlsTypeClass(type);
  const typeLabel = type.toUpperCase();
  const typeBadge = mlsTypeBadge(type);
  if (typeBadge) {
    typeBadge.classList.add('mls-item-type');
    if (typeClass) {
      typeBadge.classList.add(typeClass);
    }
  }
  const typeBadgeHtml = typeBadge
    ? typeBadge.outerHTML
    : `<span class="mls-item-type ${typeClass}">${escapeHtml(typeLabel)}</span>`;

  const metaParts = [];
  if (time) metaParts.push(`time: ${time}`);
  if (relatedWo) metaParts.push(`WO: ${relatedWo}`);
  if (relatedSession) metaParts.push(`session: ${relatedSession}`);
  if (verified) metaParts.push('✅ verified');
  const metaText = metaParts.join(' | ');
  const tagsText = tags.length ? `tags: ${tags.join(', ')}` : '';

  return `
    <div class="mls-item" data-mls-id="${escapeHtml(id)}">
      <div class="mls-item-header">
        <span class="mls-item-title">${escapeHtml(title)}</span>
        ${typeBadgeHtml}
      </div>
      ${metaText ? `<div class="mls-item-meta">${escapeHtml(metaText)}</div>` : ''}
      ${details ? `<div class="mls-item-meta">${escapeHtml(details)}</div>` : ''}
      ${tagsText ? `<div class="mls-item-tags">${escapeHtml(tagsText)}</div>` : ''}
    </div>
  `;
}

function getMlsTypeClass(type) {
  switch (type) {
    case 'solution':
      return 'mls-type-solution';
    case 'failure':
      return 'mls-type-failure';
    case 'pattern':
      return 'mls-type-pattern';
    case 'improvement':
      return 'mls-type-improvement';
    default:
      return 'mls-type-other';
  }
}

// --- Work Orders list ---

async function loadWos() {
  const params = new URLSearchParams();
  if (currentWoStatusFilter) {
    params.set('status', currentWoStatusFilter);
  }
  const query = params.toString();
  const url = query ? `/api/wos?${query}` : '/api/wos';

  try {
    const res = await fetch(url, {
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
    renderWosTable(allWos);
    renderWoSummary(allWos);
  } catch (error) {
    console.error('Error loading WOs', error);
  }
}

// === Summary cards ===

function setSummaryText(cardEl, main, sub, foot) {
  if (!cardEl) return;
  const mainEl = cardEl.querySelector('.summary-card-main');
  const subEl = cardEl.querySelector('.summary-card-sub');
  const footEl = cardEl.querySelector('.summary-card-foot');
  if (mainEl) {
    mainEl.textContent = main;
  }
  if (subEl) {
    subEl.textContent = sub;
  }
  if (footEl && typeof foot !== 'undefined') {
    footEl.textContent = foot;
  }
}

function formatSummaryUpdatedLabel(date = new Date()) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    return SUMMARY_LOADING_FOOTER;
  }
  try {
    return `Updated ${date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}`;
  } catch (error) {
    console.warn('Falling back to default time string for summary footer', error);
    return `Updated ${date.toLocaleTimeString()}`;
  }
}

function setSummaryLoading(cardEl) {
  setSummaryText(cardEl, '—', 'loading…', SUMMARY_LOADING_FOOTER);
}

function initSummaryCards() {
  const wosCard = document.getElementById('summary-wos');
  const servicesCard = document.getElementById('summary-services');
  const mlsCard = document.getElementById('summary-mls');

  if (!wosCard && !servicesCard && !mlsCard) {
    return;
  }

  const refreshAll = () => {
    refreshSummaryWos(wosCard);
    refreshSummaryServices(servicesCard);
    refreshSummaryMls(mlsCard);
  };

  refreshAll();

  if (summaryIntervalId) {
    clearInterval(summaryIntervalId);
  }
  summaryIntervalId = setInterval(refreshAll, SUMMARY_REFRESH_MS);
}

async function refreshSummaryWos(cardEl) {
  if (!cardEl) return;

  try {
    setSummaryLoading(cardEl);
    const payload = await fetchJSON('/api/wos');
    const wos = Array.isArray(payload)
      ? payload
      : Array.isArray(payload?.wos)
        ? payload.wos
        : Array.isArray(payload?.results)
          ? payload.results
          : null;

    if (!Array.isArray(wos)) {
      setSummaryText(cardEl, '0', 'no data');
      return;
    }

    const total = wos.length;
    let active = 0;
    let failed = 0;

    wos.forEach((wo) => {
      const status = String(wo?.status || '').toLowerCase();
      if (!status) return;

      if (status === 'failed' || status === 'error') {
        failed += 1;
      } else if (!['done', 'completed', 'cancelled', 'canceled'].includes(status)) {
        active += 1;
      }
    });

    const subParts = [`active: ${active}`];
    if (failed > 0) {
      subParts.push(`failed: ${failed}`);
    }

    setSummaryText(cardEl, String(total), subParts.join(' | '), formatSummaryUpdatedLabel());
  } catch (error) {
    console.error('Failed to refresh WO summary:', error);
    setSummaryText(cardEl, '—', 'error loading', SUMMARY_LOADING_FOOTER);
  }
}

async function refreshSummaryServices(cardEl) {
  if (!cardEl) return;

  try {
    setSummaryLoading(cardEl);
    const data = await fetchJSON('/api/services');

    const summary = data?.summary ?? {};
    const total = Number(summary.total) || 0;
    const running = Number(summary.running) || 0;
    const failed = Number(summary.failed) || 0;

    const subParts = [`running: ${running}`];
    if (failed > 0) {
      subParts.push(`failed: ${failed}`);
    }

    const mainValue = total > 0 ? `${running}/${total}` : String(running);
    setSummaryText(cardEl, mainValue, subParts.join(' | '), formatSummaryUpdatedLabel());
  } catch (error) {
    console.error('Failed to refresh services summary:', error);
    setSummaryText(cardEl, '—', 'error loading', SUMMARY_LOADING_FOOTER);
  }
}

async function refreshSummaryMls(cardEl) {
  if (!cardEl) return;

  try {
    setSummaryLoading(cardEl);
    const data = await fetchJSON('/api/mls');

    const summary = data?.summary ?? {};
    const total = Number(summary.total) || 0;
    const solutions = Number(summary.solutions) || 0;
    const failures = Number(summary.failures) || 0;

    const subParts = [`solutions: ${solutions}`];
    if (failures > 0) {
      subParts.push(`failures: ${failures}`);
    }

    setSummaryText(cardEl, String(total), subParts.join(' | '), formatSummaryUpdatedLabel());
  } catch (error) {
    console.error('Failed to refresh MLS summary:', error);
    setSummaryText(cardEl, '—', 'error loading', SUMMARY_LOADING_FOOTER);
  }
}

function initWoStatusFilters() {
  const container = document.getElementById('wo-status-filters');
  if (!container) return;

  const chips = Array.from(container.querySelectorAll('.wo-status-chip'));
  chips.forEach((chip) => {
    chip.addEventListener('click', () => {
      const newStatus = chip.dataset.status || '';
      currentWoStatusFilter = newStatus;

      chips.forEach((c) => c.classList.remove('wo-status-chip--active'));
      chip.classList.add('wo-status-chip--active');

      loadWos();
    });
  });
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
    const statusBadge = woStatusBadge(wo?.status);
    if (statusBadge) {
      statusCell.appendChild(statusBadge);
    } else {
      statusCell.textContent = wo?.status || '—';
    }
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

function renderWoSummary(wos = []) {
  const summaryEl = document.getElementById('wos-summary');
  if (!summaryEl) return;

  const counts = {
    pending: 0,
    running: 0,
    completed: 0,
    failed: 0,
    other: 0
  };

  const dataset = Array.isArray(wos) ? wos : [];
  dataset.forEach((wo) => {
    const key = normalizeWoStatus(wo?.status);
    if (counts[key] !== undefined) {
      counts[key] += 1;
    } else {
      counts.other += 1;
    }
  });

  const total = dataset.length;
  const filteredCount = dataset.length;
  const parts = [];
  parts.push(`${total} WOs`);
  if (counts.running) parts.push(`${counts.running} running`);
  if (counts.failed) parts.push(`${counts.failed} failed`);
  if (currentWoStatusFilter) {
    const label = currentWoStatusFilter
      .split(',')
      .map((status) => status.trim() || 'all')
      .join('/');
    parts.push(`filter: ${label} (${filteredCount} shown)`);
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
    const statusBadge = woStatusBadge(status);
    if (statusBadge) {
      statusBadge.classList.add('wo-history-status');
    }
    const statusHtml = statusBadge ? statusBadge.outerHTML : escapeHtml(status || '—');

    tr.innerHTML = `
      <td><code>${escapeHtml(wo?.id ?? '')}</code></td>
      <td>${escapeHtml(started)}</td>
      <td>${statusHtml}</td>
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

// === Service health panel ===

function serviceStatusBadge(statusRaw) {
  const label = formatBadgeLabel(statusRaw || 'unknown') || 'unknown';
  const badge = makeBadge(label);
  if (!badge) return null;

  const status = label.toLowerCase();
  badge.textContent = status;

  if (status === 'running') {
    badge.classList.add('badge-service-running');
  } else if (status === 'failed') {
    badge.classList.add('badge-service-failed');
  } else if (status === 'stopped') {
    badge.classList.add('badge-service-stopped');
  }

  return badge;
}

async function refreshServices(fromUser) {
  try {
    const res = await fetch('/api/services', { headers: { Accept: 'application/json' } });
    if (!res.ok) {
      console.error('Failed to load services', res.status);
      if (fromUser) {
        alert('Failed to load services status.');
      }
      return;
    }
    const payload = await res.json();
    serviceData = Array.isArray(payload?.services) ? payload.services : [];
    renderServiceTable(serviceData);
  } catch (error) {
    console.error('Error fetching services', error);
    if (fromUser) {
      alert('Error fetching services.');
    }
  }
}

function renderServiceTable(services) {
  const tbody = document.getElementById('service-table-body');
  if (!tbody) return;

  tbody.innerHTML = '';

  if (!Array.isArray(services) || services.length === 0) {
    const tr = document.createElement('tr');
    const td = document.createElement('td');
    td.colSpan = 6;
    td.textContent = 'No 02luka services found.';
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  services.forEach((svc) => {
    const tr = document.createElement('tr');

    const tdLabel = document.createElement('td');
    tdLabel.textContent = svc?.label || '-';
    tr.appendChild(tdLabel);

    const tdStatus = document.createElement('td');
    const badge = serviceStatusBadge(svc?.status);
    if (badge) {
      tdStatus.appendChild(badge);
    } else {
      tdStatus.textContent = svc?.status || 'unknown';
    }
    tr.appendChild(tdStatus);

    const tdType = document.createElement('td');
    tdType.textContent = svc?.type || '-';
    tr.appendChild(tdType);

    const tdPid = document.createElement('td');
    tdPid.textContent = svc?.pid != null ? String(svc.pid) : '-';
    tr.appendChild(tdPid);

    const tdExit = document.createElement('td');
    tdExit.textContent = svc?.exit_code != null ? String(svc.exit_code) : '-';
    tr.appendChild(tdExit);

    const tdAction = document.createElement('td');
    const btnLogs = document.createElement('button');
    btnLogs.type = 'button';
    btnLogs.textContent = 'Logs';
    btnLogs.style.fontSize = '0.7rem';
    btnLogs.addEventListener('click', () => {
      openServiceLogs();
    });
    tdAction.appendChild(btnLogs);
    tr.appendChild(tdAction);

    tbody.appendChild(tr);
  });
}

async function openServiceLogs() {
  try {
    const res = await fetch('/api/health/logs?lines=200', { headers: { Accept: 'application/json' } });
    if (!res.ok) {
      alert('Failed to load health logs.');
      return;
    }
    const data = await res.json();
    const lines = Array.isArray(data?.lines) ? data.lines : [];
    const text = lines.join('\n');

    const w = window.open('', 'health-logs');
    if (w) {
      w.document.write('<pre style="font-size:11px; white-space:pre-wrap; margin:0;">');
      w.document.write(escapeHtml(text));
      w.document.write('</pre>');
      w.document.close();
    } else {
      alert(text.slice(0, 2000) || 'No log data available.');
    }
  } catch (error) {
    console.error('Error loading health logs', error);
    alert('Error loading health logs.');
  }
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

// --- WO ↔ MLS linking (detail panel) ---

function onWorkOrderSelected(woId) {
  if (!woId) {
    currentWoId = null;
  } else {
    currentWoId = String(woId);
  }
  refreshWoDetailMls();
}

async function refreshWoDetailMls() {
  const emptyEl = document.getElementById('wo-detail-mls-empty');
  const listEl = document.getElementById('wo-detail-mls-list');

  if (!listEl) {
    return;
  }

  const defaultMessage = emptyEl?.dataset?.defaultMessage || 'No MLS lessons linked to this work order yet.';

  if (!currentWoId) {
    listEl.innerHTML = '';
    if (emptyEl) {
      emptyEl.style.display = '';
      emptyEl.textContent = defaultMessage;
    }
    return;
  }

  try {
    if (!Array.isArray(cachedMlsEntries)) {
      const res = await fetch('/api/mls', { headers: { Accept: 'application/json' } });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const payload = await res.json();
      cachedMlsEntries = Array.isArray(payload.entries) ? payload.entries : [];
    }

    const related = cachedMlsEntries.filter((entry) => {
      if (!entry || entry.related_wo === undefined || entry.related_wo === null) {
        return false;
      }
      return String(entry.related_wo) === String(currentWoId);
    });

    listEl.innerHTML = '';

    if (!related.length) {
      if (emptyEl) {
        emptyEl.style.display = '';
        emptyEl.textContent = defaultMessage;
      }
      return;
    }

    if (emptyEl) {
      emptyEl.style.display = 'none';
      emptyEl.textContent = defaultMessage;
    }

    related.forEach((entry) => {
      const li = document.createElement('li');
      li.className = 'wo-detail-mls-item';
      const entryId = entry.id || entry.mls_id || 'MLS-UNKNOWN';
      li.dataset.mlsId = entryId;
      li.textContent = entry.title || entryId || 'MLS lesson';
      listEl.appendChild(li);
    });
  } catch (error) {
    console.error('Failed to load related MLS lessons for WO', currentWoId, error);
    cachedMlsEntries = null;
    listEl.innerHTML = '';
    if (emptyEl) {
      emptyEl.style.display = '';
      emptyEl.textContent = 'Error loading MLS lessons for this work order.';
    }
  }
}

function focusMlsCardById(mlsId) {
  const list = document.getElementById('mls-list');
  if (!list || !mlsId) {
    return;
  }

  const safeId = cssEscapeAttr(mlsId);
  if (!safeId) {
    return;
  }

  const card = list.querySelector(`[data-mls-id="${safeId}"]`);
  if (card && typeof card.scrollIntoView === 'function') {
    card.scrollIntoView({ behavior: 'smooth', block: 'center' });
    card.classList.add('mls-card-highlight');
    setTimeout(() => card.classList.remove('mls-card-highlight'), 1500);
  }
}

function cssEscapeAttr(value) {
  if (value === undefined || value === null) {
    return '';
  }
  const stringValue = String(value);
  if (typeof window !== 'undefined' && window.CSS && typeof window.CSS.escape === 'function') {
    return window.CSS.escape(stringValue);
  }
  return stringValue.replace(/"/g, '\\"');
}

document.addEventListener('click', (event) => {
  const baseTarget = event.target;
  if (!(baseTarget instanceof Element)) {
    return;
  }

  const target = baseTarget.closest('.wo-detail-mls-item');
  if (!target) {
    return;
  }

  const mlsId = target.dataset?.mlsId;
  if (!mlsId) {
    return;
  }

  if (typeof window.selectMlsLesson === 'function') {
    window.selectMlsLesson(mlsId);
    return;
  }

  focusMlsCardById(mlsId);
});

// --- WO detail rendering / history ---

function renderWoDetail(wo) {
  const container = document.getElementById('wo-detail-content');

  if (!container) {
    renderWoDetailHistory(wo);
    return;
  }

  container.innerHTML = '';

  if (!wo) {
    const placeholder = document.createElement('p');
    placeholder.textContent = 'Select a work order to view its details.';
    container.appendChild(placeholder);
    renderWoDetailHistory(null);
    return;
  }

  const title = document.createElement('h3');
  title.textContent = wo.id || 'Work Order';
  container.appendChild(title);

  if (wo.status) {
    const statusLine = document.createElement('div');
    statusLine.textContent = `Status: ${wo.status}`;
    container.appendChild(statusLine);
  }

  const description = wo.description || wo.goal || wo.summary;
  if (description) {
    const descEl = document.createElement('p');
    descEl.textContent = description;
    container.appendChild(descEl);
  }

  const metaFields = [
    { label: 'Owner', value: wo.owner || wo.created_by || wo.requested_by },
    { label: 'Worker', value: wo.worker || wo.agent },
    { label: 'Type', value: wo.type },
    { label: 'Started', value: formatWoTimestamp(wo.started_at || wo.created_at) },
    { label: 'Finished', value: formatWoTimestamp(wo.finished_at) },
    { label: 'Updated', value: formatWoTimestamp(wo.updated_at || wo.last_update) }
  ].filter((item) => item.value);

  if (metaFields.length) {
    const list = document.createElement('ul');
    list.className = 'wo-detail-meta';
    metaFields.forEach((item) => {
      const li = document.createElement('li');
      li.textContent = `${item.label}: ${item.value}`;
      list.appendChild(li);
    });
    container.appendChild(list);
  }

  renderWoDetailHistory(wo);
}

function renderWoDetailHistory(wo) {
  const listEl = document.getElementById('wo-detail-history-list');
  const emptyEl = document.getElementById('wo-detail-history-empty');

  if (!listEl) {
    return;
  }

  listEl.innerHTML = '';

  const historyItems = normalizeWoDetailHistory(wo);

  if (!historyItems.length) {
    if (emptyEl) {
      emptyEl.style.display = '';
      emptyEl.textContent = 'No history recorded for this work order yet.';
    }
    return;
  }

  if (emptyEl) {
    emptyEl.style.display = 'none';
  }

  historyItems.forEach((rawItem) => {
    const item = typeof rawItem === 'object' && rawItem !== null ? rawItem : { message: rawItem };
    const li = document.createElement('li');
    li.className = 'wo-history-item';

    const meta = document.createElement('div');
    meta.className = 'wo-history-meta';
    const timeValue =
      item.time ||
      item.timestamp ||
      item.date ||
      item.when ||
      item.created_at ||
      item.updated_at ||
      '';
    const formattedTime = formatWoTimestamp(timeValue) || timeValue || '';
    const statusValue = item.status || item.state || item.type || item.event || '';
    const metaParts = [formattedTime, statusValue].filter(Boolean);
    if (metaParts.length) {
      meta.textContent = metaParts.join(' · ');
      li.appendChild(meta);
    }

    const message =
      item.message ||
      item.details ||
      item.note ||
      item.summary ||
      item.description ||
      (typeof rawItem === 'string' || typeof rawItem === 'number' ? String(rawItem) : '');

    if (message) {
      const body = document.createElement('div');
      body.textContent = message;
      li.appendChild(body);
    } else if (!metaParts.length) {
      const fallback = document.createElement('div');
      fallback.textContent = 'Event recorded';
      li.appendChild(fallback);
    }

    listEl.appendChild(li);
  });
}

function normalizeWoDetailHistory(wo) {
  if (!wo) {
    return [];
  }

  const candidates = [wo.history, wo.events, wo.timeline];
  for (const candidate of candidates) {
    if (Array.isArray(candidate) && candidate.length) {
      return candidate;
    }
  }
  return [];
}

async function loadAndRenderWorkOrder(woId) {
  const historyList = document.getElementById('wo-detail-history-list');
  const historyEmpty = document.getElementById('wo-detail-history-empty');
  const detailContainer = document.getElementById('wo-detail-content');

  if (!woId) {
    renderWoDetail(null);
    return;
  }

  if (detailContainer) {
    detailContainer.innerHTML = '<p>Loading work order…</p>';
  }
  if (historyList) {
    historyList.innerHTML = '';
  }
  if (historyEmpty) {
    historyEmpty.style.display = '';
    historyEmpty.textContent = 'Loading history…';
  }

  try {
    const res = await fetch(`/api/wos/${encodeURIComponent(woId)}?tail=50`, { headers: { Accept: 'application/json' } });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    const wo = await res.json();
    renderWoDetail(wo);
  } catch (error) {
    console.error('Error loading WO detail', woId, error);
    if (detailContainer) {
      detailContainer.innerHTML = '';
      const message = document.createElement('p');
      message.textContent = `Failed to load work order ${woId}.`;
      detailContainer.appendChild(message);
    }
    if (historyEmpty) {
      historyEmpty.style.display = '';
      historyEmpty.textContent = 'Failed to load history for this work order.';
    }
  }
}

// --- WO Timeline Panel ---

function initWoTimelinePanel() {
  const panel = document.getElementById('wo-timeline-panel');
  if (!panel || woTimelineInitialized) {
    return;
  }

  const statusSelect = document.getElementById('wo-filter-status');
  if (statusSelect) {
    statusSelect.addEventListener('change', () => {
      woTimelineFilterStatus = statusSelect.value || '';
      renderWoTimelinePanel();
    });
  }

  const searchInput = document.getElementById('wo-filter-search');
  if (searchInput) {
    const handleSearch = debounce(() => {
      woTimelineSearchQuery = searchInput.value || '';
      renderWoTimelinePanel();
    }, 200);
    searchInput.addEventListener('input', handleSearch);
  }

  const listEl = document.getElementById('wo-timeline-list');
  listEl?.addEventListener('click', (event) => {
    const actionBtn = event.target.closest('.wo-timeline-view');
    if (actionBtn?.dataset.woId) {
      openWoTimeline(actionBtn.dataset.woId);
    }
  });

  woTimelineInitialized = true;
  refreshWoTimeline();
  woTimelineIntervalId = setInterval(refreshWoTimeline, WO_TIMELINE_REFRESH_MS);
}

async function refreshWoTimeline() {
  const panel = document.getElementById('wo-timeline-panel');
  if (!panel) return;

  const listEl = document.getElementById('wo-timeline-list');

  try {
    const res = await fetch('/api/wos', { headers: { Accept: 'application/json' } });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }

    const payload = await res.json();
    let dataset = [];
    if (Array.isArray(payload)) {
      dataset = payload;
    } else if (Array.isArray(payload?.wos)) {
      dataset = payload.wos;
    } else if (Array.isArray(payload?.results)) {
      dataset = payload.results;
    }

    const entries = dataset.map((wo) => normalizeWoTimelineEntry(wo));
    entries.sort((a, b) => getTimelineSortKey(b) - getTimelineSortKey(a));
    woTimelineAll = entries;
    renderWoTimelinePanel();
  } catch (error) {
    console.error('Failed to refresh WO timeline', error);
    if (listEl) {
      listEl.innerHTML = `
        <div class="wo-timeline-item">
          <div class="wo-timeline-row">
            <span>Failed to load work orders.</span>
          </div>
          <div class="wo-timeline-when">${escapeHtml(error.message || String(error))}</div>
        </div>
      `;
    }
  }
}

function renderWoTimelinePanel() {
  const listEl = document.getElementById('wo-timeline-list');
  const summaryEl = document.getElementById('wo-timeline-summary');
  if (!listEl || !summaryEl) return;

  let entries = woTimelineAll;
  if (woTimelineFilterStatus) {
    entries = entries.filter((entry) => {
      if (woTimelineFilterStatus === 'failed') {
        return entry.status === 'failed';
      }
      if (woTimelineFilterStatus === 'done') {
        return entry.status === 'done';
      }
      if (woTimelineFilterStatus === 'active') {
        return entry.status === 'pending' || entry.status === 'running';
      }
      return true;
    });
  }

  const normalizedSearch = woTimelineSearchQuery.trim().toLowerCase();
  if (normalizedSearch) {
    entries = entries.filter((entry) => {
      const haystack = [entry.id, entry.title, entry.description]
        .map((value) => String(value || '').toLowerCase());
      return haystack.some((field) => field && field.includes(normalizedSearch));
    });
  }

  if (!entries.length) {
    listEl.innerHTML = '<div class="wo-timeline-empty">No work orders match the current filters.</div>';
  } else {
    listEl.innerHTML = entries.map((entry) => renderWoTimelineItem(entry)).join('');
  }

  const counts = {
    pending: 0,
    running: 0,
    done: 0,
    failed: 0
  };
  woTimelineAll.forEach((entry) => {
    if (counts[entry.status] !== undefined) {
      counts[entry.status] += 1;
    }
  });

  const total = woTimelineAll.length;
  const summaryParts = [
    `Total: ${total}`,
    `pending: ${counts.pending}`,
    `running: ${counts.running}`,
    `done: ${counts.done}`,
    `failed: ${counts.failed}`,
    `filter: ${woTimelineFilterStatus || 'all'}`
  ];

  if (normalizedSearch) {
    summaryParts.push(`search: "${woTimelineSearchQuery.trim()}"`);
  }

  summaryEl.textContent = summaryParts.join(' · ');
}

function renderWoTimelineItem(entry) {
  const statusClass = getTimelineStatusClass(entry.status);
  const statusLabel = (entry.status || 'unknown').toUpperCase();
  const timelineMarkup = buildTimelineSegmentsMarkup(entry);
  const statusBadge = woStatusBadge(entry.status);
  if (statusBadge) {
    statusBadge.classList.add('wo-timeline-status');
  }
  const statusHtml = statusBadge
    ? statusBadge.outerHTML
    : `<span class="wo-timeline-status ${statusClass}">${statusLabel}</span>`;

  return `
    <article class="wo-timeline-item" data-wo-id="${escapeHtml(entry.id)}">
      <div class="wo-timeline-row">
        <span class="wo-timeline-id">${escapeHtml(entry.id)}</span>
        ${statusHtml}
      </div>
      <div class="wo-timeline-when">${timelineMarkup}</div>
      <div class="wo-timeline-actions">
        <button type="button" class="wo-timeline-view" data-wo-id="${escapeHtml(entry.id)}">View details</button>
      </div>
    </article>
  `;
}

function buildTimelineSegmentsMarkup(entry) {
  const segments = [
    { label: 'Created', value: entry.createdAt },
    { label: 'Started', value: entry.startedAt },
    { label: 'Finished', value: entry.finishedAt || entry.updatedAt }
  ];

  return segments
    .map((segment) => {
      const formatted = formatWoTimestamp(segment.value) || '—';
      return `
        <span class="wo-timeline-segment">
          <span class="wo-timeline-segment-label">${segment.label}</span>
          <span class="wo-timeline-segment-value">${escapeHtml(formatted)}</span>
        </span>
      `;
    })
    .join('<span class="wo-timeline-arrow">→</span>');
}

function getTimelineStatusClass(status) {
  switch (status) {
    case 'pending':
      return 'wo-status-pill-pending';
    case 'running':
      return 'wo-status-pill-running';
    case 'done':
      return 'wo-status-pill-done';
    case 'failed':
      return 'wo-status-pill-failed';
    default:
      return 'wo-status-pill-unknown';
  }
}

function getTimelineSortKey(entry) {
  const candidate = entry.updatedAt || entry.finishedAt || entry.startedAt || entry.createdAt;
  const parsed = candidate ? Date.parse(candidate) : NaN;
  if (Number.isNaN(parsed)) {
    return 0;
  }
  return parsed;
}

function initDashboard() {
  initTabs();
  initWoHistoryFilters();
  initWoStatusFilters();
  loadWos();
}

function cleanupIntervals() {
  if (servicesIntervalId) {
    clearInterval(servicesIntervalId);
    servicesIntervalId = null;
  }

  if (serviceAutoRefreshTimer) {
    clearInterval(serviceAutoRefreshTimer);
    serviceAutoRefreshTimer = null;
  }

  if (woTimelineIntervalId) {
    clearInterval(woTimelineIntervalId);
    woTimelineIntervalId = null;
  }

  if (summaryIntervalId) {
    clearInterval(summaryIntervalId);
    summaryIntervalId = null;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const serviceRefreshBtn = document.getElementById('service-refresh');
  if (serviceRefreshBtn) {
    serviceRefreshBtn.addEventListener('click', () => {
      refreshServices(true);
    });
  }

  refreshServices(false);
  if (!serviceAutoRefreshTimer) {
    serviceAutoRefreshTimer = setInterval(() => {
      refreshServices(false);
    }, 60000);
  }

  initSummaryCards();
  initDashboard();
  initWoTimelinePanel();
  renderWoDetail(null);

  window.addEventListener('wo:select', (event) => {
    const detail = event?.detail;
    let woId = null;
    if (detail && typeof detail === 'object') {
      woId = detail.id || detail.woId || detail.wo_id || detail.value;
    } else if (detail) {
      woId = detail;
    }

    if (woId) {
      onWorkOrderSelected(woId);
      loadAndRenderWorkOrder(woId);
    } else {
      onWorkOrderSelected(null);
      renderWoDetail(null);
    }
  });

  refreshWoDetailMls();
  window.loadAndRenderWorkOrder = loadAndRenderWorkOrder;
});

window.addEventListener('beforeunload', () => {
  cleanupIntervals();
});
