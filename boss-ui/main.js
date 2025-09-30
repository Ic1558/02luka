const API_BASE = 'http://localhost:4000/api';
const folders = ['inbox', 'sent', 'deliverables', 'dropbox', 'drafts', 'documents'];

const folderContainer = document.getElementById('folders');
const fileList = document.getElementById('file-list');
const preview = document.getElementById('preview');

let currentFolder = null;
let currentFile = null;

function setActiveFolder(folder) {
  currentFolder = folder;
  currentFile = null;
  document.querySelectorAll('.folder').forEach((el) => {
    el.classList.toggle('active', el.dataset.folder === folder);
  });
}

function setActiveFile(name) {
  currentFile = name;
  document.querySelectorAll('.file-item').forEach((el) => {
    el.classList.toggle('active', el.dataset.file === name);
  });
}

async function loadFolders() {
  folderContainer.innerHTML = '';
  folders.forEach((folder) => {
    const item = document.createElement('div');
    item.className = 'folder';
    item.dataset.folder = folder;
    item.textContent = folder.charAt(0).toUpperCase() + folder.slice(1);
    item.addEventListener('click', () => {
      if (currentFolder === folder) {
        return;
      }
      setActiveFolder(folder);
      renderFileListLoading();
      fetchFileList(folder);
    });
    folderContainer.appendChild(item);
  });
}

function renderFileListLoading() {
  fileList.innerHTML = '<p class="empty-state">Loading files…</p>';
  preview.innerHTML = '<p class="empty-state">Choose a file to preview its contents.</p>';
}

function renderFileList(files) {
  if (!files.length) {
    fileList.innerHTML = '<p class="empty-state">No files found in this folder.</p>';
    return;
  }

  const list = document.createElement('div');
  files.forEach((fileName) => {
    const item = document.createElement('div');
    item.className = 'file-item';
    item.dataset.file = fileName;
    item.textContent = fileName;
    item.addEventListener('click', () => {
      if (currentFile === fileName) {
        return;
      }
      setActiveFile(fileName);
      preview.innerHTML = '<p class="empty-state">Loading preview…</p>';
      fetchFileContent(currentFolder, fileName);
    });
    list.appendChild(item);
  });
  fileList.innerHTML = '';
  fileList.appendChild(list);
}

function renderPreview(content) {
  const pre = document.createElement('pre');
  pre.textContent = content;
  preview.innerHTML = '';
  preview.appendChild(pre);
}

function renderError(target, message) {
  target.innerHTML = `<p class="empty-state">${message}</p>`;
}

async function fetchFileList(folder) {
  try {
    const response = await fetch(`${API_BASE}/list/${encodeURIComponent(folder)}`);
    if (!response.ok) {
      throw new Error('Unable to load files');
    }
    const data = await response.json();
    renderFileList(data.files || []);
  } catch (error) {
    renderError(fileList, error.message);
  }
}

async function fetchFileContent(folder, file) {
  try {
    const response = await fetch(`${API_BASE}/file/${encodeURIComponent(folder)}/${encodeURIComponent(file)}`);
    if (!response.ok) {
      const errorPayload = await response.json().catch(() => ({}));
      throw new Error(errorPayload.error || 'Unable to load file');
    }
    const text = await response.text();
    renderPreview(text);
  } catch (error) {
    renderError(preview, error.message);
  }
}

loadFolders();
