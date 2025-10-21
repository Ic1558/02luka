/* Hybrid search: FTS pre-filter + embedding rerank */

const sqlite3 = require('sqlite3').verbose();
const { getEmbedding, cosineSimilarity } = require('./embedder.cjs');

/**
 * Hybrid search with 3-stage pipeline
 * @param {object} db - SQLite database connection
 * @param {string} query - Search query
 * @param {object} options - Search options
 * @returns {Promise<object>} - Results with timings
 */
async function hybridSearch(db, query, options = {}) {
  const {
    topK = 10,
    prefilterLimit = 50,
    ftsWeight = 0.3,
    semanticWeight = 0.7,
    minScore = 0.0
  } = options;

  const timings = {};
  const t0 = hrNow();

  // Stage 1: FTS pre-filter (fast keyword matching)
  const tFts0 = hrNow();
  const prefiltered = await ftsPrefilter(db, query, prefilterLimit);
  timings.fts_ms = hrSince(tFts0);

  if (prefiltered.length === 0) {
    return {
      results: [],
      count: 0,
      timings: { ...timings, total_ms: hrSince(t0) }
    };
  }

  // Stage 2: Get query embedding
  const tEmbed0 = hrNow();
  const queryEmbedding = await getEmbedding(query);
  timings.embed_ms = hrSince(tEmbed0);

  // Stage 3: Semantic rerank
  const tRank0 = hrNow();
  const reranked = await semanticRerank(
    prefiltered,
    queryEmbedding,
    { ftsWeight, semanticWeight, minScore }
  );
  timings.rerank_ms = hrSince(tRank0);

  // Top K results
  const results = reranked
    .sort((a, b) => b.finalScore - a.finalScore)
    .slice(0, topK);

  timings.total_ms = hrSince(t0);

  return {
    results,
    count: results.length,
    timings
  };
}

/**
 * Stage 1: FTS pre-filter using SQLite FTS5
 * @param {object} db - Database connection
 * @param {string} query - Search query
 * @param {number} limit - Max results
 * @returns {Promise<Array>} - Pre-filtered candidates
 */
async function ftsPrefilter(db, query, limit) {
  return new Promise((resolve, reject) => {
    // Tokenize query and wrap each term in quotes (handles special chars, allows multi-term matching)
    const ftsQuery = query
      .split(/\s+/)
      .filter(Boolean)
      .map(term => `"${term.replace(/"/g, '""')}"`)
      .join(' OR ');

    const sql = `
      SELECT
        dc.id,
        dc.doc_path,
        dc.chunk_index,
        dc.text,
        dc.embedding,
        dc.metadata,
        snippet(document_chunks_fts, 0, '[', ']', '...', 15) AS snippet,
        rank
      FROM document_chunks_fts
      JOIN document_chunks dc ON document_chunks_fts.rowid = dc.id
      WHERE document_chunks_fts MATCH ?
      ORDER BY rank
      LIMIT ?
    `;

    db.all(sql, [ftsQuery, limit], (err, rows) => {
      if (err) return reject(err);

      resolve(rows.map((row, index) => ({
        id: row.id,
        doc_path: row.doc_path,
        chunk_index: row.chunk_index,
        text: row.text,
        embedding: row.embedding ? bufferToFloatArray(row.embedding) : null,
        metadata: row.metadata ? JSON.parse(row.metadata) : {},
        snippet: row.snippet,
        ftsRank: index, // 0 = best match
        ftsScore: normalize(index, 0, limit) // 1.0 = best, 0.0 = worst
      })));
    });
  });
}

/**
 * Stage 2: Semantic rerank using embeddings
 * @param {Array} candidates - Pre-filtered candidates
 * @param {number[]} queryEmbedding - Query embedding vector
 * @param {object} weights - Scoring weights
 * @returns {Array} - Reranked results with scores
 */
async function semanticRerank(candidates, queryEmbedding, weights) {
  const { ftsWeight, semanticWeight, minScore } = weights;

  return candidates
    .map(candidate => {
      // Calculate semantic similarity
      let semanticScore = 0;
      if (candidate.embedding && candidate.embedding.length > 0) {
        semanticScore = cosineSimilarity(queryEmbedding, candidate.embedding);
      }

      // Hybrid score (weighted combination)
      const ftsScore = candidate.ftsScore;
      const finalScore = (ftsWeight * ftsScore) + (semanticWeight * semanticScore);

      return {
        id: candidate.id,
        doc_path: candidate.doc_path,
        chunk_index: candidate.chunk_index,
        text: candidate.text,
        snippet: candidate.snippet,
        metadata: candidate.metadata,
        scores: {
          fts: ftsScore,
          semantic: semanticScore,
          final: finalScore
        },
        finalScore
      };
    })
    .filter(result => result.finalScore >= minScore);
}

/**
 * Convert Buffer (BLOB) to Float32Array
 * @param {Buffer} buffer - Binary embedding data
 * @returns {number[]} - Float array
 */
function bufferToFloatArray(buffer) {
  const floats = new Float32Array(buffer.buffer, buffer.byteOffset, buffer.length / 4);
  return Array.from(floats);
}

/**
 * Normalize value to 0-1 range (inverted for rank)
 * @param {number} value - Current value
 * @param {number} min - Min value
 * @param {number} max - Max value
 * @returns {number} - Normalized (1.0 = best rank)
 */
function normalize(value, min, max) {
  if (max === min) return 1.0;
  return 1.0 - ((value - min) / (max - min));
}

/**
 * High-resolution timestamp (for timing)
 * @returns {bigint} - Nanosecond timestamp
 */
function hrNow() {
  return process.hrtime.bigint();
}

/**
 * Milliseconds since high-res timestamp
 * @param {bigint} start - Start timestamp
 * @returns {number} - Elapsed milliseconds
 */
function hrSince(start) {
  const ns = Number(process.hrtime.bigint() - start);
  return ns / 1e6;
}

module.exports = {
  hybridSearch,
  ftsPrefilter,
  semanticRerank,
  bufferToFloatArray
};
