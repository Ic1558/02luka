const { tokenize } = require('./util/tokenize');

/**
 * Score documents and derive snippets.
 * @param {string} query
 * @param {Array<{id: string, title: string, content: string, updatedAt: Date}>} documents
 * @param {{limit: number}} options
 * @returns {{snippets: Array<{id: string, sourceId: string, summary: string, relevanceScore: number, freshnessScore: number, estimatedTokens: number}>, diagnostics: any[]}}
 */
function scoreSnippets(query, documents, options) {
  const queryTokens = tokenize(query);
  const queryTokenSet = new Set(queryTokens);

  const diagnostics = [];
  const snippets = documents.map(doc => {
    const docTokens = tokenize(doc.content);
    const overlap = docTokens.filter(token => queryTokenSet.has(token));
    const relevance = docTokens.length === 0 ? 0 : overlap.length / Math.sqrt(docTokens.length * (queryTokens.length || 1));

    const daysSinceUpdate = Math.max(0, (Date.now() - doc.updatedAt.getTime()) / (1000 * 60 * 60 * 24));
    const freshness = Math.max(0, Math.min(1, 1 - daysSinceUpdate / 180));

    const preview = doc.content.slice(0, 280).replace(/\s+/g, ' ').trim();
    const estimatedTokens = Math.max(1, Math.round(preview.length / 4));

    const score = 0.8 * relevance + 0.2 * freshness;

    diagnostics.push({
      id: doc.id,
      relevance,
      freshness,
      score,
      overlap
    });

    return {
      id: `${doc.id}#0`,
      sourceId: doc.id,
      summary: preview,
      relevanceScore: Number(score.toFixed(3)),
      freshnessScore: Number(freshness.toFixed(3)),
      estimatedTokens
    };
  }).filter(snippet => snippet.relevanceScore > 0.05)
    .sort((a, b) => b.relevanceScore - a.relevanceScore)
    .slice(0, options.limit * 3); // keep buffer for diagnostics

  return { snippets, diagnostics };
}

module.exports = {
  scoreSnippets
};
