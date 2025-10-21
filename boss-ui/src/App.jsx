import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import ErrorBoundary from './ErrorBoundary';
import {
  API_BASE,
  decideApproval,
  fetchMemoryRecall,
  fetchRun,
  fetchRuns,
  fetchTelemetrySummary,
  requestApproval,
  subscribeEvents,
  updateRun
} from './api.js';

const STATUS_META = {
  success: { label: 'Success', tone: 'success' },
  failed: { label: 'Failed', tone: 'danger' },
  running: { label: 'Running', tone: 'info' },
  queued: { label: 'Queued', tone: 'pending' },
  cancelled: { label: 'Cancelled', tone: 'neutral' }
};

function StatusBadge({ status }) {
  const meta = STATUS_META[status] || { label: status ?? 'Unknown', tone: 'neutral' };
  return <span className={`pill pill-${meta.tone}`}>{meta.label}</span>;
}

function RiskBadge({ value }) {
  const score = Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0;
  let tone = 'low';
  if (score >= 0.67) tone = 'high';
  else if (score >= 0.34) tone = 'medium';
  const label = score >= 0.67 ? 'High' : score >= 0.34 ? 'Medium' : 'Low';
  return (
    <span className={`pill pill-risk-${tone}`}>
      {label}
      <span className="pill-detail">{Math.round(score * 100)}%</span>
    </span>
  );
}

function formatDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString();
}

function formatDuration(ms) {
  const duration = Number(ms) || 0;
  if (!duration) return '—';
  if (duration < 1000) return `${duration} ms`;
  const seconds = duration / 1000;
  if (seconds < 60) return `${seconds.toFixed(1)} s`;
  const minutes = Math.floor(seconds / 60);
  const remaining = Math.round(seconds % 60);
  return `${minutes}m ${remaining}s`;
}

function upsertRun(list, run) {
  if (!run?.id) return list;
  const idx = list.findIndex((item) => item.id === run.id);
  if (idx === -1) {
    const next = [run, ...list];
    next.sort((a, b) => {
      const left = new Date(a.createdAt || 0).getTime();
      const right = new Date(b.createdAt || 0).getTime();
      return right - left;
    });
    return next.slice(0, 120);
  }
  const next = list.slice();
  next[idx] = { ...next[idx], ...run };
  return next;
}

function RunsSidebar({
  runs,
  filteredRuns,
  runQuery,
  setRunQuery,
  loading,
  selectedId,
  onSelect,
  telemetry
}) {
  const successRate = useMemo(() => {
    if (!telemetry?.runs?.total) return null;
    return Math.round((telemetry.runs.success / telemetry.runs.total) * 100);
  }, [telemetry]);

  return (
    <aside className="console-sidebar">
      <header className="sidebar-header">
        <div>
          <p className="sidebar-overline">Unified Console</p>
          <h1>Task Orchestration</h1>
        </div>
        <p className="sidebar-api">{API_BASE}</p>
      </header>

      <div className="sidebar-section">
        <label htmlFor="run-search">Search runs</label>
        <input
          id="run-search"
          type="search"
          placeholder="Title, ID, or agent"
          value={runQuery}
          onChange={(event) => setRunQuery(event.target.value)}
        />
      </div>

      <div className="sidebar-section sidebar-runs">
        <div className="sidebar-section-heading">
          <h2>Recent runs</h2>
          {loading ? <span className="status-text">Loading…</span> : <span className="status-text">{runs.length} total</span>}
        </div>
        <div className="run-list" role="list">
          {filteredRuns.length === 0 && !loading ? (
            <p className="empty-state">No runs match the current filters.</p>
          ) : (
            filteredRuns.map((run) => (
              <button
                key={run.id}
                type="button"
                className={`run-item${selectedId === run.id ? ' active' : ''}`}
                onClick={() => onSelect(run.id)}
              >
                <div className="run-item-title">{run.title || run.id}</div>
                <div className="run-item-meta">
                  <StatusBadge status={run.status} />
                  <RiskBadge value={run.riskScore} />
                </div>
                <div className="run-item-foot">
                  <span>Agent · {run.agent || '—'}</span>
                  <span>{formatDate(run.createdAt)}</span>
                </div>
              </button>
            ))
          )}
        </div>
      </div>

      <div className="sidebar-section sidebar-telemetry">
        <div className="sidebar-section-heading">
          <h2>Rolling 14d health</h2>
          {telemetry ? (
            <span className="status-text success">{successRate ?? '—'}% success</span>
          ) : (
            <span className="status-text">Loading…</span>
          )}
        </div>
        {telemetry ? (
          <dl className="telemetry-grid">
            <div>
              <dt>Total runs</dt>
              <dd>{telemetry.runs.total}</dd>
            </div>
            <div>
              <dt>Failed</dt>
              <dd>{telemetry.runs.failed}</dd>
            </div>
            <div>
              <dt>Cancelled</dt>
              <dd>{telemetry.runs.cancelled}</dd>
            </div>
            <div>
              <dt>p95 latency</dt>
              <dd>{telemetry.service?.[0]?.latencyP95 ? `${telemetry.service[0].latencyP95.toFixed(1)}s` : '—'}</dd>
            </div>
            <div>
              <dt>Tokens saved</dt>
              <dd>{telemetry.service?.[0]?.tokensSaved ?? '—'}</dd>
            </div>
            <div>
              <dt>Tokens spent</dt>
              <dd>{telemetry.service?.[0]?.tokensSpent ?? '—'}</dd>
            </div>
          </dl>
        ) : (
          <p className="empty-state">Telemetry will appear once data is available.</p>
        )}
      </div>
    </aside>
  );
}

function MemoryPanel({ run, query, setQuery, results, loading, onRefresh }) {
  const hits = run?.memoryHits || [];
  return (
    <section className="panel">
      <header className="panel-header">
        <div>
          <h3>Memory Reference</h3>
          <p>{hits.length} memories used in this run</p>
        </div>
        <button type="button" onClick={onRefresh} className="ghost-btn">Refresh</button>
      </header>

      <div className="memory-used" role="list">
        {hits.length === 0 ? (
          <p className="empty-state">Run has not called memory yet.</p>
        ) : (
          hits.map((hit) => (
            <article key={hit.id} className="memory-hit" role="listitem">
              <h4>{hit.title}</h4>
              <p className="memory-meta">
                <span>Score {hit.score?.toFixed(2)}</span>
                <span>{hit.kind}</span>
              </p>
              <p>{hit.snippet}</p>
            </article>
          ))
        )}
      </div>

      <form className="memory-search" onSubmit={(event) => event.preventDefault()}>
        <label htmlFor="memory-search-input">Search knowledge base</label>
        <input
          id="memory-search-input"
          type="search"
          placeholder="Vector memory, reports, telemetry…"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </form>

      <div className="memory-results" role="list">
        {query ? (
          loading ? (
            <p className="status-text">Searching…</p>
          ) : results.length === 0 ? (
            <p className="empty-state">No matches for “{query}”.</p>
          ) : (
            results.map((item) => (
              <article key={item.id} className="memory-hit" role="listitem">
                <h4>{item.title}</h4>
                <p className="memory-meta">
                  <span>{item.kind}</span>
                  <span>Importance {item.importance}</span>
                </p>
                <p>{item.snippet}</p>
              </article>
            ))
          )
        ) : (
          <p className="empty-state">Start typing to search across knowledge.</p>
        )}
      </div>
    </section>
  );
}

function ApprovalsPanel({ run, onRequest, onDecision }) {
  const approvals = run?.approvals || [];
  const pending = approvals.filter((approval) => approval.status === 'pending');
  return (
    <section className="panel">
      <header className="panel-header">
        <div>
          <h3>Approvals</h3>
          <p>{pending.length} pending</p>
        </div>
        <button type="button" className="primary-btn" onClick={onRequest}>
          Request approval
        </button>
      </header>
      <div className="approvals-list" role="list">
        {approvals.length === 0 ? (
          <p className="empty-state">No approvals logged for this run yet.</p>
        ) : (
          approvals.map((approval) => (
            <article key={approval.id} className={`approval-card status-${approval.status}`} role="listitem">
              <header>
                <strong>{approval.status === 'pending' ? 'Pending review' : approval.status}</strong>
                <span>Requested by {approval.requestedBy || 'system'}</span>
              </header>
              <p>{approval.reason || 'No rationale provided.'}</p>
              <footer>
                <span>{formatDate(approval.requestedAt)}</span>
                {approval.status === 'pending' ? (
                  <div className="approval-actions">
                    <button type="button" className="ghost-btn" onClick={() => onDecision(approval, 'denied')}>
                      Deny
                    </button>
                    <button type="button" className="primary-btn" onClick={() => onDecision(approval, 'approved')}>
                      Approve
                    </button>
                  </div>
                ) : (
                  <span>
                    {approval.decidedBy ? `By ${approval.decidedBy}` : 'Auto'} · {formatDate(approval.decidedAt)}
                  </span>
                )}
              </footer>
            </article>
          ))
        )}
      </div>
    </section>
  );
}

function MetricsPanel({ run }) {
  return (
    <section className="panel">
      <header className="panel-header">
        <div>
          <h3>Run Metrics</h3>
          <p>Execution cost &amp; timing</p>
        </div>
      </header>
      <dl className="metrics-grid">
        <div>
          <dt>Status</dt>
          <dd>
            <StatusBadge status={run?.status} />
          </dd>
        </div>
        <div>
          <dt>Risk score</dt>
          <dd>
            <RiskBadge value={run?.riskScore} />
          </dd>
        </div>
        <div>
          <dt>Duration</dt>
          <dd>{formatDuration(run?.durationMs)}</dd>
        </div>
        <div>
          <dt>Tokens used</dt>
          <dd>{run?.tokensUsed ?? '—'}</dd>
        </div>
        <div>
          <dt>Tokens saved</dt>
          <dd>{run?.tokensSaved ?? '—'}</dd>
        </div>
        <div>
          <dt>Started</dt>
          <dd>{formatDate(run?.startedAt)}</dd>
        </div>
        <div>
          <dt>Completed</dt>
          <dd>{formatDate(run?.completedAt)}</dd>
        </div>
      </dl>
    </section>
  );
}

function TimelinePanel({ run, onRetry }) {
  const steps = run?.steps || [];
  return (
    <section className="panel">
      <header className="panel-header">
        <div>
          <h3>Run timeline</h3>
          <p>{steps.length} steps captured</p>
        </div>
        <button type="button" className="ghost-btn" onClick={onRetry}>
          Retry run
        </button>
      </header>
      <div className="timeline" role="list">
        {steps.length === 0 ? (
          <p className="empty-state">Run has not recorded any steps yet.</p>
        ) : (
          steps.map((step) => (
            <article key={step.id} className={`timeline-step status-${step.status}`} role="listitem">
              <header>
                <strong>{step.title}</strong>
                <StatusBadge status={step.status} />
              </header>
              <p className="timeline-meta">
                <span>{formatDate(step.startedAt)}</span>
                <span>{formatDuration(step.startedAt && step.completedAt ? new Date(step.completedAt) - new Date(step.startedAt) : 0)}</span>
              </p>
              {step.log ? <pre>{step.log}</pre> : null}
              {Array.isArray(step.artifacts) && step.artifacts.length > 0 ? (
                <ul className="timeline-artifacts">
                  {step.artifacts.map((artifact) => (
                    <li key={artifact.name || artifact.url}>{artifact.label || artifact.name}</li>
                  ))}
                </ul>
              ) : null}
            </article>
          ))
        )}
      </div>
    </section>
  );
}

function LogsPanel({ run, containerRef }) {
  const logs = run?.logs || [];
  return (
    <section className="panel logs-panel">
      <header className="panel-header">
        <div>
          <h3>Live logs</h3>
          <p>{logs.length} entries</p>
        </div>
      </header>
      <div ref={containerRef} className="logs-body">
        {logs.length === 0 ? (
          <p className="empty-state">No logs captured yet.</p>
        ) : (
          logs.map((entry) => (
            <article key={entry.id || `${entry.timestamp}-${entry.message}`} className={`log-entry level-${entry.level}`}>
              <header>
                <span>{formatDate(entry.timestamp)}</span>
                <span className="log-level">{entry.level?.toUpperCase()}</span>
              </header>
              <pre>{entry.message}</pre>
            </article>
          ))
        )}
      </div>
    </section>
  );
}

function ApprovalsModal({ modal, onClose, onSubmit, loading }) {
  const [reason, setReason] = useState('');
  const [riskScore, setRiskScore] = useState(modal?.riskScore ?? 0.5);
  const [note, setNote] = useState('');

  useEffect(() => {
    setReason(modal?.reason ?? '');
    setRiskScore(modal?.riskScore ?? 0.5);
    setNote('');
  }, [modal]);

  if (!modal) return null;
  const isDecision = modal.type === 'decision';
  const actionLabel = isDecision ? (modal.action === 'approved' ? 'Approve run' : 'Deny run') : 'Submit request';

  const handleSubmit = (event) => {
    event.preventDefault();
    if (isDecision) {
      onSubmit({
        type: 'decision',
        approval: modal.approval,
        action: modal.action,
        note
      });
    } else {
      onSubmit({ type: 'request', reason, riskScore });
    }
  };

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal">
        <header>
          <h2>{isDecision ? actionLabel : 'Request approval'}</h2>
          <button type="button" className="ghost-btn" onClick={onClose}>
            Close
          </button>
        </header>
        <form onSubmit={handleSubmit} className="modal-body">
          {isDecision ? (
            <>
              <p>Confirm you want to {modal.action} the selected approval request.</p>
              <label htmlFor="decision-note">Decision note</label>
              <textarea
                id="decision-note"
                placeholder="Optional context for the audit log"
                value={note}
                onChange={(event) => setNote(event.target.value)}
              />
            </>
          ) : (
            <>
              <label htmlFor="approval-reason">Why is this approval required?</label>
              <textarea
                id="approval-reason"
                placeholder="Summarize the risky action and mitigation."
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                required
              />
              <label htmlFor="approval-risk">Risk score</label>
              <input
                id="approval-risk"
                type="number"
                min="0"
                max="1"
                step="0.05"
                value={riskScore}
                onChange={(event) => setRiskScore(Number(event.target.value))}
              />
            </>
          )}
          <footer className="modal-footer">
            <button type="button" className="ghost-btn" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="primary-btn" disabled={loading}>
              {loading ? 'Processing…' : actionLabel}
            </button>
          </footer>
        </form>
      </div>
    </div>
  );
}

function AppShell() {
  const [runs, setRuns] = useState([]);
  const [runQuery, setRunQuery] = useState('');
  const [runsLoading, setRunsLoading] = useState(true);
  const [selectedRunId, setSelectedRunId] = useState(null);
  const [selectedRun, setSelectedRun] = useState(null);
  const [runLoading, setRunLoading] = useState(false);
  const [telemetry, setTelemetry] = useState(null);
  const [memoryQuery, setMemoryQuery] = useState('');
  const [memoryLoading, setMemoryLoading] = useState(false);
  const [memoryResults, setMemoryResults] = useState([]);
  const [modal, setModal] = useState(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [error, setError] = useState(null);
  const logContainerRef = useRef(null);

  const filteredRuns = useMemo(() => {
    if (!runQuery) {
      return runs;
    }
    const search = runQuery.toLowerCase();
    return runs.filter((run) => {
      return (
        run.title?.toLowerCase().includes(search) ||
        run.id?.toLowerCase().includes(search) ||
        run.agent?.toLowerCase().includes(search)
      );
    });
  }, [runs, runQuery]);

  const loadRuns = useCallback(async () => {
    try {
      setRunsLoading(true);
      const data = await fetchRuns({ limit: 60 });
      setRuns(data);
      setSelectedRunId((current) => (current ? current : data[0]?.id ?? null));
    } catch (err) {
      console.error('Failed to load runs', err);
      setError('Failed to load runs.');
    } finally {
      setRunsLoading(false);
    }
  }, []);

  const loadRunDetail = useCallback(async (runId) => {
    if (!runId) {
      setSelectedRun(null);
      return;
    }
    try {
      setRunLoading(true);
      const run = await fetchRun(runId, { logs: 300 });
      setSelectedRun(run);
    } catch (err) {
      console.error('Failed to load run detail', err);
      setError('Failed to load run detail.');
    } finally {
      setRunLoading(false);
    }
  }, []);

  const loadTelemetry = useCallback(async () => {
    try {
      const summary = await fetchTelemetrySummary({ window: 14 });
      setTelemetry(summary);
    } catch (err) {
      console.warn('Telemetry unavailable', err);
    }
  }, []);

  useEffect(() => {
    loadRuns();
    loadTelemetry();
  }, [loadRuns, loadTelemetry]);

  useEffect(() => {
    loadRunDetail(selectedRunId);
  }, [selectedRunId, loadRunDetail]);

  useEffect(() => {
    if (!memoryQuery) {
      setMemoryResults([]);
      return undefined;
    }
    setMemoryLoading(true);
    const handle = setTimeout(async () => {
      try {
        const results = await fetchMemoryRecall({ search: memoryQuery, limit: 10 });
        setMemoryResults(results);
      } catch (err) {
        console.error('Memory search failed', err);
      } finally {
        setMemoryLoading(false);
      }
    }, 350);
    return () => clearTimeout(handle);
  }, [memoryQuery]);

  useEffect(() => {
    if (!selectedRun?.logs || !logContainerRef.current) {
      return;
    }
    logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight;
  }, [selectedRun?.logs?.length]);

  const handleEvents = useCallback((event) => {
    if (!event || !event.type) return;

    if (event.type === 'run.created' && event.run) {
      setRuns((prev) => upsertRun(prev, event.run));
      return;
    }

    if (event.type === 'run.updated' && event.run) {
      setRuns((prev) => upsertRun(prev, event.run));
      setSelectedRun((prev) => (prev?.id === event.run.id ? { ...prev, ...event.run } : prev));
      return;
    }

    if (event.type === 'run.steps') {
      setSelectedRun((prev) => (prev?.id === event.runId ? { ...prev, steps: event.steps } : prev));
      return;
    }

    if (event.type === 'run.memory') {
      setSelectedRun((prev) => (prev?.id === event.runId ? { ...prev, memoryHits: event.memoryHits } : prev));
      return;
    }

    if (event.type === 'run.logs') {
      setSelectedRun((prev) => {
        if (!prev || prev.id !== event.runId) return prev;
        const nextLogs = [...(prev.logs || []), ...(event.entries || [])];
        const limited = nextLogs.slice(-400);
        return { ...prev, logs: limited };
      });
      return;
    }

    if (event.type === 'approval.created') {
      setSelectedRun((prev) => {
        if (!prev || prev.id !== event.runId) return prev;
        const approvals = prev.approvals || [];
        const exists = approvals.some((approval) => approval.id === event.approval.id);
        return exists ? prev : { ...prev, approvals: [event.approval, ...approvals] };
      });
      return;
    }

    if (event.type === 'approval.updated') {
      setSelectedRun((prev) => {
        if (!prev) return prev;
        const approvals = prev.approvals || [];
        const idx = approvals.findIndex((approval) => approval.id === event.approval.id);
        if (idx === -1) return prev;
        const next = approvals.slice();
        next[idx] = event.approval;
        return { ...prev, approvals: next };
      });
    }
  }, []);

  useEffect(() => {
    const unsubscribe = subscribeEvents(handleEvents);
    return unsubscribe;
  }, [handleEvents]);

  const handleDecision = useCallback((approval, action) => {
    setModal({ type: 'decision', approval, action });
  }, []);

  const handleModalSubmit = useCallback(async (payload) => {
    if (!selectedRun) return;
    setModalLoading(true);
    try {
      if (payload.type === 'decision' && payload.approval) {
        await decideApproval(payload.approval.id, {
          status: payload.action,
          decisionNote: payload.note,
          decidedBy: 'operator'
        });
      } else if (payload.type === 'request') {
        await requestApproval(selectedRun.id, {
          reason: payload.reason,
          riskScore: payload.riskScore,
          requestedBy: 'operator'
        });
      }
      await loadRunDetail(selectedRun.id);
    } catch (err) {
      console.error('Approval action failed', err);
      setError('Approval action failed.');
    } finally {
      setModalLoading(false);
      setModal(null);
    }
  }, [loadRunDetail, selectedRun]);

  const handleRetry = useCallback(async () => {
    if (!selectedRun?.id) return;
    try {
      await updateRun(selectedRun.id, { status: 'queued', startedAt: null, completedAt: null });
    } catch (err) {
      console.error('Failed to retry run', err);
      setError('Unable to queue retry.');
    }
  }, [selectedRun]);

  const refreshMemory = useCallback(() => {
    if (selectedRun?.id) {
      loadRunDetail(selectedRun.id);
    }
  }, [loadRunDetail, selectedRun]);

  return (
    <div className="console-shell">
      <RunsSidebar
        runs={runs}
        filteredRuns={filteredRuns}
        runQuery={runQuery}
        setRunQuery={setRunQuery}
        loading={runsLoading}
        selectedId={selectedRunId}
        onSelect={setSelectedRunId}
        telemetry={telemetry}
      />
      <main className="console-main">
        {error ? <div className="error-banner">{error}</div> : null}
        {!selectedRun ? (
          <div className="empty-state large">Select a run to inspect details.</div>
        ) : (
          <>
            <header className="run-header">
              <div>
                <p className="run-id">Run · {selectedRun.id}</p>
                <h2>{selectedRun.title || 'Untitled run'}</h2>
                {selectedRun.summary ? <p className="run-summary">{selectedRun.summary}</p> : null}
              </div>
              <div className="run-header-actions">
                <StatusBadge status={selectedRun.status} />
                <RiskBadge value={selectedRun.riskScore} />
                <button type="button" className="ghost-btn" onClick={() => loadRunDetail(selectedRun.id)} disabled={runLoading}>
                  {runLoading ? 'Refreshing…' : 'Refresh'}
                </button>
              </div>
            </header>

            <div className="console-panels">
              <div className="primary-column">
                <TimelinePanel run={selectedRun} onRetry={handleRetry} />
                <LogsPanel run={selectedRun} containerRef={logContainerRef} />
              </div>
              <div className="secondary-column">
                <MemoryPanel
                  run={selectedRun}
                  query={memoryQuery}
                  setQuery={setMemoryQuery}
                  results={memoryResults}
                  loading={memoryLoading}
                  onRefresh={refreshMemory}
                />
                <ApprovalsPanel run={selectedRun} onRequest={() => setModal({ type: 'request', riskScore: selectedRun.riskScore })} onDecision={handleDecision} />
                <MetricsPanel run={selectedRun} />
              </div>
            </div>
          </>
        )}
      </main>
      <ApprovalsModal modal={modal} onClose={() => setModal(null)} onSubmit={handleModalSubmit} loading={modalLoading} />
    </div>
  );
}

export default function App() {
  return (
    <ErrorBoundary>
      <AppShell />
    </ErrorBoundary>
  );
}
