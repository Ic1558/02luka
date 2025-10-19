#!/usr/bin/env node
/**
 * Minimal Vector Memo System (Phase 6 + 6.5-A)
 *
 * Provides semantic memory storage and retrieval using TF-IDF vectors
 * and cosine similarity for lightweight, file-backed vector search.
 *
 * Functions:
 * - remember({kind, text, meta, importance}) - Store a memory with semantic embedding
 * - recall({query, kind, topK}) - Retrieve similar memories
 * - stats() - Get memory statistics
 * - cleanup({maxAgeDays, minImportance}) - Remove old/low-importance memories
 * - clear() - Clear all memories
 *
 * Features (Phase 6.5-A):
 * - Automatic importance scoring based on kind and metadata
 * - Smart cleanup that preserves recent or important memories
 *
 * Storage: g/memory/vector_index.json
 */

const fs = require('fs');
const path = require('path');

// Configuration
const REPO_ROOT = process.env.REPO_ROOT || path.resolve(__dirname, '..');
const MEMORY_DIR = path.join(REPO_ROOT, 'g', 'memory');
const INDEX_FILE = path.join(MEMORY_DIR, 'vector_index.json');

// Ensure memory directory exists
if (!fs.existsSync(MEMORY_DIR)) {
  fs.mkdirSync(MEMORY_DIR, { recursive: true });
}

// ============================================================================
// TF-IDF Vectorization
// ============================================================================

/**
 * Tokenize text into words (lowercase, alphanumeric only)
 */
function tokenize(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(word => word.length > 2); // Filter out short words
}

/**
 * Calculate term frequency for a document
 */
function termFrequency(tokens) {
  const tf = {};
  const total = tokens.length;

  for (const token of tokens) {
    tf[token] = (tf[token] || 0) + 1;
  }

  // Normalize by document length
  for (const token in tf) {
    tf[token] = tf[token] / total;
  }

  return tf;
}

/**
 * Calculate inverse document frequency for corpus
 */
function inverseDocumentFrequency(documents) {
  const idf = {};
  const numDocs = documents.length;

  // Count documents containing each term
  const docCount = {};
  for (const doc of documents) {
    const uniqueTerms = new Set(doc.tokens);
    for (const term of uniqueTerms) {
      docCount[term] = (docCount[term] || 0) + 1;
    }
  }

  // Calculate IDF
  for (const term in docCount) {
    idf[term] = Math.log(numDocs / docCount[term]);
  }

  return idf;
}

/**
 * Create TF-IDF vector for a document
 */
function createTfidfVector(tf, idf) {
  const vector = {};

  for (const term in tf) {
    vector[term] = tf[term] * (idf[term] || 0);
  }

  return vector;
}

// ============================================================================
// Cosine Similarity
// ============================================================================

/**
 * Calculate cosine similarity between two sparse vectors
 */
function cosineSimilarity(vec1, vec2) {
  let dotProduct = 0;
  let mag1 = 0;
  let mag2 = 0;

  // Get all unique terms
  const allTerms = new Set([...Object.keys(vec1), ...Object.keys(vec2)]);

  for (const term of allTerms) {
    const v1 = vec1[term] || 0;
    const v2 = vec2[term] || 0;

    dotProduct += v1 * v2;
    mag1 += v1 * v1;
    mag2 += v2 * v2;
  }

  if (mag1 === 0 || mag2 === 0) {
    return 0;
  }

  return dotProduct / (Math.sqrt(mag1) * Math.sqrt(mag2));
}

// ============================================================================
// Memory Storage
// ============================================================================

/**
 * Load existing memory index from disk
 */
function loadIndex() {
  if (!fs.existsSync(INDEX_FILE)) {
    return { memories: [], idf: {} };
  }

  try {
    const content = fs.readFileSync(INDEX_FILE, 'utf-8');
    return JSON.parse(content);
  } catch (err) {
    console.error('Error loading memory index:', err.message);
    return { memories: [], idf: {} };
  }
}

/**
 * Save memory index to disk
 */
function saveIndex(index) {
  try {
    fs.writeFileSync(INDEX_FILE, JSON.stringify(index, null, 2));
  } catch (err) {
    console.error('Error saving memory index:', err.message);
    throw err;
  }
}

/**
 * Rebuild IDF scores for entire corpus
 */
function rebuildIdf(memories) {
  const documents = memories.map(m => ({ tokens: m.tokens }));
  return inverseDocumentFrequency(documents);
}

/**
 * Rebuild TF-IDF vectors for all memories
 */
function rebuildVectors(memories, idf) {
  for (const memory of memories) {
    const tf = termFrequency(memory.tokens);
    memory.vector = createTfidfVector(tf, idf);
  }
}

// ============================================================================
// Importance Scoring (Phase 6.5-A)
// ============================================================================

/**
 * Calculate importance score for a memory
 *
 * @param {string} kind - Memory type (plan, solution, error, insight, config)
 * @param {Object} meta - Metadata with optional successRate, reuseCount
 * @param {number} userImportance - User-provided base importance (0.0-1.0)
 * @returns {number} Importance score (0.0-1.0)
 */
function calculateImportance(kind, meta = {}, userImportance = 0.5) {
  let score = userImportance;

  // Kind-based importance
  if (kind === 'error') score += 0.2;
  if (kind === 'insight') score += 0.15;

  // Metadata-based importance
  if (meta.successRate && meta.successRate > 0.9) score += 0.1;
  if (meta.reuseCount && meta.reuseCount > 5) score += 0.1;

  // Cap at 1.0
  return Math.min(1.0, score);
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Store a memory with semantic embedding
 *
 * @param {Object} options
 * @param {string} options.kind - Memory type (e.g., 'plan', 'solution', 'error')
 * @param {string} options.text - Memory content
 * @param {Object} options.meta - Additional metadata
 * @param {number} options.importance - User-provided importance (0.0-1.0, optional)
 * @returns {Object} Stored memory object
 */
function remember({ kind, text, meta = {}, importance = null }) {
  if (!kind || !text) {
    throw new Error('remember() requires kind and text');
  }

  const index = loadIndex();

  // Calculate importance score
  const baseImportance = importance !== null ? importance : 0.5;
  const importanceScore = calculateImportance(kind, meta, baseImportance);

  // Create new memory
  const tokens = tokenize(text);
  const memory = {
    id: `${kind}_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`,
    kind,
    text,
    meta,
    importance: importanceScore,
    tokens,
    vector: {},
    timestamp: new Date().toISOString()
  };

  // Add to index
  index.memories.push(memory);

  // Rebuild IDF and vectors
  index.idf = rebuildIdf(index.memories);
  rebuildVectors(index.memories, index.idf);

  // Save to disk
  saveIndex(index);

  return {
    id: memory.id,
    kind: memory.kind,
    importance: memory.importance,
    timestamp: memory.timestamp
  };
}

/**
 * Retrieve similar memories using cosine similarity
 *
 * @param {Object} options
 * @param {string} options.query - Search query
 * @param {string} options.kind - Filter by memory type (optional)
 * @param {number} options.topK - Number of results to return (default: 5)
 * @returns {Array} Top matching memories with similarity scores
 */
function recall({ query, kind = null, topK = 5 }) {
  if (!query) {
    throw new Error('recall() requires query');
  }

  const index = loadIndex();

  if (index.memories.length === 0) {
    return [];
  }

  // Create query vector
  const queryTokens = tokenize(query);
  const queryTf = termFrequency(queryTokens);
  const queryVector = createTfidfVector(queryTf, index.idf);

  // Calculate similarity scores
  let results = index.memories.map(memory => ({
    id: memory.id,
    kind: memory.kind,
    text: memory.text,
    meta: memory.meta,
    timestamp: memory.timestamp,
    similarity: cosineSimilarity(queryVector, memory.vector)
  }));

  // Filter by kind if specified
  if (kind) {
    results = results.filter(r => r.kind === kind);
  }

  // Sort by similarity (descending) and take top K
  results.sort((a, b) => b.similarity - a.similarity);
  results = results.slice(0, topK);

  return results;
}

/**
 * Get statistics about the memory index
 */
function stats() {
  const index = loadIndex();

  const kindCounts = {};
  for (const memory of index.memories) {
    kindCounts[memory.kind] = (kindCounts[memory.kind] || 0) + 1;
  }

  return {
    totalMemories: index.memories.length,
    byKind: kindCounts,
    vocabularySize: Object.keys(index.idf).length,
    indexFile: INDEX_FILE
  };
}

/**
 * Clean up old or low-importance memories
 *
 * @param {Object} options
 * @param {number} options.maxAgeDays - Keep memories newer than this (default: 90)
 * @param {number} options.minImportance - Keep memories with importance >= this (default: 0.3)
 * @returns {Object} Cleanup results
 */
function cleanup({ maxAgeDays = 90, minImportance = 0.3 } = {}) {
  const index = loadIndex();
  const before = index.memories.length;

  const now = Date.now();
  const cutoff = now - maxAgeDays * 86400000; // Convert days to milliseconds

  // Keep memories that are either:
  // 1. Recent (within maxAgeDays)
  // 2. Important (importance >= minImportance)
  index.memories = index.memories.filter(m => {
    const ts = new Date(m.timestamp).getTime();
    const imp = m.importance ?? 0.5; // Default to 0.5 if no importance field

    return ts >= cutoff || imp >= minImportance;
  });

  const after = index.memories.length;
  const removed = before - after;

  // Rebuild IDF and vectors after cleanup
  if (removed > 0) {
    index.idf = rebuildIdf(index.memories);
    rebuildVectors(index.memories, index.idf);
  }

  saveIndex(index);

  return {
    before,
    after,
    removed,
    kept: after
  };
}

/**
 * Clear all memories (use with caution)
 */
function clear() {
  const index = { memories: [], idf: {} };
  saveIndex(index);
  return { cleared: true };
}

// ============================================================================
// CLI Interface
// ============================================================================

if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];

  try {
    if (command === '--remember') {
      const kind = args[1];

      // Check for --meta flag
      let metaIndex = args.indexOf('--meta');
      let meta = {};
      let textArgs = args.slice(2);

      if (metaIndex !== -1 && metaIndex >= 2) {
        // Extract meta JSON
        const metaStr = args[metaIndex + 1];
        try {
          meta = JSON.parse(metaStr);
        } catch (e) {
          throw new Error('Invalid JSON for --meta: ' + e.message);
        }
        // Remove --meta and its value from text args
        textArgs = args.slice(2, metaIndex);
      }

      const text = textArgs.join(' ');
      const result = remember({ kind, text, meta });
      console.log(JSON.stringify(result, null, 2));
    }
    else if (command === '--recall') {
      const query = args.slice(1).join(' ');
      const results = recall({ query, topK: 3 });
      console.log(JSON.stringify(results, null, 2));
    }
    else if (command === '--recall-kind') {
      const kind = args[1];
      const query = args.slice(2).join(' ');
      const results = recall({ query, kind, topK: 3 });
      console.log(JSON.stringify(results, null, 2));
    }
    else if (command === '--stats') {
      const result = stats();
      console.log(JSON.stringify(result, null, 2));
    }
    else if (command === '--cleanup') {
      // Parse optional parameters
      let maxAgeDays = 90;
      let minImportance = 0.3;

      const maxAgeIndex = args.indexOf('--maxAge');
      if (maxAgeIndex !== -1) {
        maxAgeDays = parseInt(args[maxAgeIndex + 1], 10);
      }

      const minImpIndex = args.indexOf('--minImportance');
      if (minImpIndex !== -1) {
        minImportance = parseFloat(args[minImpIndex + 1]);
      }

      const result = cleanup({ maxAgeDays, minImportance });
      console.log(`🧹 Cleanup complete:`);
      console.log(`   Before: ${result.before} memories`);
      console.log(`   Removed: ${result.removed} memories`);
      console.log(`   After: ${result.after} memories`);
      console.log(JSON.stringify(result, null, 2));
    }
    else if (command === '--clear') {
      const result = clear();
      console.log(JSON.stringify(result, null, 2));
    }
    else {
      console.log('Usage:');
      console.log('  node memory/index.cjs --remember <kind> <text> [--meta <json>]');
      console.log('  node memory/index.cjs --recall <query>');
      console.log('  node memory/index.cjs --recall-kind <kind> <query>');
      console.log('  node memory/index.cjs --stats');
      console.log('  node memory/index.cjs --cleanup [--maxAge <days>] [--minImportance <score>]');
      console.log('  node memory/index.cjs --clear');
      console.log('');
      console.log('Examples:');
      console.log('  node memory/index.cjs --remember plan "Deploy fix" --meta \'{"successRate":0.95}\'');
      console.log('  node memory/index.cjs --cleanup --maxAge 90 --minImportance 0.3');
      process.exit(1);
    }
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  remember,
  recall,
  stats,
  cleanup,
  clear
};
