#!/usr/bin/env node
/**
 * Query Cache Utility - Simple CLI for cache management
 *
 * Wraps packages/embeddings/cache.cjs for ops scripts
 *
 * Commands:
 * - stats: Show cache statistics
 * - warm [N]: Warm cache with top N queries
 * - reset: Reset cache statistics
 */

const { getStats, warmCache, resetStats } = require('../../packages/embeddings/cache.cjs');
const { getEmbedding } = require('../embedder.cjs');

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  switch (command) {
    case 'stats':
      showStats();
      break;

    case 'warm':
      const topN = parseInt(args[1]) || 20;
      await runWarmCache(topN);
      break;

    case 'reset':
      resetStats();
      console.log('✅ Cache statistics reset\n');
      break;

    default:
      showUsage();
      break;
  }
}

function showStats() {
  const stats = getStats();

  console.log('📊 Cache Statistics\n');
  console.log(`Connected: ${stats.connected}`);
  console.log(`Hits: ${stats.hits}`);
  console.log(`Misses: ${stats.misses}`);
  console.log(`Errors: ${stats.errors}`);
  console.log(`Total Requests: ${stats.total_requests}`);
  console.log(`Hit Rate: ${stats.hit_rate_pct}%`);
  console.log(`Last Reset: ${stats.last_reset}\n`);
}

async function runWarmCache(topN) {
  console.log(`🔥 Warming cache with top ${topN} queries...\n`);

  // Warm cache with embedding function
  const embedFn = async (query) => await getEmbedding(query);

  try {
    await warmCache(topN, embedFn);
    console.log('✅ Cache warming complete\n');
    showStats();
  } catch (err) {
    console.error(`❌ Cache warming failed: ${err.message}\n`);
    process.exit(1);
  }
}

function showUsage() {
  console.log(`
Query Cache Utility

Usage:
  node knowledge/util/query_cache.cjs <command> [options]

Commands:
  stats              Show cache statistics
  warm [N]           Warm cache with top N queries (default: 20)
  reset              Reset cache statistics

Examples:
  node knowledge/util/query_cache.cjs stats
  node knowledge/util/query_cache.cjs warm 50
  node knowledge/util/query_cache.cjs reset
`);
}

if (require.main === module) {
  main().catch(err => {
    console.error(`❌ Error: ${err.message}`);
    process.exit(1);
  });
}

module.exports = { showStats, runWarmCache };
