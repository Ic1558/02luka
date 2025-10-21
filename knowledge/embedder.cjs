/* Embedding generator using @xenova/transformers (all-MiniLM-L6-v2) */

let _embedder = null;
let _pipelinePromise = null;

/**
 * Get embedding vector for text (384 dimensions)
 * @param {string} text - Input text to embed
 * @returns {Promise<number[]>} - 384-dim normalized embedding
 */
async function getEmbedding(text) {
  // Lazy load the model (singleton pattern)
  if (!_embedder) {
    if (!_pipelinePromise) {
      _pipelinePromise = (async () => {
        const { pipeline } = await import('@xenova/transformers');
        return await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
      })();
    }
    _embedder = await _pipelinePromise;
  }

  const output = await _embedder(text, { pooling: 'mean', normalize: true });
  return Array.from(output.data);
}

/**
 * Get embeddings for multiple texts in batch
 * @param {string[]} texts - Array of texts to embed
 * @returns {Promise<number[][]>} - Array of 384-dim embeddings
 */
async function getBatchEmbeddings(texts) {
  if (!_embedder) {
    if (!_pipelinePromise) {
      _pipelinePromise = (async () => {
        const { pipeline } = await import('@xenova/transformers');
        return await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
      })();
    }
    _embedder = await _pipelinePromise;
  }

  const embeddings = [];
  for (const text of texts) {
    const output = await _embedder(text, { pooling: 'mean', normalize: true });
    embeddings.push(Array.from(output.data));
  }
  return embeddings;
}

/**
 * Cosine similarity between two embedding vectors
 * @param {number[]} a - First embedding
 * @param {number[]} b - Second embedding
 * @returns {number} - Similarity score (0-1)
 */
function cosineSimilarity(a, b) {
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

module.exports = {
  getEmbedding,
  getBatchEmbeddings,
  cosineSimilarity
};
