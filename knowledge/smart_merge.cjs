#!/usr/bin/env node
/* Smart Merge Controller v2 - Auto RRF/MMR Selection with --explain + --mmr-mode */

const { cosineSimilarity } = require('./embedder.cjs');
const { rrfMerge } = require('./merge.cjs');

/**
 * Compute Jaccard similarity between two sets (tokenized strings)
 * @param {string} a - First text
 * @param {string} b - Second text
 * @returns {number} - Jaccard coefficient (0-1)
 */
function jaccardSimilarity(a, b) {
  const tokensA = new Set(tokenize(a));
  const tokensB = new Set(tokenize(b));

  const intersection = new Set([...tokensA].filter(x => tokensB.has(x)));
  const union = new Set([...tokensA, ...tokensB]);

  if (union.size === 0) return 0;
  return intersection.size / union.size;
}

/**
 * Tokenize text into normalized tokens
 * @param {string} text - Input text
 * @returns {string[]} - Array of tokens
 */
function tokenize(text) {
  if (!text) return [];
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
}

/**
 * Compute overlap ratio (Jaccard) across all result pairs
 * @param {Array<Object>} results - Array of results with text/snippet fields
 * @returns {number} - Average Jaccard overlap (0-1)
 */
function computeOverlapRatio(results) {
  if (results.length < 2) return 0;

  const texts = results.map(r => r.text || r.snippet || r.title || '');
  let totalOverlap = 0;
  let pairCount = 0;

  for (let i = 0; i < texts.length; i++) {
    for (let j = i + 1; j < texts.length && j < 10; j++) { // Limit pairs for performance
      totalOverlap += jaccardSimilarity(texts[i], texts[j]);
      pairCount++;
    }
  }

  return pairCount > 0 ? totalOverlap / pairCount : 0;
}

/**
 * Compute source diversity (unique sources / total sources)
 * @param {Array<Array<Object>>} sourceLists - Array of source lists
 * @returns {number} - Source diversity ratio (0-1)
 */
function computeSourceDiversity(sourceLists) {
  const allSources = sourceLists.map(list => list.source || 'unknown');
  const uniqueSources = new Set(allSources);

  if (allSources.length === 0) return 0;
  return uniqueSources.size / allSources.length;
}

/**
 * Compute title entropy (Shannon entropy of title tokens)
 * @param {Array<Object>} results - Array of results with title fields
 * @returns {number} - Normalized entropy (0-1)
 */
function computeTitleEntropy(results) {
  const tokens = [];

  results.forEach(r => {
    const title = r.title || r.doc_path || '';
    tokens.push(...tokenize(title));
  });

  if (tokens.length === 0) return 0;

  // Count token frequencies
  const freq = {};
  tokens.forEach(t => {
    freq[t] = (freq[t] || 0) + 1;
  });

  // Compute Shannon entropy
  let entropy = 0;
  const total = tokens.length;

  Object.values(freq).forEach(count => {
    const p = count / total;
    entropy -= p * Math.log2(p);
  });

  // Normalize by maximum possible entropy (log2 of unique tokens)
  const maxEntropy = Math.log2(Object.keys(freq).length);
  return maxEntropy > 0 ? entropy / maxEntropy : 0;
}

/**
 * Detect operational vs creative intent from query keywords
 * @param {string} query - Search query
 * @returns {Object} - { hasOps: boolean, hasCreative: boolean, opsKeywords: string[], creativeKeywords: string[] }
 */
function detectIntent(query) {
  const opsPatterns = [
    'status', 'verify', 'check', 'list', 'show', 'get', 'find',
    'error', 'issue', 'problem', 'fix', 'debug', 'troubleshoot',
    'config', 'setting', 'parameter', 'option', 'flag',
    'deploy', 'install', 'setup', 'run', 'execute', 'start',
    'log', 'report', 'metric', 'monitor', 'health', 'performance'
  ];

  const creativePatterns = [
    'design', 'create', 'build', 'develop', 'implement', 'architect',
    'idea', 'concept', 'approach', 'strategy', 'plan', 'vision',
    'innovative', 'creative', 'novel', 'unique', 'different',
    'explore', 'discover', 'research', 'investigate', 'analyze',
    'optimize', 'improve', 'enhance', 'refactor', 'redesign'
  ];

  const tokens = tokenize(query);
  const opsKeywords = tokens.filter(t => opsPatterns.includes(t));
  const creativeKeywords = tokens.filter(t => creativePatterns.includes(t));

  return {
    hasOps: opsKeywords.length > 0,
    hasCreative: creativeKeywords.length > 0,
    opsKeywords,
    creativeKeywords
  };
}

/**
 * Decide whether to use RRF or MMR based on computed signals
 * @param {Object} signals - Computed signal values
 * @param {Object} thresholds - Decision thresholds
 * @returns {string} - 'rrf' or 'mmr'
 */
function decideMode(signals, thresholds) {
  const { overlap_ratio, source_diversity, hasOps } = signals;
  const { overlap_rrf, overlap_mmr, source_div_mmr } = thresholds;

  // Rule 1: High overlap OR ops intent → RRF (precision/exact matches)
  if (overlap_ratio > overlap_rrf || hasOps) {
    return 'rrf';
  }

  // Rule 2: Low overlap AND high diversity → MMR (diversity/exploration)
  if (overlap_ratio < overlap_mmr || source_diversity > source_div_mmr) {
    return 'mmr';
  }

  // Default: RRF (safer for most queries)
  return 'rrf';
}

/**
 * Generate explanation string for the decision
 * @param {string} mode - Selected mode ('rrf' or 'mmr')
 * @param {Object} signals - Computed signals
 * @param {Object} thresholds - Decision thresholds
 * @returns {string} - Human-readable explanation
 */
function generateExplanation(mode, signals, thresholds) {
  const reasons = [];

  if (mode === 'rrf') {
    if (signals.hasOps) {
      reasons.push(`ops intent (keywords: [${signals.opsKeywords.join(',')}])`);
    }
    if (signals.overlap_ratio > thresholds.overlap_rrf) {
      reasons.push(`high overlap (${signals.overlap_ratio.toFixed(2)} > ${thresholds.overlap_rrf})`);
    }

    if (reasons.length === 0) {
      reasons.push('default (safe for most queries)');
    }

    return `RRF chosen: ${reasons.join(' + ')}`;
  } else {
    if (signals.overlap_ratio < thresholds.overlap_mmr) {
      reasons.push(`low overlap (${signals.overlap_ratio.toFixed(2)} < ${thresholds.overlap_mmr})`);
    }
    if (signals.source_diversity > thresholds.source_div_mmr) {
      reasons.push(`high diversity (${signals.source_diversity.toFixed(2)} > ${thresholds.source_div_mmr})`);
    }
    if (signals.hasCreative) {
      reasons.push(`creative intent (keywords: [${signals.creativeKeywords.join(',')}])`);
    }

    return `MMR chosen: ${reasons.join(' + ')}`;
  }
}

/**
 * MMR algorithm (Maximal Marginal Relevance)
 * @param {Array<Object>} items - Candidate items with scores
 * @param {Object} options - MMR options
 * @returns {Array<Object>} - Diversified results
 */
async function mmrSelect(items, options = {}) {
  const { topK = 10, lambda = 0.5, mode = 'fast', db = null } = options;

  if (items.length === 0) return [];

  const selected = [];
  const remaining = [...items];

  // Select first item (highest relevance)
  selected.push(remaining.shift());

  // Iteratively select items that maximize MMR score
  while (selected.length < topK && remaining.length > 0) {
    let maxScore = -Infinity;
    let maxIndex = -1;

    for (let i = 0; i < remaining.length; i++) {
      const candidate = remaining[i];

      // Relevance score (normalized from existing score)
      const relevance = candidate.fused_score || candidate.finalScore || 0;

      // Compute diversity (minimum similarity to already selected items)
      let minSimilarity = Infinity;

      for (const selectedItem of selected) {
        let similarity;

        if (mode === 'quality' && db) {
          // Quality mode: Use embedding cosine similarity
          // Note: embeddings should be pre-fetched in the input
          if (candidate.embedding && selectedItem.embedding) {
            similarity = cosineSimilarity(candidate.embedding, selectedItem.embedding);
          } else {
            // Fallback to Jaccard if embeddings not available
            const textA = candidate.text || candidate.snippet || candidate.title || '';
            const textB = selectedItem.text || selectedItem.snippet || selectedItem.title || '';
            similarity = jaccardSimilarity(textA, textB);
          }
        } else {
          // Fast mode: Use Jaccard on text
          const textA = candidate.text || candidate.snippet || candidate.title || '';
          const textB = selectedItem.text || selectedItem.snippet || selectedItem.title || '';
          similarity = jaccardSimilarity(textA, textB);
        }

        minSimilarity = Math.min(minSimilarity, similarity);
      }

      // MMR score: λ * relevance - (1-λ) * similarity
      const mmrScore = lambda * relevance - (1 - lambda) * minSimilarity;

      if (mmrScore > maxScore) {
        maxScore = mmrScore;
        maxIndex = i;
      }
    }

    if (maxIndex >= 0) {
      selected.push(remaining.splice(maxIndex, 1)[0]);
    } else {
      break; // No more candidates
    }
  }

  return selected;
}

/**
 * Main smart merge controller
 * @param {Array<Array<Object>>} sourceLists - Array of source lists
 * @param {string} query - Original search query
 * @param {Object} options - Merge options
 * @returns {Promise<Object>} - Merged results with decision metadata
 */
async function smartMerge(sourceLists, query, options = {}) {
  const {
    boosts = {},
    topK = 10,
    explain = false,
    mmrMode = 'fast',
    db = null
  } = options;

  const t0 = hrNow();

  // Define decision thresholds
  const thresholds = {
    overlap_rrf: 0.25,     // RRF if overlap > this
    overlap_mmr: 0.12,     // MMR if overlap < this
    source_div_mmr: 0.55,  // MMR if source diversity > this
    title_entropy_mmr: 0.6 // MMR if title entropy > this (future use)
  };

  // Flatten all results for signal computation
  const allResults = sourceLists.flatMap(list => list.results || []);

  // Compute signals
  const overlapRatio = computeOverlapRatio(allResults);
  const sourceDiversity = computeSourceDiversity(sourceLists);
  const titleEntropy = computeTitleEntropy(allResults);
  const intent = detectIntent(query);

  const signals = {
    overlap_ratio: overlapRatio,
    source_diversity: sourceDiversity,
    title_entropy: titleEntropy,
    hasOps: intent.hasOps,
    hasCreative: intent.hasCreative,
    opsKeywords: intent.opsKeywords,
    creativeKeywords: intent.creativeKeywords
  };

  // Decide mode
  const mode = decideMode(signals, thresholds);

  const t1 = hrNow();

  // Execute merge based on mode
  let results;
  if (mode === 'mmr') {
    // First merge with RRF to get candidate pool
    const rrfCandidates = rrfMerge(sourceLists, { boosts, topK: topK * 3 }); // 3x for MMR pool

    // Apply MMR for diversity
    results = await mmrSelect(rrfCandidates, { topK, mode: mmrMode, db });
  } else {
    // Use RRF directly
    results = rrfMerge(sourceLists, { boosts, topK });
  }

  const t2 = hrNow();

  // Build output
  const output = {
    mode,
    results,
    count: results.length,
    timing_ms: {
      signal_computation: hrSince(t0, t1),
      merge_execution: hrSince(t1, t2),
      total: hrSince(t0)
    }
  };

  // Add explanation if requested
  if (explain) {
    output.explanation = generateExplanation(mode, signals, thresholds);
    output.meta = {
      signals: {
        overlap_ratio: signals.overlap_ratio,
        source_diversity: signals.source_diversity,
        title_entropy: signals.title_entropy,
        hasOps: signals.hasOps,
        hasCreative: signals.hasCreative
      },
      thresholds,
      mmr_mode: mmrMode
    };
  }

  return output;
}

/**
 * Parse command line flags
 * @param {string[]} args - Process arguments
 * @returns {Object} - Parsed options
 */
function parseFlags(args) {
  const options = {
    boosts: {},
    explain: false,
    mmrMode: 'fast',
    query: ''
  };

  args.forEach(arg => {
    if (arg.startsWith('--boost-sources=')) {
      const boostStr = arg.split('=')[1];
      const pairs = boostStr.split(',');
      pairs.forEach(pair => {
        const [source, weight] = pair.split(':');
        if (source && weight) {
          options.boosts[source.trim()] = parseFloat(weight);
        }
      });
    } else if (arg === '--explain') {
      options.explain = true;
    } else if (arg.startsWith('--mmr-mode=')) {
      const mode = arg.split('=')[1];
      if (mode === 'fast' || mode === 'quality') {
        options.mmrMode = mode;
      } else {
        console.error(`Warning: Invalid mmr-mode '${mode}', using 'fast'`);
      }
    } else if (arg.startsWith('--query=')) {
      options.query = arg.split('=')[1];
    } else if (!arg.startsWith('--')) {
      // Assume it's the query if not a flag
      if (!options.query) {
        options.query = arg;
      }
    }
  });

  return options;
}

/**
 * High-resolution timestamp
 * @returns {bigint} - Nanosecond timestamp
 */
function hrNow() {
  return process.hrtime.bigint();
}

/**
 * Milliseconds since high-res timestamp
 * @param {bigint} start - Start timestamp
 * @param {bigint} end - End timestamp (optional, defaults to now)
 * @returns {number} - Elapsed milliseconds
 */
function hrSince(start, end = null) {
  const endTime = end || process.hrtime.bigint();
  const ns = Number(endTime - start);
  return ns / 1e6;
}

/**
 * CLI entry point
 */
async function main() {
  const args = process.argv.slice(2);
  const options = parseFlags(args);

  // Read input from stdin
  const fs = require('fs');
  let inputData = '';

  try {
    inputData = fs.readFileSync(0, 'utf-8');
  } catch (e) {
    console.error('Error: Failed to read input from stdin');
    console.error('Expected format: {"query": "...", "sourceLists": [...]}');
    process.exit(1);
  }

  // Parse input JSON
  let input;
  try {
    input = JSON.parse(inputData);
  } catch (e) {
    console.error('Error: Input must be valid JSON');
    console.error('Expected format: {"query": "...", "sourceLists": [...]}');
    process.exit(1);
  }

  // Validate input
  if (!input.sourceLists || !Array.isArray(input.sourceLists)) {
    console.error('Error: Input must contain "sourceLists" array');
    process.exit(1);
  }

  const query = options.query || input.query || '';

  if (!query) {
    console.error('Warning: No query provided, intent detection will not work');
  }

  // Execute smart merge
  const result = await smartMerge(input.sourceLists, query, {
    boosts: options.boosts,
    explain: options.explain,
    mmrMode: options.mmrMode,
    topK: input.topK || 10
  });

  // Output results
  console.log(JSON.stringify(result, null, 2));

  // Performance warnings
  const totalRows = input.sourceLists.reduce((sum, list) => sum + (list.results?.length || 0), 0);
  const timingMs = result.timing_ms.total;

  if (options.mmrMode === 'fast' && totalRows <= 300 && timingMs >= 20) {
    console.error(`Warning: Fast mode performance degraded (${timingMs.toFixed(2)}ms for ${totalRows} rows)`);
  }

  if (options.mmrMode === 'quality' && totalRows <= 100 && timingMs >= 100) {
    console.error(`Warning: Quality mode performance degraded (${timingMs.toFixed(2)}ms for ${totalRows} rows)`);
  }
}

// Export for module usage
if (require.main === module) {
  main().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
} else {
  module.exports = {
    smartMerge,
    mmrSelect,
    jaccardSimilarity,
    computeOverlapRatio,
    computeSourceDiversity,
    computeTitleEntropy,
    detectIntent,
    decideMode,
    generateExplanation
  };
}
