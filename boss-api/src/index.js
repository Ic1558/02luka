import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { promisify } from 'util';
import { execFile } from 'child_process';
import fs from 'fs/promises';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SOT_PATH = process.env.SOT_PATH || path.resolve(__dirname, '..', '..');
const RESOLVER_SCRIPT = path.join(SOT_PATH, 'g', 'tools', 'path_resolver.sh');
const PORT = process.env.PORT || 4000;

const ALLOWED_FOLDERS = new Set([
  'inbox',
  'sent',
  'deliverables',
  'dropbox',
  'drafts',
  'documents'
]);

const execFileAsync = promisify(execFile);

class HttpError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}

async function resolveFolder(folder) {
  if (!ALLOWED_FOLDERS.has(folder)) {
    throw new HttpError(400, `Unsupported folder: ${folder}`);
  }

  const mappingKey = `human:${folder}`;

  try {
    const { stdout } = await execFileAsync('bash', [RESOLVER_SCRIPT, mappingKey], {
      cwd: SOT_PATH,
      env: { ...process.env, SOT_PATH }
    });
    return stdout.trim();
  } catch (error) {
    throw new HttpError(500, `Failed to resolve path for ${folder}`);
  }
}

async function listFiles(folderPath) {
  try {
    const entries = await fs.readdir(folderPath, { withFileTypes: true });
    return entries.filter((entry) => entry.isFile()).map((entry) => entry.name).sort();
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new HttpError(404, 'Folder not found');
    }

    throw new HttpError(500, 'Failed to list files');
  }
}

async function readFileSafe(folderPath, fileName) {
  const requestedPath = path.join(folderPath, fileName);
  const normalizedPath = path.normalize(requestedPath);
  const relativePath = path.relative(folderPath, normalizedPath);

  if (relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
    throw new HttpError(400, 'Invalid file path');
  }

  try {
    const content = await fs.readFile(normalizedPath, 'utf8');
    return content;
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new HttpError(404, `File not found: ${fileName}`);
    }

    throw new HttpError(500, 'Failed to read file');
  }
}

function handleError(res, error) {
  const statusCode = error.statusCode || 500;
  const message = error.message || 'Internal server error';
  res.status(statusCode).json({ message, code: statusCode });
}

const app = express();
app.use(cors());

app.get('/api/list/:folder', async (req, res) => {
  try {
    const folder = req.params.folder;
    const folderPath = await resolveFolder(folder);
    const files = await listFiles(folderPath);
    res.json({ folder, files });
  } catch (error) {
    handleError(res, error);
  }
});

app.get('/api/file/:folder/:name', async (req, res) => {
  try {
    const { folder, name } = req.params;
    const folderPath = await resolveFolder(folder);
    const content = await readFileSafe(folderPath, name);
    res.json({ folder, name, content });
  } catch (error) {
    handleError(res, error);
  }
});

app.use((req, res) => {
  res.status(404).json({ message: 'Not found', code: 404 });
});

app.listen(PORT, () => {
  console.log(`Boss API running on port ${PORT}`);
});
