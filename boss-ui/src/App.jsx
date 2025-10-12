import { useEffect, useMemo, useState } from 'react';
import { marked } from 'marked';
import DOMPurify from 'dompurify';

const API_BASE = 'http://localhost:4000';

const FOLDERS = [
  { key: 'inbox', label: 'Inbox' },
  { key: 'sent', label: 'Sent' },
  { key: 'deliverables', label: 'Deliverables' },
  { key: 'dropbox', label: 'Dropbox' },
  { key: 'drafts', label: 'Drafts' },
  { key: 'documents', label: 'Documents' }
];

const markdownRenderer = new marked.Renderer();

export default function App() {
  const [activeFolder, setActiveFolder] = useState(FOLDERS[0].key);
  const [files, setFiles] = useState([]);
  const [listError, setListError] = useState('');
  const [isLoadingList, setIsLoadingList] = useState(false);
  const [selectedFile, setSelectedFile] = useState('');
  const [fileContent, setFileContent] = useState('');
  const [isLoadingFile, setIsLoadingFile] = useState(false);
  const [fileError, setFileError] = useState('');

  useEffect(() => {
    async function fetchList() {
      setIsLoadingList(true);
      setListError('');
      setFiles([]);
      setSelectedFile('');
      setFileContent('');
      setFileError('');

      try {
        const response = await fetch(`${API_BASE}/api/list/${activeFolder}`);

        if (!response.ok) {
          const error = await response.json().catch(() => ({}));
          throw new Error(error.message || 'Failed to load files');
        }

        const data = await response.json();
        setFiles(data.files || []);
      } catch (error) {
        setListError(error.message);
      } finally {
        setIsLoadingList(false);
      }
    }

    fetchList();
  }, [activeFolder]);

  useEffect(() => {
    if (!selectedFile) {
      return;
    }

    let abort = false;

    async function fetchFile() {
      setIsLoadingFile(true);
      setFileError('');

      try {
        const response = await fetch(
          `${API_BASE}/api/file/${activeFolder}/${encodeURIComponent(selectedFile)}`
        );

        if (!response.ok) {
          const error = await response.json().catch(() => ({}));
          throw new Error(error.message || 'Failed to load file');
        }

        const data = await response.json();
        if (!abort) {
          setFileContent(data.content || '');
        }
      } catch (error) {
        if (!abort) {
          setFileError(error.message);
          setFileContent('');
        }
      } finally {
        if (!abort) {
          setIsLoadingFile(false);
        }
      }
    }

    fetchFile();

    return () => {
      abort = true;
    };
  }, [activeFolder, selectedFile]);

  const renderedMarkdown = useMemo(() => {
    if (!fileContent) {
      return '';
    }

    const rawHtml = marked(fileContent, { renderer: markdownRenderer, breaks: true });
    return DOMPurify.sanitize(rawHtml);
  }, [fileContent]);

  return (
    <div className="app">
      <aside className="sidebar">
        <h1 className="sidebar__title">Boss Workspace</h1>
        <nav>
          <ul className="sidebar__list">
            {FOLDERS.map((folder) => (
              <li key={folder.key}>
                <button
                  type="button"
                  className={`sidebar__button${folder.key === activeFolder ? ' is-active' : ''}`}
                  onClick={() => setActiveFolder(folder.key)}
                >
                  {folder.label}
                </button>
              </li>
            ))}
          </ul>
        </nav>
      </aside>

      <main className="main">
        <section className="file-list">
          <header className="section-header">
            <h2>{FOLDERS.find((folder) => folder.key === activeFolder)?.label}</h2>
          </header>
          {isLoadingList ? (
            <p className="status">Loading files…</p>
          ) : listError ? (
            <p className="status status--error">{listError}</p>
          ) : files.length === 0 ? (
            <p className="status">No files in this folder.</p>
          ) : (
            <ul className="file-list__items">
              {files.map((fileName) => (
                <li key={fileName}>
                  <button
                    type="button"
                    className={`file-list__button${fileName === selectedFile ? ' is-active' : ''}`}
                    onClick={() => setSelectedFile(fileName)}
                  >
                    {fileName}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="viewer">
          <header className="section-header">
            <h2>{selectedFile || 'Preview'}</h2>
          </header>
          {!selectedFile ? (
            <p className="status">Select a file to preview its contents.</p>
          ) : isLoadingFile ? (
            <p className="status">Loading preview…</p>
          ) : fileError ? (
            <p className="status status--error">{fileError}</p>
          ) : (
            <article
              className="viewer__content"
              dangerouslySetInnerHTML={{ __html: renderedMarkdown }}
            />
          )}
        </section>
      </main>
    </div>
  );
}
