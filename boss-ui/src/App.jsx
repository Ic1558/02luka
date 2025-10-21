import { useEffect, useMemo, useState, useCallback, memo, useRef } from 'react';
import { marked } from 'marked';
import ErrorBoundary from './ErrorBoundary';

const resolveApiBase = () => {
  const envBase = import.meta?.env?.VITE_API_BASE;
  if (envBase && typeof envBase === 'string' && envBase.trim()) {
    return envBase.trim().replace(/\/+$/, '');
  }

  if (typeof window !== 'undefined') {
    if (window.API_BASE && typeof window.API_BASE === 'string' && window.API_BASE.trim()) {
      return window.API_BASE.trim().replace(/\/+$/, '');
    }

    const { protocol = 'http:', hostname = '127.0.0.1' } = window.location || {};
    return `${protocol}//${hostname}:4000`;
  }

  return 'http://127.0.0.1:4000';
};

const API_BASE = resolveApiBase();

const folders = [
  { key: 'inbox', label: 'Inbox' },
  { key: 'sent', label: 'Sent' },
  { key: 'deliverables', label: 'Deliverables' },
  { key: 'dropbox', label: 'Dropbox' },
  { key: 'drafts', label: 'Drafts' },
  { key: 'documents', label: 'Documents' }
];

const defaultMarkdown = '# Boss Workspace\n\nSelect a file to preview its contents or review system status on the left.';

// Cache for API responses with size limits
const apiCache = new Map();
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes
const MAX_CACHE_SIZE = 50; // Maximum cached responses
const MAX_CACHE_MEMORY = 10 * 1024 * 1024; // 10MB max cache memory

const textEncoder = typeof TextEncoder !== 'undefined' ? new TextEncoder() : null;
let cacheMemoryUsage = 0;

const estimateEntrySize = (text) => {
  if (!text) return 0;
  const stringified = typeof text === 'string' ? text : JSON.stringify(text);
  if (textEncoder) {
    return textEncoder.encode(stringified).length;
  }
  return stringified.length;
};

const normalizeFiles = (items) => {
  if (!Array.isArray(items)) {
    return [];
  }

  const seen = new Set();
  const normalized = [];

  for (const item of items) {
    if (!item) continue;
    const entry = typeof item === 'string' ? { name: item } : item;
    if (!entry?.name || seen.has(entry.name)) continue;
    seen.add(entry.name);
    normalized.push(entry);
  }

  return normalized;
};

const parseLastUpdated = (payload) => {
  if (!payload || typeof payload !== 'object') {
    return null;
  }

  const candidates = [
    payload.lastUpdated,
    payload.updatedAt,
    payload.timestamp,
    payload.lastRefreshed,
    payload.meta?.lastUpdated,
    payload.meta?.updatedAt
  ];

  for (const candidate of candidates) {
    if (!candidate) continue;
    const parsed = new Date(candidate);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }

  return null;
};

const diffFileLists = (previous = [], next = []) => {
  const previousNames = new Set(previous.map((item) => item.name));
  const nextNames = new Set(next.map((item) => item.name));

  const added = [];
  const removed = [];

  for (const name of nextNames) {
    if (!previousNames.has(name)) {
      added.push(name);
    }
  }

  for (const name of previousNames) {
    if (!nextNames.has(name)) {
      removed.push(name);
    }
  }

  added.sort((a, b) => a.localeCompare(b));
  removed.sort((a, b) => a.localeCompare(b));

  return { added, removed };
};

const normalizeConnectorEntries = (connectors) => {
  if (!connectors || typeof connectors !== 'object') {
    return [];
  }

  const entries = [];

  const describe = (id, label, data) => {
    if (!data || typeof data !== 'object') {
      return;
    }

    const ready = typeof data.ready === 'boolean' ? data.ready : false;
    const error = typeof data.error === 'string' ? data.error : '';
    let detail = '';
    if (error) {
      detail = error;
    } else if (typeof data.documents === 'number') {
      detail = `${data.documents} document${data.documents === 1 ? '' : 's'}`;
    } else if (Array.isArray(data.datasets)) {
      const count = data.datasets.length;
      detail = `${count} dataset${count === 1 ? '' : 's'}`;
    } else if (typeof data.script === 'string' && data.script) {
      detail = data.script.split('/').pop();
    } else if (ready) {
      detail = 'Ready';
    } else {
      detail = 'Unavailable';
    }

    entries.push({ id, label, ready, detail });
  };

  for (const [provider, value] of Object.entries(connectors)) {
    if (!value || typeof value !== 'object') {
      continue;
    }

    if (typeof value.ready === 'boolean') {
      describe(provider, provider, value);
    }

    for (const [capability, data] of Object.entries(value)) {
      if (capability === 'ready' || capability === 'error') {
        continue;
      }
      describe(`${provider}:${capability}`, `${provider} ${capability}`, data);
    }
  }

  return entries.sort((a, b) => a.label.localeCompare(b.label));
};

const formatFeatureLabel = (key) => {
  if (!key) {
    return '';
  }
  return key
    .toString()
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (match) => match.toUpperCase());
};

const createStatusState = () => ({
  data: null,
  loading: true,
  error: null,
  fetchedAt: null,
  status: 'unknown'
});

const normalizeReportStatus = (value) => {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
  if (['ok', 'ready', 'pass', 'healthy'].includes(normalized)) {
    return 'ok';
  }
  if (['warn', 'warning', 'unknown', 'pending', 'partial'].includes(normalized)) {
    return 'warn';
  }
  if (normalized) {
    return 'error';
  }
  return 'unknown';
};

const formatTimestamp = (value) => {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    return '';
  }
  return value.toLocaleTimeString();
};

const truncateText = (value, max = 140) => {
  if (typeof value !== 'string') {
    return '';
  }
  if (value.length <= max) {
    return value;
  }
  return `${value.slice(0, max - 1)}…`;
};

const removeCacheEntry = (key) => {
  const entry = apiCache.get(key);
  if (!entry) return false;
  cacheMemoryUsage = Math.max(0, cacheMemoryUsage - (entry.size || 0));
  apiCache.delete(key);
  return true;
};

const ensureCacheHasSpace = (incomingSize = 0) => {
  if (incomingSize > MAX_CACHE_MEMORY) {
    return false;
  }

  if (cacheMemoryUsage + incomingSize <= MAX_CACHE_MEMORY && apiCache.size < MAX_CACHE_SIZE) {
    return true;
  }

  const entries = Array.from(apiCache.entries());
  entries.sort((a, b) => a[1].timestamp - b[1].timestamp);

  for (const [key] of entries) {
    if (cacheMemoryUsage + incomingSize <= MAX_CACHE_MEMORY && apiCache.size < MAX_CACHE_SIZE) {
      break;
    }
    removeCacheEntry(key);
  }

  return cacheMemoryUsage + incomingSize <= MAX_CACHE_MEMORY && apiCache.size < MAX_CACHE_SIZE;
};

// Configure marked for better performance
marked.setOptions({
  breaks: true,
  gfm: true,
  sanitize: false,
  smartLists: true,
  smartypants: false
});

export default function App() {
  const [selectedFolder, setSelectedFolder] = useState(folders[0].key);
  const [files, setFiles] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null);
  const [content, setContent] = useState(defaultMarkdown);
  const [error, setError] = useState(null);
  const [loadingStates, setLoadingStates] = useState({ files: false, file: false });
  const [isRescanning, setIsRescanning] = useState(false);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [listInsights, setListInsights] = useState(null);
  const [healthState, setHealthState] = useState(createStatusState);
  const [capabilitiesState, setCapabilitiesState] = useState(createStatusState);
  const [reportsState, setReportsState] = useState(createStatusState);
  const selectedFileRef = useRef(null);
  const filesRef = useRef(files);
  const activeControllersRef = useRef({ files: null, file: null, health: null, capabilities: null, reports: null });

  useEffect(() => {
    selectedFileRef.current = selectedFile;
  }, [selectedFile]);

  useEffect(() => {
    filesRef.current = files;
  }, [files]);

  const setLoading = useCallback((key, value) => {
    setLoadingStates((previous) => {
      if (previous[key] === value) {
        return previous;
      }
      return { ...previous, [key]: value };
    });
  }, []);

  const isLoadingFiles = loadingStates.files;
  const isLoading = loadingStates.files || loadingStates.file;

  // Cache cleanup function
  const cleanupCache = useCallback(() => {
    const now = Date.now();
    let cleaned = 0;

    for (const [key, value] of Array.from(apiCache.entries())) {
      if (now - value.timestamp > CACHE_DURATION) {
        if (removeCacheEntry(key)) {
          cleaned++;
        }
      }
    }

    if (cacheMemoryUsage > MAX_CACHE_MEMORY || apiCache.size > MAX_CACHE_SIZE) {
      const entries = Array.from(apiCache.entries());
      entries.sort((a, b) => a[1].timestamp - b[1].timestamp);

      for (const [key] of entries) {
        if (cacheMemoryUsage <= MAX_CACHE_MEMORY && apiCache.size <= MAX_CACHE_SIZE) {
          break;
        }
        if (removeCacheEntry(key)) {
          cleaned++;
        }
      }
    }

    if (cleaned > 0) {
      console.log(`Frontend cache cleanup: removed ${cleaned} entries`);
    }
  }, []);

  // Cached API call function
  const fetchWithCache = useCallback(async (url, cacheKey, { signal, bypassCache = false } = {}) => {
    const now = Date.now();
    const cached = apiCache.get(cacheKey);

    if (cached && !bypassCache && (now - cached.timestamp) < CACHE_DURATION) {
      cached.timestamp = now;
      return cached.data;
    }

    if (cached) {
      removeCacheEntry(cacheKey);
    }

    const response = await fetch(url, { signal, cache: 'no-store' });
    if (!response.ok) {
      const errorText = await response.text().catch(() => '');
      let message = 'Unable to fetch data';
      if (errorText) {
        try {
          const payload = JSON.parse(errorText);
          message = payload.message || message;
        } catch {
          message = errorText;
        }
      }
      throw new Error(message);
    }

    const rawText = await response.text();
    let data;
    if (!rawText) {
      data = {};
    } else {
      try {
        data = JSON.parse(rawText);
      } catch {
        data = { content: rawText };
      }
    }

    if (signal?.aborted) {
      throw new DOMException('Aborted', 'AbortError');
    }

    cleanupCache();

    const entrySize = estimateEntrySize(rawText);
    if (ensureCacheHasSpace(entrySize)) {
      apiCache.set(cacheKey, { data, timestamp: now, size: entrySize });
      cacheMemoryUsage += entrySize;
    } else if (entrySize > 0) {
      console.warn(`Skipping cache for ${cacheKey} due to memory constraints (size: ${entrySize} bytes)`);
    }

    return data;
  }, [cleanupCache]);

  const loadHealth = useCallback(async ({ bypassCache = false } = {}) => {
    const controller = new AbortController();
    if (activeControllersRef.current.health) {
      activeControllersRef.current.health.abort();
    }
    activeControllersRef.current.health = controller;

    setHealthState((previous) => ({ ...previous, loading: true, error: null }));

    try {
      const payload = await fetchWithCache(
        `${API_BASE}/healthz`,
        'healthz',
        { signal: controller.signal, bypassCache }
      );

      if (controller.signal.aborted) {
        return;
      }

      const ok = typeof payload?.status === 'string' && payload.status.toLowerCase() === 'ok';
      setHealthState({
        data: payload,
        loading: false,
        error: null,
        fetchedAt: new Date(),
        status: ok ? 'ok' : 'error'
      });
    } catch (err) {
      if (err.name === 'AbortError') {
        return;
      }
      setHealthState({
        data: null,
        loading: false,
        error: err.message,
        fetchedAt: new Date(),
        status: 'error'
      });
    } finally {
      if (activeControllersRef.current.health === controller) {
        activeControllersRef.current.health = null;
      }
    }
  }, [fetchWithCache]);

  const loadCapabilities = useCallback(async ({ bypassCache = false } = {}) => {
    const controller = new AbortController();
    if (activeControllersRef.current.capabilities) {
      activeControllersRef.current.capabilities.abort();
    }
    activeControllersRef.current.capabilities = controller;

    setCapabilitiesState((previous) => ({ ...previous, loading: true, error: null }));

    try {
      const payload = await fetchWithCache(
        `${API_BASE}/api/capabilities`,
        'capabilities',
        { signal: controller.signal, bypassCache }
      );

      if (controller.signal.aborted) {
        return;
      }

      const hasMailboxes = Array.isArray(payload?.mailboxes?.list) && payload.mailboxes.list.length > 0;
      setCapabilitiesState({
        data: payload,
        loading: false,
        error: null,
        fetchedAt: new Date(),
        status: hasMailboxes ? 'ok' : 'warn'
      });
    } catch (err) {
      if (err.name === 'AbortError') {
        return;
      }
      setCapabilitiesState({
        data: null,
        loading: false,
        error: err.message,
        fetchedAt: new Date(),
        status: 'error'
      });
    } finally {
      if (activeControllersRef.current.capabilities === controller) {
        activeControllersRef.current.capabilities = null;
      }
    }
  }, [fetchWithCache]);

  const loadReportsSummary = useCallback(async ({ bypassCache = false } = {}) => {
    const controller = new AbortController();
    if (activeControllersRef.current.reports) {
      activeControllersRef.current.reports.abort();
    }
    activeControllersRef.current.reports = controller;

    setReportsState((previous) => ({ ...previous, loading: true, error: null }));

    try {
      const payload = await fetchWithCache(
        `${API_BASE}/api/reports/summary`,
        'reports-summary',
        { signal: controller.signal, bypassCache }
      );

      if (controller.signal.aborted) {
        return;
      }

      const status = normalizeReportStatus(payload?.status);
      setReportsState({
        data: payload,
        loading: false,
        error: null,
        fetchedAt: new Date(),
        status
      });
    } catch (err) {
      if (err.name === 'AbortError') {
        return;
      }
      setReportsState({
        data: null,
        loading: false,
        error: err.message,
        fetchedAt: new Date(),
        status: 'error'
      });
    } finally {
      if (activeControllersRef.current.reports === controller) {
        activeControllersRef.current.reports = null;
      }
    }
  }, [fetchWithCache]);

  // Periodic cache cleanup
  useEffect(() => {
    const cleanupInterval = setInterval(cleanupCache, 60000); // Every minute
    return () => clearInterval(cleanupInterval);
  }, [cleanupCache]);

  const openFile = useCallback(async (file, { bypassCache = false } = {}) => {
    const controller = new AbortController();
    if (activeControllersRef.current.file) {
      activeControllersRef.current.file.abort();
    }
    activeControllersRef.current.file = controller;

    setLoading('file', true);
    setError(null);

    try {
      const cacheKey = `file-${selectedFolder}-${file.name}`;
      const payload = await fetchWithCache(
        `${API_BASE}/api/file/${selectedFolder}/${encodeURIComponent(file.name)}`,
        cacheKey,
        { signal: controller.signal, bypassCache }
      );
      setSelectedFile(payload.name || file.name);
      setContent(payload.content || '');
    } catch (err) {
      if (err.name === 'AbortError') {
        return;
      }
      setError(err.message);
    } finally {
      if (!controller.signal.aborted) {
        setLoading('file', false);
      }
      if (activeControllersRef.current.file === controller) {
        activeControllersRef.current.file = null;
      }
    }
  }, [selectedFolder, fetchWithCache, setLoading]);

  const loadFiles = useCallback(async ({ bypassCache = false, resetSelection = true } = {}) => {
    const controller = new AbortController();
    if (activeControllersRef.current.files) {
      activeControllersRef.current.files.abort();
    }
    activeControllersRef.current.files = controller;

    setLoading('files', true);
    setError(null);
    if (resetSelection) {
      setSelectedFile(null);
      setContent(defaultMarkdown);
      setLastUpdated(null);
      setListInsights(null);
    }
    if (bypassCache) {
      setIsRescanning(true);
    }

    try {
      const payload = await fetchWithCache(
        `${API_BASE}/api/list/${selectedFolder}`,
        `files-${selectedFolder}`,
        { signal: controller.signal, bypassCache }
      );
      const nextFiles = Array.isArray(payload)
        ? payload
        : Array.isArray(payload?.items)
          ? payload.items
          : Array.isArray(payload?.files)
            ? payload.files
            : [];
      const normalizedFiles = normalizeFiles(nextFiles);
      const previousFiles = filesRef.current || [];

      if (!resetSelection) {
        const { added, removed } = diffFileLists(previousFiles, normalizedFiles);
        if (added.length > 0 || removed.length > 0 || bypassCache) {
          setListInsights({
            added,
            removed,
            generatedAt: new Date()
          });
        } else {
          setListInsights(null);
        }
      }

      setFiles(normalizedFiles);
      filesRef.current = normalizedFiles;
      if (!resetSelection) {
        const currentName = selectedFileRef.current;
        if (currentName) {
          const match = normalizedFiles.find((item) => item.name === currentName);
          if (!match) {
            setSelectedFile(null);
            setContent(defaultMarkdown);
          } else if (bypassCache) {
            await openFile(match, { bypassCache: true });
          }
        }
      }
      const updatedAt = parseLastUpdated(payload) || new Date();
      setLastUpdated(updatedAt);
    } catch (err) {
      if (err.name === 'AbortError') {
        return;
      }
      setError(err.message);
      setFiles([]);
      filesRef.current = [];
      setListInsights(null);
      if (!resetSelection) {
        setSelectedFile(null);
        setContent(defaultMarkdown);
      }
    } finally {
      if (!controller.signal.aborted) {
        setLoading('files', false);
      }
      if (bypassCache) {
        setIsRescanning(false);
      }
      if (activeControllersRef.current.files === controller) {
        activeControllersRef.current.files = null;
      }
    }
  }, [fetchWithCache, openFile, selectedFolder, setLoading, selectedFileRef]);

  useEffect(() => {
    loadFiles({ resetSelection: true });
    return () => {
      if (activeControllersRef.current.files) {
        activeControllersRef.current.files.abort();
        activeControllersRef.current.files = null;
      }
      if (activeControllersRef.current.file) {
        activeControllersRef.current.file.abort();
        activeControllersRef.current.file = null;
      }
    };
  }, [loadFiles]);

  useEffect(() => {
    loadHealth();
    loadCapabilities();
    loadReportsSummary();

    return () => {
      ['health', 'capabilities', 'reports'].forEach((key) => {
        if (activeControllersRef.current[key]) {
          activeControllersRef.current[key].abort();
          activeControllersRef.current[key] = null;
        }
      });
    };
  }, [loadHealth, loadCapabilities, loadReportsSummary]);

  const handleRescan = useCallback(() => {
    loadFiles({ bypassCache: true, resetSelection: false });
  }, [loadFiles]);

  const handleStatusRefresh = useCallback(() => {
    loadHealth({ bypassCache: true });
    loadCapabilities({ bypassCache: true });
    loadReportsSummary({ bypassCache: true });
  }, [loadHealth, loadCapabilities, loadReportsSummary]);

  const isRefreshingStatus = healthState.loading || capabilitiesState.loading || reportsState.loading;

  // Memoized markdown rendering with better performance
  const renderedMarkdown = useMemo(() => {
    if (!content || content === defaultMarkdown) {
      return marked.parse(content || defaultMarkdown);
    }
    
    // Use a more efficient parsing approach for large content
    try {
      return marked.parse(content);
    } catch (error) {
      console.warn('Markdown parsing error:', error);
      return `<pre>Error parsing markdown: ${error.message}</pre>`;
    }
  }, [content]);

  return (
    <ErrorBoundary>
      <div className="app-shell">
        <Sidebar
          folders={folders}
          selectedFolder={selectedFolder}
          onFolderSelect={setSelectedFolder}
        />
        <main className="main-pane">
          <SystemStatus
            health={healthState}
            capabilities={capabilitiesState}
            reports={reportsState}
            onRefresh={handleStatusRefresh}
            isRefreshing={isRefreshingStatus}
          />
          <FileList
            files={files}
            selectedFile={selectedFile}
            selectedFolder={selectedFolder}
            folders={folders}
            isLoading={isLoadingFiles}
            error={error}
            onFileSelect={openFile}
            onRescan={handleRescan}
            isRescanning={isRescanning}
            lastUpdated={lastUpdated}
            listInsights={listInsights}
          />
          <PreviewPane
            selectedFile={selectedFile}
            content={renderedMarkdown}
            isLoading={isLoading}
          />
        </main>
      </div>
    </ErrorBoundary>
  );
}

const StatusChip = ({ label, state, detail, loading }) => {
  const normalizedState = loading ? 'pending' : state || 'unknown';
  const className = `status-chip ${normalizedState}`;
  return (
    <span className={className}>
      <span className="dot" aria-hidden="true"></span>
      <span className="status-chip-label">{label}</span>
      <span className="status-chip-detail">{loading ? 'Checking…' : detail || '—'}</span>
    </span>
  );
};

const SystemStatus = memo(({ health, capabilities, reports, onRefresh, isRefreshing }) => {
  const connectors = useMemo(
    () => normalizeConnectorEntries(capabilities?.data?.connectors),
    [capabilities]
  );

  const features = useMemo(() => {
    const raw = capabilities?.data?.features;
    if (!raw || typeof raw !== 'object') {
      return [];
    }
    return Object.entries(raw)
      .map(([key, value]) => ({ key, label: formatFeatureLabel(key), enabled: Boolean(value) }))
      .sort((a, b) => a.label.localeCompare(b.label));
  }, [capabilities]);

  const engines = useMemo(() => {
    const raw = capabilities?.data?.engine;
    if (!raw || typeof raw !== 'object') {
      return [];
    }
    return Object.entries(raw)
      .map(([key, value]) => ({ key, label: formatFeatureLabel(key), enabled: Boolean(value) }))
      .sort((a, b) => a.label.localeCompare(b.label));
  }, [capabilities]);

  const mailboxFlow = useMemo(() => {
    const flow = capabilities?.data?.mailboxes?.flow;
    return Array.isArray(flow) ? flow : [];
  }, [capabilities]);

  const readyConnectors = connectors.filter((item) => item.ready).length;
  const mailboxCount = Array.isArray(capabilities?.data?.mailboxes?.list)
    ? capabilities.data.mailboxes.list.length
    : 0;

  const healthDetail = health.loading
    ? 'Checking…'
    : health.error
      ? truncateText(health.error)
      : `Online${health.fetchedAt ? ` · ${formatTimestamp(health.fetchedAt)}` : ''}`;

  let capabilitiesDetail;
  if (capabilities.loading) {
    capabilitiesDetail = 'Loading…';
  } else if (capabilities.error) {
    capabilitiesDetail = truncateText(capabilities.error);
  } else {
    const parts = [];
    parts.push(`${mailboxCount} mailbox${mailboxCount === 1 ? '' : 'es'}`);
    if (connectors.length > 0) {
      parts.push(`${readyConnectors}/${connectors.length} connector${connectors.length === 1 ? '' : 's'} ready`);
    }
    if (capabilities.fetchedAt) {
      parts.push(formatTimestamp(capabilities.fetchedAt));
    }
    capabilitiesDetail = parts.join(' · ');
  }

  let reportsDetail;
  if (reports.loading) {
    reportsDetail = 'Refreshing…';
  } else if (reports.error) {
    reportsDetail = truncateText(reports.error);
  } else if (reports.data) {
    const parts = [];
    parts.push(formatFeatureLabel(reports.status));
    if (reports.data.note) {
      parts.push(truncateText(reports.data.note, 100));
    } else if (reports.data.hint) {
      parts.push(truncateText(reports.data.hint, 100));
    }
    if (reports.fetchedAt) {
      parts.push(formatTimestamp(reports.fetchedAt));
    }
    reportsDetail = parts.filter(Boolean).join(' · ');
  } else {
    reportsDetail = 'No summary';
  }

  return (
    <section className="system-status">
      <header>
        <div className="status-heading">
          <h2>System Status</h2>
          {!capabilities.loading && capabilities.fetchedAt && (
            <span className="status-note">Synced {formatTimestamp(capabilities.fetchedAt)}</span>
          )}
        </div>
        <button
          type="button"
          className="status-refresh"
          onClick={() => onRefresh?.()}
          disabled={isRefreshing}
        >
          {isRefreshing ? 'Refreshing…' : 'Refresh'}
        </button>
      </header>
      <div className="status-chip-row">
        <StatusChip label="API" state={health.status} detail={healthDetail} loading={health.loading} />
        <StatusChip
          label="Capabilities"
          state={capabilities.status}
          detail={capabilitiesDetail}
          loading={capabilities.loading}
        />
        <StatusChip label="Reports" state={reports.status} detail={reportsDetail} loading={reports.loading} />
      </div>

      {mailboxFlow.length > 0 && (
        <div className="status-section">
          <h3>Mailboxes</h3>
          <div className="status-note flow">{mailboxFlow.join(' → ')}</div>
        </div>
      )}

      {connectors.length > 0 && (
        <div className="status-section">
          <div className="status-section-header">
            <h3>Connectors</h3>
            <span className="status-note">{readyConnectors}/{connectors.length} ready</span>
          </div>
          <ul className="connector-list">
            {connectors.map((connector) => (
              <li key={connector.id} className="connector-item">
                <span className={`status-dot ${connector.ready ? 'ok' : 'error'}`} aria-hidden="true"></span>
                <span className="connector-name">{connector.label}</span>
                <span className="connector-detail">{connector.detail}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {features.length > 0 && (
        <div className="status-section">
          <h3>Features</h3>
          <div className="feature-tags">
            {features.map((feature) => (
              <span
                key={feature.key}
                className={`feature-chip ${feature.enabled ? 'enabled' : 'disabled'}`}
              >
                {feature.label}
              </span>
            ))}
          </div>
        </div>
      )}

      {engines.length > 0 && (
        <div className="status-section">
          <h3>Engines</h3>
          <div className="feature-tags">
            {engines.map((engine) => (
              <span
                key={engine.key}
                className={`feature-chip ${engine.enabled ? 'enabled' : 'disabled'}`}
              >
                {engine.label}
              </span>
            ))}
          </div>
        </div>
      )}
    </section>
  );
});

// Memoized Sidebar component
const Sidebar = memo(({ folders, selectedFolder, onFolderSelect }) => (
  <aside className="sidebar">
    <div className="sidebar-title">Boss Workspace</div>
    <nav>
      {folders.map((folder) => (
        <button
          key={folder.key}
          className={`nav-item${selectedFolder === folder.key ? ' active' : ''}`}
          onClick={() => onFolderSelect(folder.key)}
          type="button"
        >
          {folder.label}
        </button>
      ))}
    </nav>
  </aside>
));

// Memoized FileList component
const FileList = memo(({
  files,
  selectedFile,
  selectedFolder,
  folders,
  isLoading,
  error,
  onFileSelect,
  onRescan,
  isRescanning,
  lastUpdated,
  listInsights
}) => (
  <section className="file-list">
    <header>
      <div className="file-list-heading">
        <h2>{folders.find((f) => f.key === selectedFolder)?.label}</h2>
        {lastUpdated && !isRescanning && (
          <span className="file-list-meta">Updated {lastUpdated.toLocaleTimeString()}</span>
        )}
        {isRescanning && <span className="file-list-meta">Rescanning…</span>}
      </div>
      <button
        type="button"
        className="rescan-button"
        onClick={onRescan}
        disabled={isLoading || isRescanning}
      >
        {isRescanning ? 'Rescanning…' : 'Rescan'}
      </button>
    </header>
    {isLoading && <div className="status">Loading…</div>}
    {error && <div className="status error">{error}</div>}
    {!error && listInsights && (
      <div className="status insights">
        <div className="insights-summary">
          {listInsights.added.length === 0 && listInsights.removed.length === 0 ? (
            <span>No file changes detected during the rescan.</span>
          ) : (
            <>
              {listInsights.added.length > 0 && (
                <span>{listInsights.added.length} added</span>
              )}
              {listInsights.removed.length > 0 && (
                <span>{listInsights.removed.length} removed</span>
              )}
            </>
          )}
        </div>
        <span className="insights-timestamp">
          Verified {(listInsights.generatedAt || new Date()).toLocaleTimeString()}
        </span>
        {(listInsights.added.length > 0 || listInsights.removed.length > 0) && (
          <details>
            <summary>View details</summary>
            <div className="insights-details">
              {listInsights.added.length > 0 && (
                <div>
                  <strong>Added</strong>
                  <ul>
                    {listInsights.added.map((name) => (
                      <li key={`added-${name}`}>{name}</li>
                    ))}
                  </ul>
                </div>
              )}
              {listInsights.removed.length > 0 && (
                <div>
                  <strong>Removed</strong>
                  <ul>
                    {listInsights.removed.map((name) => (
                      <li key={`removed-${name}`}>{name}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </details>
        )}
      </div>
    )}
    {!isLoading && !error && files.length === 0 && <div className="status">No files available.</div>}
    <ul>
      {files.map((file) => (
        <FileItem
          key={file.name}
          file={file}
          isSelected={selectedFile === file.name}
          onSelect={onFileSelect}
        />
      ))}
    </ul>
  </section>
));

// Memoized FileItem component
const FileItem = memo(({ file, isSelected, onSelect }) => (
  <li>
    <button
      type="button"
      className={`file-item${isSelected ? ' selected' : ''}`}
      onClick={() => onSelect(file)}
    >
      {file.name}
    </button>
  </li>
));

// Memoized PreviewPane component
const PreviewPane = memo(({ selectedFile, content, isLoading }) => (
  <section className="preview-pane">
    <header>
      <h2>{selectedFile || 'Preview'}</h2>
    </header>
    {isLoading ? (
      <div className="loading-skeleton">
        <div className="skeleton-line"></div>
        <div className="skeleton-line"></div>
        <div className="skeleton-line short"></div>
        <div className="skeleton-line"></div>
        <div className="skeleton-line short"></div>
      </div>
    ) : (
      <article className="markdown" dangerouslySetInnerHTML={{ __html: content }} />
    )}
  </section>
));
