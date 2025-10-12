import { API } from './api.js';

export const NAV_LINKS = [
  { id: 'landing', label: 'Mission Control', path: '/' },
  { id: 'chat', label: 'Chat', path: '/chat' },
  { id: 'plan', label: 'Plan', path: '/plan' },
  { id: 'build', label: 'Build', path: '/build' },
  { id: 'ship', label: 'Ship', path: '/ship' },
  { id: 'signals', label: 'Signals', path: '/signals' }
];

export function mountAppShell(options = {}) {
  const {
    active = 'landing',
    title = 'Luka Workspace',
    subtitle = 'Split-lane control surface for boss agents'
  } = options;

  document.body.className = 'app-body';
  document.body.innerHTML = '';

  const shell = document.createElement('div');
  shell.className = 'app-shell';

  const header = document.createElement('header');
  header.className = 'app-header';

  const brand = document.createElement('div');
  brand.className = 'brand';
  brand.innerHTML = `
    <span class="brand-badge">L</span>
    <div class="brand-text">
      <span class="brand-title">${title}</span>
      <span class="brand-subtitle">${subtitle}</span>
    </div>
  `;
  header.appendChild(brand);

  const nav = document.createElement('nav');
  nav.className = 'app-nav';
  NAV_LINKS.forEach((link) => {
    const anchor = document.createElement('a');
    anchor.href = link.path;
    anchor.textContent = link.label;
    anchor.dataset.route = link.id;
    if (link.id === active) {
      anchor.setAttribute('aria-current', 'page');
    }
    nav.appendChild(anchor);
  });
  header.appendChild(nav);
  shell.appendChild(header);

  const statusBar = document.createElement('section');
  statusBar.className = 'status-bar';
  shell.appendChild(statusBar);

  const main = document.createElement('main');
  main.className = 'app-main';
  shell.appendChild(main);

  document.body.appendChild(shell);

  return { shell, header, nav, main, statusBar };
}

export function createPanel(title, subtitle = '') {
  const panel = document.createElement('section');
  panel.className = 'panel';

  if (title) {
    const heading = document.createElement('h2');
    heading.textContent = title;
    panel.appendChild(heading);
  }

  if (subtitle) {
    const sub = document.createElement('p');
    sub.className = 'panel-subtitle';
    sub.textContent = subtitle;
    panel.appendChild(sub);
  }

  return panel;
}

export function renderStatusPill(label, state = 'ok', detail = '') {
  const pill = document.createElement('span');
  pill.className = `status-pill ${state}`;
  const dot = document.createElement('span');
  dot.className = 'dot';
  pill.appendChild(dot);

  const labelSpan = document.createElement('span');
  labelSpan.className = 'status-label';
  labelSpan.textContent = label;
  pill.appendChild(labelSpan);

  const detailSpan = document.createElement('span');
  detailSpan.className = 'status-detail';
  detailSpan.textContent = detail;
  pill.appendChild(detailSpan);

  return pill;
}

export async function hydrateStatus(statusBar) {
  if (!statusBar) {
    return;
  }
  statusBar.innerHTML = '';

  const apiPill = renderStatusPill('API', 'warn', 'checking…');
  const capsPill = renderStatusPill('Capabilities', 'warn', 'checking…');
  statusBar.append(apiPill, capsPill);

  try {
    const [health, caps] = await Promise.all([
      API.health().catch((err) => ({ error: err.message || String(err) })),
      API.caps().catch((err) => ({ error: err.message || String(err) }))
    ]);

    const apiOk = health && !health.error;
    apiPill.className = `status-pill ${apiOk ? 'ok' : 'fail'}`;
    apiPill.querySelector('.status-detail').textContent = apiOk ? 'online' : 'offline';

    const capsReady = caps && !caps.error && Array.isArray(caps.mailboxes?.list);
    capsPill.className = `status-pill ${capsReady ? 'ok' : 'warn'}`;
    capsPill.querySelector('.status-detail').textContent = capsReady ? 'loaded' : 'pending';
  } catch (err) {
    statusBar.innerHTML = '';
    const fallback = renderStatusPill('Status', 'warn', 'unavailable');
    statusBar.appendChild(fallback);
  }
}

export function showResult(outputEl, data) {
  if (!outputEl) {
    return;
  }
  if (data === undefined || data === null) {
    outputEl.textContent = 'No response.';
    return;
  }
  if (typeof data === 'string') {
    outputEl.textContent = data;
    return;
  }
  try {
    outputEl.textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    outputEl.textContent = String(data);
  }
}

export function showError(outputEl, error) {
  const message = error && error.message ? error.message : String(error || 'Unknown error');
  showResult(outputEl, `Error: ${message}`);
}
