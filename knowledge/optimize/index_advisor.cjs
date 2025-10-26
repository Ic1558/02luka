#!/usr/bin/env node
/**
 * Index Advisor - Analyzes query performance and recommends database indexes
 *
 * Features:
 * - Parses query_perf.jsonl for slow queries
 * - Identifies missing indexes based on query patterns
 * - Generates SQL recommendations with impact estimates
 * - Supports dry-run mode for advisory reports
 */

const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const ROOT = path.resolve(__dirname, '../..');
const PERF_LOG = path.join(ROOT, 'g/reports/query_perf.jsonl');
const DB_PATH = path.join(ROOT, 'knowledge/02luka.db');
const ADVISOR_REPORT = path.join(ROOT, 'g/reports/index_advisor_report.json');

// Thresholds
const SLOW_QUERY_THRESHOLD_MS = 100; // p95 > 100ms
const MIN_QUERY_SAMPLES = 3; // Need at least 3 samples to recommend

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const verbose = args.includes('--verbose');

  console.log('🔍 Index Advisor - Analyzing query performance...\n');

  if (dryRun) {
    console.log('📋 Running in DRY-RUN mode (advisory only)\n');
  }

  // Step 1: Parse performance logs
  const queryStats = await parsePerformanceLogs(verbose);

  if (Object.keys(queryStats).length === 0) {
    console.log('⚠️  No query data found in performance logs');
    console.log(`   Log file: ${PERF_LOG}\n`);
    process.exit(0);
  }

  // Step 2: Identify slow queries
  const slowQueries = identifySlowQueries(queryStats, verbose);

  if (slowQueries.length === 0) {
    console.log('✅ No slow queries detected (all queries < 100ms p95)\n');
    saveReport({ status: 'healthy', slow_queries: [], recommendations: [] });
    process.exit(0);
  }

  // Step 3: Analyze database schema
  const db = await openDb(DB_PATH);
  const existingIndexes = await getExistingIndexes(db);

  // Step 4: Generate recommendations
  const recommendations = generateRecommendations(slowQueries, existingIndexes, verbose);

  // Step 5: Save report
  const report = {
    timestamp: new Date().toISOString(),
    status: recommendations.length > 0 ? 'recommendations' : 'healthy',
    slow_queries: slowQueries,
    existing_indexes: existingIndexes,
    recommendations: recommendations
  };

  saveReport(report);

  // Step 6: Display results
  displayResults(report, dryRun);

  db.close();

  // Exit code: 0 if healthy, 1 if recommendations
  process.exit(recommendations.length > 0 ? 1 : 0);
}

/**
 * Parse performance logs and aggregate query statistics
 */
function parsePerformanceLogs(verbose) {
  if (!fs.existsSync(PERF_LOG)) {
    return {};
  }

  const lines = fs.readFileSync(PERF_LOG, 'utf8').trim().split('\n');
  const queryStats = {};

  for (const line of lines) {
    if (!line) continue;

    try {
      const entry = JSON.parse(line);

      // Extract query pattern (normalize for aggregation)
      const pattern = normalizeQueryPattern(entry.query || '');
      if (!pattern) continue;

      // Initialize stats for this pattern
      if (!queryStats[pattern]) {
        queryStats[pattern] = {
          pattern,
          samples: [],
          count: 0
        };
      }

      // Add timing sample
      const totalMs = entry.timings?.total_ms || entry.duration_ms || 0;
      queryStats[pattern].samples.push(totalMs);
      queryStats[pattern].count++;

    } catch (err) {
      if (verbose) {
        console.error(`[warn] Failed to parse log line: ${err.message}`);
      }
    }
  }

  // Calculate percentiles
  for (const pattern in queryStats) {
    const stats = queryStats[pattern];
    stats.samples.sort((a, b) => a - b);
    stats.p50 = quantile(stats.samples, 0.5);
    stats.p95 = quantile(stats.samples, 0.95);
    stats.p99 = quantile(stats.samples, 0.99);
  }

  return queryStats;
}

/**
 * Normalize query pattern for aggregation
 */
function normalizeQueryPattern(query) {
  // Convert to lowercase
  let pattern = query.toLowerCase().trim();

  // Remove common noise
  pattern = pattern.replace(/\s+/g, ' ');
  pattern = pattern.replace(/--k=\d+/g, '');

  return pattern;
}

/**
 * Calculate quantile
 */
function quantile(sorted, q) {
  if (sorted.length === 0) return 0;
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;

  if (sorted[base + 1] !== undefined) {
    return sorted[base] + rest * (sorted[base + 1] - sorted[base]);
  }
  return sorted[base];
}

/**
 * Identify slow queries based on threshold
 */
function identifySlowQueries(queryStats, verbose) {
  const slowQueries = [];

  for (const pattern in queryStats) {
    const stats = queryStats[pattern];

    // Only consider queries with enough samples
    if (stats.count < MIN_QUERY_SAMPLES) {
      if (verbose) {
        console.log(`[skip] ${pattern}: only ${stats.count} samples`);
      }
      continue;
    }

    // Check if p95 exceeds threshold
    if (stats.p95 > SLOW_QUERY_THRESHOLD_MS) {
      slowQueries.push({
        pattern,
        samples: stats.count,
        p50: Math.round(stats.p50),
        p95: Math.round(stats.p95),
        p99: Math.round(stats.p99)
      });
    }
  }

  // Sort by p95 (slowest first)
  slowQueries.sort((a, b) => b.p95 - a.p95);

  return slowQueries;
}

/**
 * Get existing indexes from database
 */
async function getExistingIndexes(db) {
  const indexes = await allAsync(db, `
    SELECT name, tbl_name, sql
    FROM sqlite_master
    WHERE type='index'
  `);

  return indexes.map(idx => ({
    name: idx.name,
    table: idx.tbl_name,
    sql: idx.sql
  }));
}

/**
 * Generate index recommendations
 */
function generateRecommendations(slowQueries, existingIndexes, verbose) {
  const recommendations = [];

  // Index recommendation rules
  const rules = [
    {
      pattern: /hybrid.*search|embedding|vector/i,
      table: 'document_chunks',
      column: 'embedding',
      reason: 'Embedding-heavy queries benefit from BLOB optimization',
      sql: '-- Embedding column already indexed via primary key'
    },
    {
      pattern: /doc_path|path/i,
      table: 'document_chunks',
      column: 'doc_path',
      reason: 'Document path lookups',
      sql: 'CREATE INDEX IF NOT EXISTS idx_doc_path ON document_chunks(doc_path);'
    },
    {
      pattern: /chunk.*index/i,
      table: 'document_chunks',
      column: 'chunk_index',
      reason: 'Chunk position queries',
      sql: 'CREATE INDEX IF NOT EXISTS idx_chunk_index ON document_chunks(chunk_index);'
    },
    {
      pattern: /indexed.*at|timestamp/i,
      table: 'document_chunks',
      column: 'indexed_at',
      reason: 'Time-based filtering',
      sql: 'CREATE INDEX IF NOT EXISTS idx_indexed_at ON document_chunks(indexed_at);'
    }
  ];

  for (const query of slowQueries) {
    for (const rule of rules) {
      if (rule.pattern.test(query.pattern)) {
        // Check if index already exists
        const indexExists = existingIndexes.some(idx =>
          idx.table === rule.table && idx.sql && idx.sql.includes(rule.column)
        );

        if (!indexExists && rule.sql !== '-- Embedding column already indexed via primary key') {
          recommendations.push({
            query_pattern: query.pattern,
            p95_ms: query.p95,
            table: rule.table,
            column: rule.column,
            reason: rule.reason,
            sql: rule.sql,
            estimated_impact: estimateImpact(query.p95)
          });
        }
      }
    }
  }

  // Deduplicate recommendations
  const unique = [];
  const seen = new Set();

  for (const rec of recommendations) {
    const key = `${rec.table}:${rec.column}`;
    if (!seen.has(key)) {
      seen.add(key);
      unique.push(rec);
    }
  }

  return unique;
}

/**
 * Estimate impact of index
 */
function estimateImpact(currentP95) {
  if (currentP95 > 500) return 'high';
  if (currentP95 > 200) return 'medium';
  return 'low';
}

/**
 * Save report to disk
 */
function saveReport(report) {
  const dir = path.dirname(ADVISOR_REPORT);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(ADVISOR_REPORT, JSON.stringify(report, null, 2));
}

/**
 * Display results
 */
function displayResults(report, dryRun) {
  console.log('📊 Analysis Results\n');
  console.log(`Slow Queries Detected: ${report.slow_queries.length}`);
  console.log(`Recommendations: ${report.recommendations.length}\n`);

  if (report.slow_queries.length > 0) {
    console.log('🐌 Slow Queries (p95 > 100ms):');
    console.log('─'.repeat(70));

    for (const query of report.slow_queries) {
      console.log(`Query: ${query.pattern.slice(0, 50)}...`);
      console.log(`  Samples: ${query.samples} | p50: ${query.p50}ms | p95: ${query.p95}ms | p99: ${query.p99}ms`);
    }
    console.log('');
  }

  if (report.recommendations.length > 0) {
    console.log('💡 Index Recommendations:');
    console.log('─'.repeat(70));

    for (const rec of report.recommendations) {
      console.log(`Table: ${rec.table}.${rec.column}`);
      console.log(`  Reason: ${rec.reason}`);
      console.log(`  Impact: ${rec.estimated_impact} (current p95: ${rec.p95_ms}ms)`);
      console.log(`  SQL: ${rec.sql}`);
      console.log('');
    }

    if (dryRun) {
      console.log('📋 DRY-RUN: No indexes created (use apply_indexes.sh to apply)\n');
    } else {
      console.log('📋 Run apply_indexes.sh to create these indexes\n');
    }
  }

  console.log(`📄 Full report: ${ADVISOR_REPORT}\n`);
}

// Database utilities
function openDb(dbPath) {
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(dbPath, err => {
      if (err) return reject(err);
      resolve(db);
    });
  });
}

function allAsync(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) return reject(err);
      resolve(rows);
    });
  });
}

// Run
if (require.main === module) {
  main().catch(err => {
    console.error('❌ Index advisor failed:', err.message);
    process.exit(1);
  });
}

module.exports = { main, parsePerformanceLogs, identifySlowQueries };
