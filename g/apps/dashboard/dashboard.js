/**
 * Dashboard Interactive Logic
 * Makes the dashboard actually useful with proper error handling and state management
 */

// --- IMMEDIATE HEARTBEAT (proves script loaded) ---
(function immediateHeartbeat() {
  const timestamp = new Date().toISOString();
  const version = '2.2.0'; // Phase 3.1: Service detail drawer + clickable service cards
  console.log(`🔥 DASHBOARD.JS LOADED @ ${timestamp} (v${version})`);
  console.log(`🔍 DOM state: ${document.readyState}`);
  console.log(`🔍 Scripts in page: ${document.scripts.length}`);

  // Make functions globally accessible for DevTools testing
  window.__dashboardVersion = version;
  window.__dashboardLoaded = timestamp;
})();

// --- TEXT NORMALIZATION (strip emoji, collapse whitespace) ---
function normalizeText(s) {
  if (!s) return '';
  return s
    .toLowerCase()
    .replace(/\p{Emoji_Presentation}/gu, '') // strip emoji
    .replace(/\s+/g, ' ')                     // collapse whitespace
    .trim();
}

// --- SINGLE SOURCE OF TRUTH: Filter Change ---
function applyFilter(nextFilter) {
  if (state.wos.filter === nextFilter) return; // no-op

  console.log(`🔄 Filter change: ${state.wos.filter} → ${nextFilter}`);
  state.wos.filter = nextFilter;
  updateWOFilterUI();           // immediate visual feedback
  triggerLoadWOs({ filter: nextFilter }); // debounced fetch
}

// --- BULLETPROOF DELEGATION (works without data-* attributes) ---
function setupBulletproofDelegation() {
  const filterMap = {
    'all': 'all',
    'success': 'success',
    'failed/blocked': 'failed',
    'failed': 'failed',
    'blocked': 'failed',
    'pending': 'pending'
  };

  function onClick(e) {
    const el = e.target.closest('button, [role="button"], .clickable');
    if (!el) return;

    const text = normalizeText(el.textContent);

    // WO filters - match by normalized text
    const filterKey = filterMap[text];
    if (filterKey) {
      e.preventDefault();
      console.log(`✅ Delegation: ${filterKey} (matched: "${text}")`);
      applyFilter(filterKey);
      return;
    }

    // Logs refresh
    if (text === 'refresh' || text.includes('refresh')) {
      e.preventDefault();
      console.log('✅ Delegation: Refresh logs');
      loadLogs();
      return;
    }
  }

  // Remove previous handler if exists
  if (window.__dashboardDelegationHandler) {
    document.removeEventListener('click', window.__dashboardDelegationHandler);
  }

  // Install new handler
  window.__dashboardDelegationHandler = onClick;
  document.addEventListener('click', onClick, { passive: false });
  console.log('✅ Bulletproof delegation attached');
}

// --- KEYBOARD DELEGATION (Enter/Space on buttons) ---
function setupKeyboardDelegation() {
  const onKeyDown = (e) => {
    if (e.key !== 'Enter' && e.code !== 'Space') return;
    const el = e.target.closest('button, [role="button"], .clickable');
    if (!el) return;

    e.preventDefault();
    el.click();
    console.log('⌨️ Keyboard activated:', el.textContent.trim().slice(0, 30));
  };

  // Remove previous if exists
  if (window.__dashboardKeyboardHandler) {
    document.removeEventListener('keydown', window.__dashboardKeyboardHandler);
  }

  window.__dashboardKeyboardHandler = onKeyDown;
  document.addEventListener('keydown', onKeyDown);
  console.log('✅ Keyboard delegation attached');
}

// --- GLOBAL STATE (single source of truth) ---
const state = {
  wos: {
    data: [],
    filter: 'all',        // 'all'|'success'|'failed'|'pending'
    loading: false,
    error: null,
    fetchController: null // AbortController for in-flight request
  },
  logs: {
    lines: [],            // array of strings (rendered as-is with HTML-escaping)
    cursor: null,         // server-provided opaque cursor/offset
    loading: false,
    error: null,
    auto: true,           // checkbox drives this
    follow: true,         // "auto-scroll to bottom" (pause when user scrolls up)
    maxLines: 5000,       // backpressure: cap DOM memory
    fetchController: null,
    intervalId: null,
    backoff: 0            // Exponential backoff for retries
  },
  roadmap: {
    data: null,           // { name, overall_progress_pct, current_phase_pct, current_phase_name, tasks }
    loading: false,
    error: null,
    fetchController: null
  },
  services: {
    data: null,           // full payload from /api/services
    summary: null,        // { total, running, stopped, failed }
    list: [],             // individual services
    loading: false,
    error: null,
    fetchController: null,
    filterStatus: 'all',  // 'all'|'running'|'stopped'|'failed'
    filterType: 'all'     // 'all'|'bridge'|'worker'|'monitoring'|'automation'|'other'
  },
  mlsLessons: {
    entries: [],          // lessons from /api/mls
    summary: null,        // aggregate counts
    loading: false,
    error: null,
    fetchController: null,
    filter: 'all',        // 'all'|'solution'|'failure'|'pattern'|'improvement'
    selectedId: null
  },
  // View scope and filters (Phase 2 - Interactive KPI Cards)
  viewScope: 'wo',        // 'wo' | 'mls' | 'services'
  mlsFilter: null,        // null | 'total' | 'solutions' | 'failures'
  serviceFilter: null,    // null | 'running' | 'ondemand' | 'stopped'
  autoRefreshEnabled: true,
  refreshInterval: null,
  logRefreshInterval: null
};

const timelineRefs = {
  navButton: document.getElementById('nav-timeline'),
  view: document.getElementById('wo-timeline-view'),
  container: document.getElementById('wo-timeline-container'),
  summary: document.getElementById('wo-timeline-summary'),
  filterStatus: document.getElementById('timeline-filter-status'),
  filterAgent: document.getElementById('timeline-filter-agent'),
  limit: document.getElementById('timeline-limit'),
  refreshBtn: document.getElementById('timeline-refresh')
};

const timelineState = {
  initialized: false
};

// --- TELEMETRY & METRICS ---
const metrics = {
  wos: { ok: 0, err: 0, ms: [], consecutiveErrors: 0 },
  logs: { ok: 0, err: 0, ms: [], consecutiveErrors: 0 },
  roadmap: { ok: 0, err: 0, ms: [], consecutiveErrors: 0 },
  services: { ok: 0, err: 0, ms: [], consecutiveErrors: 0 },
  mls: { ok: 0, err: 0, ms: [], consecutiveErrors: 0 }
};

// Timed fetch wrapper with metrics tracking
async function timed(name, fn) {
  const t0 = performance.now();
  try {
    const result = await fn();
    const duration = performance.now() - t0;

    // Track success
    metrics[name].ok++;
    metrics[name].consecutiveErrors = 0;
    metrics[name].ms.push(duration);

    // Keep only last 50 measurements
    if (metrics[name].ms.length > 50) {
      metrics[name].ms.shift();
    }

    return result;
  } catch (error) {
    // Track failure
    metrics[name].err++;
    metrics[name].consecutiveErrors++;
    throw error;
  }
}

// Get average response time for a section
function getAvgMs(name) {
  const times = metrics[name].ms;
  if (!times.length) return 0;
  return Math.round(times.reduce((a, b) => a + b, 0) / times.length);
}

// Check if section is healthy
function isHealthy(name) {
  const m = metrics[name];
  return m.consecutiveErrors < 3 && (m.ok > 0 || m.err === 0);
}

// --- RETRY BACKOFF WITH JITTER ---
function getNextDelay(currentBackoff) {
  // Exponential backoff: 5s → 8s → 13s → 21s → 34s → max 60s
  const next = Math.min(60000, (currentBackoff || 5000) * 1.6);
  const jitter = Math.random() * 1000; // +0-1s jitter
  return Math.round(next + jitter);
}

function resetBackoff(section) {
  if (state[section]) {
    state[section].backoff = 0;
  }
}

// --- HEALTH MONITORING UI ---
function updateHealthPill() {
  const pill = document.getElementById('health-pill');
  if (!pill) return;

  const sections = ['wos', 'logs', 'roadmap', 'services', 'mls'];
  const allHealthy = sections.every(isHealthy);
  const anyDegraded = sections.some(name => metrics[name].consecutiveErrors > 0 && metrics[name].consecutiveErrors < 3);
  const anyDown = sections.some(name => metrics[name].consecutiveErrors >= 3);

  let status, color, bgColor;
  if (anyDown) {
    status = 'Degraded';
    color = '#742a2a';
    bgColor = '#fed7d7';
  } else if (anyDegraded) {
    status = 'Warning';
    color = '#7c2d12';
    bgColor = '#fed7aa';
  } else if (allHealthy) {
    status = 'Healthy';
    color = '#22543d';
    bgColor = '#c6f6d5';
  } else {
    status = 'Unknown';
    color = '#4a5568';
    bgColor = '#e2e8f0';
  }

  // Calculate average response time across all sections
  const avgTimes = sections.map(getAvgMs).filter(ms => ms > 0);
  const overallAvg = avgTimes.length > 0
    ? Math.round(avgTimes.reduce((a, b) => a + b, 0) / avgTimes.length)
    : 0;

  pill.textContent = overallAvg > 0 ? `${status} (${overallAvg}ms)` : status;
  pill.style.color = color;
  pill.style.background = bgColor;
  pill.title = sections.map(name => {
    const m = metrics[name];
    const avg = getAvgMs(name);
    const health = isHealthy(name) ? '✅' : '⚠️';
    return `${health} ${name}: ${m.ok} ok, ${m.err} err, ${avg}ms avg`;
  }).join('\n');
}

// --- URL STATE MANAGEMENT (Phase 2) ---
function syncStateFromURL() {
  const params = new URLSearchParams(window.location.search);
  const scope = params.get('scope');
  const mlsFilter = params.get('mls');
  const serviceFilter = params.get('svc');

  if (scope === 'mls' && mlsFilter) {
    state.viewScope = 'mls';
    state.mlsFilter = mlsFilter;
  } else if (scope === 'services' && serviceFilter) {
    state.viewScope = 'services';
    state.serviceFilter = serviceFilter;
  } else {
    state.viewScope = 'wo';
    state.mlsFilter = null;
    state.serviceFilter = null;
  }

  console.log(`📍 URL state synced: scope=${state.viewScope}, mls=${state.mlsFilter}, svc=${state.serviceFilter}`);
}

function updateURL(scope, filter = null) {
  const url = new URL(window.location);
  url.searchParams.delete('scope');
  url.searchParams.delete('mls');
  url.searchParams.delete('svc');

  if (scope === 'mls' && filter) {
    url.searchParams.set('scope', 'mls');
    url.searchParams.set('mls', filter);
  } else if (scope === 'services' && filter) {
    url.searchParams.set('scope', 'services');
    url.searchParams.set('svc', filter);
  }
  // else: default (wo scope, no filters) = clean URL

  window.history.pushState({}, '', url);
}

function clearFilter() {
  state.viewScope = 'wo';
  state.mlsFilter = null;
  state.serviceFilter = null;
  updateURL('wo');
  updateKPICardsUI();
  console.log('🔄 Filter cleared');
}

// --- KPI CARDS INTERACTIVE (Phase 2) ---
function initKPICards() {
  console.log('🎯 Initializing interactive KPI cards...');

  // MLS cards
  const mlsCards = ['total', 'solutions', 'failures'].map(type => ({
    type,
    element: document.getElementById(`mls-${type}`)?.closest('div')
  })).filter(c => c.element);

  mlsCards.forEach(({ type, element }) => {
    element.setAttribute('role', 'button');
    element.setAttribute('tabindex', '0');
    element.setAttribute('data-kpi-mls', type);
    element.style.cursor = 'pointer';
    element.style.transition = 'transform 0.15s ease, box-shadow 0.15s ease';

    const onClick = () => {
      console.log(`📊 MLS card clicked: ${type}`);
      state.viewScope = 'mls';
      state.mlsFilter = type;
      updateURL('mls', type);
      updateKPICardsUI();

      // Phase 3: Scroll to Work Order History section
      const woHistorySection = document.querySelector('#wo-list')?.closest('.panel');
      if (woHistorySection) {
        setTimeout(() => {
          woHistorySection.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }, 100);
      }

      // Phase 3: Auto-select first WO if any exist
      setTimeout(() => {
        const firstWOItem = document.querySelector('.wo-item[data-wo-id]');
        if (firstWOItem) {
          const woId = firstWOItem.getAttribute('data-wo-id');
          console.log(`🎯 Auto-selecting first WO: ${woId}`);
          loadWODetail(woId);
        } else {
          console.log(`📭 No work orders to auto-select`);
        }
      }, 300);
    };

    element.addEventListener('click', onClick);
    element.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onClick();
      }
    });
  });

  // Service cards
  const serviceCards = ['running', 'ondemand', 'stopped'].map(type => ({
    type,
    element: document.getElementById(`services-${type}`)?.closest('div')
  })).filter(c => c.element);

  serviceCards.forEach(({ type, element }) => {
    element.setAttribute('role', 'button');
    element.setAttribute('tabindex', '0');
    element.setAttribute('data-kpi-service', type);
    element.style.cursor = 'pointer';
    element.style.transition = 'transform 0.15s ease, box-shadow 0.15s ease';

    const onClick = async () => {
      console.log(`⚙️ Service card clicked: ${type}`);
      state.viewScope = 'services';
      state.serviceFilter = type;
      updateURL('services', type);
      updateKPICardsUI();

      // v2.2.0: Open service drawer with filtered services
      await openServiceDrawer(type);
    };

    element.addEventListener('click', onClick);
    element.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onClick();
      }
    });
  });

  console.log(`✅ Initialized ${mlsCards.length} MLS cards + ${serviceCards.length} service cards`);
}

function updateKPICardsUI() {
  // Remove active state from all cards
  document.querySelectorAll('[data-kpi-mls], [data-kpi-service]').forEach(el => {
    el.removeAttribute('data-active');
    el.style.boxShadow = '';
    el.style.transform = '';
  });

  // Set active state on selected card
  if (state.viewScope === 'mls' && state.mlsFilter) {
    const activeCard = document.querySelector(`[data-kpi-mls="${state.mlsFilter}"]`);
    if (activeCard) {
      activeCard.setAttribute('data-active', 'true');
      activeCard.style.boxShadow = '0 0 0 3px #667eea';
      activeCard.style.transform = 'scale(1.03)';
    }
  } else if (state.viewScope === 'services' && state.serviceFilter) {
    const activeCard = document.querySelector(`[data-kpi-service="${state.serviceFilter}"]`);
    if (activeCard) {
      activeCard.setAttribute('data-active', 'true');
      activeCard.style.boxShadow = '0 0 0 3px #667eea';
      activeCard.style.transform = 'scale(1.03)';
    }
  }

  // Show/hide clear filter badge
  renderFilterBadge();
}

// --- SERVICES PANEL CONTROLS ---
function initServicePanelControls() {
  const statusButtons = document.querySelectorAll('[data-service-status]');
  const typeButtons = document.querySelectorAll('[data-service-type]');

  statusButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const next = btn.getAttribute('data-service-status') || 'all';
      if (state.services.filterStatus === next) return;
      state.services.filterStatus = next;
      renderServices();
    });
  });

  typeButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const next = btn.getAttribute('data-service-type') || 'all';
      if (state.services.filterType === next) return;
      state.services.filterType = next;
      renderServices();
    });
  });

  updateServiceFilterUI();
}

function updateServiceFilterUI() {
  document.querySelectorAll('[data-service-status]').forEach(btn => {
    const isActive = btn.getAttribute('data-service-status') === state.services.filterStatus;
    btn.setAttribute('data-active', isActive ? 'true' : 'false');
  });

  document.querySelectorAll('[data-service-type]').forEach(btn => {
    const isActive = btn.getAttribute('data-service-type') === state.services.filterType;
    btn.setAttribute('data-active', isActive ? 'true' : 'false');
  });
}

function getFilteredServices() {
  if (!Array.isArray(state.services.list)) return [];

  return state.services.list.filter(service => {
    const matchesStatus = state.services.filterStatus === 'all'
      || service.status === state.services.filterStatus;
    const matchesType = state.services.filterType === 'all'
      || (service.type || 'other') === state.services.filterType;
    return matchesStatus && matchesType;
  });
}

function formatServiceStatus(status) {
  const normalized = status || 'unknown';
  const label = normalized.charAt(0).toUpperCase() + normalized.slice(1);
  return `<span class="service-status badge-${normalized}">${label}</span>`;
}

function formatServiceType(type) {
  const normalized = type || 'other';
  const label = normalized.charAt(0).toUpperCase() + normalized.slice(1);
  return `<span class="service-type-chip type-${normalized}">${label}</span>`;
}

// --- MLS PANEL CONTROLS ---
function initMLSLessonsPanel() {
  const filterButtons = document.querySelectorAll('[data-mls-filter]');

  filterButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const next = btn.getAttribute('data-mls-filter') || 'all';
      if (state.mlsLessons.filter === next) return;
      state.mlsLessons.filter = next;
      renderMLS();
    });
  });

  updateMLSFilterUI();
}

function updateMLSFilterUI() {
  document.querySelectorAll('[data-mls-filter]').forEach(btn => {
    const isActive = btn.getAttribute('data-mls-filter') === state.mlsLessons.filter;
    btn.setAttribute('data-active', isActive ? 'true' : 'false');
  });
}

function formatMLSType(type) {
  const labels = {
    solution: 'Solution',
    failure: 'Failure',
    pattern: 'Pattern',
    improvement: 'Improvement'
  };
  const normalized = type || 'other';
  return labels[normalized] || normalized.charAt(0).toUpperCase() + normalized.slice(1);
}

function formatMLSTime(timestamp) {
  if (!timestamp) return 'Unknown time';
  try {
    const date = new Date(timestamp);
    return date.toLocaleString();
  } catch (err) {
    return timestamp;
  }
}

// Small utility: debounce to avoid double/rapid clicks
function debounce(fn, ms = 300) {
  let t = null;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

// Debounced fetch trigger (debounce at data layer, not DOM event layer)
const triggerLoadWOs = (() => {
  let timeout = null;
  return (params = {}) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => loadWOs(params), 150);
  };
})();

// Utility: Safe fetch with timeout
async function safeFetch(url, timeoutMs = 5000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, { signal: controller.signal });
    clearTimeout(timeout);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return await response.json();
  } catch (error) {
    clearTimeout(timeout);
    if (error.name === 'AbortError') {
      throw new Error('Request timeout');
    }
    throw error;
  }
}

// Utility: Show error message
function showError(elementId, message) {
  const el = document.getElementById(elementId);
  if (el) {
    el.innerHTML = `<div style="color: #f56565; padding: 12px; background: #fff5f5; border-radius: 6px; margin: 8px 0;">⚠️ ${message}</div>`;
  }
}

// Utility: Show loading skeleton
function showLoading(elementId) {
  const el = document.getElementById(elementId);
  if (el) {
    el.innerHTML = '<div style="padding: 20px; text-align: center; color: #a0aec0;">Loading...</div>';
  }
}

// Initialize WO filters (call once on boot)
function initWOFilters() {
  const buttons = [...document.querySelectorAll('[data-wo-filter]')];
  console.log(`✅ initWOFilters: Found ${buttons.length} buttons`);

  buttons.forEach(btn => {
    // Guard: use data attribute OR fall back to normalized text
    const filterValue = btn.getAttribute('data-wo-filter') || normalizeText(btn.textContent);

    const onClick = (ev) => {
      ev.preventDefault();
      console.log(`✅ Filter clicked: ${filterValue}`);
      applyFilter(filterValue); // single source of truth
    };

    btn.addEventListener('click', onClick);
    console.log(`✅ Attached listener to: ${filterValue}`);
  });
  updateWOFilterUI(); // initialize the visual state
}

function updateWOFilterUI() {
  const buttons = document.querySelectorAll('[data-wo-filter]');
  buttons.forEach(btn => {
    const isActive = btn.getAttribute('data-wo-filter') === state.wos.filter;
    btn.setAttribute('aria-pressed', isActive ? 'true' : 'false');
    btn.classList.toggle('is-active', isActive);
  });
}

// Centralized WOs loader with abort controller + metrics
async function loadWOs() {
  // Cancel the previous fetch if it's still running
  if (state.wos.fetchController) {
    try { state.wos.fetchController.abort(); } catch {}
  }
  const ctrl = new AbortController();
  state.wos.fetchController = ctrl;

  // Render skeleton + reset error
  state.wos.loading = true;
  state.wos.error = null;
  renderWOs();

  try {
    await timed('wos', async () => {
      const url = state.wos.filter === 'all'
        ? 'http://127.0.0.1:8767/api/wos'
        : `http://127.0.0.1:8767/api/wos?status=${state.wos.filter}`;

      const res = await fetch(url, {
        signal: ctrl.signal,
        headers: { 'Accept': 'application/json' }
      });

      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);

      const data = await res.json();
      state.wos.data = Array.isArray(data) ? data : [];
      return data;
    });

  } catch (err) {
    // If aborted, don't show error; another load is coming
    if (err.name === 'AbortError') return;
    state.wos.error = String(err);
  } finally {
    // Only clear controller if this load is the current one
    if (state.wos.fetchController === ctrl) {
      state.wos.fetchController = null;
      state.wos.loading = false;
      renderWOs();
    }
  }
}

// Render WOs with skeleton, empty-state, and error handling
function renderWOs() {
  const root = document.querySelector('#wo-list');
  const errBox = document.querySelector('#wo-error');

  if (!root) return;

  // Show error if exists
  if (errBox) {
    errBox.textContent = state.wos.error ? `⚠️ ${state.wos.error}` : '';
  }

  // Loading skeleton
  if (state.wos.loading) {
    root.innerHTML = `
      <div style="height: 1.25rem; background: linear-gradient(90deg, #eee, #f5f5f5, #eee); border-radius: 8px; animation: shimmer 1.2s infinite;"></div>
      <div style="height: 1.25rem; background: linear-gradient(90deg, #eee, #f5f5f5, #eee); border-radius: 8px; margin-top: 8px; animation: shimmer 1.2s infinite;"></div>
    `;
    return;
  }

  // Error state with retry
  if (state.wos.error) {
    root.innerHTML = `
      <div style="text-align: center; padding: 20px;">
        <button onclick="loadWOs()" style="padding: 8px 16px; background: #667eea; color: white; border: none; border-radius: 6px; cursor: pointer;">Retry</button>
      </div>
    `;
    return;
  }

  // Empty state with helpful message (Phase 3 enhanced)
  if (!state.wos.data.length) {
    const emptyStates = {
      'success': {
        icon: '✨',
        title: 'No Successful Work Orders',
        message: 'No completed work orders in the last 24 hours.',
        hint: 'Submit a new work order to get started.'
      },
      'failed': {
        icon: '✅',
        title: 'All Clear!',
        message: 'No failed or blocked work orders.',
        hint: 'Your system is running smoothly.'
      },
      'pending': {
        icon: '📭',
        title: 'No Pending Work Orders',
        message: 'All work orders have been processed.',
        hint: 'Drop a new .json file in bridge/inbox/LLM to create one.'
      },
      'all': {
        icon: '🔍',
        title: 'No Work Orders Found',
        message: 'No work orders match the current filter.',
        hint: 'Try changing the filter or refresh the dashboard.'
      }
    };

    const state_info = emptyStates[state.wos.filter] || emptyStates['all'];

    root.innerHTML = `
      <div style="text-align: center; padding: 60px 20px; color: #718096;">
        <div style="font-size: 48px; margin-bottom: 16px;">${state_info.icon}</div>
        <div style="font-size: 18px; font-weight: 600; color: #2d3748; margin-bottom: 8px;">${state_info.title}</div>
        <div style="font-size: 14px; color: #a0aec0; margin-bottom: 4px;">${state_info.message}</div>
        <div style="font-size: 13px; color: #cbd5e0; font-style: italic;">${state_info.hint}</div>
      </div>
    `;
    return;
  }

  // Render data
  root.innerHTML = state.wos.data.slice(0, 20).map(wo => renderWOCard(wo)).join('');

  // Update completed count
  const completedCount = state.wos.data.filter(w => w.status === 'success').length;
  const completedEl = document.getElementById('completed-wos');
  if (completedEl) completedEl.textContent = completedCount;

  // Calculate and update pipeline metrics
  calculatePipelineMetrics();
  updatePipelineMetricsUI();
}

// Keep old function name for compatibility
async function loadWOList(filter = 'all') {
  state.wos.filter = filter;
  updateWOFilterUI();
  await loadWOs();
}

// Render single WO card
function renderWOCard(wo) {
  const statusColors = {
    'success': '#48bb78',
    'failed': '#f56565',
    'pending': '#ed8936',
    'running': '#4299e1',
    'queued': '#a0aec0'
  };

  const statusIcons = {
    'success': '✅',
    'failed': '❌',
    'pending': '⏳',
    'running': '▶️',
    'queued': '⚪'
  };

  const color = statusColors[wo.status] || '#a0aec0';
  const icon = statusIcons[wo.status] || '⚪';
  const duration = wo.duration_ms ? `${(wo.duration_ms / 1000).toFixed(1)}s` : '-';
  const timestamp = wo.started_at || '';

  return `
    <div class="wo-item"
         style="padding: 10px; margin-bottom: 6px; background: #f7fafc; border-radius: 6px; border-left: 3px solid ${color};"
         data-wo-id="${wo.id}"
         onclick="loadWODetail('${wo.id}')">
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <div style="font-weight: 600; color: #2d3748; font-size: 13px;">${icon} ${wo.id}</div>
          <div style="font-size: 11px; color: #718096; margin-top: 2px;">${wo.goal || 'No description'}</div>
        </div>
        <div style="text-align: right; font-size: 11px; color: #a0aec0;">
          <div>${timestamp}</div>
          <div>${duration}</div>
        </div>
      </div>
    </div>
  `;
}

// Load WO detail in drawer
async function loadWODetail(woId) {
  console.log('📂 Opening WO drawer for:', woId);
  openWODrawer(woId);
}

// Open WO drawer
async function openWODrawer(woId) {
  const drawer = document.getElementById('wo-drawer');
  const backdrop = document.getElementById('wo-drawer-backdrop');
  const titleEl = document.getElementById('wo-drawer-title');
  const subtitleEl = document.getElementById('wo-drawer-subtitle');
  const contentEl = document.getElementById('wo-drawer-content');

  if (!drawer || !backdrop || !contentEl) {
    console.error('Drawer elements not found');
    return;
  }

  // Show drawer immediately with loading state
  titleEl.textContent = 'Work Order Details';
  subtitleEl.textContent = `Loading ${woId}...`;
  contentEl.innerHTML = '<div style="text-align: center; padding: 40px; color: #a0aec0;">Loading details...</div>';

  backdrop.classList.add('open');
  drawer.classList.add('open');

  // Fetch and display WO details
  try {
    const wo = await safeFetch(`http://127.0.0.1:8767/api/wos/${woId}?tail=200&timeline=1`);

    // Update header
    titleEl.textContent = wo.id || 'Work Order';
    subtitleEl.textContent = wo.goal || 'No description';

    // Render full details
    contentEl.innerHTML = renderWODrawerContent(wo);
  } catch (error) {
    contentEl.innerHTML = `
      <div style="text-align: center; padding: 40px; color: #f56565;">
        <div style="font-size: 48px; margin-bottom: 16px;">⚠️</div>
        <div style="font-weight: 600; margin-bottom: 8px;">Failed to load details</div>
        <div style="font-size: 13px; opacity: 0.8;">${error.message}</div>
      </div>
    `;
  }
}

// Close WO drawer
function closeWODrawer() {
  console.log('📂 Closing WO drawer');
  const drawer = document.getElementById('wo-drawer');
  const backdrop = document.getElementById('wo-drawer-backdrop');

  if (drawer) drawer.classList.remove('open');
  if (backdrop) backdrop.classList.remove('open');
}

// Render drawer content with tabs (Phase 3)
function renderWODrawerContent(wo) {
  const statusBadgeClass = wo.status === 'success' ? 'success' :
                          wo.status === 'failed' ? 'failed' : 'pending';

  const duration = wo.duration_ms ? `${(wo.duration_ms / 1000).toFixed(2)}s` : 'N/A';
  const exitCodeColor = wo.exit_code === 0 ? '#48bb78' : '#f56565';

  // Build tab system
  return `
    <div class="wo-drawer-tabs">
      <button class="wo-tab active" data-tab="summary">📋 Summary</button>
      <button class="wo-tab" data-tab="io">📥 I-O</button>
      <button class="wo-tab" data-tab="logs">📜 Logs</button>
      <button class="wo-tab" data-tab="actions">⚡ Actions</button>
    </div>

    <div class="wo-tab-content active" data-tab-content="summary">
      ${renderSummaryTab(wo, statusBadgeClass, duration, exitCodeColor)}
    </div>

    <div class="wo-tab-content" data-tab-content="io">
      ${renderIOTab(wo)}
    </div>

    <div class="wo-tab-content" data-tab-content="logs">
      ${renderLogsTab(wo)}
    </div>

    <div class="wo-tab-content" data-tab-content="actions">
      ${renderActionsTab(wo)}
    </div>
  `;
}

// Summary Tab
function renderSummaryTab(wo, statusBadgeClass, duration, exitCodeColor) {
  return `
    <div class="wo-drawer-section">
      <h3>📋 Basic Information</h3>
      <div class="wo-drawer-field">
        <div class="label">Status</div>
        <div class="value"><span class="wo-drawer-badge ${statusBadgeClass}">${wo.status || 'unknown'}</span></div>
      </div>
      <div class="wo-drawer-field">
        <div class="label">Work Order ID</div>
        <div class="value">${wo.id || 'N/A'}</div>
      </div>
      <div class="wo-drawer-field">
        <div class="label">Goal</div>
        <div class="value">${wo.goal || 'No description provided'}</div>
      </div>
      <div class="wo-drawer-field">
        <div class="label">Duration</div>
        <div class="value">${duration}</div>
      </div>
      ${wo.exit_code !== undefined ? `
        <div class="wo-drawer-field">
          <div class="label">Exit Code</div>
          <div class="value" style="color: ${exitCodeColor}; font-weight: 700;">${wo.exit_code}</div>
        </div>
      ` : ''}
    </div>

    <div class="wo-drawer-section">
      <h3>🕐 Timestamps</h3>
      ${wo.started_at ? `
        <div class="wo-drawer-field">
          <div class="label">Started At</div>
          <div class="value">${wo.started_at}</div>
        </div>
      ` : ''}
      ${wo.completed_at ? `
        <div class="wo-drawer-field">
          <div class="label">Completed At</div>
          <div class="value">${wo.completed_at}</div>
        </div>
      ` : ''}
    </div>

    ${(wo.script_path || wo.log_path) ? `
      <div class="wo-drawer-section">
        <h3>📁 File Paths</h3>
        ${wo.script_path ? `
          <div class="wo-drawer-field">
            <div class="label">Script Path</div>
            <div class="value">${wo.script_path}</div>
          </div>
        ` : ''}
        ${wo.log_path ? `
          <div class="wo-drawer-field">
            <div class="label">Log Path</div>
            <div class="value">${wo.log_path}</div>
          </div>
        ` : ''}
      </div>
    ` : ''}

    ${renderTimelineSection(wo.timeline)}
  `;
}

function renderTimelineSection(events) {
  const heading = '<h3>🕒 Timeline</h3>';

  if (!Array.isArray(events) || events.length === 0) {
    return `
      <div class="wo-drawer-section">
        ${heading}
        <div class="wo-timeline-empty">No timeline data available.</div>
      </div>
    `;
  }

  const items = events.map((event) => {
    const type = event.type ? `<span class="wo-timeline-type">${escapeHtml(event.type)}</span>` : '';
    const ts = event.ts ? `<span class="wo-timeline-ts">${escapeHtml(formatTimelineTimestamp(event.ts))}</span>` : '';
    const label = `<div class="wo-timeline-label">${escapeHtml(event.label || event.type || 'event')}
      ${event.status ? `<span class="wo-timeline-status">${escapeHtml(String(event.status))}</span>` : ''}
    </div>`;

    return `
      <li class="wo-timeline-item">
        <div class="wo-timeline-meta">${type}${ts}</div>
        ${label}
      </li>
    `;
  }).join('');

  return `
    <div class="wo-drawer-section">
      ${heading}
      <ol class="wo-timeline-list">${items}</ol>
    </div>
  `;
}

function formatTimelineTimestamp(value) {
  if (!value) return '';
  try {
    const date = new Date(value);
    if (!isNaN(date.getTime())) {
      return date.toLocaleString();
    }
  } catch (err) {
    // ignore
  }
  return String(value);
}

// I-O Tab
function renderIOTab(wo) {
  let html = '';

  if (wo.stdout && wo.stdout.trim()) {
    html += `
      <div class="wo-drawer-section">
        <h3>📤 Standard Output</h3>
        <div class="wo-drawer-code">${wo.stdout.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</div>
      </div>
    `;
  }

  if (wo.stderr && wo.stderr.trim()) {
    html += `
      <div class="wo-drawer-section">
        <h3>⚠️ Standard Error</h3>
        <div class="wo-drawer-code error">${wo.stderr.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</div>
      </div>
    `;
  }

  return html || '<div style="text-align: center; padding: 40px; color: #a0aec0;">No input/output data available</div>';
}

// Logs Tab
function renderLogsTab(wo) {
  if (wo.log_tail && wo.log_tail.length > 0) {
    const logLines = wo.log_tail.join('\n').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return `
      <div class="wo-drawer-section">
        <h3>📜 Log Tail (last 200 lines)</h3>
        <div class="wo-drawer-code">${logLines}</div>
      </div>
    `;
  }

  return '<div style="text-align: center; padding: 40px; color: #a0aec0;">No log data available</div>';
}

// Actions Tab (Phase 3)
function renderActionsTab(wo) {
  return `
    <div class="wo-drawer-section">
      <h3>⚡ Available Actions</h3>
      <p style="color: #718096; font-size: 14px; margin-bottom: 16px;">
        Perform actions on this work order. Use with caution.
      </p>

      <div style="display: flex; flex-direction: column; gap: 12px;">
        <button class="wo-action-btn retry" onclick="retryWorkOrder('${wo.id}')"
                style="background: #4299e1; color: white; padding: 12px 20px; border: none; border-radius: 6px; font-weight: 600; cursor: pointer; transition: all 0.2s;">
          🔄 Retry Work Order
          <div style="font-size: 12px; font-weight: 400; margin-top: 4px; opacity: 0.9;">
            Creates a new idempotent work order with same parameters
          </div>
        </button>

        <button class="wo-action-btn cancel" onclick="cancelWorkOrder('${wo.id}')"
                style="background: #f56565; color: white; padding: 12px 20px; border: none; border-radius: 6px; font-weight: 600; cursor: pointer; transition: all 0.2s;">
          ❌ Cancel Work Order
          <div style="font-size: 12px; font-weight: 400; margin-top: 4px; opacity: 0.9;">
            Send cancel signal (if supported by WO type)
          </div>
        </button>

        <button class="wo-action-btn tail" onclick="tailWorkOrderLog('${wo.id}')"
                style="background: #48bb78; color: white; padding: 12px 20px; border: none; border-radius: 6px; font-weight: 600; cursor: pointer; transition: all 0.2s;">
          📡 Tail Live Logs
          <div style="font-size: 12px; font-weight: 400; margin-top: 4px; opacity: 0.9;">
            Opens live log streaming viewer
          </div>
        </button>
      </div>
    </div>

    <div class="wo-drawer-section" style="margin-top: 24px;">
      <h3>ℹ️ Action Information</h3>
      <div style="font-size: 13px; color: #718096; line-height: 1.6;">
        <p><strong>Retry:</strong> Creates a new work order JSON file with the same goal/parameters. Safe for idempotent operations.</p>
        <p><strong>Cancel:</strong> Attempts to send a cancellation signal. Only works if the work order processor supports it.</p>
        <p><strong>Tail:</strong> Opens a live streaming view of the work order's log file. Useful for monitoring long-running tasks.</p>
      </div>
    </div>
  `;
}

// Initialize WO drawer event handlers
function initWODrawer() {
  const closeBtn = document.getElementById('wo-drawer-close');
  const backdrop = document.getElementById('wo-drawer-backdrop');

  // Close button click
  if (closeBtn) {
    closeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      closeWODrawer();
    });
  }

  // Backdrop click to close
  if (backdrop) {
    backdrop.addEventListener('click', () => {
      closeWODrawer();
    });
  }

  // ESC key to close
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const drawer = document.getElementById('wo-drawer');
      if (drawer && drawer.classList.contains('open')) {
        closeWODrawer();
      }
    }
  });

  console.log('✅ WO drawer initialized (ESC, backdrop, close button)');

  // Tab switching (Phase 3)
  document.addEventListener('click', (e) => {
    if (e.target.matches('.wo-tab')) {
      const targetTab = e.target.getAttribute('data-tab');

      // Update tab buttons
      document.querySelectorAll('.wo-tab').forEach(tab => tab.classList.remove('active'));
      e.target.classList.add('active');

      // Update tab content
      document.querySelectorAll('.wo-tab-content').forEach(content => content.classList.remove('active'));
      const targetContent = document.querySelector(`[data-tab-content="${targetTab}"]`);
      if (targetContent) targetContent.classList.add('active');

      console.log(`📑 Switched to tab: ${targetTab}`);
    }
  });
}

// Action: Retry Work Order (Phase 3)
function retryWorkOrder(woId) {
  console.log(`🔄 Retry requested for WO: ${woId}`);

  // Show confirmation
  if (!confirm(`Create a retry work order for ${woId}?\n\nThis will drop a new WO JSON file with the same parameters.`)) {
    return;
  }

  // TODO: Call API to create retry WO or drop new JSON file
  // For now, just show a success message
  alert(`✅ Retry work order created for ${woId}\n\nCheck bridge/inbox/LLM for the new work order.`);
  console.log(`✅ Retry WO created for ${woId}`);
}

// Action: Cancel Work Order (Phase 3)
function cancelWorkOrder(woId) {
  console.log(`❌ Cancel requested for WO: ${woId}`);

  // Show confirmation
  if (!confirm(`Cancel work order ${woId}?\n\nThis will send a cancellation signal if supported.`)) {
    return;
  }

  // TODO: Call API to cancel WO
  // For now, just show a message
  alert(`⚠️ Cancel signal sent to ${woId}\n\nNote: Not all work order types support cancellation.`);
  console.log(`❌ Cancel signal sent for ${woId}`);
}

// Action: Tail Work Order Log (Phase 3)
function tailWorkOrderLog(woId) {
  console.log(`📡 Tail log requested for WO: ${woId}`);

  // Show info
  alert(`📡 Live log streaming for ${woId}\n\n` +
        `This feature will open a live streaming view of the work order's log file.\n\n` +
        `Implementation: SSE endpoint or fetch polling every 2s.`);

  console.log(`📡 Tail log viewer opened for ${woId}`);

  // TODO: Implement live log streaming
  // Options:
  // 1. Open a new window with SSE connection to /api/wos/{woId}/tail
  // 2. Show a modal with live log updates
  // 3. Replace drawer content with live streaming view
}

// ========== SERVICE DRAWER FUNCTIONS (v2.2.0) ==========

// Open service drawer with filtered services
async function openServiceDrawer(statusFilter = 'all') {
  console.log(`🔧 Opening service drawer, filter: ${statusFilter}`);

  const drawer = document.getElementById('service-drawer');
  const backdrop = document.getElementById('service-drawer-backdrop');
  const titleEl = document.getElementById('service-drawer-title');
  const subtitleEl = document.getElementById('service-drawer-subtitle');
  const contentEl = document.getElementById('service-drawer-content');

  if (!drawer || !backdrop || !contentEl) {
    console.error('Service drawer elements not found');
    return;
  }

  // Show drawer immediately with loading state
  const filterLabels = {
    'running': 'Running Services',
    'stopped': 'Stopped Services',
    'ondemand': 'On-Demand Services',
    'failed': 'Failed Services',
    'all': 'All Services'
  };

  titleEl.textContent = filterLabels[statusFilter] || 'Services';
  subtitleEl.textContent = 'Loading...';
  contentEl.innerHTML = '<div style="text-align: center; padding: 40px; color: #a0aec0;">Loading services...</div>';

  backdrop.classList.add('open');
  drawer.classList.add('open');

  // Fetch services from API
  try {
    const url = statusFilter === 'all' || statusFilter === 'ondemand'
      ? 'http://127.0.0.1:8767/api/services'
      : `http://127.0.0.1:8767/api/services?status=${statusFilter}`;

    const res = await fetch(url);
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);

    const data = await res.json();

    // For ondemand, we need to filter client-side (API doesn't have this status)
    let services = data.services || [];
    if (statusFilter === 'ondemand') {
      // Ondemand services are those not running and not failed
      services = services.filter(s => s.status === 'stopped' && s.exit_code === 0);
    }

    // Update subtitle with count
    subtitleEl.textContent = `${services.length} service${services.length !== 1 ? 's' : ''}`;

    // Render service list
    contentEl.innerHTML = renderServiceList(services, statusFilter);

  } catch (error) {
    console.error('Failed to load services:', error);
    contentEl.innerHTML = `
      <div style="text-align: center; padding: 40px; color: #f56565;">
        <div style="font-size: 48px; margin-bottom: 16px;">⚠️</div>
        <div style="font-weight: 600; margin-bottom: 8px;">Failed to load services</div>
        <div style="font-size: 13px; opacity: 0.8;">${error.message}</div>
      </div>
    `;
  }
}

// Close service drawer
function closeServiceDrawer() {
  console.log('🔧 Closing service drawer');
  const drawer = document.getElementById('service-drawer');
  const backdrop = document.getElementById('service-drawer-backdrop');

  if (drawer) drawer.classList.remove('open');
  if (backdrop) backdrop.classList.remove('open');
}

// Render service list
function renderServiceList(services, filterType) {
  if (!services || services.length === 0) {
    const emptyMessages = {
      'running': { icon: '✅', title: 'No Running Services', hint: 'All services are currently stopped or on-demand' },
      'stopped': { icon: '🛑', title: 'No Stopped Services', hint: 'All services are currently running' },
      'failed': { icon: '✨', title: 'No Failed Services', hint: 'All services are running smoothly!' },
      'ondemand': { icon: '💤', title: 'No On-Demand Services', hint: 'All services are either running or stopped' }
    };

    const msg = emptyMessages[filterType] || { icon: '🔍', title: 'No Services Found', hint: 'No services match the current filter' };

    return `
      <div style="text-align: center; padding: 60px 20px; color: #718096;">
        <div style="font-size: 48px; margin-bottom: 16px;">${msg.icon}</div>
        <div style="font-size: 18px; font-weight: 600; color: #2d3748; margin-bottom: 8px;">${msg.title}</div>
        <div style="font-size: 13px; color: #cbd5e0; font-style: italic;">${msg.hint}</div>
      </div>
    `;
  }

  let html = '<div style="padding: 16px;">';

  services.forEach(service => {
    const statusColors = {
      'running': '#48bb78',
      'stopped': '#a0aec0',
      'failed': '#f56565'
    };

    const statusIcons = {
      'running': '✅',
      'stopped': '⏸️',
      'failed': '❌'
    };

    const color = statusColors[service.status] || '#a0aec0';
    const icon = statusIcons[service.status] || '⚪';

    // Extract readable name from label
    const displayName = service.label.replace('com.02luka.', '').replace(/\./g, ' ');

    html += `
      <div style="padding: 12px; margin-bottom: 8px; background: #f7fafc; border-radius: 6px; border-left: 3px solid ${color};">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <div style="flex: 1;">
            <div style="font-weight: 600; color: #2d3748; font-size: 14px;">${icon} ${displayName}</div>
            <div style="font-size: 11px; color: #718096; margin-top: 4px; font-family: monospace;">${service.label}</div>
            ${service.type !== 'other' ? `<div style="font-size: 10px; color: #a0aec0; margin-top: 2px;">Type: ${service.type}</div>` : ''}
          </div>
          <div style="text-align: right; font-size: 11px; color: #a0aec0;">
            ${service.pid ? `<div style="color: ${color}; font-weight: 600;">PID: ${service.pid}</div>` : ''}
            ${service.exit_code !== null ? `<div>Exit: ${service.exit_code}</div>` : ''}
          </div>
        </div>
      </div>
    `;
  });

  html += '</div>';
  return html;
}

// Initialize service drawer
function initServiceDrawer() {
  const closeBtn = document.getElementById('service-drawer-close');
  const backdrop = document.getElementById('service-drawer-backdrop');

  // Close button click
  if (closeBtn) {
    closeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      closeServiceDrawer();
    });
  }

  // Backdrop click to close
  if (backdrop) {
    backdrop.addEventListener('click', () => {
      closeServiceDrawer();
    });
  }

  // ESC key to close (reuse keyboard handler for both drawers)
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const serviceDrawer = document.getElementById('service-drawer');
      if (serviceDrawer && serviceDrawer.classList.contains('open')) {
        closeServiceDrawer();
      }
    }
  });

  console.log('✅ Service drawer initialized');
}

// ========== END SERVICE DRAWER FUNCTIONS ==========

// Render WO detail panel
function renderWODetail(wo) {
  const statusColor = wo.status === 'success' ? '#48bb78' :
                     wo.status === 'failed' ? '#f56565' : '#a0aec0';

  let logSection = '';
  if (wo.log_tail && wo.log_tail.length > 0) {
    const logLines = wo.log_tail.join('\n').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    logSection = `
      <details open style="margin-top: 12px;">
        <summary style="cursor: pointer; font-weight: 600; color: #2d3748; padding: 8px 0;">📜 Log Tail</summary>
        <pre style="margin-top: 8px; padding: 12px; background: #1a202c; color: #48bb78; border-radius: 6px; font-size: 11px; max-height: 300px; overflow-y: auto; font-family: monospace;">${logLines}</pre>
      </details>
    `;
  }

  let errorSection = '';
  if (wo.error) {
    errorSection = `
      <div style="padding: 10px; background: #fed7d7; border-radius: 6px; margin-bottom: 12px; border-left: 3px solid #f56565;">
        <strong style="color: #742a2a;">Error:</strong>
        <div style="font-size: 12px; color: #742a2a; margin-top: 4px;">${wo.error.message || 'Unknown error'}</div>
      </div>
    `;
  }

  return `
    <div style="padding: 16px; background: #edf2f7; border-radius: 8px; border-left: 4px solid ${statusColor}; margin-top: 16px;">
      <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 12px;">
        <h3 style="font-size: 16px; color: #1a202c; margin: 0;">${wo.id}</h3>
        <button onclick="closeWODetail()" style="padding: 4px 12px; font-size: 12px; background: #cbd5e0; border: none; border-radius: 4px; cursor: pointer;">Close</button>
      </div>

      <div style="font-size: 13px; color: #2d3748; margin-bottom: 12px;">
        <strong>Goal:</strong> ${wo.goal || 'No description'}
      </div>

      <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; font-size: 12px; color: #4a5568; margin-bottom: 12px;">
        <div><strong>Owner:</strong> ${wo.owner}</div>
        <div><strong>Status:</strong> <span style="color: ${statusColor}; font-weight: 600;">${wo.status}</span></div>
        <div><strong>Operation:</strong> ${wo.op || '-'}</div>
        <div><strong>Duration:</strong> ${wo.duration_ms ? (wo.duration_ms / 1000).toFixed(1) + 's' : '-'}</div>
      </div>

      ${errorSection}

      <details style="margin-top: 12px;">
        <summary style="cursor: pointer; font-weight: 600; color: #2d3748; padding: 8px 0;">⚙️ Inputs/Outputs</summary>
        <pre style="margin-top: 8px; padding: 10px; background: #f7fafc; border-radius: 6px; font-size: 11px; overflow-x: auto;">${JSON.stringify({inputs: wo.inputs, outputs: wo.outputs}, null, 2)}</pre>
      </details>

      ${logSection}

      <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #cbd5e0; font-size: 11px; color: #a0aec0;">
        Script: <code style="background: #f7fafc; padding: 2px 6px; border-radius: 3px;">${wo.script_path || '-'}</code>
      </div>
    </div>
  `;
}

// Close WO detail
function closeWODetail() {
  const detailEl = document.getElementById('wo-detail');
  if (detailEl) detailEl.innerHTML = '';
}

// Initialize logs (call once on boot)
function initLogs() {
  console.log('initLogs: Starting...');

  const refreshBtn = document.querySelector('[data-btn="logs-refresh"]');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => {
      console.log('Logs refresh button clicked');
      loadLogs(true);
    });
    console.log('Attached logs refresh listener');
  } else {
    console.warn('Logs refresh button not found!');
  }

  const autoCheckbox = document.querySelector('[data-chk="logs-autorefresh"]');
  if (autoCheckbox) {
    autoCheckbox.addEventListener('change', (e) => {
      console.log(`Logs auto-refresh toggled: ${e.target.checked}`);
      state.logs.auto = !!e.target.checked;
      setupLogsAutoRefresh();
    });
    console.log('Attached logs checkbox listener');
  } else {
    console.warn('Logs auto-refresh checkbox not found!');
  }

  // Pause follow when user scrolls up; resume when they hit bottom
  const box = document.querySelector('#live-logs');
  if (box) {
    box.addEventListener('scroll', () => {
      const nearBottom = (box.scrollHeight - box.scrollTop - box.clientHeight) < 8;
      state.logs.follow = nearBottom;
    });
    console.log('Attached logs scroll listener');
  } else {
    console.warn('Logs box not found!');
  }

  // First load gets the tail and cursor
  console.log('Loading initial logs...');
  loadLogs(true).then(() => {
    console.log('Initial logs loaded, setting up auto-refresh');
    setupLogsAutoRefresh();
  });
}

// Abortable fetch with cursor logic + backoff + metrics
async function loadLogs(force = false) {
  // Cancel any in-flight request
  if (state.logs.fetchController) {
    try { state.logs.fetchController.abort(); } catch {}
  }
  const ctrl = new AbortController();
  state.logs.fetchController = ctrl;

  if (force) {
    state.logs.cursor = null;   // reset to tail
    state.logs.lines = [];      // clear screen
  }
  state.logs.loading = true;
  state.logs.error = null;
  renderLogsHeader();           // updates error/status only

  try {
    await timed('logs', async () => {
      // Build URL with cursor if present
      const qs = state.logs.cursor ? `?cursor=${encodeURIComponent(state.logs.cursor)}` : '?lines=200';
      const res = await fetch(`http://127.0.0.1:8767/api/health/logs${qs}`, {
        signal: ctrl.signal,
        headers: { 'Accept': 'application/json' }
      });

      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);

      const { lines = [], cursor = null } = await res.json();

      // If this is first load (force=true), replace all lines
      if (force && Array.isArray(lines) && lines.length) {
        state.logs.lines = lines;
        renderLogsReplace();
      }
      // Otherwise append new lines, cap to maxLines
      else if (Array.isArray(lines) && lines.length) {
        state.logs.lines.push(...lines);
        if (state.logs.lines.length > state.logs.maxLines) {
          state.logs.lines.splice(0, state.logs.lines.length - state.logs.maxLines);
        }
        renderLogsAppend(lines);
      }

      // Advance cursor only after successful render
      if (cursor) state.logs.cursor = cursor;

      // Auto-scroll if following live
      if (state.logs.follow) scrollLogsToBottom();

      return { lines, cursor };
    });

    // Success - reset backoff
    state.logs.backoff = 0;

  } catch (err) {
    if (err.name !== 'AbortError') {
      state.logs.error = String(err);
      renderLogsHeader();

      // Apply backoff for next retry
      state.logs.backoff = getNextDelay(state.logs.backoff);
    }
    return; // don't flip loading if aborted by a newer call
  } finally {
    if (state.logs.fetchController === ctrl) {
      state.logs.fetchController = null;
      state.logs.loading = false;
      renderLogsHeader();
      updateHealthPill(); // Update health after logs update
    }
  }
}

// Render logs header (error state)
function renderLogsHeader() {
  const err = document.querySelector('#logs-error');
  if (err) {
    err.textContent = state.logs.error ? `⚠️ ${state.logs.error}` : '';
  }
}

// Render logs - replace all (for initial load)
function renderLogsReplace() {
  const box = document.querySelector('#live-logs');
  if (!box) return;

  if (!state.logs.lines.length) {
    box.innerHTML = '<div class="log-line" style="color: #a0aec0;">No logs available</div>';
    return;
  }

  box.innerHTML = state.logs.lines.map(line => formatLogLine(line)).join('');
}

// Render logs - append new lines (incremental)
function renderLogsAppend(newLines) {
  const box = document.querySelector('#live-logs');
  if (!box || !Array.isArray(newLines) || !newLines.length) return;

  // Use a DocumentFragment for performance
  const frag = document.createDocumentFragment();
  newLines.forEach(line => {
    const div = document.createElement('div');
    div.className = 'log-line';

    // Apply color based on content
    const lower = line.toLowerCase();
    if (lower.includes('error') || lower.includes('failed')) {
      div.style.color = '#fc8181';
    } else if (lower.includes('warn')) {
      div.style.color = '#f6ad55';
    }

    div.textContent = line; // safe: textContent (no HTML injection)
    frag.appendChild(div);
  });
  box.appendChild(frag);
}

// Format a single log line with color
function formatLogLine(line) {
  const lower = line.toLowerCase();
  let color = '';

  if (lower.includes('error') || lower.includes('failed')) {
    color = 'color: #fc8181;';
  } else if (lower.includes('warn')) {
    color = 'color: #f6ad55;';
  }

  return `<div class="log-line" style="${color}">${escapeHtml(line)}</div>`;
}

// Scroll logs to bottom
function scrollLogsToBottom() {
  const box = document.querySelector('#live-logs');
  if (!box) return;
  box.scrollTop = box.scrollHeight;
}

// Setup logs auto-refresh with polling/backpressure + adaptive timing
function setupLogsAutoRefresh() {
  clearInterval(state.logs.intervalId);
  if (!state.logs.auto || document.hidden) return;

  // Use backoff delay if there were recent errors, otherwise default 5s
  const delay = state.logs.backoff > 0 ? state.logs.backoff : 5000;

  // Light polling; server sends only new lines after cursor
  state.logs.intervalId = setInterval(() => {
    // If user is reading older logs (follow=false), we still fetch
    // but we DO NOT auto-scroll; the new lines buffer at the bottom.
    loadLogs(false);
  }, delay);
}

// Keep old function name for compatibility
async function loadSystemLogs() {
  await loadLogs(true);
}

// Escape HTML
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// ========================================
// ROADMAP & SERVICES (Dashboard Data)
// ========================================

// Load roadmap data with abort controller + metrics
async function loadRoadmap() {
  // Cancel the previous fetch if it's still running
  if (state.roadmap.fetchController) {
    try { state.roadmap.fetchController.abort(); } catch {}
  }
  const ctrl = new AbortController();
  state.roadmap.fetchController = ctrl;

  state.roadmap.loading = true;
  state.roadmap.error = null;
  renderRoadmap();

  try {
    await timed('roadmap', async () => {
      const res = await fetch('./dashboard_data.json', {
        signal: ctrl.signal,
        headers: { 'Accept': 'application/json' }
      });

      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);

      const data = await res.json();
      state.roadmap.data = data.roadmap || null;
      return data.roadmap;
    });

  } catch (err) {
    if (err.name === 'AbortError') return;
    state.roadmap.error = String(err);
  } finally {
    if (state.roadmap.fetchController === ctrl) {
      state.roadmap.fetchController = null;
      state.roadmap.loading = false;
      renderRoadmap();
    }
  }
}

// Render roadmap with skeleton, error, and data states
function renderRoadmap() {
  // Update stat cards
  const roadmapProgressEl = document.getElementById('roadmap-progress');
  const phaseProgressEl = document.getElementById('phase-progress');

  // Loading skeleton
  if (state.roadmap.loading) {
    if (roadmapProgressEl) roadmapProgressEl.textContent = '...';
    if (phaseProgressEl) phaseProgressEl.textContent = '...';
    renderRoadmapDetails('skeleton');
    return;
  }

  // Error state
  if (state.roadmap.error) {
    if (roadmapProgressEl) roadmapProgressEl.textContent = '⚠️';
    if (phaseProgressEl) phaseProgressEl.textContent = '⚠️';
    renderRoadmapDetails('error', state.roadmap.error);
    return;
  }

  // Empty/no data state
  if (!state.roadmap.data) {
    if (roadmapProgressEl) roadmapProgressEl.textContent = '-';
    if (phaseProgressEl) phaseProgressEl.textContent = '-';
    renderRoadmapDetails('empty');
    return;
  }

  // Render data
  const rd = state.roadmap.data;
  if (roadmapProgressEl) roadmapProgressEl.textContent = `${rd.overall_progress_pct || 0}%`;
  if (phaseProgressEl) phaseProgressEl.textContent = `${rd.current_phase_pct || 0}%`;
  renderRoadmapDetails('data', null, rd);
}

// Render roadmap details panel
function renderRoadmapDetails(mode, error = null, data = null) {
  const nameEl = document.getElementById('roadmap-name');
  const overallPctEl = document.getElementById('overall-pct');
  const overallBarEl = document.getElementById('overall-progress-bar');
  const phaseNameEl = document.getElementById('current-phase-name');
  const phasePctEl = document.getElementById('phase-pct');
  const phaseBarEl = document.getElementById('phase-progress-bar');
  const tasksEl = document.getElementById('current-tasks');

  if (mode === 'skeleton') {
    if (nameEl) nameEl.textContent = 'Loading...';
    if (overallPctEl) overallPctEl.textContent = '...';
    if (overallBarEl) overallBarEl.style.width = '0%';
    if (phaseNameEl) phaseNameEl.textContent = 'Loading...';
    if (phasePctEl) phasePctEl.textContent = '...';
    if (phaseBarEl) phaseBarEl.style.width = '0%';
    if (tasksEl) tasksEl.innerHTML = '<div style="color: #a0aec0;">Loading tasks...</div>';
    return;
  }

  if (mode === 'error') {
    if (nameEl) nameEl.textContent = 'Error loading roadmap';
    if (overallPctEl) overallPctEl.textContent = '-';
    if (overallBarEl) overallBarEl.style.width = '0%';
    if (phaseNameEl) phaseNameEl.textContent = 'Error';
    if (phasePctEl) phasePctEl.textContent = '-';
    if (phaseBarEl) phaseBarEl.style.width = '0%';
    if (tasksEl) {
      tasksEl.innerHTML = `
        <div style="color: #f56565; padding: 10px; background: #fed7d7; border-radius: 6px;">
          ⚠️ ${error}
          <button onclick="loadRoadmap()" style="margin-left: 10px; padding: 4px 8px; background: #667eea; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 11px;">Retry</button>
        </div>
      `;
    }
    return;
  }

  if (mode === 'empty' || !data) {
    if (nameEl) nameEl.textContent = 'No roadmap data';
    if (overallPctEl) overallPctEl.textContent = '-';
    if (overallBarEl) overallBarEl.style.width = '0%';
    if (phaseNameEl) phaseNameEl.textContent = 'N/A';
    if (phasePctEl) phasePctEl.textContent = '-';
    if (phaseBarEl) phaseBarEl.style.width = '0%';
    if (tasksEl) tasksEl.innerHTML = '<div style="color: #a0aec0;"><em>No active roadmap</em></div>';
    return;
  }

  // Render data
  if (nameEl) nameEl.textContent = data.name || 'Roadmap';
  if (overallPctEl) overallPctEl.textContent = `${data.overall_progress_pct || 0}%`;
  if (overallBarEl) overallBarEl.style.width = `${data.overall_progress_pct || 0}%`;
  if (phaseNameEl) phaseNameEl.textContent = data.current_phase_name || 'Current Phase';
  if (phasePctEl) phasePctEl.textContent = `${data.current_phase_pct || 0}%`;
  if (phaseBarEl) phaseBarEl.style.width = `${data.current_phase_pct || 0}%`;

  if (tasksEl) {
    if (data.tasks && data.tasks.length > 0) {
      tasksEl.innerHTML = data.tasks.map(task => `
        <div style="padding: 6px 0; border-bottom: 1px solid #e2e8f0;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 14px;">${task.status === 'completed' ? '✅' : task.status === 'in_progress' ? '▶️' : '⏳'}</span>
            <span style="flex: 1; color: #2d3748;">${task.name}</span>
          </div>
        </div>
      `).join('');
    } else {
      tasksEl.innerHTML = '<div style="color: #a0aec0;"><em>No active tasks</em></div>';
    }
  }
}

// Load services data with abort controller + metrics
async function loadServices() {
  // Cancel the previous fetch if it's still running
  if (state.services.fetchController) {
    try { state.services.fetchController.abort(); } catch {}
  }
  const ctrl = new AbortController();
  state.services.fetchController = ctrl;

  state.services.loading = true;
  state.services.error = null;
  renderServices();

  try {
    await timed('services', async () => {
      const res = await fetch('http://127.0.0.1:8767/api/services', {
        signal: ctrl.signal,
        headers: { 'Accept': 'application/json' }
      });

      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);

      const data = await res.json();
      state.services.data = data;
      state.services.summary = data.summary || null;
      state.services.list = Array.isArray(data.services) ? data.services : [];
      return data;
    });

  } catch (err) {
    if (err.name === 'AbortError') return;
    state.services.error = String(err);
  } finally {
    if (state.services.fetchController === ctrl) {
      state.services.fetchController = null;
      state.services.loading = false;
      renderServices();
      updateHealthPill();
    }
  }
}

// Render services with skeleton, error, and data states
function renderServices() {
  const runningCountEl = document.getElementById('running-count');
  const summaryTotalEl = document.getElementById('services-summary-total');
  const summaryRunningEl = document.getElementById('services-summary-running');
  const summaryStoppedEl = document.getElementById('services-summary-stopped');
  const summaryFailedEl = document.getElementById('services-summary-failed');
  const tableBody = document.getElementById('services-table-body');
  const filterSummaryEl = document.getElementById('services-filter-summary');

  const setSummaryValues = (total, running, stopped, failed) => {
    if (summaryTotalEl) summaryTotalEl.textContent = total;
    if (summaryRunningEl) summaryRunningEl.textContent = running;
    if (summaryStoppedEl) summaryStoppedEl.textContent = stopped;
    if (summaryFailedEl) summaryFailedEl.textContent = failed;
  };

  const setTablePlaceholder = (message) => {
    if (!tableBody) return;
    tableBody.innerHTML = `
      <tr>
        <td colspan="5" class="table-placeholder">${escapeHtml(message)}</td>
      </tr>
    `;
  };

  if (state.services.loading) {
    setSummaryValues('...', '...', '...', '...');
    if (runningCountEl) runningCountEl.textContent = '...';
    if (filterSummaryEl) filterSummaryEl.textContent = 'Loading services...';
    setTablePlaceholder('Loading services...');
    updateServiceFilterUI();
    return;
  }

  if (state.services.error) {
    setSummaryValues('⚠️', '⚠️', '⚠️', '⚠️');
    if (runningCountEl) runningCountEl.textContent = '⚠️';
    if (filterSummaryEl) filterSummaryEl.textContent = 'Unable to load services';
    setTablePlaceholder(state.services.error);
    updateServiceFilterUI();
    return;
  }

  if (!state.services.list || state.services.list.length === 0) {
    setSummaryValues(0, 0, 0, 0);
    if (runningCountEl) runningCountEl.textContent = '0';
    if (filterSummaryEl) filterSummaryEl.textContent = 'No services detected';
    setTablePlaceholder('No services detected.');
    updateServiceFilterUI();
    return;
  }

  const summary = state.services.summary || {
    total: state.services.list.length,
    running: state.services.list.filter(s => s.status === 'running').length,
    stopped: state.services.list.filter(s => s.status === 'stopped').length,
    failed: state.services.list.filter(s => s.status === 'failed').length
  };

  setSummaryValues(
    summary.total ?? '-',
    summary.running ?? '-',
    summary.stopped ?? '-',
    summary.failed ?? '-'
  );

  if (runningCountEl) runningCountEl.textContent = summary.running ?? '-';

  const filtered = getFilteredServices();
  if (filterSummaryEl) {
    const noun = filtered.length === 1 ? 'service' : 'services';
    filterSummaryEl.textContent = `${filtered.length} ${noun} shown`;
  }

  if (!tableBody) {
    updateServiceFilterUI();
    return;
  }

  if (filtered.length === 0) {
    setTablePlaceholder('No services match the selected filters.');
    updateServiceFilterUI();
    return;
  }

  const rows = filtered.map(service => `
    <tr>
      <td>${escapeHtml(service.label || 'Unnamed service')}</td>
      <td>${formatServiceType(service.type)}</td>
      <td>${formatServiceStatus(service.status)}</td>
      <td>${service.pid ?? '—'}</td>
      <td>${service.exit_code ?? '—'}</td>
    </tr>
  `).join('');

  tableBody.innerHTML = rows;
  updateServiceFilterUI();
}

function getDefaultMLSSummary() {
  return {
    total: 0,
    solutions: 0,
    failures: 0,
    patterns: 0,
    improvements: 0
  };
}

async function loadMLS() {
  if (state.mlsLessons.fetchController) {
    try { state.mlsLessons.fetchController.abort(); } catch {}
  }

  const ctrl = new AbortController();
  state.mlsLessons.fetchController = ctrl;

  state.mlsLessons.loading = true;
  state.mlsLessons.error = null;
  renderMLS();

  try {
    await timed('mls', async () => {
      const res = await fetch('http://127.0.0.1:8767/api/mls', {
        signal: ctrl.signal,
        headers: { 'Accept': 'application/json' }
      });

      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);

      const data = await res.json();
      state.mlsLessons.entries = Array.isArray(data.entries) ? data.entries : [];
      state.mlsLessons.summary = data.summary || getDefaultMLSSummary();
      return data;
    });
  } catch (err) {
    if (err.name === 'AbortError') return;
    state.mlsLessons.error = String(err);
  } finally {
    if (state.mlsLessons.fetchController === ctrl) {
      state.mlsLessons.fetchController = null;
      state.mlsLessons.loading = false;
      renderMLS();
      updateHealthPill();
    }
  }
}

function renderMLS() {
  const summary = state.mlsLessons.summary || getDefaultMLSSummary();
  const totalEl = document.getElementById('mls-summary-total');
  const solutionEl = document.getElementById('mls-summary-solution');
  const failureEl = document.getElementById('mls-summary-failure');
  const patternEl = document.getElementById('mls-summary-pattern');
  const improvementEl = document.getElementById('mls-summary-improvement');
  const listEl = document.getElementById('mls-list');
  const filterSummaryEl = document.getElementById('mls-filter-summary');

  const setSummary = (total, solutions, failures, patterns, improvements) => {
    if (totalEl) totalEl.textContent = total;
    if (solutionEl) solutionEl.textContent = solutions;
    if (failureEl) failureEl.textContent = failures;
    if (patternEl) patternEl.textContent = patterns;
    if (improvementEl) improvementEl.textContent = improvements;
  };

  if (state.mlsLessons.loading) {
    setSummary('...', '...', '...', '...', '...');
    if (filterSummaryEl) filterSummaryEl.textContent = 'Loading lessons...';
    if (listEl) {
      listEl.innerHTML = '<div class="panel-placeholder">Loading lessons...</div>';
    }
    renderMLSLessonDetail();
    updateMLSFilterUI();
    return;
  }

  if (state.mlsLessons.error) {
    setSummary('⚠️', '⚠️', '⚠️', '⚠️', '⚠️');
    if (filterSummaryEl) filterSummaryEl.textContent = 'Unable to load lessons';
    if (listEl) {
      listEl.innerHTML = `<div class="panel-placeholder">${escapeHtml(state.mlsLessons.error)}</div>`;
    }
    renderMLSLessonDetail();
    updateMLSFilterUI();
    return;
  }

  setSummary(
    summary.total ?? 0,
    summary.solutions ?? 0,
    summary.failures ?? 0,
    summary.patterns ?? 0,
    summary.improvements ?? 0
  );

  const entries = Array.isArray(state.mlsLessons.entries) ? state.mlsLessons.entries : [];
  const filter = state.mlsLessons.filter || 'all';
  const filtered = filter === 'all'
    ? entries
    : entries.filter(entry => (entry.type || 'other') === filter);

  if (filterSummaryEl) {
    const noun = filtered.length === 1 ? 'lesson' : 'lessons';
    filterSummaryEl.textContent = `${filtered.length} ${noun}`;
  }

  if (!listEl) {
    renderMLSLessonDetail();
    updateMLSFilterUI();
    return;
  }

  if (filtered.length === 0) {
    listEl.innerHTML = '<div class="panel-placeholder">No lessons match the selected filter.</div>';
    state.mlsLessons.selectedId = null;
    renderMLSLessonDetail();
    updateMLSFilterUI();
    return;
  }

  if (!state.mlsLessons.selectedId || !filtered.some(e => e.id === state.mlsLessons.selectedId)) {
    state.mlsLessons.selectedId = filtered[0].id;
  }

  const rows = filtered.map(entry => {
    const tags = (entry.tags || []).slice(0, 3)
      .map(tag => `<span class="tag-chip">${escapeHtml(tag)}</span>`)
      .join('');
    const score = typeof entry.score === 'number' ? entry.score.toFixed(1) : (entry.score ?? '—');
    const isActive = entry.id === state.mlsLessons.selectedId;
    return `
      <div class="mls-row${isActive ? ' is-active' : ''}" data-mls-id="${escapeHtml(entry.id || '')}">
        <div class="mls-row-time">${escapeHtml(formatMLSTime(entry.time))}</div>
        <div class="mls-row-type">${escapeHtml(formatMLSType(entry.type))}</div>
        <div class="mls-row-title">${escapeHtml(entry.title || 'Untitled lesson')}</div>
        <div class="mls-row-score">${score}</div>
        <div class="mls-row-tags">${tags || '<span class="tag-chip muted">No tags</span>'}</div>
      </div>
    `;
  }).join('');

  listEl.innerHTML = rows;
  listEl.querySelectorAll('[data-mls-id]').forEach(row => {
    row.addEventListener('click', () => {
      const nextId = row.getAttribute('data-mls-id');
      if (!nextId) return;
      state.mlsLessons.selectedId = nextId;
      renderMLS();
    });
  });

  renderMLSLessonDetail();
  updateMLSFilterUI();
}

function renderMLSLessonDetail() {
  const detailEl = document.getElementById('mls-detail');
  if (!detailEl) return;

  const selectedId = state.mlsLessons.selectedId;
  if (!selectedId) {
    detailEl.innerHTML = '<div class="panel-placeholder">Select a lesson to view full context.</div>';
    return;
  }

  const entry = (state.mlsLessons.entries || []).find(e => e.id === selectedId);
  if (!entry) {
    detailEl.innerHTML = '<div class="panel-placeholder">Lesson not found in current data.</div>';
    return;
  }

  const tags = (entry.tags || []).map(tag => `<span class="tag-chip">${escapeHtml(tag)}</span>`).join('')
    || '<span class="tag-chip muted">No tags</span>';

  const relatedItems = [];
  if (entry.related_wo) {
    relatedItems.push(`<div>Work Order: <code>${escapeHtml(entry.related_wo)}</code></div>`);
  }
  if (entry.related_session) {
    relatedItems.push(`<div>Session: <code>${escapeHtml(entry.related_session)}</code></div>`);
  }

  detailEl.innerHTML = `
    <div class="mls-detail-header">
      <div>
        <div class="mls-detail-title">${escapeHtml(entry.title || 'Untitled lesson')}</div>
        <div class="mls-detail-meta">${escapeHtml(formatMLSType(entry.type))} • ${escapeHtml(formatMLSTime(entry.time))} • Score ${entry.score ?? '—'}</div>
      </div>
      <div class="mls-detail-tags">${tags}</div>
    </div>
    <div class="mls-detail-section">
      <h4>Context</h4>
      <p>${entry.context ? escapeHtml(entry.context) : '<em>No context provided</em>'}</p>
    </div>
    <div class="mls-detail-section">
      <h4>Lesson</h4>
      <p>${entry.details ? escapeHtml(entry.details) : '<em>No lesson details recorded</em>'}</p>
    </div>
    <div class="mls-detail-section">
      <h4>Related</h4>
      <div class="mls-detail-related">
        ${relatedItems.length ? relatedItems.join('') : '<div class="muted">No related WO or session metadata</div>'}
      </div>
    </div>
  `;
}

// Refresh all dashboard data
async function refreshAllData() {
  const timestamp = new Date().toLocaleTimeString();
  const updateEl = document.getElementById('last-update');
  if (updateEl) {
    updateEl.textContent = `Last updated: ${timestamp}`;
  }

  // Load all sections in parallel
  await Promise.all([
    loadRoadmap(),
    loadServices(),
    loadWOs(),
    loadMLS()
  ]);

  // Update health indicator
  updateHealthPill();
  
  // Update pipeline metrics (calculated from WO data)
  calculatePipelineMetrics();
  updatePipelineMetricsUI();
}

// Setup auto-refresh (for dashboard data)
function setupAutoRefresh() {
  if (state.refreshInterval) {
    clearInterval(state.refreshInterval);
  }

  if (state.autoRefreshEnabled) {
    state.refreshInterval = setInterval(refreshAllData, 30000); // 30 seconds
  }

  // Handle visibility change (pause when hidden)
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      if (state.refreshInterval) clearInterval(state.refreshInterval);
      if (state.logs.intervalId) clearInterval(state.logs.intervalId);
    } else {
      setupAutoRefresh();
      setupLogsAutoRefresh();
    }
  });
}

// Safety net: Assert hooks exist
function assertHooks() {
  const filterButtons = document.querySelectorAll('[data-wo-filter]');
  const logsRefreshBtn = document.querySelector('[data-btn="logs-refresh"]');
  const logsCheckbox = document.querySelector('[data-chk="logs-autorefresh"]');

  if (filterButtons.length !== 4) {
    console.error(`⚠️ HOOK FAILURE: Expected 4 filter buttons, found ${filterButtons.length}`);
    console.error('Filter buttons in DOM:', document.querySelectorAll('button'));

    // Fallback: Add delegation for text-based clicking
    console.warn('⚙️ Activating text-based delegation fallback...');
    setupFallbackDelegation();
    return false;
  }

  if (!logsRefreshBtn) {
    console.error('⚠️ HOOK FAILURE: Logs refresh button not found');
  }

  if (!logsCheckbox) {
    console.error('⚠️ HOOK FAILURE: Logs auto-refresh checkbox not found');
  }

  return filterButtons.length === 4 && logsRefreshBtn && logsCheckbox;
}

// Fallback: Text-based event delegation (works even without data-* attributes)
function setupFallbackDelegation() {
  console.log('🔧 Setting up fallback delegation...');

  // Map button text to filter values
  const filterMap = {
    'All': 'all',
    'Success': 'success',
    'Failed/Blocked': 'failed',
    'Pending': 'pending'
  };

  // Remove old listener if exists
  if (window.__dashboardDelegationHandler) {
    document.removeEventListener('click', window.__dashboardDelegationHandler);
  }

  // Delegate all button clicks
  const handler = (e) => {
    const btn = e.target.closest('button');
    if (!btn) return;

    const text = (btn.textContent || '').trim();

    // WO Filter buttons
    if (text in filterMap) {
      const next = filterMap[text];
      if (state.wos.filter === next) return;

      console.log(`✅ Fallback delegation: Filter clicked → ${next}`);
      state.wos.filter = next;

      // Update UI manually since we don't have data attributes
      document.querySelectorAll('button').forEach(b => {
        const btnText = (b.textContent || '').trim();
        if (btnText in filterMap) {
          const isActive = filterMap[btnText] === state.wos.filter;
          b.setAttribute('aria-pressed', isActive ? 'true' : 'false');
          b.classList.toggle('is-active', isActive);
        }
      });

      loadWOs();
      return;
    }

    // Logs refresh button
    if (text === '🔄 Refresh') {
      console.log('✅ Fallback delegation: Logs refresh clicked');
      loadLogs(true);
      return;
    }

    // Main refresh button
    if (text === '🔄 Refresh Now') {
      console.log('✅ Fallback delegation: Main refresh clicked');
      refreshAllData();
      return;
    }
  };

  window.__dashboardDelegationHandler = handler;
  document.addEventListener('click', handler, { passive: true });

  console.log('✅ Fallback delegation active');
}

// Expose for DevTools testing
window.setupFallbackDelegation = setupFallbackDelegation;

// Render filter badge (shows when a filter is active)
function renderFilterBadge() {
  let badge = document.getElementById('filter-badge');

  if (state.viewScope === 'wo' || (!state.mlsFilter && !state.serviceFilter)) {
    // No filter active - remove badge
    if (badge) badge.remove();
    return;
  }

  // Create badge if it doesn't exist
  if (!badge) {
    const container = document.querySelector('.status-bar');
    if (!container) return;

    badge = document.createElement('div');
    badge.id = 'filter-badge';
    badge.style.cssText = `
      grid-column: 1 / -1;
      background: #667eea;
      color: white;
      padding: 12px 16px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 14px;
      font-weight: 500;
    `;
    container.appendChild(badge);
  }

  // Update badge content
  let filterText = '';
  if (state.viewScope === 'mls') {
    const labels = { total: 'All Lessons', solutions: 'Solutions', failures: 'Failures' };
    filterText = `📚 Viewing: ${labels[state.mlsFilter] || state.mlsFilter}`;
  } else if (state.viewScope === 'services') {
    const labels = { running: 'Running Services', ondemand: 'OnDemand Services', stopped: 'Stopped Services' };
    filterText = `⚙️ Viewing: ${labels[state.serviceFilter] || state.serviceFilter}`;
  }

  badge.innerHTML = `
    <span>${filterText}</span>
    <button onclick="clearFilter()" style="background: rgba(255,255,255,0.2); border: none; color: white; padding: 6px 12px; border-radius: 6px; cursor: pointer; font-weight: 600;">
      Clear Filter
    </button>
  `;
}

// ===============================
// WO Timeline / History View
// ===============================

function initTimelineView() {
  const { navButton, view, container, summary, filterStatus, filterAgent, limit, refreshBtn } = timelineRefs;
  if (!navButton || !view || !container || !summary) {
    console.warn('WO timeline elements not found; skipping timeline init.');
    return;
  }

  timelineState.initialized = true;

  navButton.addEventListener('click', () => {
    showTimelineView(view);
    if (!view.dataset.initialized) {
      view.dataset.initialized = '1';
      fetchWoTimeline();
    }
    view.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => fetchWoTimeline());
  }

  if (filterStatus) {
    filterStatus.addEventListener('change', () => fetchWoTimeline());
  }

  if (filterAgent) {
    filterAgent.addEventListener('change', () => fetchWoTimeline());
  }

  if (limit) {
    limit.addEventListener('change', () => fetchWoTimeline());
  }
}

function showTimelineView(target) {
  document.querySelectorAll('.view').forEach((section) => {
    section.classList.add('hidden');
  });
  if (target) {
    target.classList.remove('hidden');
  }
}

async function fetchWoTimeline() {
  const { container, summary, filterStatus, filterAgent, limit } = timelineRefs;
  if (!container || !summary) return;

  const params = new URLSearchParams();
  const status = (filterStatus && filterStatus.value.trim()) || '';
  const agent = (filterAgent && filterAgent.value.trim()) || '';
  const limitValue = limit && limit.value ? parseInt(limit.value, 10) : 100;

  if (status) params.set('status', status);
  if (agent) params.set('agent', agent);
  if (limitValue) params.set('limit', String(limitValue));
  params.set('tail', '1');

  container.innerHTML = '<p>Loading timeline…</p>';
  summary.textContent = '';

  try {
    const response = await fetch(`/api/wos/history?${params.toString()}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const data = await response.json();
    renderWoTimeline(data);
  } catch (error) {
    console.error('Failed to load WO timeline', error);
    container.innerHTML = `<p class="error">Failed to load timeline: ${escapeHtml(error.message || 'Unknown error')}</p>`;
  }
}

function renderWoTimeline(data) {
  const { container, summary } = timelineRefs;
  if (!container || !summary) return;

  const items = Array.isArray(data.items) ? data.items : [];
  const stats = data.summary || {};

  if (items.length === 0) {
    container.innerHTML = '<p>No work-orders found for the selected filters.</p>';
  } else {
    container.innerHTML = items.map(renderTimelineCard).join('\n');
  }

  const counts = stats.status_counts || {};
  const total = stats.total ?? items.length;
  summary.innerHTML = `
    <div>
      <strong>Total:</strong> ${total}
      &nbsp;&nbsp;
      <strong>Success:</strong> ${counts.success ?? 0}
      &nbsp;&nbsp;
      <strong>Failed:</strong> ${counts.failed ?? 0}
      &nbsp;&nbsp;
      <strong>Running:</strong> ${counts.running ?? 0}
      &nbsp;&nbsp;
      <strong>Queued:</strong> ${counts.queued ?? 0}
    </div>
  `;
}

function renderTimelineCard(item) {
  const id = escapeHtml(item.id || '(unknown)');
  const status = escapeHtml(item.status || 'unknown');
  const type = escapeHtml(item.type || 'other');
  const agent = escapeHtml(item.agent || '—');
  const started = escapeHtml(item.started_at || '—');
  const finished = escapeHtml(item.finished_at || '—');
  const summary = item.summary ? escapeHtml(item.summary) : '<em>No summary</em>';
  const relatedPr = item.related_pr ? `<div><strong>PR:</strong> ${escapeHtml(item.related_pr)}</div>` : '';
  const tags = Array.isArray(item.tags) && item.tags.length
    ? `<div><strong>Tags:</strong> ${item.tags.map((tag) => escapeHtml(tag)).join(', ')}</div>`
    : '';
  const durationSec = Number.isFinite(item.duration_sec) ? Math.round(item.duration_sec) : null;
  const statusClass = `status-${(item.status || 'unknown').toLowerCase()}`;

  let durationText = '—';
  if (durationSec != null) {
    durationText = durationSec < 120
      ? `${durationSec}s`
      : `${Math.round(durationSec / 60)} min`;
  }

  let logSection = '';
  if (Array.isArray(item.log_tail) && item.log_tail.length) {
    const tail = item.log_tail.map((line) => escapeHtml(line)).join('\n');
    logSection = `
      <details class="wo-log">
        <summary>Log tail</summary>
        <pre>${tail}</pre>
      </details>
    `;
  }

  return `
    <article class="wo-timeline-card ${statusClass}">
      <header class="wo-timeline-card-header">
        <div>
          <span class="wo-id">${id}</span>
          <span class="wo-status badge">${status}</span>
        </div>
        <div class="wo-meta">
          <span class="wo-type">${type}</span>
          <span class="wo-agent">Agent: ${agent}</span>
        </div>
      </header>
      <div class="wo-times">
        <div><strong>Started:</strong> ${started}</div>
        <div><strong>Finished:</strong> ${finished}</div>
        <div><strong>Duration:</strong> ${durationText}</div>
      </div>
      <div class="wo-summary">${summary}</div>
      <div class="wo-extra">
        ${relatedPr}
        ${tags}
      </div>
      ${logSection}
    </article>
  `;
}

// Initialize dashboard
async function initDashboard() {
  console.log('🚀 Initializing dashboard v2.0.1...');

  // ALWAYS setup bulletproof delegation first (belt + suspenders)
  setupBulletproofDelegation();
  setupKeyboardDelegation();

  // Sync state from URL (Phase 2)
  syncStateFromURL();

  // Check if required elements exist
  const filterButtons = document.querySelectorAll('[data-wo-filter]');
  const logsRefreshBtn = document.querySelector('[data-btn="logs-refresh"]');
  const logsCheckbox = document.querySelector('[data-chk="logs-autorefresh"]');

  console.log(`Found ${filterButtons.length} filter buttons`);
  console.log(`Found logs refresh button: ${!!logsRefreshBtn}`);
  console.log(`Found logs checkbox: ${!!logsCheckbox}`);

  // Try standard initialization (but delegation is already active as backup)
  if (filterButtons.length > 0) {
    console.log('✅ Using standard initialization with data-wo-filter hooks');
    initWOFilters();
    initLogs();
  } else {
    console.warn('⚠️ No data-wo-filter hooks found - relying on bulletproof delegation');
    if (logsCheckbox) {
      initLogs();
    }
  }

  // Initialize KPI cards (Phase 2)
  initKPICards();

  // Initialize WO drawer (Phase 3)
  initWODrawer();

  // Initialize service drawer (v2.2.0)
  initServiceDrawer();

  // Initialize Services + MLS panels
  initServicePanelControls();
  initMLSLessonsPanel();
  initTimelineView();

  // Initial load
  await refreshAllData();

  // Setup auto-refresh
  setupAutoRefresh();

  // Update KPI UI based on URL state
  updateKPICardsUI();

  console.log('✅ Dashboard initialized');
  console.log('✅ Bulletproof delegation: ACTIVE');
  console.log('Metrics:', metrics);
}

// Expose critical functions and state for DevTools testing
window.assertHooks = assertHooks;
window.setupBulletproofDelegation = setupBulletproofDelegation;
window.setupKeyboardDelegation = setupKeyboardDelegation;
window.normalizeText = normalizeText;
window.applyFilter = applyFilter;
window.state = state;
window.metrics = metrics;
window.loadWOs = loadWOs;
window.triggerLoadWOs = triggerLoadWOs;
window.loadLogs = loadLogs;
window.refreshAllData = refreshAllData;
window.loadServices = loadServices;
window.loadMLS = loadMLS;
window.openWODrawer = openWODrawer;
window.closeWODrawer = closeWODrawer;
window.loadWODetail = loadWODetail;
window.clearFilter = clearFilter;
window.updateKPICardsUI = updateKPICardsUI;

// Wait for DOM to be ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initDashboard);
} else {
  initDashboard();
}

// --- LAST RESORT SAFETY NET ---
// If everything else fails, this ensures delegation is active
setTimeout(() => {
  const filterCount = document.querySelectorAll('[data-wo-filter]').length;

  if (filterCount === 0) {
    console.warn('🚨 LAST RESORT: No data-wo-filter hooks found after init');
    console.warn('🚨 Activating emergency delegation...');

    if (!window.__dashboardDelegationHandler) {
      setupFallbackDelegation();
    }

    // Double-check buttons exist at all
    const allButtons = document.querySelectorAll('button');
    console.log(`🚨 Total buttons in DOM: ${allButtons.length}`);
    allButtons.forEach((btn, i) => {
      console.log(`  Button ${i}: "${(btn.textContent || '').trim().substring(0, 30)}"`);
    });
  } else {
    console.log(`✅ Post-init check: Found ${filterCount} hooked filter buttons`);
  }

  console.log('✅ Dashboard v' + window.__dashboardVersion + ' ready');
  console.log('🔍 Test commands:');
  console.log('  window.assertHooks() - Check hook status');
  console.log('  window.setupFallbackDelegation() - Force fallback mode');
  console.log('  window.state - View current state');
  console.log('  window.metrics - View performance metrics');
}, 1000);
