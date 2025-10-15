import { useEffect, useMemo, useState, useCallback, memo, useRef } from 'react';
import { marked } from 'marked';
import ErrorBoundary from './ErrorBoundary';

const API_BASE = 'http://localhost:4000';

const folders = [
  { key: 'inbox', label: 'Inbox' },
  { key: 'sent', label: 'Sent' },
  { key: 'deliverables', label: 'Deliverables' },
  { key: 'dropbox', label: 'Dropbox' },
  { key: 'drafts', label: 'Drafts' },
  { key: 'documents', label: 'Documents' }
];

const defaultMarkdown = '# Boss Workspace\n\nSelect a file to preview its contents.';

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
  const selectedFileRef = useRef(null);
  const filesRef = useRef(files);
  const activeControllersRef = useRef({ files: null, file: null });

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
    };
  }, [loadFiles]);

  const handleRescan = useCallback(() => {
    loadFiles({ bypassCache: true, resetSelection: false });
  }, [loadFiles]);

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
