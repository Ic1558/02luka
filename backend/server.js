const express = require('express');
const cors = require('cors');
const fs = require('fs');
const fsp = fs.promises;
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 4123;
const CONTEXT_ROOT = process.env.CENTRAL_CONTEXT_ROOT || path.join(process.cwd(), 'central-context');
const BOSS_ROOT = path.join(CONTEXT_ROOT, 'boss');
const FOLDERS = ['inbox', 'sent', 'deliverables', 'drafts', 'dropbox'];

async function ensureWorkspace() {
  await fsp.mkdir(BOSS_ROOT, { recursive: true });
  await Promise.all(
    FOLDERS.map(async (folder) => {
      const dir = path.join(BOSS_ROOT, folder);
      await fsp.mkdir(dir, { recursive: true });
    })
  );
}

function toFrontMatter(metadata) {
  const lines = Object.entries(metadata)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${key}: ${formatValue(value)}`);
  return `---\n${lines.join('\n')}\n---`;
}

function formatValue(value) {
  if (Array.isArray(value)) {
    return `[${value.map(formatValue).join(', ')}]`;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  switch (typeof value) {
    case 'number':
    case 'boolean':
      return String(value);
    case 'string': {
      if (!value.length) return "''";
      if (/[:#\n\r]/.test(value)) {
        return JSON.stringify(value);
      }
      return value;
    }
    default:
      return JSON.stringify(value);
  }
}

function parseFrontMatter(raw) {
  if (!raw.startsWith('---')) {
    return { metadata: {}, body: raw.trimStart() };
  }
  const end = raw.indexOf('\n---', 3);
  if (end === -1) {
    return { metadata: {}, body: raw.trimStart() };
  }
  const fmRaw = raw.slice(3, end).trim();
  const body = raw.slice(end + 4).trimStart();
  const metadata = {};
  const lines = fmRaw.split(/\r?\n/);
  for (const line of lines) {
    const idx = line.indexOf(':');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    let value = line.slice(idx + 1).trim();
    if (!key) continue;
    if (!value.length) {
      metadata[key] = '';
      continue;
    }
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      try {
        metadata[key] = JSON.parse(value.replace(/'/g, '"'));
      } catch (err) {
        metadata[key] = value.slice(1, -1);
      }
      continue;
    }
    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        metadata[key] = JSON.parse(value);
        continue;
      } catch (err) {
        // fall through
      }
    }
    if (value === 'true' || value === 'false') {
      metadata[key] = value === 'true';
      continue;
    }
    const num = Number(value);
    if (!Number.isNaN(num)) {
      metadata[key] = num;
      continue;
    }
    metadata[key] = value;
  }
  return { metadata, body };
}

async function readMessageFile(folder, name) {
  const filePath = path.join(BOSS_ROOT, folder, name);
  const stat = await fsp.stat(filePath);
  if (!stat.isFile()) {
    return null;
  }
  const raw = await fsp.readFile(filePath, 'utf8');
  const { metadata, body } = parseFrontMatter(raw);
  const createdAt = metadata.createdAt || stat.birthtime?.toISOString() || stat.mtime.toISOString();
  const role = folder === 'inbox' || folder === 'deliverables' ? 'assistant' : 'user';
  return {
    id: `${folder}/${name}`,
    name,
    folder,
    role,
    content: body.trim(),
    metadata,
    createdAt,
    updatedAt: stat.mtime.toISOString(),
    clientId: metadata.clientId || metadata.id || null,
    size: stat.size,
  };
}

async function loadMessages(folders) {
  const results = [];
  for (const folder of folders) {
    const dir = path.join(BOSS_ROOT, folder);
    let files = [];
    try {
      files = await fsp.readdir(dir);
    } catch (err) {
      continue;
    }
    for (const file of files) {
      if (file.startsWith('.')) continue;
      try {
        const message = await readMessageFile(folder, file);
        if (message) {
          results.push(message);
        }
      } catch (err) {
        console.error('Failed to read message file', { folder, file, error: err.message });
      }
    }
  }
  results.sort((a, b) => {
    const aTime = Number(new Date(a.createdAt));
    const bTime = Number(new Date(b.createdAt));
    if (aTime === bTime) {
      return a.id.localeCompare(b.id);
    }
    return aTime - bTime;
  });
  return results;
}

async function writeMessage(folder, filename, content) {
  const target = path.join(BOSS_ROOT, folder, filename);
  await fsp.writeFile(target, content, 'utf8');
  return target;
}

function sanitizeFileComponent(value) {
  return value.replace(/[^a-zA-Z0-9_-]/g, '-');
}

async function handleSendMessage(req, res) {
  const { content, subject = '', sessionId = 'default', metadata = {}, clientId } = req.body || {};
  if (!content || !content.trim()) {
    return res.status(400).json({ error: 'Message content is required.' });
  }

  const createdAt = new Date().toISOString();
  const id = clientId || crypto.randomUUID();
  const filenameBase = `${createdAt.replace(/[:.]/g, '-')}-${sanitizeFileComponent(id.slice(0, 8))}`;
  const filename = `${filenameBase}.md`;

  const meta = {
    id,
    clientId: id,
    createdAt,
    sessionId,
    subject,
    source: 'luka-ui',
    ...metadata,
  };

  const fileBody = `${toFrontMatter(meta)}\n\n${content.trim()}\n`;

  await writeMessage('dropbox', filename, fileBody);
  await writeMessage('sent', filename, fileBody);

  res.json({
    status: 'queued',
    file: { name: filename, folder: 'dropbox' },
    metadata: meta,
  });
}

async function handleListFolder(req, res) {
  const { folder } = req.params;
  if (!FOLDERS.includes(folder)) {
    return res.status(404).json({ error: `Unknown folder: ${folder}` });
  }
  try {
    const dir = path.join(BOSS_ROOT, folder);
    const files = await fsp.readdir(dir);
    const items = await Promise.all(
      files
        .filter((name) => !name.startsWith('.'))
        .map(async (name) => {
          const filePath = path.join(dir, name);
          const stat = await fsp.stat(filePath);
          return {
            name,
            size: stat.size,
            modifiedAt: stat.mtime.toISOString(),
            createdAt: stat.birthtime?.toISOString() || stat.mtime.toISOString(),
          };
        })
    );
    res.json({ folder, files: items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}

async function handleGetFile(req, res) {
  const { folder, name } = req.params;
  if (!FOLDERS.includes(folder)) {
    return res.status(404).json({ error: `Unknown folder: ${folder}` });
  }
  try {
    const filePath = path.join(BOSS_ROOT, folder, name);
    const data = await fsp.readFile(filePath, 'utf8');
    res.type('text/plain').send(data);
  } catch (err) {
    if (err.code === 'ENOENT') {
      res.status(404).json({ error: 'File not found' });
    } else {
      res.status(500).json({ error: err.message });
    }
  }
}

async function handleChatHistory(req, res) {
  const folders = (req.query.folders ? String(req.query.folders).split(',') : ['sent', 'dropbox', 'inbox', 'deliverables']).filter((folder) =>
    FOLDERS.includes(folder)
  );
  const messages = await loadMessages(folders);
  res.json({ messages });
}

function buildStatus() {
  return {
    contextRoot: CONTEXT_ROOT,
    folders: FOLDERS.map((folder) => ({
      name: folder,
      path: path.join(BOSS_ROOT, folder),
    })),
  };
}

async function main() {
  await ensureWorkspace();

  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '5mb' }));

  app.get('/health', (req, res) => {
    res.json({ status: 'ok', workspace: buildStatus() });
  });

  app.get('/api/folders', (req, res) => {
    res.json(buildStatus());
  });

  app.get('/api/messages/:folder', (req, res) => {
    handleListFolder(req, res);
  });

  app.get('/api/messages/:folder/:name', (req, res) => {
    handleGetFile(req, res);
  });

  app.get('/api/chat/history', (req, res) => {
    handleChatHistory(req, res);
  });

  app.post('/api/chat/send', (req, res) => {
    handleSendMessage(req, res).catch((err) => {
      console.error('Failed to send message', err);
      res.status(500).json({ error: 'Failed to send message' });
    });
  });

  app.listen(PORT, () => {
    console.log(`Central context backend listening on http://localhost:${PORT}`);
  });
}

main().catch((err) => {
  console.error('Failed to start backend', err);
  process.exit(1);
});
