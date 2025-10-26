#!/usr/bin/env node
/**
 * Day 1 Verification Script
 *
 * Comprehensive verification of all deliverables:
 * 1. File integrity (existence, line counts, key functions)
 * 2. Database schema (tables, indexes, FTS)
 * 3. Integration (cache → embedder → search pipeline)
 * 4. Performance (actual query timing)
 * 5. Telemetry (cache metrics logging)
 */

const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const { getEmbedding } = require('./embedder.cjs');
const { hybridSearch } = require('./search.cjs');
const { getCacheKey, getStats: getCacheStats } = require('../packages/embeddings/cache.cjs');

const ROOT = path.resolve(__dirname, '..');

async function main() {
  console.log('🔍 Day 1 Verification - Comprehensive System Check\n');
  console.log('='.repeat(70));

  const results = {
    checks: [],
    pass: 0,
    fail: 0,
    warnings: 0
  };

  // Section 1: File Integrity
  console.log('\n📁 Section 1: File Integrity');
  console.log('-'.repeat(70));
  await verifyFiles(results);

  // Section 2: Database Schema
  console.log('\n🗄️  Section 2: Database Schema');
  console.log('-'.repeat(70));
  await verifyDatabase(results);

  // Section 3: Integration Pipeline
  console.log('\n🔗 Section 3: Integration Pipeline');
  console.log('-'.repeat(70));
  await verifyIntegration(results);

  // Section 4: Performance Verification
  console.log('\n⚡ Section 4: Performance Verification');
  console.log('-'.repeat(70));
  await verifyPerformance(results);

  // Section 5: Telemetry
  console.log('\n📊 Section 5: Telemetry');
  console.log('-'.repeat(70));
  await verifyTelemetry(results);

  // Final Report
  console.log('\n' + '='.repeat(70));
  console.log('\n📋 Verification Report\n');

  console.log(`Total Checks: ${results.checks.length}`);
  console.log(`✅ Passed: ${results.pass}`);
  console.log(`❌ Failed: ${results.fail}`);
  console.log(`⚠️  Warnings: ${results.warnings}\n`);

  if (results.fail > 0) {
    console.log('Failed checks:');
    results.checks.filter(c => c.status === 'fail').forEach(c => {
      console.log(`   ❌ ${c.name}: ${c.message}`);
    });
    console.log('');
  }

  if (results.warnings > 0) {
    console.log('Warnings:');
    results.checks.filter(c => c.status === 'warning').forEach(c => {
      console.log(`   ⚠️  ${c.name}: ${c.message}`);
    });
    console.log('');
  }

  const grade = results.fail === 0 ? '✅ PASS' : '❌ FAIL';
  console.log(`Final Status: ${grade}\n`);

  process.exit(results.fail > 0 ? 1 : 0);
}

/**
 * Section 1: Verify file integrity
 */
async function verifyFiles(results) {
  const files = [
    {
      path: 'packages/embeddings/cache.cjs',
      minLines: 300,
      requiredFunctions: ['getOrEmbed', 'warmCache', 'getStats', 'getCacheKey']
    },
    {
      path: 'packages/embeddings/adapter.cjs',
      minLines: 80,
      requiredFunctions: ['adaptEmbedding', 'normalizeModel', 'padEmbedding', 'trimEmbedding']
    },
    {
      path: 'knowledge/smoke_test.cjs',
      minLines: 250,
      requiredFunctions: ['main', 'testDatabaseIndexes', 'testRedisCache']
    },
    {
      path: 'knowledge/schema.sql',
      minLines: 80,
      requiredPatterns: ['document_chunks', 'idx_doc_path', 'idx_chunk_index']
    }
  ];

  for (const file of files) {
    const filePath = path.join(ROOT, file.path);

    // Check existence
    if (!fs.existsSync(filePath)) {
      check(results, `File: ${file.path}`, 'fail', 'File does not exist');
      continue;
    }

    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n').length;

    // Check line count
    if (lines < file.minLines) {
      check(results, `File: ${file.path}`, 'fail',
        `Only ${lines} lines (expected ≥${file.minLines})`);
      continue;
    }

    // Check required functions/patterns
    let missing = [];
    if (file.requiredFunctions) {
      missing = file.requiredFunctions.filter(fn => !content.includes(fn));
    } else if (file.requiredPatterns) {
      missing = file.requiredPatterns.filter(pat => !content.includes(pat));
    }

    if (missing.length > 0) {
      check(results, `File: ${file.path}`, 'fail',
        `Missing: ${missing.join(', ')}`);
    } else {
      check(results, `File: ${file.path}`, 'pass',
        `${lines} lines, all required elements present`);
    }
  }
}

/**
 * Section 2: Verify database schema
 */
async function verifyDatabase(results) {
  const dbPath = path.join(ROOT, 'knowledge', '02luka.db');

  if (!fs.existsSync(dbPath)) {
    check(results, 'Database', 'fail', 'Database file not found');
    return;
  }

  const db = await openDb(dbPath);

  // Check table exists
  const tables = await allAsync(db, `
    SELECT name FROM sqlite_master WHERE type='table' AND name='document_chunks'
  `);

  if (tables.length === 0) {
    check(results, 'Table: document_chunks', 'fail', 'Table does not exist');
    db.close();
    return;
  }

  check(results, 'Table: document_chunks', 'pass', 'Table exists');

  // Check FTS table
  const ftsTables = await allAsync(db, `
    SELECT name FROM sqlite_master WHERE type='table' AND name='document_chunks_fts'
  `);

  if (ftsTables.length === 0) {
    check(results, 'FTS: document_chunks_fts', 'fail', 'FTS table does not exist');
  } else {
    check(results, 'FTS: document_chunks_fts', 'pass', 'FTS table exists');
  }

  // Check indexes
  const indexes = await allAsync(db, `
    SELECT name FROM sqlite_master
    WHERE type='index' AND tbl_name='document_chunks'
  `);

  const indexNames = indexes.map(idx => idx.name);
  const required = ['idx_doc_path', 'idx_chunk_index', 'idx_indexed_at', 'idx_doc_path_chunk'];
  const missing = required.filter(name => !indexNames.includes(name));

  if (missing.length > 0) {
    check(results, 'Database Indexes', 'fail', `Missing: ${missing.join(', ')}`);
  } else {
    check(results, 'Database Indexes', 'pass', `All 4 indexes present`);
  }

  // Check row count
  const countResult = await getAsync(db, `SELECT COUNT(*) as count FROM document_chunks`);
  const rowCount = countResult.count;

  if (rowCount === 0) {
    check(results, 'Database Content', 'warning', 'No documents indexed (run reindex-all.cjs)');
  } else {
    check(results, 'Database Content', 'pass', `${rowCount} chunks indexed`);
  }

  db.close();
}

/**
 * Section 3: Verify integration pipeline
 */
async function verifyIntegration(results) {
  try {
    // Test 1: Cache key generation
    const cacheKey = getCacheKey('test-model', 'test query');

    if (!cacheKey.startsWith('embed:')) {
      check(results, 'Cache Key Generation', 'fail', 'Invalid cache key format');
    } else {
      check(results, 'Cache Key Generation', 'pass', `Key: ${cacheKey.slice(0, 20)}...`);
    }

    // Test 2: Embedding generation
    const testText = 'integration test query';
    const embedding = await getEmbedding(testText);

    if (!Array.isArray(embedding) || embedding.length !== 384) {
      check(results, 'Embedding Generation', 'fail',
        `Invalid embedding: ${typeof embedding}, length: ${embedding?.length}`);
    } else {
      check(results, 'Embedding Generation', 'pass', `384-dim vector generated`);
    }

    // Test 3: Embedding with metadata
    const embedResult = await getEmbedding(testText, { withMetadata: true });

    if (!embedResult.embedding || !embedResult.hasOwnProperty('cached')) {
      check(results, 'Embedding Metadata', 'fail', 'Metadata not returned');
    } else {
      check(results, 'Embedding Metadata', 'pass',
        `cached=${embedResult.cached}, duration=${embedResult.duration_ms}ms`);
    }

  } catch (err) {
    check(results, 'Integration Pipeline', 'fail', err.message);
  }
}

/**
 * Section 4: Verify performance
 */
async function verifyPerformance(results) {
  const dbPath = path.join(ROOT, 'knowledge', '02luka.db');

  if (!fs.existsSync(dbPath)) {
    check(results, 'Performance Test', 'fail', 'Database not found');
    return;
  }

  const db = await openDb(dbPath);

  try {
    // Check if database has content
    const countResult = await getAsync(db, `SELECT COUNT(*) as count FROM document_chunks`);

    if (countResult.count === 0) {
      check(results, 'Performance Test', 'warning',
        'Cannot test performance - no documents indexed');
      db.close();
      return;
    }

    // Run actual query
    const query = 'phase 7 embeddings';
    const result = await hybridSearch(db, query, { topK: 5 });

    const { timings } = result;

    // Verify timing structure
    if (!timings.fts_ms || !timings.embed_ms || !timings.rerank_ms || !timings.total_ms) {
      check(results, 'Performance Timings', 'fail', 'Missing timing fields');
      db.close();
      return;
    }

    check(results, 'Performance Timings', 'pass',
      `FTS: ${timings.fts_ms.toFixed(1)}ms, Embed: ${timings.embed_ms.toFixed(1)}ms, ` +
      `Rerank: ${timings.rerank_ms.toFixed(1)}ms, Total: ${timings.total_ms.toFixed(1)}ms`);

    // Verify performance target
    if (timings.total_ms > 100) {
      check(results, 'Performance Target', 'warning',
        `${timings.total_ms.toFixed(1)}ms (target: <100ms)`);
    } else {
      check(results, 'Performance Target', 'pass',
        `${timings.total_ms.toFixed(1)}ms (under 100ms target)`);
    }

    // Verify cache metadata present
    if (!timings.hasOwnProperty('cache_hit')) {
      check(results, 'Cache Telemetry', 'fail', 'cache_hit field missing');
    } else {
      check(results, 'Cache Telemetry', 'pass',
        `cache_hit=${timings.cache_hit}, embed_cache_ms=${timings.embed_cache_ms}`);
    }

  } catch (err) {
    check(results, 'Performance Test', 'fail', err.message);
  }

  db.close();
}

/**
 * Section 5: Verify telemetry
 */
async function verifyTelemetry(results) {
  // Check cache stats
  const stats = getCacheStats();

  if (!stats.hasOwnProperty('hits') || !stats.hasOwnProperty('misses')) {
    check(results, 'Cache Statistics', 'fail', 'Stats structure invalid');
  } else {
    check(results, 'Cache Statistics', 'pass',
      `hits=${stats.hits}, misses=${stats.misses}, hit_rate=${stats.hit_rate_pct}%`);
  }

  // Check perf log file
  const perfLogPath = path.join(ROOT, 'g', 'reports', 'query_perf.jsonl');

  if (!fs.existsSync(perfLogPath)) {
    check(results, 'Performance Log', 'warning', 'query_perf.jsonl not found');
    return;
  }

  const content = fs.readFileSync(perfLogPath, 'utf8');
  const lines = content.trim().split('\n').filter(Boolean);

  if (lines.length === 0) {
    check(results, 'Performance Log', 'warning', 'No log entries');
    return;
  }

  // Parse last entry
  try {
    const lastEntry = JSON.parse(lines[lines.length - 1]);

    if (!lastEntry.timings) {
      check(results, 'Performance Log Format', 'fail', 'Missing timings field');
    } else {
      check(results, 'Performance Log Format', 'pass',
        `${lines.length} entries, latest: ${lastEntry.ts}`);
    }
  } catch (err) {
    check(results, 'Performance Log Format', 'fail', 'Invalid JSON');
  }
}

// Helper functions
function check(results, name, status, message) {
  results.checks.push({ name, status, message });

  if (status === 'pass') {
    results.pass++;
    console.log(`✅ ${name}: ${message}`);
  } else if (status === 'fail') {
    results.fail++;
    console.log(`❌ ${name}: ${message}`);
  } else if (status === 'warning') {
    results.warnings++;
    console.log(`⚠️  ${name}: ${message}`);
  }
}

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

function getAsync(db, sql, params = []) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) return reject(err);
      resolve(row);
    });
  });
}

// Run
if (require.main === module) {
  main().catch(err => {
    console.error('❌ Verification failed:', err);
    process.exit(1);
  });
}

module.exports = { main };
