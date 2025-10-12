import express from 'express';
import dotenv from 'dotenv';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const require = createRequire(import.meta.url);
const { createPaulaRouter } = require('./paula/index.cjs');

const app = express();
const PORT = process.env.PORT || 4000;
const defaultSotPath = path.resolve(__dirname, '..', '..');
const SOT_PATH = process.env.SOT_PATH || defaultSotPath;
const pathResolverScript = path.resolve(__dirname, '..', '..', 'g', 'tools', 'path_resolver.sh');
const execFileAsync = promisify(execFile);

// Add middleware for better performance
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use('/api/paula', createPaulaRouter({
  enableEmbeddings: process.env.PAULA_ENABLE_EMBEDDINGS === '1',
  maxConcurrency: Number.parseInt(process.env.PAULA_MAX_CONCURRENCY || '4', 10),
  embeddingBatchSize: Number.parseInt(process.env.PAULA_EMBED_BATCH || '64', 10)
}));

// Add CORS headers for better performance
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.header('Cache-Control', 'public, max-age=300'); // 5 minutes cache
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Simple in-memory cache with size limits
const cache = new Map();
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes
const MAX_CACHE_SIZE = 100; // Maximum number of cached items
const MAX_CACHE_MEMORY = 50 * 1024 * 1024; // 50MB max cache memory

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

// Cache utility functions
function getCached(key) {
  const cached = cache.get(key);
  if (cached && (Date.now() - cached.timestamp) < CACHE_DURATION) {
    return cached.data;
  }
  cache.delete(key);
  return null;
}

function setCached(key, data) {
  // Check cache size limits
  if (cache.size >= MAX_CACHE_SIZE) {
    // Remove oldest entries
    const entries = Array.from(cache.entries());
    entries.sort((a, b) => a[1].timestamp - b[1].timestamp);
    const toRemove = Math.floor(MAX_CACHE_SIZE * 0.2); // Remove 20% of cache
    for (let i = 0; i < toRemove; i++) {
      cache.delete(entries[i][0]);
    }
  }
  
  // Check memory usage
  const dataSize = JSON.stringify(data).length;
  if (dataSize > MAX_CACHE_MEMORY / 10) { // If single item is > 10% of max memory
    console.warn(`Large cache item detected: ${dataSize} bytes`);
  }
  
  cache.set(key, {
    data,
    timestamp: Date.now(),
    size: dataSize
  });
}

// Clean up old cache entries periodically
setInterval(() => {
  const now = Date.now();
  let cleaned = 0;
  for (const [key, value] of cache.entries()) {
    if ((now - value.timestamp) > CACHE_DURATION) {
      cache.delete(key);
      cleaned++;
    }
  }
  if (cleaned > 0) {
    console.log(`Cache cleanup: removed ${cleaned} expired entries`);
  }
}, CACHE_DURATION);

// Memory monitoring and garbage collection
setInterval(() => {
  const memUsage = process.memoryUsage();
  const cacheSize = cache.size;
  const cacheMemory = Array.from(cache.values()).reduce((sum, item) => sum + (item.size || 0), 0);
  
  console.log(`Memory: RSS=${Math.round(memUsage.rss/1024/1024)}MB, Cache: ${cacheSize} items (${Math.round(cacheMemory/1024)}KB)`);
  
  // Force garbage collection if memory usage is high
  if (memUsage.rss > 100 * 1024 * 1024) { // 100MB
    if (global.gc) {
      global.gc();
      console.log('Forced garbage collection');
    }
  }
  
  // Clear cache if it's too large
  if (cacheMemory > MAX_CACHE_MEMORY) {
    console.log('Cache too large, clearing...');
    cache.clear();
  }
}, 30000); // Every 30 seconds

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
    const cacheKey = `list-${folderKey}`;
    
    // Check cache first
    const cached = getCached(cacheKey);
    if (cached) {
      return res.json(cached);
    }

    const folderPath = await resolveFolder(folderKey);
    await fs.access(folderPath);
    const entries = await fs.readdir(folderPath, { withFileTypes: true });
    const files = entries
      .filter((entry) => entry.isFile())
      .map((entry) => ({ name: entry.name }))
      .sort((a, b) => a.name.localeCompare(b.name)); // Sort for consistent ordering

    const result = { files };
    setCached(cacheKey, result);
    res.json(result);
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
    const cacheKey = `file-${folder}-${name}`;
    
    // Check cache first
    const cached = getCached(cacheKey);
    if (cached) {
      return res.json(cached);
    }

    const folderPath = await resolveFolder(folder);
    const filePath = ensureChildPath(folderPath, name);
    
    // Get file stats for better caching
    const stats = await fs.stat(filePath);
    const content = await fs.readFile(filePath, 'utf8');

    const result = { name, content, size: stats.size, modified: stats.mtime };
    setCached(cacheKey, result);
    res.json(result);
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
