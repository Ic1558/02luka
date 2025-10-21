const path = require('path');
const { loadLocalDocuments } = require('./sources/localFiles');
const { scoreSnippets } = require('./relevance');
const { buildTokenBudget } = require('./tokenBudgeter');

/**
 * @typedef {Object} ContextOptions
 * @property {number} [limit] Maximum number of context snippets to return.
 * @property {number} [tokenBudget] Desired token budget for combined context.
 * @property {boolean} [includeDiagnostics] Whether to include scoring diagnostics.
 */

/**
 * @typedef {Object} ContextSnippet
 * @property {string} id Canonical identifier for the snippet.
 * @property {string} sourceId Source document identifier.
 * @property {string} summary Short excerpt of the content.
 * @property {number} relevanceScore Normalized relevance score between 0 and 1.
 * @property {number} freshnessScore Recency boost between 0 and 1.
 * @property {number} estimatedTokens Estimated token size of the snippet.
 */

/**
 * @typedef {Object} ContextResult
 * @property {ContextSnippet[]} snippets Ordered snippets for downstream prompting.
 * @property {number} confidence Overall confidence score (0-1).
 * @property {ReturnType<typeof buildTokenBudget>} tokenBudget Token allocation for downstream model calls.
 * @property {Array<Object>} [diagnostics] Optional scoring diagnostics when requested.
 * @property {Array<Object>} trace Transparency entries describing steps taken.
 */

const DEFAULT_LIMIT = 5;
const DEFAULT_TOKEN_BUDGET = 1200;

/**
 * Build retrieval-augmented context for a query.
 * @param {string} query Natural language query from the user or planner.
 * @param {ContextOptions} [options] Additional configuration overrides.
 * @returns {ContextResult}
 */
function buildContext(query, options = {}) {
  if (!query || typeof query !== 'string') {
    throw new Error('Query is required to build context.');
  }

  const limit = options.limit ?? DEFAULT_LIMIT;
  const tokenBudgetTarget = options.tokenBudget ?? DEFAULT_TOKEN_BUDGET;
  const includeDiagnostics = Boolean(options.includeDiagnostics);

  const documents = loadLocalDocuments({ rootDir: path.resolve(__dirname, '../../docs') });
  const { snippets, diagnostics } = scoreSnippets(query, documents, { limit });

  const selected = snippets.slice(0, limit);
  const totalTokens = selected.reduce((acc, item) => acc + item.estimatedTokens, 0);
  const budget = buildTokenBudget({ target: tokenBudgetTarget, used: totalTokens });

  const confidence = selected.length === 0 ? 0 : Math.min(1, selected[0].relevanceScore + selected[0].freshnessScore / 2);

  const trace = [
    {
      step: 'load-documents',
      what: `Loaded ${documents.length} local documents`,
      why: 'Offline-first context bootstrapping',
      sources: documents.map(doc => doc.id)
    },
    {
      step: 'score-snippets',
      what: `Ranked ${snippets.length} snippets for query`,
      why: 'Lexical similarity and recency blend',
      details: {
        topScore: selected[0]?.relevanceScore ?? 0,
        averageFreshness: selected.reduce((acc, s) => acc + s.freshnessScore, 0) / (selected.length || 1)
      }
    }
  ];

  return {
    snippets: selected,
    confidence,
    tokenBudget: budget,
    diagnostics: includeDiagnostics ? diagnostics : undefined,
    trace
  };
}

/**
 * List available context sources.
 * @returns {Array<{id: string, kind: string, description: string}>}
 */
function listSources() {
  return [
    {
      id: 'local-docs',
      kind: 'filesystem',
      description: 'Repository markdown documentation used for offline retrieval.'
    },
    {
      id: 'drive-placeholder',
      kind: 'drive',
      description: 'Google Drive connector stub pending credential provisioning.'
    },
    {
      id: 'slack-placeholder',
      kind: 'slack',
      description: 'Slack channel history connector (requires ops:approve scope).'
    },
    {
      id: 'crm-placeholder',
      kind: 'crm',
      description: 'CRM data pipeline stub gated behind supervised autonomy.'
    }
  ];
}

module.exports = {
  buildContext,
  listSources
};
