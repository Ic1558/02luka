/**
 * Embedding model adapter for compatibility
 *
 * Handles dimension padding/trimming when switching between models:
 * - nomic-embed-text: 768 dimensions
 * - all-MiniLM-L6-v2: 384 dimensions
 */

/**
 * Pad embedding vector to target dimension
 * @param {number[]} embedding - Source embedding
 * @param {number} targetDim - Target dimension
 * @returns {number[]} Padded embedding
 */
function padEmbedding(embedding, targetDim) {
  if (embedding.length >= targetDim) {
    return embedding.slice(0, targetDim);
  }

  const padded = [...embedding];
  while (padded.length < targetDim) {
    padded.push(0);
  }

  return padded;
}

/**
 * Trim embedding vector to target dimension
 * @param {number[]} embedding - Source embedding
 * @param {number} targetDim - Target dimension
 * @returns {number[]} Trimmed embedding
 */
function trimEmbedding(embedding, targetDim) {
  return embedding.slice(0, targetDim);
}

/**
 * Normalize embedding model name
 * @param {string} modelName - Model name
 * @returns {{name: string, dim: number}}
 */
function normalizeModel(modelName) {
  const modelMap = {
    'nomic-embed-text': { name: 'nomic-embed-text', dim: 768 },
    'all-minilm-l6-v2': { name: 'all-MiniLM-L6-v2', dim: 384 },
    'all-MiniLM-L6-v2': { name: 'all-MiniLM-L6-v2', dim: 384 }
  };

  const normalized = modelMap[modelName];
  if (!normalized) {
    throw new Error(`Unknown embedding model: ${modelName}`);
  }

  return normalized;
}

/**
 * Adapt embedding from source model to target dimension
 * @param {number[]} embedding - Source embedding
 * @param {string} sourceModel - Source model name
 * @param {number} targetDim - Target dimension
 * @returns {number[]} Adapted embedding
 */
function adaptEmbedding(embedding, sourceModel, targetDim) {
  const model = normalizeModel(sourceModel);

  if (model.dim === targetDim) {
    return embedding; // No adaptation needed
  }

  if (model.dim > targetDim) {
    console.log(`[adapter] Trimming ${model.name} embedding: ${model.dim} → ${targetDim}`);
    return trimEmbedding(embedding, targetDim);
  }

  console.log(`[adapter] Padding ${model.name} embedding: ${model.dim} → ${targetDim}`);
  return padEmbedding(embedding, targetDim);
}

module.exports = {
  padEmbedding,
  trimEmbedding,
  normalizeModel,
  adaptEmbedding
};
