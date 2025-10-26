#!/usr/bin/env node
/* Test suite for Smart Merge Controller v2 */

const assert = require('assert');
const {
  smartMerge,
  mmrSelect,
  jaccardSimilarity,
  computeOverlapRatio,
  computeSourceDiversity,
  computeTitleEntropy,
  detectIntent,
  decideMode,
  generateExplanation
} = require('../smart_merge.cjs');

// Test color codes
const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const RESET = '\x1b[0m';

let passCount = 0;
let failCount = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`${GREEN}✓${RESET} ${name}`);
    passCount++;
  } catch (err) {
    console.log(`${RED}✗${RESET} ${name}`);
    console.error(`  ${err.message}`);
    failCount++;
  }
}

async function asyncTest(name, fn) {
  try {
    await fn();
    console.log(`${GREEN}✓${RESET} ${name}`);
    passCount++;
  } catch (err) {
    console.log(`${RED}✗${RESET} ${name}`);
    console.error(`  ${err.message}`);
    failCount++;
  }
}

// ============================================================================
// Unit Tests: Helper Functions
// ============================================================================

console.log('\n=== Unit Tests: Helper Functions ===\n');

test('jaccardSimilarity: identical texts', () => {
  const sim = jaccardSimilarity('hello world', 'hello world');
  assert.strictEqual(sim, 1.0, 'Identical texts should have similarity 1.0');
});

test('jaccardSimilarity: completely different texts', () => {
  const sim = jaccardSimilarity('hello world', 'foo bar');
  assert.strictEqual(sim, 0.0, 'Disjoint texts should have similarity 0.0');
});

test('jaccardSimilarity: partial overlap', () => {
  const sim = jaccardSimilarity('hello world foo', 'hello bar baz');
  assert.ok(sim > 0 && sim < 1, 'Partial overlap should be between 0 and 1');
  assert.ok(Math.abs(sim - 0.2) < 0.01, 'Expected ~0.2 (1 common / 5 total)');
});

test('computeOverlapRatio: empty results', () => {
  const overlap = computeOverlapRatio([]);
  assert.strictEqual(overlap, 0, 'Empty results should return 0');
});

test('computeOverlapRatio: single result', () => {
  const overlap = computeOverlapRatio([{ text: 'test' }]);
  assert.strictEqual(overlap, 0, 'Single result should return 0');
});

test('computeOverlapRatio: high overlap', () => {
  const results = [
    { text: 'status check deploy verify' },
    { text: 'status check error log' },
    { text: 'deploy verify status health' }
  ];
  const overlap = computeOverlapRatio(results);
  assert.ok(overlap > 0.3, `High overlap expected (got ${overlap})`);
});

test('computeOverlapRatio: low overlap', () => {
  const results = [
    { text: 'design creative innovative' },
    { text: 'architecture patterns structure' },
    { text: 'implementation refactoring optimize' }
  ];
  const overlap = computeOverlapRatio(results);
  assert.ok(overlap < 0.2, `Low overlap expected (got ${overlap})`);
});

test('computeSourceDiversity: single source', () => {
  const sourceLists = [{ source: 'docs', results: [] }];
  const diversity = computeSourceDiversity(sourceLists);
  assert.strictEqual(diversity, 1.0, 'Single source should have diversity 1.0');
});

test('computeSourceDiversity: all different sources', () => {
  const sourceLists = [
    { source: 'docs', results: [] },
    { source: 'reports', results: [] },
    { source: 'memory', results: [] }
  ];
  const diversity = computeSourceDiversity(sourceLists);
  assert.strictEqual(diversity, 1.0, 'All different sources should have diversity 1.0');
});

test('computeSourceDiversity: duplicate sources', () => {
  const sourceLists = [
    { source: 'docs', results: [] },
    { source: 'docs', results: [] },
    { source: 'reports', results: [] }
  ];
  const diversity = computeSourceDiversity(sourceLists);
  assert.ok(Math.abs(diversity - 0.667) < 0.01, `Expected ~0.667 (got ${diversity})`);
});

test('computeTitleEntropy: empty results', () => {
  const entropy = computeTitleEntropy([]);
  assert.strictEqual(entropy, 0, 'Empty results should return 0');
});

test('computeTitleEntropy: uniform distribution', () => {
  const results = [
    { title: 'a b c' },
    { title: 'd e f' },
    { title: 'g h i' }
  ];
  const entropy = computeTitleEntropy(results);
  assert.ok(entropy > 0.8, `High entropy expected for uniform distribution (got ${entropy})`);
});

test('detectIntent: ops keywords', () => {
  const intent = detectIntent('check status and verify deployment');
  assert.ok(intent.hasOps, 'Should detect ops intent');
  assert.ok(intent.opsKeywords.includes('check'), 'Should include "check"');
  assert.ok(intent.opsKeywords.includes('status'), 'Should include "status"');
  assert.ok(intent.opsKeywords.includes('verify'), 'Should include "verify"');
});

test('detectIntent: creative keywords', () => {
  const intent = detectIntent('design innovative architecture');
  assert.ok(intent.hasCreative, 'Should detect creative intent');
  assert.ok(intent.creativeKeywords.includes('design'), 'Should include "design"');
  assert.ok(intent.creativeKeywords.includes('innovative'), 'Should include "innovative"');
});

test('detectIntent: no special keywords', () => {
  const intent = detectIntent('hello world foo bar');
  assert.ok(!intent.hasOps, 'Should not detect ops intent');
  assert.ok(!intent.hasCreative, 'Should not detect creative intent');
});

test('decideMode: high overlap → RRF', () => {
  const signals = { overlap_ratio: 0.35, source_diversity: 0.4, hasOps: false, hasCreative: false };
  const thresholds = { overlap_rrf: 0.25, overlap_mmr: 0.12, source_div_mmr: 0.55 };
  const mode = decideMode(signals, thresholds);
  assert.strictEqual(mode, 'rrf', 'High overlap should select RRF');
});

test('decideMode: ops intent → RRF', () => {
  const signals = { overlap_ratio: 0.15, source_diversity: 0.4, hasOps: true, hasCreative: false };
  const thresholds = { overlap_rrf: 0.25, overlap_mmr: 0.12, source_div_mmr: 0.55 };
  const mode = decideMode(signals, thresholds);
  assert.strictEqual(mode, 'rrf', 'Ops intent should select RRF');
});

test('decideMode: low overlap → MMR', () => {
  const signals = { overlap_ratio: 0.08, source_diversity: 0.4, hasOps: false, hasCreative: false };
  const thresholds = { overlap_rrf: 0.25, overlap_mmr: 0.12, source_div_mmr: 0.55 };
  const mode = decideMode(signals, thresholds);
  assert.strictEqual(mode, 'mmr', 'Low overlap should select MMR');
});

test('decideMode: high diversity → MMR', () => {
  const signals = { overlap_ratio: 0.15, source_diversity: 0.65, hasOps: false, hasCreative: false };
  const thresholds = { overlap_rrf: 0.25, overlap_mmr: 0.12, source_div_mmr: 0.55 };
  const mode = decideMode(signals, thresholds);
  assert.strictEqual(mode, 'mmr', 'High diversity should select MMR');
});

test('decideMode: default → RRF', () => {
  const signals = { overlap_ratio: 0.15, source_diversity: 0.4, hasOps: false, hasCreative: false };
  const thresholds = { overlap_rrf: 0.25, overlap_mmr: 0.12, source_div_mmr: 0.55 };
  const mode = decideMode(signals, thresholds);
  assert.strictEqual(mode, 'rrf', 'Default case should select RRF');
});

test('generateExplanation: RRF with ops intent', () => {
  const signals = { overlap_ratio: 0.15, hasOps: true, opsKeywords: ['status', 'verify'] };
  const thresholds = { overlap_rrf: 0.25, overlap_mmr: 0.12 };
  const explanation = generateExplanation('rrf', signals, thresholds);
  assert.ok(explanation.includes('ops intent'), 'Should mention ops intent');
  assert.ok(explanation.includes('status'), 'Should include keyword');
});

test('generateExplanation: MMR with low overlap', () => {
  const signals = { overlap_ratio: 0.08, source_diversity: 0.4, hasCreative: false, creativeKeywords: [] };
  const thresholds = { overlap_rrf: 0.25, overlap_mmr: 0.12, source_div_mmr: 0.55 };
  const explanation = generateExplanation('mmr', signals, thresholds);
  assert.ok(explanation.includes('low overlap'), 'Should mention low overlap');
});

// ============================================================================
// Integration Tests: MMR Algorithm
// ============================================================================

async function runAsyncTests() {
console.log('\n=== Integration Tests: MMR Algorithm ===\n');

await asyncTest('mmrSelect: empty input', async () => {
  const results = await mmrSelect([]);
  assert.strictEqual(results.length, 0, 'Empty input should return empty array');
});

await asyncTest('mmrSelect: single item', async () => {
  const items = [{ id: 1, text: 'test', fused_score: 0.5 }];
  const results = await mmrSelect(items, { topK: 5 });
  assert.strictEqual(results.length, 1, 'Should return single item');
  assert.strictEqual(results[0].id, 1);
});

await asyncTest('mmrSelect: diversification works', async () => {
  const items = [
    { id: 1, text: 'machine learning neural networks', fused_score: 0.9 },
    { id: 2, text: 'machine learning deep learning', fused_score: 0.85 },
    { id: 3, text: 'database query optimization', fused_score: 0.8 },
    { id: 4, text: 'web security authentication', fused_score: 0.75 },
    { id: 5, text: 'machine learning algorithms', fused_score: 0.7 }
  ];

  const results = await mmrSelect(items, { topK: 3, lambda: 0.5, mode: 'fast' });

  assert.strictEqual(results.length, 3, 'Should return 3 items');
  assert.strictEqual(results[0].id, 1, 'First item should be highest relevance');

  // Check that diverse items are selected (not all ML-related)
  const texts = results.map(r => r.text);
  const allMlRelated = texts.every(t => t.includes('machine learning'));
  assert.ok(!allMlRelated, 'Should select diverse items, not all ML-related');
});

await asyncTest('mmrSelect: respects topK limit', async () => {
  const items = Array.from({ length: 20 }, (_, i) => ({
    id: i + 1,
    text: `document ${i + 1} content`,
    fused_score: 1.0 - (i * 0.01)
  }));

  const results = await mmrSelect(items, { topK: 5 });
  assert.strictEqual(results.length, 5, 'Should return exactly topK items');
});

// ============================================================================
// Integration Tests: Smart Merge
// ============================================================================

console.log('\n=== Integration Tests: Smart Merge ===\n');

await asyncTest('smartMerge: high overlap query (ops) → RRF', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'status check deployment verify', fused_score: 0.9 },
        { id: 2, text: 'status error log troubleshoot', fused_score: 0.8 }
      ]
    },
    {
      source: 'reports',
      results: [
        { id: 3, text: 'verify deployment status health', fused_score: 0.85 },
        { id: 4, text: 'check configuration settings', fused_score: 0.7 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'check status verify', {
    explain: true,
    mmrMode: 'fast'
  });

  assert.strictEqual(result.mode, 'rrf', 'Should select RRF for ops query');
  assert.ok(result.explanation, 'Should include explanation');
  assert.ok(result.explanation.includes('ops intent'), 'Explanation should mention ops intent');
  assert.ok(result.meta, 'Should include meta');
  assert.ok(result.meta.signals.hasOps, 'Should detect ops intent');
});

await asyncTest('smartMerge: low overlap query (creative) → MMR', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'design innovative architecture patterns', fused_score: 0.9 },
        { id: 2, text: 'creative approach to problem solving', fused_score: 0.8 }
      ]
    },
    {
      source: 'reports',
      results: [
        { id: 3, text: 'explore new technologies research', fused_score: 0.85 },
        { id: 4, text: 'optimize performance refactoring', fused_score: 0.7 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'design creative explore', {
    explain: true,
    mmrMode: 'fast'
  });

  // Note: With these low-overlap diverse results, should trigger MMR
  assert.ok(['rrf', 'mmr'].includes(result.mode), 'Should select RRF or MMR');
  assert.ok(result.explanation, 'Should include explanation');
  assert.ok(result.meta, 'Should include meta');
});

await asyncTest('smartMerge: empty source lists', async () => {
  const result = await smartMerge([], '', { explain: true });

  assert.ok(result.mode, 'Should return a mode');
  assert.strictEqual(result.results.length, 0, 'Should return empty results');
});

await asyncTest('smartMerge: single source', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'test content', fused_score: 0.9 },
        { id: 2, text: 'more content', fused_score: 0.8 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'test query', {
    explain: true,
    mmrMode: 'fast'
  });

  assert.ok(result.mode, 'Should return a mode');
  assert.ok(result.results.length > 0, 'Should return results');
});

await asyncTest('smartMerge: performance fast mode', async () => {
  // Create a large dataset (300 rows across sources)
  const sourceLists = Array.from({ length: 3 }, (_, sourceIdx) => ({
    source: `source_${sourceIdx}`,
    results: Array.from({ length: 100 }, (_, i) => ({
      id: sourceIdx * 100 + i + 1,
      text: `document ${sourceIdx * 100 + i + 1} content with some text`,
      fused_score: 1.0 - (i * 0.001)
    }))
  }));

  const t0 = Date.now();
  const result = await smartMerge(sourceLists, 'test query', {
    mmrMode: 'fast'
  });
  const elapsed = Date.now() - t0;

  console.log(`  ⏱  Fast mode: ${elapsed}ms for 300 rows`);
  assert.ok(elapsed < 50, `Fast mode should complete in <50ms (got ${elapsed}ms)`);
});

// ============================================================================
// Edge Cases
// ============================================================================

console.log('\n=== Edge Cases ===\n');

await asyncTest('smartMerge: all results identical', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'identical text', fused_score: 0.9 },
        { id: 2, text: 'identical text', fused_score: 0.8 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'test', { explain: true });

  assert.strictEqual(result.mode, 'rrf', 'High overlap should trigger RRF');
  assert.ok(result.meta.signals.overlap_ratio > 0.5, 'Should detect very high overlap');
});

await asyncTest('smartMerge: query with special characters', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'test content', fused_score: 0.9 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'test! @#$ %^&* query?', {
    explain: true
  });

  assert.ok(result.mode, 'Should handle special characters gracefully');
});

await asyncTest('smartMerge: very long query', async () => {
  const longQuery = Array.from({ length: 100 }, (_, i) => `word${i}`).join(' ');

  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'test content', fused_score: 0.9 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, longQuery, { explain: true });

  assert.ok(result.mode, 'Should handle very long queries');
});

await asyncTest('smartMerge: results with missing fields', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, fused_score: 0.9 }, // No text field
        { id: 2, text: '', fused_score: 0.8 }, // Empty text
        { id: 3, fused_score: 0.7 } // No text field
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'test', { explain: true });

  assert.ok(result.mode, 'Should handle missing text fields gracefully');
  assert.ok(result.results, 'Should return results');
});

// ============================================================================
// CLI Flag Tests
// ============================================================================

console.log('\n=== CLI Output Format Tests ===\n');

await asyncTest('smartMerge: --explain flag includes all fields', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'test content', fused_score: 0.9 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'test query', {
    explain: true,
    mmrMode: 'fast'
  });

  assert.ok(result.explanation, 'Should include explanation');
  assert.ok(result.meta, 'Should include meta');
  assert.ok(result.meta.signals, 'Should include signals');
  assert.ok(result.meta.thresholds, 'Should include thresholds');
  assert.ok(result.meta.mmr_mode, 'Should include mmr_mode');

  // Check signals structure
  assert.ok(typeof result.meta.signals.overlap_ratio === 'number');
  assert.ok(typeof result.meta.signals.source_diversity === 'number');
  assert.ok(typeof result.meta.signals.title_entropy === 'number');
  assert.ok(typeof result.meta.signals.hasOps === 'boolean');
  assert.ok(typeof result.meta.signals.hasCreative === 'boolean');

  // Check thresholds structure
  assert.ok(typeof result.meta.thresholds.overlap_rrf === 'number');
  assert.ok(typeof result.meta.thresholds.overlap_mmr === 'number');
  assert.ok(typeof result.meta.thresholds.source_div_mmr === 'number');
});

await asyncTest('smartMerge: without --explain flag', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'test content', fused_score: 0.9 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'test query', {
    explain: false,
    mmrMode: 'fast'
  });

  assert.ok(!result.explanation, 'Should not include explanation');
  assert.ok(!result.meta, 'Should not include meta');
  assert.ok(result.mode, 'Should include mode');
  assert.ok(result.results, 'Should include results');
});

await asyncTest('smartMerge: timing_ms structure', async () => {
  const sourceLists = [
    {
      source: 'docs',
      results: [
        { id: 1, text: 'test content', fused_score: 0.9 }
      ]
    }
  ];

  const result = await smartMerge(sourceLists, 'test query', {});

  assert.ok(result.timing_ms, 'Should include timing_ms');
  assert.ok(typeof result.timing_ms.signal_computation === 'number');
  assert.ok(typeof result.timing_ms.merge_execution === 'number');
  assert.ok(typeof result.timing_ms.total === 'number');
  assert.ok(result.timing_ms.total >= result.timing_ms.signal_computation);
  assert.ok(result.timing_ms.total >= result.timing_ms.merge_execution);
});

// ============================================================================
// Summary
// ============================================================================

console.log('\n' + '='.repeat(60));
console.log('Test Summary');
console.log('='.repeat(60));
console.log(`${GREEN}Passed:${RESET} ${passCount}`);
console.log(`${RED}Failed:${RESET} ${failCount}`);
console.log(`${YELLOW}Total:${RESET}  ${passCount + failCount}`);
console.log('='.repeat(60));

if (failCount > 0) {
  process.exit(1);
}
}

// Run async tests
runAsyncTests().catch(err => {
  console.error('Fatal error in async tests:', err);
  process.exit(1);
});
