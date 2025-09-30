const http = require('http');
const { execFile } = require('child_process');
const fs = require('fs').promises;
const path = require('path');

const PORT = process.env.PORT ? Number(process.env.PORT) : 4000;
const ALLOWED_FOLDERS = new Set([
  'inbox',
  'sent',
  'deliverables',
  'dropbox',
  'drafts',
  'documents',
]);

const repoRoot = process.env.SOT_PATH || path.resolve(__dirname, '..');
const resolverScript = path.join(repoRoot, 'g', 'tools', 'path_resolver.sh');

function sendJson(res, statusCode, data) {
  const payload = JSON.stringify(data);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(payload);
}

function sendText(res, statusCode, text, contentType = 'text/plain; charset=utf-8') {
  res.writeHead(statusCode, {
    'Content-Type': contentType,
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(text);
}

function resolveFolder(folder) {
  return new Promise((resolve, reject) => {
    if (!ALLOWED_FOLDERS.has(folder)) {
      reject(new Error('Invalid folder'));
      return;
    }

    execFile(
      'bash',
      [resolverScript, `human:${folder}`],
      { cwd: repoRoot, env: process.env },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr.trim() || error.message));
          return;
        }
        resolve(stdout.trim());
      }
    );
  });
}

async function handleList(folder, res) {
  try {
    const targetDir = await resolveFolder(folder);
    const entries = await fs.readdir(targetDir, { withFileTypes: true });
    const files = entries
      .filter((entry) => entry.isFile())
      .map((entry) => entry.name)
      .sort((a, b) => a.localeCompare(b));
    sendJson(res, 200, { files });
  } catch (error) {
    sendJson(res, 400, { error: error.message });
  }
}

async function handleFile(folder, name, res) {
  try {
    const targetDir = await resolveFolder(folder);
    const targetRoot = path.resolve(targetDir);
    const resolvedPath = path.resolve(targetRoot, name);
    const relative = path.relative(targetRoot, resolvedPath);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      throw new Error('Invalid file path');
    }
    const content = await fs.readFile(resolvedPath, 'utf-8');
    sendText(res, 200, content);
  } catch (error) {
    sendJson(res, 400, { error: error.message });
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const segments = url.pathname.split('/').filter(Boolean);

  if (req.method === 'GET' && segments.length === 3 && segments[0] === 'api' && segments[1] === 'list') {
    const folder = segments[2];
    await handleList(folder, res);
    return;
  }

  if (req.method === 'GET' && segments.length >= 4 && segments[0] === 'api' && segments[1] === 'file') {
    const folder = segments[2];
    const name = decodeURIComponent(segments.slice(3).join('/'));
    await handleFile(folder, name, res);
    return;
  }

  res.writeHead(404, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`boss-api listening on port ${PORT}`);
});
