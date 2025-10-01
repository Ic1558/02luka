const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const fsp = require('fs/promises');
const { execFile } = require('child_process');
const util = require('util');

const execFileAsync = util.promisify(execFile);

const PORT = Number(process.env.PORT || 4000);
const HOST = process.env.HOST || '127.0.0.1';
const ROOT = path.resolve(__dirname, '..');
const PATH_RESOLVER = path.join(ROOT, 'g', 'tools', 'path_resolver.sh');

const MAILBOX_KEYS = new Map([
  ['inbox', 'human:inbox'],
  ['sent', 'human:sent'],
  ['deliverables', 'human:deliverables'],
  ['dropbox', 'human:dropbox'],
]);

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

async function resolvePath(key) {
  const mapping = MAILBOX_KEYS.get(key);
  if (!mapping) {
    const err = new Error('Unknown mailbox');
    err.statusCode = 404;
    throw err;
  }
  const [namespace, mailbox] = mapping.split(':');
  try {
    const { stdout } = await execFileAsync(PATH_RESOLVER, [`${namespace}:${mailbox}`], {
      cwd: ROOT,
      encoding: 'utf8',
    });
    return stdout.trim();
  } catch (error) {
    error.statusCode = 500;
    throw error;
  }
}

function assertSafeName(name) {
  if (!name || name.includes('..') || name.includes('/') || name.includes('\\')) {
    const err = new Error('Invalid name');
    err.statusCode = 400;
    throw err;
  }
}

app.get('/api/list/:mailbox', async (req, res) => {
  try {
    const mailboxKey = req.params.mailbox;
    const dirPath = await resolvePath(mailboxKey);
    const entries = await fsp.readdir(dirPath, { withFileTypes: true });
    const files = await Promise.all(
      entries
        .filter((entry) => entry.isFile())
        .map(async (entry) => {
          const fullPath = path.join(dirPath, entry.name);
          const stats = await fsp.stat(fullPath);
          return {
            name: entry.name,
            size: stats.size,
            modified: stats.mtime.toISOString(),
          };
        })
    );
    res.json({ mailbox: mailboxKey, files });
  } catch (error) {
    const status = error.statusCode || 500;
    res.status(status).json({ error: error.message });
  }
});

app.get('/api/file/:mailbox/:name', async (req, res) => {
  try {
    const mailboxKey = req.params.mailbox;
    const fileName = req.params.name;
    assertSafeName(fileName);
    const dirPath = await resolvePath(mailboxKey);
    const fullPath = path.join(dirPath, fileName);
    const relative = path.relative(dirPath, fullPath);
    if (relative.startsWith('..')) {
      throw Object.assign(new Error('Invalid path'), { statusCode: 400 });
    }
    await fsp.access(fullPath, fs.constants.R_OK);
    res.sendFile(fullPath);
  } catch (error) {
    const status = error.statusCode || (error.code === 'ENOENT' ? 404 : 500);
    res.status(status).json({ error: error.message });
  }
});

async function runValidation(command, args = []) {
  try {
    const { stdout, stderr } = await execFileAsync(command, args, {
      cwd: ROOT,
      encoding: 'utf8',
    });
    return { success: true, stdout, stderr };
  } catch (error) {
    return {
      success: false,
      stdout: error.stdout || '',
      stderr: error.stderr || error.message,
    };
  }
}

app.post('/api/validate/preflight', async (_req, res) => {
  const script = path.join(ROOT, '.codex', 'preflight.sh');
  const result = await runValidation(script, []);
  res.json(result);
});

app.post('/api/validate/drift_guard', async (_req, res) => {
  const script = path.join(ROOT, 'g', 'tools', 'mapping_drift_guard.sh');
  const result = await runValidation(script, ['--validate']);
  res.json(result);
});

app.post('/api/validate/gate', async (req, res) => {
  const scope = req.body?.scope || 'precommit';
  const allowed = new Set(['precommit', 'security', 'all']);
  if (!allowed.has(scope)) {
    return res.status(400).json({ error: 'Invalid scope' });
  }
  const script = path.join(ROOT, 'g', 'tools', 'clc_gate.sh');
  const args = ['--scope=' + scope];
  const result = await runValidation(script, args);
  res.json({ scope, ...result });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.listen(PORT, HOST, () => {
  console.log(`boss-api server listening on http://${HOST}:${PORT}`);
});
