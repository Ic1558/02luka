const http = require('http');
const path = require('path');
const fs = require('fs/promises');
const { execFile } = require('child_process');

const HOST = process.env.HOST || '127.0.0.1';
const PORT = Number(process.env.PORT || 4000);
const repoRoot = path.resolve(__dirname, '..'); // 02luka-repo root

// ใช้ resolver ตามกติกา (ห้ามพาธฮาร์ดโค้ด)
function resolveKey(key) {
  return new Promise((resolve, reject) => {
    execFile(
      'bash',
      ['g/tools/path_resolver.sh', key],
      { cwd: repoRoot, encoding: 'utf8' },
      (err, stdout) => {
        if (err) return reject(err);
        resolve(stdout.trim());
      }
    );
  });
}

function json(res, code, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(body);
}

const allowed = new Set(['inbox','sent','deliverables','dropbox','drafts','documents']);

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    return res.end();
  }

  try {
    // /api/list/:folder
    if (req.method === 'GET' && url.pathname.startsWith('/api/list/')) {
      const folder = url.pathname.slice('/api/list/'.length);
      if (!allowed.has(folder)) return json(res, 400, { error: 'Invalid folder' });

      const abs = await resolveKey(`human:${folder}`);
      const dirEntries = await fs.readdir(abs, { withFileTypes: true });
      const files = dirEntries.filter(e => e.isFile() && !e.name.startsWith('.'));

      const items = await Promise.all(files.map(async e => {
        const full = path.join(abs, e.name);
        const st = await fs.stat(full);
        return {
          id: e.name,
          name: e.name,
          path: path.relative(repoRoot, full),
          size: st.size,
          updatedAt: st.mtime.toISOString(),
        };
      }));

      return json(res, 200, { mailbox: folder, items });
    }

    // /api/file/:folder/:name
    if (req.method === 'GET' && url.pathname.startsWith('/api/file/')) {
      const parts = url.pathname.split('/').filter(Boolean); // ['api','file',folder, ...name]
      const folder = parts[2];
      const name = parts.slice(3).join('/'); // allow nested if any

      if (!folder || !name) return json(res, 400, { error: 'folder and name required' });
      if (!allowed.has(folder)) return json(res, 400, { error: 'Invalid folder' });

      const abs = await resolveKey(`human:${folder}`);
      const full = path.resolve(abs, name);

      // ป้องกัน path traversal
      const rel = path.relative(abs, full);
      if (rel.startsWith('..') || path.isAbsolute(rel)) {
        return json(res, 400, { error: 'Invalid path' });
      }

      try {
        const stat = await fs.stat(full);
        if (!stat.isFile()) return json(res, 404, { error: 'not found' });
        const data = await fs.readFile(full, 'utf8');
        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8',
          'Access-Control-Allow-Origin': '*'
        });
        return res.end(data);
      } catch {
        return json(res, 404, { error: 'not found' });
      }
    }

    return json(res, 404, { error: 'Not Found' });
  } catch (e) {
    console.error('[boss-api]', e.message || e);
    return json(res, 500, { error: 'Internal Server Error' });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`boss-api listening on http://${HOST}:${PORT}`);
});
