#!/usr/bin/env node
/* RRF (Reciprocal Rank Fusion) Merger v2 with source-level boosting */

/**
 * Merges multiple ranked result lists using RRF algorithm
 * @param {Array<Array<Object>>} sourceLists - Array of ranked result lists
 * @param {Object} options - Merge options
 * @param {Object} options.boosts - Source-level boost weights (default: 1.0 for all)
 * @param {number} options.k - RRF constant (default: 60)
 * @param {number} options.topK - Number of results to return (default: 10)
 * @returns {Array<Object>} - Merged and re-ranked results
 */
function rrfMerge(sourceLists, options = {}) {
  const { boosts = {}, k = 60, topK = 10 } = options;

  // Map to accumulate RRF scores by unique document ID
  const scoreMap = new Map();

  // Process each source list
  sourceLists.forEach((list, sourceIndex) => {
    const sourceName = list.source || `source_${sourceIndex}`;
    const boost = boosts[sourceName] || 1.0;

    // Calculate RRF score for each item in this source
    list.results.forEach((item, rank) => {
      const docId = item.id || item.doc_path || `${sourceName}_${rank}`;

      // RRF formula: 1 / (k + rank)
      const rrfScore = 1.0 / (k + rank);

      if (!scoreMap.has(docId)) {
        scoreMap.set(docId, {
          item: item,
          source: sourceName,
          fused_score: 0,
          boosted_score: 0,
          sources: []
        });
      }

      const entry = scoreMap.get(docId);
      entry.fused_score += rrfScore;
      entry.sources.push({ source: sourceName, rank, rrfScore });
    });
  });

  // Apply boost multipliers to fused scores
  const results = Array.from(scoreMap.values()).map(entry => {
    const boost = boosts[entry.source] || 1.0;
    entry.boosted_score = entry.fused_score * boost;
    return entry;
  });

  // Sort by boosted score (descending) and return top K
  return results
    .sort((a, b) => b.boosted_score - a.boosted_score)
    .slice(0, topK)
    .map(entry => ({
      ...entry.item,
      source: entry.source,
      fused_score: entry.fused_score,
      boosted_score: entry.boosted_score,
      sources: entry.sources
    }));
}

/**
 * Parse boost sources from command line flag
 * Format: --boost-sources=docs:1.2,reports:1.1,memory:0.9
 * @param {string} boostStr - Boost string from CLI
 * @returns {Object} - Boost weights by source name
 */
function parseBoosts(boostStr) {
  const boosts = {};
  if (!boostStr) return boosts;

  const pairs = boostStr.split(',');
  pairs.forEach(pair => {
    const [source, weight] = pair.split(':');
    if (source && weight) {
      boosts[source.trim()] = parseFloat(weight);
    }
  });

  return boosts;
}

/**
 * CLI entry point
 */
function main() {
  const args = process.argv.slice(2);

  // Parse flags
  let boostStr = '';
  let inputFiles = [];

  args.forEach(arg => {
    if (arg.startsWith('--boost-sources=')) {
      boostStr = arg.split('=')[1];
    } else if (!arg.startsWith('--')) {
      inputFiles.push(arg);
    }
  });

  const boosts = parseBoosts(boostStr);

  // Read input from stdin or files
  let inputData = '';

  if (inputFiles.length === 0) {
    // Read from stdin
    const fs = require('fs');
    inputData = fs.readFileSync(0, 'utf-8');
  } else {
    // Read from files
    const fs = require('fs');
    inputData = inputFiles.map(f => fs.readFileSync(f, 'utf-8')).join('\n');
  }

  // Parse input as JSON
  let sourceLists;
  try {
    sourceLists = JSON.parse(inputData);
  } catch (e) {
    console.error('Error: Input must be valid JSON');
    console.error('Expected format: [{"source": "docs", "results": [...]}, ...]');
    process.exit(1);
  }

  // Validate input format
  if (!Array.isArray(sourceLists)) {
    console.error('Error: Input must be an array of source lists');
    process.exit(1);
  }

  // Performance tracking
  const t0 = process.hrtime.bigint();

  // Perform RRF merge
  const merged = rrfMerge(sourceLists, { boosts });

  const t1 = process.hrtime.bigint();
  const elapsedMs = Number(t1 - t0) / 1e6;

  // Output results
  const output = {
    merged_results: merged,
    count: merged.length,
    boosts: boosts,
    timing_ms: elapsedMs
  };

  console.log(JSON.stringify(output, null, 2));

  // Verify performance requirement (<5ms for ≤200 rows)
  const totalRows = sourceLists.reduce((sum, list) => sum + (list.results?.length || 0), 0);
  if (totalRows <= 200 && elapsedMs >= 5.0) {
    console.error(`Warning: Performance degraded (${elapsedMs.toFixed(2)}ms for ${totalRows} rows)`);
  }
}

// Export for module usage
if (require.main === module) {
  main();
} else {
  module.exports = {
    rrfMerge,
    parseBoosts
  };
}
