import express from 'express';
import dotenv from 'dotenv';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 4000;
const defaultSotPath = path.resolve(__dirname, '..', '..');
const SOT_PATH = process.env.SOT_PATH || defaultSotPath;
const pathResolverScript = path.resolve(__dirname, '..', '..', 'g', 'tools', 'path_resolver.sh');
const execFileAsync = promisify(execFile);

const allowedFolders = new Set([
  'inbox',
  'sent',
  'deliverables',
  'dropbox',
  'drafts',
  'documents'
]);

function buildError(message, code = 'internal_error') {
  return { message, code };
}

async function resolveFolder(folder) {
  if (!allowedFolders.has(folder)) {
    const error = new Error(`Unknown folder: ${folder}`);
    error.status = 400;
    error.code = 'unknown_folder';
    throw error;
  }

  const { stdout } = await execFileAsync('bash', [pathResolverScript, `human:${folder}`], {
    env: {
      ...process.env,
      SOT_PATH
    }
  });

  return stdout.trim();
}

function ensureChildPath(parent, child) {
  const resolved = path.resolve(parent, child);
  const relative = path.relative(parent, resolved);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    const error = new Error('Invalid path traversal detected');
    error.status = 400;
    error.code = 'invalid_path';
    throw error;
  }
  return resolved;
}

app.get('/api/list/:folder', async (req, res) => {
  try {
    const folderKey = req.params.folder;
    const folderPath = await resolveFolder(folderKey);
    await fs.access(folderPath);
    const entries = await fs.readdir(folderPath, { withFileTypes: true });
    const files = entries
      .filter((entry) => entry.isFile())
      .map((entry) => ({ name: entry.name }));

    res.json({ files });
  } catch (error) {
    if (error.code === 'ENOENT') {
      error.status = error.status || 404;
      error.code = 'folder_not_found';
    }
    const status = error.status || 500;
    res.status(status).json(buildError(error.message, error.code || 'internal_error'));
  }
});

app.get('/api/file/:folder/:name', async (req, res) => {
  try {
    const { folder, name } = req.params;
    const folderPath = await resolveFolder(folder);
    const filePath = ensureChildPath(folderPath, name);
    const content = await fs.readFile(filePath, 'utf8');

    res.json({ name, content });
  } catch (error) {
    const status = error.status || (error.code === 'ENOENT' ? 404 : 500);
    const code = error.code === 'ENOENT' ? 'file_not_found' : error.code || 'internal_error';
    res.status(status).json(buildError(error.message, code));
  }
});

app.use((req, res) => {
  res.status(404).json(buildError('Not found', 'not_found'));
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Boss API listening on port ${PORT}`);
});
