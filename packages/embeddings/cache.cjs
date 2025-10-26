/**
 * Redis-backed embedding cache with adaptive TTL
 *
 * Features:
 * - SHA256-based cache keys (model + normalized query)
 * - Adaptive TTL: 1h default → 24h for frequent queries
 * - Top-N query warming
 * - Graceful fallback if Redis unavailable
 * - Hit rate tracking
 */

const crypto = require('crypto');
const redis = require('redis');
const fs = require('fs');
const path = require('path');

const REDIS_URL = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
const CACHE_ENABLED = process.env.CACHE_ENABLED !== '0';
const DEFAULT_TTL = parseInt(process.env.EMBED_CACHE_TTL_SEC || '3600', 10); // 1 hour
const STATS_FILE = path.join(__dirname, '../../g/reports/cache_stats.json');

let client = null;
let redisConnected = false;
let stats = {
  hits: 0,
  misses: 0,
  errors: 0,
  last_reset: new Date().toISOString()
};

/**
 * Initialize Redis client with connection handling
 */
async function initRedis() {
  if (!CACHE_ENABLED) {
    console.log('[cache] Cache disabled (CACHE_ENABLED=0)');
    return;
  }

  if (client) return client;

  try {
    client = redis.createClient({ url: REDIS_URL });

    client.on('error', (err) => {
      console.error('[cache] Redis error:', err.message);
      redisConnected = false;
    });

    client.on('connect', () => {
      console.log('[cache] Redis connected');
      redisConnected = true;
    });

    client.on('disconnect', () => {
      console.log('[cache] Redis disconnected');
      redisConnected = false;
    });

    await client.connect();
    return client;
  } catch (err) {
    console.error('[cache] Failed to connect to Redis:', err.message);
    console.log('[cache] Falling back to no-cache mode');
    return null;
  }
}

/**
 * Generate cache key from model and query
 * @param {string} model - Embedding model name
 * @param {string} query - Normalized query text
 * @returns {string} Cache key (SHA256 hash)
 */
function getCacheKey(model, query) {
  const normalized = query.toLowerCase().trim().replace(/\s+/g, ' ');
  const input = `${model}:${normalized}`;
  return `embed:${crypto.createHash('sha256').update(input).digest('hex')}`;
}

/**
 * Get adaptive TTL based on query frequency
 * @param {string} key - Cache key
 * @returns {Promise<number>} TTL in seconds
 */
async function getAdaptiveTTL(key) {
  if (!client || !redisConnected) return DEFAULT_TTL;

  try {
    // Check query frequency in last 7 days
    const freqKey = `${key}:freq`;
    const frequency = await client.get(freqKey);

    if (!frequency) {
      return DEFAULT_TTL; // 1 hour for new queries
    }

    const count = parseInt(frequency, 10);

    // Adaptive TTL based on frequency
    if (count >= 50) return 86400 * 7;  // 7 days (very frequent)
    if (count >= 20) return 86400;      // 24 hours (frequent)
    if (count >= 5) return 7200;        // 2 hours (moderate)
    return DEFAULT_TTL;                 // 1 hour (infrequent)
  } catch (err) {
    console.error('[cache] Error computing adaptive TTL:', err.message);
    return DEFAULT_TTL;
  }
}

/**
 * Update query frequency counter
 * @param {string} key - Cache key
 */
async function updateFrequency(key) {
  if (!client || !redisConnected) return;

  try {
    const freqKey = `${key}:freq`;
    await client.incr(freqKey);
    await client.expire(freqKey, 7 * 86400); // 7 days window
  } catch (err) {
    console.error('[cache] Error updating frequency:', err.message);
  }
}

/**
 * Get embedding from cache or compute via callback
 * @param {string} model - Embedding model name
 * @param {string} query - Query text
 * @param {Function} embedFn - Async function to compute embedding if miss
 * @returns {Promise<{embedding: number[], cached: boolean, cacheKey: string}>}
 */
async function getOrEmbed(model, query, embedFn) {
  const startTime = Date.now();
  const cacheKey = getCacheKey(model, query);

  // Update frequency counter (for adaptive TTL)
  await updateFrequency(cacheKey);

  // Try cache first
  if (CACHE_ENABLED && client && redisConnected) {
    try {
      const cached = await client.get(cacheKey);

      if (cached) {
        stats.hits++;
        const embedding = JSON.parse(cached);
        const duration = Date.now() - startTime;

        console.log(`[cache] HIT (${duration}ms) ${cacheKey.slice(0, 16)}...`);

        return {
          embedding,
          cached: true,
          cacheKey,
          duration_ms: duration
        };
      }
    } catch (err) {
      console.error('[cache] Error reading from cache:', err.message);
      stats.errors++;
    }
  }

  // Cache miss - compute embedding
  stats.misses++;
  console.log(`[cache] MISS ${cacheKey.slice(0, 16)}...`);

  try {
    const embedding = await embedFn();
    const embedTime = Date.now();

    // Store in cache asynchronously (don't block return)
    if (CACHE_ENABLED && client && redisConnected) {
      const ttl = await getAdaptiveTTL(cacheKey);

      client.setEx(cacheKey, ttl, JSON.stringify(embedding))
        .then(() => {
          const cacheTime = Date.now() - embedTime;
          console.log(`[cache] STORED (TTL=${ttl}s, ${cacheTime}ms) ${cacheKey.slice(0, 16)}...`);
        })
        .catch(err => {
          console.error('[cache] Error storing to cache:', err.message);
          stats.errors++;
        });
    }

    const duration = Date.now() - startTime;
    return {
      embedding,
      cached: false,
      cacheKey,
      duration_ms: duration
    };
  } catch (err) {
    console.error('[cache] Error computing embedding:', err.message);
    throw err;
  }
}

/**
 * Warm cache with top N queries from telemetry
 * @param {number} topN - Number of top queries to warm
 * @param {Function} embedFn - Function to compute embeddings
 */
async function warmCache(topN, embedFn) {
  if (!CACHE_ENABLED || !client || !redisConnected) {
    console.log('[cache] Cache warming skipped (cache disabled or not connected)');
    return;
  }

  console.log(`[cache] Warming cache with top ${topN} queries...`);

  try {
    // Read recent performance logs to find frequent queries
    const perfLogPath = path.join(__dirname, '../../g/reports/query_perf.jsonl');

    if (!fs.existsSync(perfLogPath)) {
      console.log('[cache] No perf log found, skipping warming');
      return;
    }

    const lines = fs.readFileSync(perfLogPath, 'utf8').trim().split('\n');
    const queryCounts = {};

    // Count query frequencies
    for (const line of lines) {
      if (!line) continue;
      try {
        const entry = JSON.parse(line);
        const q = entry.query || '';
        if (q) {
          queryCounts[q] = (queryCounts[q] || 0) + 1;
        }
      } catch (err) {
        // Skip invalid lines
      }
    }

    // Sort by frequency and take top N
    const topQueries = Object.entries(queryCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, topN)
      .map(([query]) => query);

    console.log(`[cache] Found ${topQueries.length} queries to warm`);

    // Warm cache (compute embeddings for queries not already cached)
    let warmed = 0;
    for (const query of topQueries) {
      const model = process.env.EMBED_MODEL || 'nomic-embed-text';
      const cacheKey = getCacheKey(model, query);

      const exists = await client.exists(cacheKey);
      if (!exists) {
        await getOrEmbed(model, query, embedFn);
        warmed++;
      }
    }

    console.log(`[cache] Warmed ${warmed}/${topQueries.length} queries`);
  } catch (err) {
    console.error('[cache] Error warming cache:', err.message);
  }
}

/**
 * Get cache statistics
 * @returns {object} Cache stats
 */
function getStats() {
  const total = stats.hits + stats.misses;
  const hitRate = total > 0 ? (stats.hits / total * 100).toFixed(1) : 0;

  return {
    ...stats,
    total_requests: total,
    hit_rate_pct: parseFloat(hitRate),
    connected: redisConnected
  };
}

/**
 * Reset cache statistics
 */
function resetStats() {
  stats = {
    hits: 0,
    misses: 0,
    errors: 0,
    last_reset: new Date().toISOString()
  };
}

/**
 * Save cache stats to file
 */
function saveStats() {
  try {
    const statsDir = path.dirname(STATS_FILE);
    if (!fs.existsSync(statsDir)) {
      fs.mkdirSync(statsDir, { recursive: true });
    }

    fs.writeFileSync(STATS_FILE, JSON.stringify(getStats(), null, 2));
  } catch (err) {
    console.error('[cache] Error saving stats:', err.message);
  }
}

/**
 * Close Redis connection
 */
async function close() {
  if (client && redisConnected) {
    saveStats();
    await client.quit();
    console.log('[cache] Redis connection closed');
  }
}

// Initialize on module load
initRedis().catch(err => {
  console.error('[cache] Failed to initialize:', err.message);
});

// Save stats periodically and on exit
setInterval(saveStats, 60000); // Every minute
process.on('SIGINT', () => close().then(() => process.exit(0)));
process.on('SIGTERM', () => close().then(() => process.exit(0)));

module.exports = {
  getOrEmbed,
  warmCache,
  getStats,
  resetStats,
  close,
  getCacheKey,
  initRedis
};
