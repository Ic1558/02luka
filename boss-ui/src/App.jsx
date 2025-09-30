import { useEffect, useMemo, useState } from 'react';
import { marked } from 'marked';

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

export default function App() {
  const [selectedFolder, setSelectedFolder] = useState(folders[0].key);
  const [files, setFiles] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null);
  const [content, setContent] = useState(defaultMarkdown);
  const [error, setError] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    async function loadFiles() {
      setIsLoading(true);
      setError(null);
      setSelectedFile(null);
      setContent(defaultMarkdown);
      try {
        const response = await fetch(`${API_BASE}/api/list/${selectedFolder}`);
        if (!response.ok) {
          const payload = await response.json().catch(() => ({}));
          throw new Error(payload.message || 'Unable to fetch files');
        }
        const payload = await response.json();
        setFiles(payload.files || []);
      } catch (err) {
        setError(err.message);
        setFiles([]);
      } finally {
        setIsLoading(false);
      }
    }

    loadFiles();
  }, [selectedFolder]);

  async function openFile(file) {
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(`${API_BASE}/api/file/${selectedFolder}/${encodeURIComponent(file.name)}`);
      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        throw new Error(payload.message || 'Unable to fetch file');
      }
      const payload = await response.json();
      setSelectedFile(payload.name);
      setContent(payload.content || '');
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }

  const renderedMarkdown = useMemo(() => marked.parse(content || defaultMarkdown), [content]);

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-title">Boss Workspace</div>
        <nav>
          {folders.map((folder) => (
            <button
              key={folder.key}
              className={`nav-item${selectedFolder === folder.key ? ' active' : ''}`}
              onClick={() => setSelectedFolder(folder.key)}
              type="button"
            >
              {folder.label}
            </button>
          ))}
        </nav>
      </aside>
      <main className="main-pane">
        <section className="file-list">
          <header>
            <h2>{folders.find((f) => f.key === selectedFolder)?.label}</h2>
          </header>
          {isLoading && <div className="status">Loading…</div>}
          {error && <div className="status error">{error}</div>}
          {!isLoading && !error && files.length === 0 && <div className="status">No files available.</div>}
          <ul>
            {files.map((file) => (
              <li key={file.name}>
                <button
                  type="button"
                  className={`file-item${selectedFile === file.name ? ' selected' : ''}`}
                  onClick={() => openFile(file)}
                >
                  {file.name}
                </button>
              </li>
            ))}
          </ul>
        </section>
        <section className="preview-pane">
          <header>
            <h2>{selectedFile || 'Preview'}</h2>
          </header>
          <article className="markdown" dangerouslySetInnerHTML={{ __html: renderedMarkdown }} />
        </section>
      </main>
    </div>
  );
}
