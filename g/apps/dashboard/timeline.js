const STATUS_THEME = {
  queued: { pill: 'border-amber-400/60 text-amber-200', dot: 'bg-amber-400' },
  running: { pill: 'border-sky-400/60 text-sky-200', dot: 'bg-sky-400' },
  success: { pill: 'border-emerald-400/70 text-emerald-200', dot: 'bg-emerald-400' },
  failed: { pill: 'border-rose-400/60 text-rose-200', dot: 'bg-rose-400' },
  dropped: { pill: 'border-slate-500/60 text-slate-200', dot: 'bg-slate-400' },
  timeout: { pill: 'border-orange-400/60 text-orange-200', dot: 'bg-orange-400' },
  unknown: { pill: 'border-slate-500/60 text-slate-200', dot: 'bg-slate-400' },
};

function formatStatus(value) {
  if (!value) return 'unknown';
  const text = String(value);
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function formatTimestamp(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString(undefined, {
    hour12: false,
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function escapeHtml(input) {
  return String(input ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatSegments(segments) {
  if (!Array.isArray(segments) || !segments.length) {
    return '';
  }
  const markup = segments
    .map((segment) => {
      const value = segment.value || '';
      const display = value.includes('T') ? formatTimestamp(value) : value;
      return `<span class="inline-flex items-center gap-2 rounded-full border border-slate-700/80 bg-slate-950/40 px-3 py-1 text-xs text-slate-200">
        <span class="text-slate-500">${escapeHtml(segment.label)}</span>
        <span class="font-semibold text-white">${escapeHtml(display)}</span>
      </span>`;
    })
    .join('<span class="text-slate-600 text-xs">→</span>');
  return `<div class="mt-5 flex flex-wrap items-center gap-3">${markup}</div>`;
}

function formatLogTail(lines) {
  if (!Array.isArray(lines) || !lines.length) {
    return '<p class="text-sm text-slate-500">No log output captured for this work order.</p>';
  }
  const text = lines.join('\n');
  return `<pre class="whitespace-pre-wrap text-xs leading-relaxed text-slate-100">${escapeHtml(text)}</pre>`;
}

function formatSources(sources) {
  if (!Array.isArray(sources) || !sources.length) {
    return '';
  }
  const chips = sources
    .map((source) => `<span class="rounded-full border border-slate-700/80 bg-slate-900/60 px-2.5 py-0.5 text-xs uppercase tracking-wide text-slate-400">${escapeHtml(source)}</span>`)
    .join('');
  return `<div class="mt-4 flex flex-wrap gap-2">${chips}</div>`;
}

function formatTags(tags) {
  if (!Array.isArray(tags) || !tags.length) {
    return '';
  }
  const chips = tags
    .map((tag) => `<span class="rounded-full bg-violet-500/10 px-3 py-1 text-xs font-medium text-violet-200">${escapeHtml(tag)}</span>`)
    .join('');
  return `<div class="mt-4 flex flex-wrap gap-2">${chips}</div>`;
}

function formatLessons(lessons) {
  if (!Array.isArray(lessons) || !lessons.length) {
    return '';
  }
  const items = lessons
    .slice(0, 4)
    .map(
      (lesson) => `<li class="rounded-2xl border border-violet-500/30 bg-violet-500/5 p-3">
        <p class="text-xs uppercase tracking-widest text-violet-300">${escapeHtml(lesson.type)}</p>
        <p class="font-semibold text-sm text-violet-50">${escapeHtml(lesson.title)}</p>
        ${lesson.summary ? `<p class="mt-1 text-sm text-violet-200/80">${escapeHtml(lesson.summary)}</p>` : ''}
      </li>`
    )
    .join('');
  return `<div class="mt-4 space-y-2">
    <p class="text-sm font-semibold text-violet-200">MLS context</p>
    <ul class="space-y-2">${items}</ul>
  </div>`;
}

function renderEntry(entry) {
  const theme = STATUS_THEME[entry.status] || STATUS_THEME.unknown;
  const summary = entry.summary || 'Work order';
  const started = formatTimestamp(entry.started_at);
  const finished = formatTimestamp(entry.finished_at);
  const duration = entry.duration_seconds ? `${entry.duration_seconds}s` : '—';
  const logBlock = formatLogTail(entry.log_tail);
  const sources = formatSources(entry.sources);
  const tags = formatTags(entry.mls_tags);
  const lessons = formatLessons(entry.mls_lessons);
  const segments = formatSegments(entry.timeline_segments);
  const lastUpdate = finished || started || '—';

  return `<article class="rounded-3xl border border-slate-800 bg-slate-900/70 p-6 shadow-xl shadow-black/30" data-wo-id="${escapeHtml(entry.id)}">
    <div class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <p class="text-xs font-mono uppercase tracking-[0.3em] text-slate-500">Work Order</p>
        <h3 class="text-2xl font-semibold text-white">${escapeHtml(entry.id)}</h3>
      </div>
      <div class="flex flex-col items-end gap-2 text-right">
        <span class="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-sm ${theme.pill}">
          <span class="h-2 w-2 rounded-full ${theme.dot}"></span>
          ${escapeHtml(formatStatus(entry.status))}
        </span>
        <p class="text-sm text-slate-400">${escapeHtml(entry.agent || 'unknown')} • ${escapeHtml(entry.type || 'operation')}</p>
      </div>
    </div>
    <p class="mt-4 text-base text-slate-200">${escapeHtml(summary)}</p>
    <dl class="mt-4 grid gap-4 text-sm text-slate-300 sm:grid-cols-3">
      <div>
        <dt class="text-slate-500">Started</dt>
        <dd class="font-medium text-white">${escapeHtml(started || '—')}</dd>
      </div>
      <div>
        <dt class="text-slate-500">Finished</dt>
        <dd class="font-medium text-white">${escapeHtml(finished || '—')}</dd>
      </div>
      <div>
        <dt class="text-slate-500">Duration</dt>
        <dd class="font-medium text-white">${escapeHtml(duration)}</dd>
      </div>
    </dl>
    ${segments}
    ${sources}
    ${tags}
    ${lessons}
    <details class="mt-6 rounded-2xl border border-slate-800 bg-slate-950/40 p-4">
      <summary class="cursor-pointer text-sm font-semibold text-slate-200">Latest log tail</summary>
      <div class="mt-3 max-h-72 overflow-y-auto">${logBlock}</div>
    </details>
    <div class="mt-6 flex flex-wrap items-center gap-3 text-sm text-slate-400">
      <a class="inline-flex items-center gap-2 rounded-full border border-slate-700 px-4 py-1.5 text-slate-200 transition hover:border-blue-400 hover:text-white" href="index.html#${encodeURIComponent(entry.id)}">
        View in dashboard
      </a>
      <span>Last update: ${escapeHtml(lastUpdate)}</span>
    </div>
  </article>`;
}

function renderTimeline(entries) {
  const container = document.getElementById('timeline-root');
  const loading = document.getElementById('timeline-loading');
  const errorBox = document.getElementById('timeline-error');
  if (!container) return;
  if (!Array.isArray(entries) || !entries.length) {
    loading?.classList.add('hidden');
    errorBox?.classList.add('hidden');
    container.innerHTML = `<div class="rounded-3xl border border-slate-800 bg-slate-950/40 p-8 text-center text-slate-400">No work order history is available yet.</div>`;
    return;
  }
  errorBox?.classList.add('hidden');
  container.innerHTML = entries.map((entry) => renderEntry(entry)).join('');
}

function showError(message) {
  const errorBox = document.getElementById('timeline-error');
  const loading = document.getElementById('timeline-loading');
  if (loading) {
    loading.classList.add('hidden');
  }
  if (errorBox) {
    errorBox.textContent = message;
    errorBox.classList.remove('hidden');
  }
}

function buildQuery() {
  const params = new URLSearchParams();
  const status = document.getElementById('filter-status')?.value;
  if (status) params.set('status', status);
  const agent = document.getElementById('filter-agent')?.value.trim();
  if (agent) params.set('agent', agent);
  const type = document.getElementById('filter-type')?.value.trim();
  if (type) params.set('type', type);
  const tail = document.getElementById('filter-tail')?.value || '50';
  params.set('tail', tail);
  params.set('limit', '200');
  return params.toString();
}

function requestTimeline() {
  const loader = document.getElementById('history-loader');
  const loading = document.getElementById('timeline-loading');
  const errorBox = document.getElementById('timeline-error');
  if (!loader || !window.htmx) {
    showError('Timeline loader unavailable.');
    return;
  }
  const query = buildQuery();
  loader.setAttribute('hx-get', `/api/wos/history?${query}`);
  errorBox?.classList.add('hidden');
  if (loading) {
    loading.classList.remove('hidden');
  }
  window.htmx.trigger(document.body, 'timelineRefresh');
}

window.addEventListener('DOMContentLoaded', () => {
  if (!window.htmx) {
    console.warn('HTMX not detected; timeline cannot be hydrated.');
    return;
  }
  const loader = document.getElementById('history-loader');
  const loading = document.getElementById('timeline-loading');

  document.body.addEventListener('htmx:afterRequest', (event) => {
    if (event.target !== loader) return;
    loading?.classList.add('hidden');
    try {
      const payload = JSON.parse(event.detail.xhr.responseText || '[]');
      renderTimeline(payload);
    } catch (error) {
      console.error('Timeline parse error', error);
      showError('Unable to parse /api/wos/history response.');
    }
  });

  document.body.addEventListener('htmx:responseError', (event) => {
    if (event.target !== loader) return;
    const status = event.detail.xhr?.status || 'error';
    showError(`Timeline request failed (${status}).`);
  });

  document.getElementById('timeline-filters')?.addEventListener('change', () => requestTimeline());
  document.querySelectorAll('[data-action="refresh-timeline"]').forEach((button) => {
    button.addEventListener('click', () => requestTimeline());
  });
});
