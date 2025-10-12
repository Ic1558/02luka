import { useEffect, useMemo, useState, useCallback, memo } from 'react';
import { marked } from 'marked';
import ErrorBoundary from './ErrorBoundary';
import { ensureConfigReady, getApiBase } from '../shared/config.js';

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
  const [isLoading, setIsLoading] = useState(false);
  const [apiBase, setApiBase] = useState(getApiBase());

  useEffect(() => {
    let mounted = true;
    ensureConfigReady().then(() => {
      if (mounted) {
        setApiBase(getApiBase());
      }
    }).catch((err) => {
      console.warn('Failed to hydrate runtime config', err);
    });
    return () => {
      mounted = false;
    };
  }, []);

  // Cache cleanup function
  const cleanupCache = useCallback(() => {
    const now = Date.now();
    let cleaned = 0;
    
    // Remove expired entries
    for (const [key, value] of apiCache.entries()) {
      if ((now - value.timestamp) > CACHE_DURATION) {
        apiCache.delete(key);
        cleaned++;
      }
    }
    
    // Remove oldest entries if cache is too large
    if (apiCache.size > MAX_CACHE_SIZE) {
      const entries = Array.from(apiCache.entries());
      entries.sort((a, b) => a[1].timestamp - b[1].timestamp);
      const toRemove = Math.floor(MAX_CACHE_SIZE * 0.3); // Remove 30%
      for (let i = 0; i < toRemove; i++) {
        apiCache.delete(entries[i][0]);
        cleaned++;
      }
    }
    
    if (cleaned > 0) {
      console.log(`Frontend cache cleanup: removed ${cleaned} entries`);
    }
  }, []);

  // Cached API call function
  const fetchWithCache = useCallback(async (url, cacheKey) => {
    const now = Date.now();
    const cached = apiCache.get(cacheKey);
    
    if (cached && (now - cached.timestamp) < CACHE_DURATION) {
      return cached.data;
    }

    const response = await fetch(url);
    if (!response.ok) {
      const payload = await response.json().catch(() => ({}));
      throw new Error(payload.message || 'Unable to fetch data');
    }
    
    const data = await response.json();
    
    // Check cache size before adding
    if (apiCache.size >= MAX_CACHE_SIZE) {
      cleanupCache();
    }
    
    apiCache.set(cacheKey, { data, timestamp: now });
    return data;
  }, [cleanupCache]);

  // Periodic cache cleanup
  useEffect(() => {
    const cleanupInterval = setInterval(cleanupCache, 60000); // Every minute
    return () => clearInterval(cleanupInterval);
  }, [cleanupCache]);

  useEffect(() => {
    if (!apiBase) {
      return;
    }

    async function loadFiles() {
      setIsLoading(true);
      setError(null);
      setSelectedFile(null);
      setContent(defaultMarkdown);
      
      try {
        const payload = await fetchWithCache(
          `${apiBase}/api/list/${selectedFolder}`,
          `files-${selectedFolder}`
        );
        setFiles(payload.items || payload.files || []);
      } catch (err) {
        setError(err.message);
        setFiles([]);
      } finally {
        setIsLoading(false);
      }
    }

    loadFiles();
  }, [selectedFolder, fetchWithCache, apiBase]);

  const openFile = useCallback(async (file) => {
    if (!apiBase) {
      return;
    }
    setIsLoading(true);
    setError(null);
    
    try {
      const cacheKey = `file-${selectedFolder}-${file.name}`;
      const payload = await fetchWithCache(
        `${apiBase}/api/file/${selectedFolder}/${encodeURIComponent(file.name)}`,
        cacheKey
      );
      setSelectedFile(payload.name);
      setContent(payload.content || '');
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }, [selectedFolder, fetchWithCache, apiBase]);

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
            isLoading={isLoading}
            error={error}
            onFileSelect={openFile}
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
const FileList = memo(({ files, selectedFile, selectedFolder, folders, isLoading, error, onFileSelect }) => (
  <section className="file-list">
    <header>
      <h2>{folders.find((f) => f.key === selectedFolder)?.label}</h2>
    </header>
    {isLoading && <div className="status">Loading…</div>}
    {error && <div className="status error">{error}</div>}
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
