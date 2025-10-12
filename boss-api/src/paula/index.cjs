const { Router } = require('express');
const { Agent, fetch } = require('undici');
const { LRUCache } = require('lru-cache');
const dns = require('node:dns');
const path = require('node:path');
const fs = require('node:fs/promises');
const crypto = require('node:crypto');
const { performance } = require('node:perf_hooks');
const sqlite3 = require('sqlite3');

const DEFAULT_USER_AGENT = 'PaulaCrawler/1.0 (+https://github.com/Ic1558/02luka)';
const MAX_HTML_BYTES = 2 * 1024 * 1024; // 2MB safety limit
const EMBEDDING_DIMS = 64;
let flushHookInstalled = false;

class DNSCache {
  constructor({ ttl = 5 * 60 * 1000, max = 512 } = {}) {
    this.cache = new LRUCache({ max, ttl, allowStale: false });
    this.stats = { hits: 0, misses: 0 };
  }

  lookup(hostname, options, callback) {
    const key = `${hostname}:${options.family || 'all'}`;
    const cached = this.cache.get(key);
    if (cached) {
      this.stats.hits += 1;
      callback(null, cached.address, cached.family);
      return;
    }

    dns.promises
      .lookup(hostname, { ...options, all: false })
      .then((addressInfo) => {
        this.cache.set(key, addressInfo);
        this.stats.misses += 1;
        callback(null, addressInfo.address, addressInfo.family);
      })
      .catch((error) => callback(error));
  }
}

class HttpClient {
  constructor({ timeout = 15000, userAgent = DEFAULT_USER_AGENT } = {}) {
    this.timeout = timeout;
    this.userAgent = userAgent;
    this.dnsCache = new DNSCache();
    this.agent = new Agent({
      connect: { timeout: timeout / 2 },
      allowH2: true,
      keepAliveTimeout: 60 * 1000,
      keepAliveMaxTimeout: 120 * 1000,
      maxRedirections: 5,
      pipelining: 1,
      headersTimeout: timeout,
      bodyTimeout: timeout,
      keepAlive: true,
      keepSocketTimeout: true,
      maxCachedSessions: 128,
      socketPath: null,
      highWaterMark: 32,
      maxHeaderSize: 8192,
      connectTimeout: timeout / 2,
      lookup: this.dnsCache.lookup.bind(this.dnsCache)
    });

    this.metadataCache = new LRUCache({ max: 2048, ttl: 60 * 60 * 1000 });
    this.stats = {
      requests: 0,
      responses: 0,
      notModified: 0,
      networkErrors: 0
    };
  }

  getDnsStats() {
    return { ...this.dnsCache.stats };
  }

  rememberMetadata(url, headers) {
    const etag = headers.get('etag') || null;
    const lastModified = headers.get('last-modified') || null;
    if (!etag && !lastModified) {
      return;
    }

    const record = this.metadataCache.get(url) || {};
    this.metadataCache.set(url, {
      ...record,
      etag: etag || record.etag || null,
      lastModified: lastModified || record.lastModified || null,
      storedAt: Date.now()
    });
  }

  getMetadata(url) {
    return this.metadataCache.get(url) || null;
  }

  async fetch(url, { conditional = true, maxBytes = MAX_HTML_BYTES } = {}) {
    const headers = {
      'User-Agent': this.userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive'
    };

    const metadata = conditional ? this.getMetadata(url) : null;
    if (metadata) {
      if (metadata.etag) {
        headers['If-None-Match'] = metadata.etag;
      }
      if (metadata.lastModified) {
        headers['If-Modified-Since'] = metadata.lastModified;
      }
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    this.stats.requests += 1;

    try {
      const response = await fetch(url, {
        dispatcher: this.agent,
        redirect: 'follow',
        signal: controller.signal,
        headers
      });

      this.stats.responses += 1;

      if (response.status === 304) {
        this.stats.notModified += 1;
        return { response, notModified: true, body: null };
      }

      if (response.status >= 400) {
        return { response, notModified: false, body: null };
      }

      this.rememberMetadata(url, response.headers);

      if (!response.body) {
        return { response, notModified: false, body: '' };
      }

      let bytesRead = 0;
      let chunks = [];
      const reader = response.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        bytesRead += value.length;
        if (bytesRead > maxBytes) {
          reader.cancel('Payload exceeds limit');
          throw new Error('response_too_large');
        }
        chunks.push(value);
      }
      const buffer = Buffer.concat(chunks);
      const text = buffer.toString('utf8');

      return { response, notModified: false, body: text };
    } catch (error) {
      this.stats.networkErrors += 1;
      throw error;
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

class RobotsCache {
  constructor(httpClient, { ttl = 30 * 60 * 1000, max = 256 } = {}) {
    this.httpClient = httpClient;
    this.cache = new LRUCache({ max, ttl, allowStale: false });
  }

  async isAllowed(url) {
    try {
      const parsed = new URL(url);
      const origin = `${parsed.protocol}//${parsed.host}`;
      const pathname = parsed.pathname || '/';
      const robots = await this.#getRules(origin);
      return robots.allows(pathname);
    } catch (error) {
      return true;
    }
  }

  async #getRules(origin) {
    const cached = this.cache.get(origin);
    if (cached) {
      return cached;
    }

    const robotsUrl = `${origin}/robots.txt`;
    try {
      const { response, body } = await this.httpClient.fetch(robotsUrl, { conditional: false, maxBytes: 128 * 1024 });
      if (!body || response.status >= 400) {
        const rules = RobotsRules.allowAll();
        this.cache.set(origin, rules);
        return rules;
      }
      const rules = RobotsRules.fromText(body);
      this.cache.set(origin, rules);
      return rules;
    } catch (error) {
      const rules = RobotsRules.allowAll();
      this.cache.set(origin, rules);
      return rules;
    }
  }
}

class RobotsRules {
  constructor(allow = [], disallow = []) {
    this.allow = allow;
    this.disallow = disallow;
  }

  allows(pathname) {
    const path = pathname || '/';
    const matches = [];

    for (const rule of this.disallow) {
      if (rule.regex.test(path)) {
        matches.push({ rule, type: 'disallow' });
      }
    }

    for (const rule of this.allow) {
      if (rule.regex.test(path)) {
        matches.push({ rule, type: 'allow' });
      }
    }

    if (matches.length === 0) {
      return true;
    }

    matches.sort((a, b) => b.rule.length - a.rule.length);
    return matches[0].type === 'allow';
  }

  static allowAll() {
    return new RobotsRules();
  }

  static fromText(text) {
    const lines = text.split(/\r?\n/);
    const allow = [];
    const disallow = [];
    let apply = false;

    for (const raw of lines) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) {
        continue;
      }
      const [directive, valueRaw] = line.split(':', 2);
      if (!directive || typeof valueRaw === 'undefined') {
        continue;
      }
      const value = valueRaw.trim();
      const lower = directive.trim().toLowerCase();

      if (lower === 'user-agent') {
        const ua = value === '*' ? '*' : value.toLowerCase();
        apply = ua === '*' || ua.includes('paula');
      } else if (apply && lower === 'allow') {
        const rule = RobotsRules.#compileRule(value);
        allow.push(rule);
      } else if (apply && lower === 'disallow') {
        const rule = RobotsRules.#compileRule(value);
        disallow.push(rule);
      }
    }

    return new RobotsRules(allow, disallow);
  }

  static #compileRule(pattern) {
    if (!pattern || pattern === '*') {
      return { regex: /^.*$/i, length: Number.MAX_SAFE_INTEGER };
    }

    const escaped = pattern.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
    const regex = new RegExp(`^${escaped}`, 'i');
    return { regex, length: pattern.length };
  }
}

class PaulaStorage {
  constructor(dbPath) {
    this.dbPath = dbPath;
    this.db = null;
    this.pendingPages = [];
    this.pendingEmbeddings = [];
    this.pageBatchSize = 32;
    this.embeddingBatchSize = 32;
    this.initialized = false;
  }

  async init() {
    if (this.initialized) {
      return;
    }

    await fs.mkdir(path.dirname(this.dbPath), { recursive: true });
    await new Promise((resolve, reject) => {
      const database = new sqlite3.Database(this.dbPath, sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE, (error) => {
        if (error) {
          reject(error);
        } else {
          this.db = database;
          resolve();
        }
      });
    });

    await this.#runExec(`
      PRAGMA journal_mode=WAL;
      CREATE TABLE IF NOT EXISTS jobs (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        dry_run INTEGER NOT NULL,
        max_pages INTEGER,
        total_fetched INTEGER DEFAULT 0,
        total_skipped INTEGER DEFAULT 0,
        total_errors INTEGER DEFAULT 0,
        total_bytes INTEGER DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS pages (
        job_id TEXT NOT NULL,
        url TEXT NOT NULL,
        status_code INTEGER,
        content_type TEXT,
        content_length INTEGER,
        fetched_at TEXT,
        etag TEXT,
        last_modified TEXT,
        content TEXT,
        content_hash TEXT,
        PRIMARY KEY (job_id, url)
      );
      CREATE TABLE IF NOT EXISTS embeddings (
        job_id TEXT NOT NULL,
        url TEXT NOT NULL,
        vector TEXT NOT NULL,
        dims INTEGER NOT NULL,
        PRIMARY KEY (job_id, url)
      );
    `);

    this.initialized = true;
  }

  async #runExec(sql) {
    await new Promise((resolve, reject) => {
      this.db.exec(sql, (error) => (error ? reject(error) : resolve()));
    });
  }

  async ensureJob(job) {
    await this.init();
    await new Promise((resolve, reject) => {
      this.db.run(
        `INSERT OR IGNORE INTO jobs (id, created_at, dry_run, max_pages) VALUES (?, ?, ?, ?)` ,
        [job.id, job.createdAt, job.dryRun ? 1 : 0, job.maxPages || null],
        (error) => (error ? reject(error) : resolve())
      );
    });
  }

  queuePage(record) {
    this.pendingPages.push(record);
    if (this.pendingPages.length >= this.pageBatchSize) {
      return this.flushPages();
    }
    return Promise.resolve();
  }

  queueEmbedding(record) {
    this.pendingEmbeddings.push(record);
    if (this.pendingEmbeddings.length >= this.embeddingBatchSize) {
      return this.flushEmbeddings();
    }
    return Promise.resolve();
  }

  async flushAll() {
    await this.flushPages();
    await this.flushEmbeddings();
  }

  async flushPages() {
    if (!this.pendingPages.length) {
      return;
    }
    await this.init();
    const items = this.pendingPages.splice(0);
    await new Promise((resolve, reject) => {
      this.db.serialize(() => {
        this.db.run('BEGIN IMMEDIATE', (beginErr) => {
          if (beginErr) {
            reject(beginErr);
            return;
          }
          const stmt = this.db.prepare(
            `INSERT OR REPLACE INTO pages (job_id, url, status_code, content_type, content_length, fetched_at, etag, last_modified, content, content_hash)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          , (prepErr) => {
            if (prepErr) {
              this.db.run('ROLLBACK', () => reject(prepErr));
              return;
            }
          });

          for (const item of items) {
            stmt.run(
              [
                item.jobId,
                item.url,
                item.statusCode || null,
                item.contentType || null,
                item.contentLength || null,
                item.fetchedAt || null,
                item.etag || null,
                item.lastModified || null,
                item.content || null,
                item.contentHash || null
              ],
              (runErr) => {
                if (runErr) {
                  this.db.run('ROLLBACK', () => reject(runErr));
                }
              }
            );
          }

          stmt.finalize((finalizeErr) => {
            if (finalizeErr) {
              this.db.run('ROLLBACK', () => reject(finalizeErr));
              return;
            }
            this.db.run('COMMIT', (commitErr) => (commitErr ? reject(commitErr) : resolve()));
          });
        });
      });
    });
  }

  async flushEmbeddings() {
    if (!this.pendingEmbeddings.length) {
      return;
    }
    await this.init();
    const items = this.pendingEmbeddings.splice(0);
    await new Promise((resolve, reject) => {
      this.db.serialize(() => {
        this.db.run('BEGIN IMMEDIATE', (beginErr) => {
          if (beginErr) {
            reject(beginErr);
            return;
          }
          const stmt = this.db.prepare(
            `INSERT OR REPLACE INTO embeddings (job_id, url, vector, dims) VALUES (?, ?, ?, ?)`
          , (prepErr) => {
            if (prepErr) {
              this.db.run('ROLLBACK', () => reject(prepErr));
              return;
            }
          });

          for (const item of items) {
            stmt.run(
              [item.jobId, item.url, JSON.stringify(item.vector), item.dims],
              (runErr) => {
                if (runErr) {
                  this.db.run('ROLLBACK', () => reject(runErr));
                }
              }
            );
          }

          stmt.finalize((finalizeErr) => {
            if (finalizeErr) {
              this.db.run('ROLLBACK', () => reject(finalizeErr));
              return;
            }
            this.db.run('COMMIT', (commitErr) => (commitErr ? reject(commitErr) : resolve()));
          });
        });
      });
    });
  }

  async updateJobTotals(job) {
    await new Promise((resolve, reject) => {
      this.db.run(
        `UPDATE jobs
         SET total_fetched = ?, total_skipped = ?, total_errors = ?, total_bytes = ?, completed_at = ?
         WHERE id = ?`,
        [
          job.stats.fetched,
          job.stats.skipped,
          job.stats.errors,
          job.stats.bytes,
          job.finishedAt || null,
          job.id
        ],
        (err) => (err ? reject(err) : resolve())
      );
    });
  }

  async getCorpusStats() {
    await this.init();
    const totals = await new Promise((resolve, reject) => {
      this.db.get(
        `SELECT COUNT(*) AS pages, IFNULL(SUM(content_length), 0) AS bytes FROM pages`,
        (err, row) => (err ? reject(err) : resolve(row))
      );
    });
    const embeddings = await new Promise((resolve, reject) => {
      this.db.get(
        `SELECT COUNT(*) AS total FROM embeddings`,
        (err, row) => (err ? reject(err) : resolve(row))
      );
    });
    return {
      pages: totals.pages || 0,
      totalBytes: totals.bytes || 0,
      embeddings: embeddings.total || 0
    };
  }
}

class EmbeddingQueue {
  constructor(storage, { enabled = false, batchSize = 64 } = {}) {
    this.storage = storage;
    this.enabled = enabled;
    this.batchSize = batchSize;
    this.buffer = [];
    this.generated = 0;
    this.batches = 0;
  }

  async enqueue(jobId, url, text) {
    if (!this.enabled) {
      return;
    }
    this.buffer.push({ jobId, url, text });
    if (this.buffer.length >= this.batchSize) {
      await this.flush();
    }
  }

  async flush() {
    if (!this.enabled || this.buffer.length === 0) {
      return;
    }
    const batch = this.buffer.splice(0);
    const vectors = batch.map((item) => ({
      jobId: item.jobId,
      url: item.url,
      vector: EmbeddingQueue.computeEmbedding(item.text),
      dims: EMBEDDING_DIMS
    }));
    for (const vector of vectors) {
      await this.storage.queueEmbedding(vector);
      this.generated += 1;
    }
    this.batches += 1;
  }

  static computeEmbedding(text) {
    const hash = crypto.createHash('sha256').update(text).digest();
    const values = [];
    for (let i = 0; i < EMBEDDING_DIMS; i += 1) {
      const byte = hash[i % hash.length];
      const normalized = (byte / 255) * 2 - 1;
      values.push(Number(normalized.toFixed(6)));
    }
    return values;
  }
}

class PaulaCrawler {
  constructor({ httpClient, robotsCache, storage, embeddingQueue, maxConcurrency = 4 }) {
    this.httpClient = httpClient;
    this.robotsCache = robotsCache;
    this.storage = storage;
    this.embeddingQueue = embeddingQueue;
    this.maxConcurrency = Math.max(1, maxConcurrency);
    this.jobs = new Map();
  }

  createJob({ seeds, maxPages, dryRun }) {
    const id = `job_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
    const normalizedSeeds = [...new Set(seeds.map((url) => this.#normalizeUrl(url)).filter(Boolean))];
    const allowedHosts = new Set(normalizedSeeds.map((url) => new URL(url).host));

    const job = {
      id,
      seeds: normalizedSeeds,
      maxPages: maxPages || 50,
      dryRun: Boolean(dryRun),
      status: 'pending',
      createdAt: new Date().toISOString(),
      startedAt: null,
      finishedAt: null,
      queue: [...normalizedSeeds],
      visited: new Set(),
      enqueued: new Set(normalizedSeeds),
      allowedHosts,
      inFlight: 0,
      cancelled: false,
      stats: {
        fetched: 0,
        skipped: 0,
        errors: 0,
        bytes: 0,
        notModified: 0,
        disallowed: 0,
        queued: normalizedSeeds.length,
        robotsRequests: 0,
        dns: { hits: 0, misses: 0 },
        embedVectors: 0,
        embedBatches: 0,
        durationMs: 0
      }
    };

    this.jobs.set(id, job);
    this.storage.ensureJob(job).catch(() => {});
    this.#run(job).catch((error) => {
      job.status = 'failed';
      job.finishedAt = new Date().toISOString();
      job.stats.errors += 1;
      job.failure = error.message;
    });
    return job;
  }

  getJob(jobId) {
    return this.jobs.get(jobId) || null;
  }

  async #run(job) {
    job.status = 'running';
    job.startedAt = new Date().toISOString();
    const start = performance.now();

    const workers = Array.from({ length: this.maxConcurrency }, () => this.#worker(job));
    await Promise.all(workers);

    job.finishedAt = new Date().toISOString();
    job.status = job.cancelled ? 'cancelled' : 'completed';
    job.stats.durationMs = Math.round(performance.now() - start);
    job.stats.dns = this.httpClient.getDnsStats();
    job.stats.embedVectors = this.embeddingQueue.generated;
    job.stats.embedBatches = this.embeddingQueue.batches;

    await this.storage.updateJobTotals(job).catch(() => {});
    await this.storage.flushAll().catch(() => {});
    await this.embeddingQueue.flush().catch(() => {});
  }

  async #worker(job) {
    while (!job.cancelled) {
      const nextUrl = this.#dequeue(job);
      if (!nextUrl) {
        if (job.inFlight > 0 || job.queue.length > 0) {
          await new Promise((resolve) => setTimeout(resolve, 25));
          continue;
        }
        break;
      }

      job.inFlight += 1;
      try {
        await this.#processUrl(job, nextUrl);
      } catch (error) {
        job.stats.errors += 1;
      } finally {
        job.inFlight -= 1;
      }
    }
  }

  #dequeue(job) {
    if (job.stats.fetched >= job.maxPages) {
      job.cancelled = true;
      return null;
    }
    return job.queue.shift() || null;
  }

  async #processUrl(job, url) {
    if (job.visited.has(url)) {
      job.stats.skipped += 1;
      return;
    }

    job.visited.add(url);

    const allowed = await this.#checkRobots(job, url);
    if (!allowed) {
      job.stats.disallowed += 1;
      return;
    }

    let fetchResult;
    try {
      fetchResult = await this.httpClient.fetch(url, { conditional: true });
    } catch (error) {
      job.stats.errors += 1;
      return;
    }

    const { response, notModified, body } = fetchResult;

    if (notModified) {
      job.stats.notModified += 1;
      job.stats.skipped += 1;
      return;
    }

    if (!response) {
      job.stats.errors += 1;
      return;
    }

    if (response.status >= 400) {
      job.stats.errors += 1;
      await this.storage.queuePage({
        jobId: job.id,
        url,
        statusCode: response.status,
        fetchedAt: new Date().toISOString(),
        contentType: response.headers.get('content-type')
      });
      return;
    }

    const contentType = response.headers.get('content-type') || '';
    const etag = response.headers.get('etag');
    const lastModified = response.headers.get('last-modified');
    const text = body || '';
    const contentLength = Buffer.byteLength(text, 'utf8');
    const contentHash = crypto.createHash('sha1').update(text).digest('hex');

    job.stats.fetched += 1;
    job.stats.bytes += contentLength;

    await this.storage.queuePage({
      jobId: job.id,
      url,
      statusCode: response.status,
      contentType,
      contentLength,
      fetchedAt: new Date().toISOString(),
      etag,
      lastModified,
      content: job.dryRun ? null : text,
      contentHash
    });

    if (!job.dryRun && contentType.includes('text')) {
      await this.embeddingQueue.enqueue(job.id, url, text);
    }

    if (contentType.includes('text/html')) {
      const links = this.#extractLinks(url, text);
      for (const link of links) {
        if (job.stats.fetched + job.queue.length >= job.maxPages) {
          break;
        }
        if (!job.allowedHosts.has(new URL(link).host)) {
          continue;
        }
        if (job.enqueued.has(link)) {
          continue;
        }
        job.queue.push(link);
        job.enqueued.add(link);
        job.stats.queued += 1;
      }
    }
  }

  async #checkRobots(job, url) {
    job.stats.robotsRequests += 1;
    return this.robotsCache.isAllowed(url);
  }

  #normalizeUrl(url) {
    try {
      const parsed = new URL(url);
      parsed.hash = '';
      if (!parsed.pathname) {
        parsed.pathname = '/';
      }
      return parsed.toString();
    } catch (error) {
      return null;
    }
  }

  #extractLinks(baseUrl, html) {
    const links = new Set();
    const base = new URL(baseUrl);
    const anchorRegex = /<a\s+[^>]*href\s*=\s*"([^"]+)"/gi;
    let match;
    while ((match = anchorRegex.exec(html)) !== null) {
      const href = match[1];
      if (!href || href.startsWith('javascript:') || href.startsWith('#')) {
        continue;
      }
      try {
        const absolute = new URL(href, base);
        if (absolute.protocol.startsWith('http')) {
          links.add(absolute.toString());
        }
      } catch (error) {
        continue;
      }
    }
    return Array.from(links);
  }
}

function createPaulaRouter(options = {}) {
  const router = Router();
  const dataDir = options.dataDir || path.resolve(__dirname, '..', '..', 'data');
  const dbPath = path.join(dataDir, 'paula.sqlite3');
  const httpClient = new HttpClient(options.httpClient || {});
  const robotsCache = new RobotsCache(httpClient);
  const storage = new PaulaStorage(dbPath);
  const embeddingQueue = new EmbeddingQueue(storage, {
    enabled: Boolean(options.enableEmbeddings),
    batchSize: options.embeddingBatchSize || 64
  });
  const crawler = new PaulaCrawler({
    httpClient,
    robotsCache,
    storage,
    embeddingQueue,
    maxConcurrency: options.maxConcurrency || 4
  });

  const flushOnExit = async () => {
    await Promise.allSettled([storage.flushAll(), embeddingQueue.flush()]);
  };

  if (!flushHookInstalled) {
    const handler = async function paulaFlushHandler() {
      await flushOnExit();
    };
    process.on('beforeExit', handler);
    process.on('SIGINT', async () => {
      await flushOnExit();
      process.exit(0);
    });
    process.on('SIGTERM', async () => {
      await flushOnExit();
      process.exit(0);
    });
    flushHookInstalled = true;
  }

  router.post('/crawl', async (req, res) => {
    try {
      const { seeds, max_pages: maxPages, maxPages: camelMaxPages, dry_run: dryRun, dryRun: camelDryRun } = req.body || {};
      const normalizedSeeds = Array.isArray(seeds) ? seeds : [];
      if (!normalizedSeeds.length) {
        res.status(400).json({ error: 'seeds_required' });
        return;
      }
      const limit = typeof maxPages === 'number' ? maxPages : typeof camelMaxPages === 'number' ? camelMaxPages : undefined;
      const isDryRun = typeof dryRun === 'boolean' ? dryRun : typeof camelDryRun === 'boolean' ? camelDryRun : false;

      const job = crawler.createJob({ seeds: normalizedSeeds, maxPages: limit, dryRun: isDryRun });
      res.status(202).json({
        job_id: job.id,
        status: job.status,
        created_at: job.createdAt,
        max_pages: job.maxPages,
        dry_run: job.dryRun,
        queued: job.stats.queued,
        links: {
          self: `/api/paula/jobs/${job.id}`,
          corpus: '/api/paula/corpus/stats'
        }
      });
    } catch (error) {
      res.status(500).json({ error: 'crawl_failed', details: error.message });
    }
  });

  router.get('/jobs/:id', async (req, res) => {
    const job = crawler.getJob(req.params.id);
    if (!job) {
      res.status(404).json({ error: 'job_not_found' });
      return;
    }
    res.json({
      id: job.id,
      status: job.status,
      created_at: job.createdAt,
      started_at: job.startedAt,
      finished_at: job.finishedAt,
      dry_run: job.dryRun,
      max_pages: job.maxPages,
      stats: {
        fetched: job.stats.fetched,
        skipped: job.stats.skipped,
        errors: job.stats.errors,
        bytes: job.stats.bytes,
        not_modified: job.stats.notModified,
        disallowed: job.stats.disallowed,
        queued: job.stats.queued,
        robots_requests: job.stats.robotsRequests,
        dns: job.stats.dns,
        embed_vectors: job.stats.embedVectors,
        embed_batches: job.stats.embedBatches,
        duration_ms: job.stats.durationMs
      },
      queue_length: job.queue.length,
      in_flight: job.inFlight,
      failure: job.failure || null
    });
  });

  router.get('/corpus/stats', async (req, res) => {
    try {
      const stats = await storage.getCorpusStats();
      res.json({
        pages: stats.pages,
        bytes: stats.totalBytes,
        embeddings: stats.embeddings
      });
    } catch (error) {
      res.status(500).json({ error: 'corpus_stats_failed', details: error.message });
    }
  });

  router.post('/auto-train', async (req, res) => {
    const { strategy = 'new', dry_run: dryRun = false } = req.body || {};
    res.json({
      status: dryRun ? 'dry_run' : 'queued',
      strategy,
      batches_pending: Math.ceil(embeddingQueue.buffer.length / (embeddingQueue.batchSize || 1)),
      embeddings_generated: embeddingQueue.generated
    });
  });

  return router;
}

module.exports = {
  createPaulaRouter
};
