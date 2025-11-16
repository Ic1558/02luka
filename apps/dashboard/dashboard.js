const SERVICES_REFRESH_MS = 30000;
const MLS_REFRESH_MS = 30000;
const KNOWN_SERVICE_TYPES = new Set(['bridge', 'worker', 'automation', 'monitoring']);

let servicesIntervalId;
let mlsIntervalId;
let currentMlsType = '';

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
    } else if (targetId === 'view-reality') {
      loadRealitySnapshot();
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

// --- Reality Snapshot ---

async function loadRealitySnapshot() {
  const meta = document.getElementById('reality-meta');
  if (meta) {
    meta.textContent = 'Loading Reality snapshot…';
  }

  try {
    const response = await fetch('/api/reality/snapshot');
    if (!response.ok) {
      const text = await response.text();
      console.error('Failed to fetch Reality snapshot', response.status, text);
      renderRealityError(`HTTP ${response.status}`);
      return;
    }
    const payload = await response.json();
    renderRealitySnapshot(payload);
  } catch (error) {
    console.error('Error loading Reality snapshot', error);
    renderRealityError(String(error));
  }
}

function renderRealityError(message) {
  const meta = document.getElementById('reality-meta');
  const deployEl = document.getElementById('reality-deployment');
  const saveBody = document.getElementById('reality-save-body');
  const orchEl = document.getElementById('reality-orchestrator');

  if (meta) meta.textContent = `Reality snapshot error: ${message}`;
  if (deployEl) deployEl.textContent = '';
  setRealitySaveMessage(saveBody, 'Unable to load save.sh runs.');
  if (orchEl) orchEl.textContent = '';
}

function setRealitySaveMessage(saveBody, message) {
  if (!saveBody) return;
  saveBody.innerHTML = `
    <tr>
      <td colspan="7">${escapeHtml(message)}</td>
    </tr>
  `;
}

function renderRealitySnapshot(payload) {
  const meta = document.getElementById('reality-meta');
  const deployEl = document.getElementById('reality-deployment');
  const saveBody = document.getElementById('reality-save-body');
  const orchEl = document.getElementById('reality-orchestrator');

  if (!meta || !deployEl || !saveBody || !orchEl) {
    return;
  }

  if (!payload || payload.status === 'no_snapshot') {
    meta.textContent = 'No Reality Hooks snapshot found yet. Run the Reality Hooks workflow in CI first.';
    deployEl.textContent = '';
    setRealitySaveMessage(saveBody, 'No save.sh runs captured.');
    orchEl.textContent = '';
    return;
  }

  if (payload.status === 'error') {
    renderRealityError(payload.error || 'invalid snapshot');
    return;
  }

  const data = payload.data || {};
  const timestamp = data.timestamp || '';
  const deployment = data.deployment_report || null;
  const saveRuns = Array.isArray(data.save_sh_full_cycle) ? data.save_sh_full_cycle : [];
  const orchestrator = data.orchestrator_summary || null;

  meta.textContent = `Latest snapshot: ${timestamp || 'unknown'} (source: ${payload.snapshot_path || 'unknown'})`;

  if (deployment && (deployment.path || deployment.summary)) {
    const summaryParts = [];
    if (deployment.path) summaryParts.push(`Report: ${deployment.path}`);
    if (deployment.summary) summaryParts.push(String(deployment.summary));
    deployEl.textContent = summaryParts.join('\n');
  } else {
    deployEl.textContent = 'No deployment report in snapshot.';
  }

  if (!saveRuns.length) {
    setRealitySaveMessage(saveBody, 'No save.sh runs captured.');
  } else {
    saveBody.innerHTML = '';
    saveRuns.forEach((run) => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><code>${escapeHtml(run.test_id || '')}</code></td>
        <td>${escapeHtml(run.lane || '')}</td>
        <td>${escapeHtml(run.layer1 || '')}</td>
        <td>${escapeHtml(run.layer2 || '')}</td>
        <td>${escapeHtml(run.layer3 || '')}</td>
        <td>${escapeHtml(run.layer4 || '')}</td>
        <td>${escapeHtml(run.git || '')}</td>
      `;
      saveBody.appendChild(tr);
    });
  }

  if (orchestrator) {
    try {
      orchEl.textContent = JSON.stringify(orchestrator, null, 2);
    } catch (err) {
      console.warn('Failed to stringify orchestrator summary', err);
      orchEl.textContent = String(orchestrator);
    }
  } else {
    orchEl.textContent = 'No orchestrator summary in snapshot.';
  }
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
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
});

window.addEventListener('beforeunload', () => {
  cleanupIntervals();
});
