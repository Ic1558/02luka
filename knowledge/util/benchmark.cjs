/* Benchmark runner for hybrid search */

const fs = require('fs');
const path = require('path');
const { hybridSearch } = require('../search.cjs');
const { now, msSince, stats } = require('./timer.cjs');

/**
 * Run benchmark with multiple queries
 * @param {object} db - Database connection
 * @param {object} options - Benchmark options
 */
async function runBenchmark(db, options = {}) {
  const {
    iterations = 30,
    queriesFile = path.join(__dirname, '..', 'bench_queries.txt'),
    warmup = 3
  } = options;

  console.log('🏁 Running hybrid search benchmark\n');

  // Load queries
  const queries = loadQueries(queriesFile);
  if (queries.length === 0) {
    console.error('❌ No queries found in', queriesFile);
    return;
  }

  console.log(`📋 Loaded ${queries.length} queries`);
  console.log(`🔥 Warmup: ${warmup} iterations`);
  console.log(`⚡ Benchmark: ${iterations} iterations\n`);

  // Warmup
  console.log('Warming up...');
  for (let i = 0; i < warmup; i++) {
    const query = queries[i % queries.length];
    await hybridSearch(db, query, { topK: 10 });
  }
  console.log('✓ Warmup complete\n');

  // Benchmark
  const timings = {
    total: [],
    fts: [],
    embed: [],
    rerank: []
  };

  console.log('Running benchmark...');
  for (let i = 0; i < iterations; i++) {
    const query = queries[i % queries.length];
    const result = await hybridSearch(db, query, { topK: 10 });

    timings.total.push(result.timings.total_ms);
    timings.fts.push(result.timings.fts_ms);
    timings.embed.push(result.timings.embed_ms);
    timings.rerank.push(result.timings.rerank_ms);

    if ((i + 1) % 10 === 0) {
      console.log(`  ✓ ${i + 1}/${iterations} iterations`);
    }
  }
  console.log('✓ Benchmark complete\n');

  // Calculate stats
  const results = {
    iterations,
    queries: queries.length,
    total: stats(timings.total),
    fts: stats(timings.fts),
    embed: stats(timings.embed),
    rerank: stats(timings.rerank)
  };

  // Print results
  printResults(results);

  return results;
}

/**
 * Load queries from file
 * @param {string} filepath - Path to queries file
 * @returns {string[]} - Array of queries
 */
function loadQueries(filepath) {
  if (!fs.existsSync(filepath)) {
    console.warn(`⚠️  Queries file not found: ${filepath}`);
    return getDefaultQueries();
  }

  const content = fs.readFileSync(filepath, 'utf8');
  return content
    .split('\n')
    .map(line => line.trim())
    .filter(line => line && !line.startsWith('#'));
}

/**
 * Get default queries if file not found
 * @returns {string[]} - Default queries
 */
function getDefaultQueries() {
  return [
    'token efficiency',
    'phase 7 delegation',
    'vector database',
    'embedding model',
    'RAG system',
    'knowledge index',
    'semantic search',
    'performance optimization',
    'TF-IDF cosine',
    'hybrid search'
  ];
}

/**
 * Print benchmark results
 * @param {object} results - Benchmark results
 */
function printResults(results) {
  console.log('═══════════════════════════════════════════════════════');
  console.log('                  BENCHMARK RESULTS');
  console.log('═══════════════════════════════════════════════════════\n');

  console.log(`Iterations: ${results.iterations}`);
  console.log(`Queries: ${results.queries} unique\n`);

  console.log('TOTAL TIME');
  printStatLine('  Min', results.total.min);
  printStatLine('  Mean', results.total.mean);
  printStatLine('  Median', results.total.median);
  printStatLine('  P95', results.total.p95);
  printStatLine('  P99', results.total.p99);
  printStatLine('  Max', results.total.max);

  console.log('\nSTAGE BREAKDOWN');
  printStatLine('  FTS (mean)', results.fts.mean);
  printStatLine('  Embed (mean)', results.embed.mean);
  printStatLine('  Rerank (mean)', results.rerank.mean);

  console.log('\n═══════════════════════════════════════════════════════\n');

  // Performance assessment
  const meanTotal = results.total.mean;
  console.log('ASSESSMENT');
  if (meanTotal < 50) {
    console.log('  🚀 Excellent performance (<50ms avg)');
  } else if (meanTotal < 100) {
    console.log('  ✅ Good performance (<100ms avg)');
  } else if (meanTotal < 200) {
    console.log('  ⚠️  Acceptable performance (<200ms avg)');
  } else {
    console.log('  ❌ Poor performance (>200ms avg)');
  }

  console.log('');
}

/**
 * Print formatted stat line
 * @param {string} label - Stat label
 * @param {number} value - Stat value (ms)
 */
function printStatLine(label, value) {
  const ms = value.toFixed(2);
  console.log(`${label.padEnd(20)} ${ms.padStart(8)} ms`);
}

module.exports = {
  runBenchmark,
  loadQueries,
  getDefaultQueries
};
