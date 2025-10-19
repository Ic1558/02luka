#!/usr/bin/env node
/**
 * Minimal Vector Memo System
 *
 * Provides semantic memory storage and retrieval using TF-IDF vectors
 * and cosine similarity for lightweight, file-backed vector search.
 *
 * Functions:
 * - remember({kind, text, meta}) - Store a memory with semantic embedding
 * - recall({query, kind, topK}) - Retrieve similar memories
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
// Public API
// ============================================================================

/**
 * Store a memory with semantic embedding
 *
 * @param {Object} options
 * @param {string} options.kind - Memory type (e.g., 'plan', 'solution', 'error')
 * @param {string} options.text - Memory content
 * @param {Object} options.meta - Additional metadata
 * @returns {Object} Stored memory object
 */
function remember({ kind, text, meta = {} }) {
  if (!kind || !text) {
    throw new Error('remember() requires kind and text');
  }

  const index = loadIndex();

  // Create new memory
  const tokens = tokenize(text);
  const memory = {
    id: `${kind}_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`,
    kind,
    text,
    meta,
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
      const text = args.slice(2).join(' ');
      const result = remember({ kind, text });
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
    else if (command === '--clear') {
      const result = clear();
      console.log(JSON.stringify(result, null, 2));
    }
    else {
      console.log('Usage:');
      console.log('  node memory/index.cjs --remember <kind> <text>');
      console.log('  node memory/index.cjs --recall <query>');
      console.log('  node memory/index.cjs --recall-kind <kind> <query>');
      console.log('  node memory/index.cjs --stats');
      console.log('  node memory/index.cjs --clear');
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
  clear
};
