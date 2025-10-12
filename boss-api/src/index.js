import express from 'express';
import dotenv from 'dotenv';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { crawlUrls, allowlistHasHost, normalizeUrl } from './crawler.js';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const HOST = process.env.HOST || '127.0.0.1';
const PORT = process.env.PORT || 4000;
const defaultSotPath = path.resolve(__dirname, '..', '..');
const SOT_PATH = process.env.SOT_PATH || defaultSotPath;
const pathResolverScript = path.resolve(__dirname, '..', '..', 'g', 'tools', 'path_resolver.sh');
const execFileAsync = promisify(execFile);

const DEFAULT_ALLOWLIST_RELATIVE = 'g/policies/crawling_allowlist.txt';
const allowlistFileEnv = process.env.CRAWL_ALLOWLIST_FILE || DEFAULT_ALLOWLIST_RELATIVE;
const CRAWL_ALLOWLIST_PATH = path.resolve(defaultSotPath, allowlistFileEnv);
const CRAWL_ALLOWLIST_FILE = allowlistFileEnv;
const CRAWL_MAX_PAGES = Number.parseInt(process.env.CRAWL_MAX_PAGES || '200', 10);
const CRAWL_PER_DOMAIN = Number.parseInt(process.env.CRAWL_PER_DOMAIN || '20', 10);
const CRAWL_USER_AGENT = process.env.CRAWL_USER_AGENT || '02LUKA-PaulaCrawler/1.0 (+ops@theedges.work)';
const SCRUB_PII = String(process.env.SCRUB_PII || 'false').toLowerCase() === 'true';
const ENABLE_EMBED = String(process.env.ENABLE_EMBED || 'false').toLowerCase() === 'true';
const CONFIG_FILE_PATH = path.resolve(defaultSotPath, 'config.json');
const DEFAULT_BASE = `http://${HOST}:${PORT}`;

let cachedAllowlist = { domains: new Set(), mtimeMs: 0 };

// Add middleware for better performance
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

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

async function loadAllowlist() {
  try {
    const stats = await fs.stat(CRAWL_ALLOWLIST_PATH);
    if (cachedAllowlist.mtimeMs === stats.mtimeMs) {
      return cachedAllowlist.domains;
    }
    const raw = await fs.readFile(CRAWL_ALLOWLIST_PATH, 'utf8');
    const domains = new Set(
      raw
        .split(/\r?\n/)
        .map((line) => line.trim().toLowerCase())
        .filter((line) => line && !line.startsWith('#'))
    );
    cachedAllowlist = { domains, mtimeMs: stats.mtimeMs };
    return domains;
  } catch (error) {
    if (error.code === 'ENOENT') {
      cachedAllowlist = { domains: new Set(), mtimeMs: 0 };
      return cachedAllowlist.domains;
    }
    throw error;
  }
}

async function loadRuntimeConfig() {
  try {
    const raw = await fs.readFile(CONFIG_FILE_PATH, 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    if (error.code === 'ENOENT') {
      return {};
    }
    throw error;
  }
}

function clampNumber(value, fallback, maxValue) {
  const parsed = Number.parseInt(String(value), 10);
  if (Number.isFinite(parsed) && parsed > 0) {
    if (Number.isFinite(maxValue) && maxValue > 0) {
      return Math.min(parsed, maxValue);
    }
    return parsed;
  }
  return fallback;
}

function validateSeeds(rawSeeds, allowlist) {
  if (!Array.isArray(rawSeeds) || rawSeeds.length === 0) {
    const error = new Error('Seeds array is required');
    error.status = 400;
    error.code = 'seeds_required';
    throw error;
  }

  const normalized = [];
  const disallowed = new Set();

  for (const rawSeed of rawSeeds) {
    if (typeof rawSeed !== 'string') {
      const error = new Error('Seed must be a string URL');
      error.status = 400;
      error.code = 'invalid_seed';
      throw error;
    }
    const trimmed = rawSeed.trim();
    if (!trimmed) {
      const error = new Error('Seed URL cannot be empty');
      error.status = 400;
      error.code = 'invalid_seed';
      throw error;
    }
    const normalizedSeed = normalizeUrl(trimmed);
    if (!normalizedSeed) {
      const error = new Error(`Invalid seed URL: ${rawSeed}`);
      error.status = 400;
      error.code = 'invalid_seed';
      throw error;
    }
    normalized.push(normalizedSeed);
    const host = new URL(normalizedSeed).hostname.toLowerCase();
    if (!allowlistHasHost(host, allowlist)) {
      disallowed.add(host);
    }
  }

  return { normalized, disallowed: Array.from(disallowed) };
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

app.get('/config.json', async (req, res) => {
  try {
    const runtimeConfig = await loadRuntimeConfig();
    const baseConfig = runtimeConfig && typeof runtimeConfig === 'object' ? runtimeConfig : {};
    const agents = { ...(baseConfig.agents || {}) };
    const gateways = { ...(baseConfig.gateways || {}) };

    if (!agents.paula) {
      agents.paula = {
        url: 'http://127.0.0.1:5002',
        name: '🤖 Paula Agent',
        type: 'agent'
      };
    }

    if (!gateways.paula && agents.paula) {
      gateways.paula = agents.paula;
    }

    const config = {
      ...baseConfig,
      apiBase: baseConfig.apiBase || DEFAULT_BASE,
      aiBase: baseConfig.aiBase || baseConfig.apiBase || DEFAULT_BASE,
      agents,
      gateways,
      crawler: {
        ...(baseConfig.crawler || {}),
        allowlistFile: CRAWL_ALLOWLIST_FILE,
        maxPages: CRAWL_MAX_PAGES,
        perDomain: CRAWL_PER_DOMAIN,
        userAgent: CRAWL_USER_AGENT,
        scrubPII: SCRUB_PII,
        enableEmbed: ENABLE_EMBED
      }
    };

    res.json(config);
  } catch (error) {
    console.error('[config] load failed', error);
    res.status(500).json(buildError('Failed to load runtime config', 'config_load_failed'));
  }
});

app.post('/api/crawl', async (req, res) => {
  try {
    const allowlist = await loadAllowlist();
    const { normalized, disallowed } = validateSeeds(req.body?.seeds, allowlist);

    if (disallowed.length > 0) {
      return res.status(400).json({ error: 'seed_domain_not_allowed', disallowed });
    }

    if (normalized.length === 0) {
      return res.status(400).json(buildError('No seeds were allowlisted', 'no_allowlisted_seeds'));
    }

    const requestedMaxPages = clampNumber(req.body?.maxPages, CRAWL_MAX_PAGES, CRAWL_MAX_PAGES);
    const requestedPerDomain = clampNumber(req.body?.perDomain, CRAWL_PER_DOMAIN, CRAWL_PER_DOMAIN);
    const effectivePerDomain = Math.max(1, Math.min(requestedPerDomain, requestedMaxPages));

    const crawlResults = await crawlUrls(normalized, {
      maxPages: requestedMaxPages,
      perDomain: effectivePerDomain,
      allowlist,
      userAgent: CRAWL_USER_AGENT,
      scrubPII: SCRUB_PII
    });

    const body = crawlResults.map((record) => JSON.stringify(record)).join('\n');
    res.setHeader('Content-Type', 'application/x-ndjson');
    res.status(200).send(body);
  } catch (error) {
    console.error('[crawl] failed', error);
    const status = error.status || 500;
    const payload = error.code
      ? { error: error.code, message: error.message }
      : buildError('Crawl failed', 'crawl_failed');
    if (!res.headersSent) {
      res.status(status).json(payload);
    }
  }
});

app.use((req, res) => {
  res.status(404).json(buildError('Not found', 'not_found'));
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Boss API listening on port ${PORT}`);
});
